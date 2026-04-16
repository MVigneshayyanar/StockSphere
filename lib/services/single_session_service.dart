import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Enforces that one account can be active on one device at a time.
///
/// How it works (client-only):
/// - On login, the app generates a random [sessionId] and writes it to
///   `users/{uid}.activeSessionId`.
/// - Every running device listens to its user doc; if `activeSessionId`
///   changes to something else, it signs out.
///
/// Notes:
/// - This is *not* a security boundary by itself. For stronger enforcement,
///   pair with backend rules / Cloud Functions.
class SingleSessionService {
  SingleSessionService._internal();

  static final SingleSessionService instance = SingleSessionService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  String? _currentSessionId;
  String? _deviceId;

  /// The current in-memory session id for this device (until sign out).
  String? get currentSessionId => _currentSessionId;

  /// Stable per-install device id (stored in Hive).
  Future<String> getDeviceId() async {
    if (_deviceId != null && _deviceId!.isNotEmpty) return _deviceId!;
    final box = await Hive.openBox('app');
    final existing = box.get('deviceId')?.toString();
    if (existing != null && existing.isNotEmpty) {
      _deviceId = existing;
      return existing;
    }
    final newId = _newSessionId('device');
    await box.put('deviceId', newId);
    _deviceId = newId;
    return newId;
  }

  /// Listen for changes to `activeSessionId` and sign out if this device is no
  /// longer the active session.
  Future<void> startSessionListener({required String uid}) async {
    // On fresh app start, `_currentSessionId` is null. If we start listening
    // immediately, we can incorrectly treat the device as "not active" and
    // force a logout. Seed the local session id from Firestore first.
    try {
      final deviceId = await getDeviceId();
      final snap = await _firestore.collection('users').doc(uid).get();
      final data = snap.data();
      final activeSessionId = data?['activeSessionId']?.toString();
      final activeDeviceId = data?['activeDeviceId']?.toString();
      if (activeDeviceId == deviceId && activeSessionId != null && activeSessionId.isNotEmpty) {
        _currentSessionId = activeSessionId;
      }
    } catch (e) {
      debugPrint('SingleSessionService: failed seeding session on start: $e');
    }

    await _startListening(uid: uid);
  }

  /// Establish a session for this device.
  ///
  /// If the account is already active on another device, a takeover request is
  /// created and this future returns an [ActivateSessionResult] with
  /// `needsApproval=true`.
  Future<ActivateSessionResult> activateOrRequestTakeover({
    required String uid,
    required String deviceLabel,
    Duration requestTimeout = const Duration(minutes: 2),
  }) async {
    final deviceId = await getDeviceId();
    final requestedSessionId = _newSessionId(uid);

    final userRef = _firestore.collection('users').doc(uid);
    final snap = await userRef.get();
    final data = snap.data();
    final activeSessionId = data?['activeSessionId']?.toString();
    final activeDeviceId = data?['activeDeviceId']?.toString();

    // If it's already active on this same device, don't rotate sessions.
    // Rotating on every launch would cause needless writes and can lead to UX
    // issues that look like "must login every time".
    if (activeDeviceId == deviceId && activeSessionId != null && activeSessionId.isNotEmpty) {
      _currentSessionId = activeSessionId;
      await _startListening(uid: uid);
      return ActivateSessionResult(activated: true, sessionId: activeSessionId);
    }

    // No active session: claim immediately.
    if (activeSessionId == null || activeSessionId.isEmpty) {
      _currentSessionId = requestedSessionId;
      await userRef.set({
        'activeSessionId': requestedSessionId,
        'activeDeviceId': deviceId,
        'activeDeviceLabel': deviceLabel,
        'activeSessionUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _startListening(uid: uid);
      return ActivateSessionResult(activated: true, sessionId: requestedSessionId);
    }

    // Someone else is active: create takeover request.
    final reqRef = userRef.collection('takeoverRequests').doc();
    final now = Timestamp.now();
    final expiresAt = Timestamp.fromDate(DateTime.now().add(requestTimeout));
    await reqRef.set({
      'status': 'pending',
      'requestedAt': now,
      'expiresAt': expiresAt,
      'requestedByDeviceId': deviceId,
      'requestedByDeviceLabel': deviceLabel,
      'requestedSessionId': requestedSessionId,
      'activeDeviceIdAtRequest': activeDeviceId,
      'activeDeviceLabelAtRequest': data?['activeDeviceLabel']?.toString(),
    });

    // Start listener (so if old device approves and activeSessionId flips, we stay consistent)
    _currentSessionId = requestedSessionId;
    await _startListening(uid: uid);

    return ActivateSessionResult(
      activated: false,
      needsApproval: true,
      requestId: reqRef.id,
      requestedSessionId: requestedSessionId,
      activeDeviceLabel: data?['activeDeviceLabel']?.toString(),
    );
  }

  /// Wait for a takeover request to be approved/denied/expired.
  /// If approved, this device becomes active and returns true.
  Future<bool> waitForTakeoverDecision({
    required String uid,
    required String requestId,
    required String requestedSessionId,
  }) async {
    final userRef = _firestore.collection('users').doc(uid);
    final reqRef = userRef.collection('takeoverRequests').doc(requestId);

    final completer = Completer<bool>();
    StreamSubscription? sub;
    sub = reqRef.snapshots().listen((snap) async {
      if (!snap.exists) return;
      final data = snap.data();
      final status = data?['status']?.toString() ?? 'pending';

      if (status == 'approved') {
        // Takeover granted: set active session now.
        final deviceId = await getDeviceId();
        await userRef.set({
          'activeSessionId': requestedSessionId,
          'activeDeviceId': deviceId,
          'activeDeviceLabel': data?['requestedByDeviceLabel']?.toString(),
          'activeSessionUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await sub?.cancel();
        if (!completer.isCompleted) completer.complete(true);
      } else if (status == 'denied' || status == 'expired' || status == 'cancelled') {
        await sub?.cancel();
        if (!completer.isCompleted) completer.complete(false);
      }
    }, onError: (e) {
      if (!completer.isCompleted) completer.complete(false);
    });

    return completer.future;
  }

  /// Start/Restart listening for session changes.
  Future<void> _startListening({required String uid}) async {
    await _sub?.cancel();

    _sub = _firestore.collection('users').doc(uid).snapshots().listen(
      (snap) async {
        if (!snap.exists) return;
        final data = snap.data();
        if (data == null) return;

        final active = data['activeSessionId']?.toString();
        final local = _currentSessionId;

        // If this device doesn't have a session yet, don't auto-logout.
        // This happens on app cold start before we seed from Firestore.
        if (local == null) return;

        // If the active session in Firestore is different than this device's
        // session, force sign out.
        if (active != null && active.isNotEmpty && active != local) {
          debugPrint('SingleSessionService: session changed, signing out.');
          await forceSignOut(reason: ForceSignOutReason.loggedInOnAnotherDevice);
        }
      },
      onError: (e) {
        debugPrint('SingleSessionService: listener error: $e');
      },
    );
  }

  /// Call on manual logout.
  Future<void> stop() async {
    _currentSessionId = null;
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> forceSignOut({required ForceSignOutReason reason}) async {
    // Avoid repeated sign-out loops.
    await stop();

    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('SingleSessionService: signOut failed: $e');
    }

    // Broadcast the reason so UI can show a confirmation message.
    ForceSignOutBus.instance.emit(reason);
  }

  String _newSessionId(String uid) {
    // good-enough unique id without extra dependencies.
    final now = DateTime.now().microsecondsSinceEpoch;
    return '${uid}_${now}_${identityHashCode(Object())}';
  }
}

class ActivateSessionResult {
  final bool activated;
  final bool needsApproval;
  final String? sessionId;
  final String? requestId;
  final String? requestedSessionId;
  final String? activeDeviceLabel;

  ActivateSessionResult({
    required this.activated,
    this.needsApproval = false,
    this.sessionId,
    this.requestId,
    this.requestedSessionId,
    this.activeDeviceLabel,
  });
}

enum ForceSignOutReason {
  loggedInOnAnotherDevice,
}

/// Simple event bus for sign-out reasons.
class ForceSignOutBus {
  ForceSignOutBus._();

  static final ForceSignOutBus instance = ForceSignOutBus._();

  final StreamController<ForceSignOutReason> _controller = StreamController<ForceSignOutReason>.broadcast();

  Stream<ForceSignOutReason> get stream => _controller.stream;

  void emit(ForceSignOutReason reason) {
    if (_controller.isClosed) return;
    _controller.add(reason);
  }
}

