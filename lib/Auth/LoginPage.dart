import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:heroicons/heroicons.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:provider/provider.dart';
import 'package:maxbillup/utils/language_provider.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/utils/plan_provider.dart';
import 'package:maxbillup/services/single_session_service.dart';

// Ensure these imports match your file structure
import 'package:maxbillup/Sales/NewSale.dart';
import 'package:maxbillup/Auth/BusinessDetailsPage.dart';
import 'package:maxbillup/Admin/Home.dart';

// --- UI CONSTANTS ---
import 'package:maxbillup/Colors.dart';

// Add math import for responsive sizing
import 'dart:math' as math;

// Web Client ID for Google Sign In
// Get this from: https://console.cloud.google.com/ > APIs & Services > Credentials > OAuth 2.0 Client IDs (Web client)
// Format: XXXXXXXXXXXX-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.apps.googleusercontent.com
const String _webClientId = '490905109908-6mbuv8jbcucq3vqanptqa7vp0q3is1tp.apps.googleusercontent.com';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _firestore_service = FirestoreService();

  // Scroll controller to ensure terms remain visible when keyboard opens
  final ScrollController _scrollController = ScrollController();

  bool _isStaff = false;
  bool _hidePass = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // --- Logic Helpers ---

  void _showMsg(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        backgroundColor: isError ? kErrorColor : kPrimaryColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _navigate(String uid, String? identifier) async {
    if (!mounted) return;
    final planProvider = Provider.of<PlanProvider>(context, listen: false);
    await planProvider.initialize();
    if (!mounted) return;

    // Enforce: one account can be active on one device.
    // If already active on another device, ask whether to logout old device.
    final sessionResult = await SingleSessionService.instance.activateOrRequestTakeover(
      uid: uid,
      deviceLabel: identifier ?? 'This device',
    );
    if (!mounted) return;

    if (sessionResult.needsApproval) {
      final activeLabel = (sessionResult.activeDeviceLabel ?? 'another device').trim();
      final confirm = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: kWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Already logged in', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: kBlack87)),
          content: Text(
            'This account is currently active on $activeLabel.\n\nDo you want to logout from the old device and continue here?',
            style: const TextStyle(color: kBlack54, height: 1.5, fontWeight: FontWeight.w500),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.tr('close'), style: const TextStyle(color: kBlack54, fontWeight: FontWeight.w800, fontSize: 12)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('Yes, Logout Old', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
            )
          ],
        ),
      );

      if (confirm != true) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        _showMsg('Login cancelled.', isError: true);
        return;
      }

      // Client-side approval: flips the request status to approved.
      // Old device will detect session flip and logout.
      final reqId = sessionResult.requestId;
      final requestedSessionId = sessionResult.requestedSessionId;
      if (reqId == null || requestedSessionId == null) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        _showMsg('Unable to start login takeover.', isError: true);
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('takeoverRequests')
          .doc(reqId)
          .set({'status': 'approved', 'approvedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));

      final ok = await SingleSessionService.instance.waitForTakeoverDecision(
        uid: uid,
        requestId: reqId,
        requestedSessionId: requestedSessionId,
      );

      if (!ok) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        _showMsg('Login request was not approved.', isError: true);
        return;
      }
    }

    if (identifier != null && identifier.toLowerCase() == 'stocksphere@gmail.com') {
      Navigator.pushReplacement(
        context,
        CupertinoPageRoute(builder: (context) => HomePage(uid: uid, userEmail: identifier)),
      );
    } else {
      Navigator.pushReplacement(
        context,
        CupertinoPageRoute(builder: (context) => NewSalePage(uid: uid, userEmail: identifier)),
      );
    }
  }

  void _showDialog({
    required String title,
    required String message,
    String actionText = 'OK',
    VoidCallback? onAction,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: kBlack87)),
        content: Text(message, style: const TextStyle(color: kBlack54, height: 1.5, fontWeight: FontWeight.w500)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('close'), style: const TextStyle(color: kBlack54, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
          if (onAction != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onAction();
              },
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: Text(actionText, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  // --- Auth Logic (Preserved) ---

  Future<void> _emailLogin() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      _showMsg(context.tr('invalid_email'), isError: true);
      return;
    }
    if (pass.length < 6) {
      _showMsg(context.tr('password_too_short'), isError: true);
      return;
    }

    setState(() => _loading = true);

    try {
      final cred = await _auth.signInWithEmailAndPassword(email: email, password: pass);
      User? user = cred.user;
      if (user == null) throw Exception('Login failed');

      await user.reload();
      user = _auth.currentUser;
      final bool isAuthVerified = user?.emailVerified ?? false;

      QuerySnapshot storeUserQuery = await (await _firestore_service.getStoreCollection('users'))
          .where('uid', isEqualTo: user!.uid)
          .limit(1)
          .get();

      DocumentReference? userRef;
      Map<String, dynamic> userData;

      if (storeUserQuery.docs.isNotEmpty) {
        userRef = storeUserQuery.docs.first.reference;
        userData = storeUserQuery.docs.first.data() as Map<String, dynamic>;
      } else {
        final globalDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (globalDoc.exists) {
          userRef = globalDoc.reference;
          userData = globalDoc.data() as Map<String, dynamic>;
        } else {
          await _auth.signOut();
          setState(() => _loading = false);
          _showMsg(context.tr('login_failed'), isError: true);
          return;
        }
      }

      if (isAuthVerified) {
        Map<String, dynamic> updates = {'lastLogin': FieldValue.serverTimestamp()};
        if (!(userData['isEmailVerified'] ?? false)) {
          updates['isEmailVerified'] = true;
          updates['verifiedAt'] = FieldValue.serverTimestamp();
        }
        if (userData.containsKey('tempPassword')) updates['tempPassword'] = FieldValue.delete();
        await userRef.update(updates);
      } else {
        await userRef.update({'lastLogin': FieldValue.serverTimestamp()});
        await _auth.signOut();
        setState(() => _loading = false);
        _showDialog(
            title: '📧 Verify Email',
            message: 'Please check your inbox and verify your email address to continue.',
            actionText: 'Resend Email',
            onAction: () async {
              await user?.sendEmailVerification();
              _showMsg('Verification email sent!');
            });
        return;
      }

      if (!(userData['isActive'] ?? false)) {
        await _auth.signOut();
        setState(() => _loading = false);
        _showDialog(
          title: '⏳ APPROVAL PENDING',
          message: 'Your account is waiting for Admin approval.',
        );
        return;
      }

      await _firestore_service.notifyStoreDataChanged();
      setState(() => _loading = false);
      _navigate(user.uid, user.email);
    } on FirebaseAuthException catch (e) {
      setState(() => _loading = false);
      _showMsg(e.message ?? 'Login failed', isError: true);
    } catch (e) {
      setState(() => _loading = false);
      _showMsg('Error: $e', isError: true);
    }
  }

  Future<void> _googleLogin() async {
    setState(() => _loading = true);
    try {
      // Use clientId for web platform
      final GoogleSignIn googleSignIn = kIsWeb
          ? GoogleSignIn(clientId: _webClientId)
          : GoogleSignIn();
      await googleSignIn.signOut();
      final GoogleSignInAccount? gUser = await googleSignIn.signIn();
      if (gUser == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final GoogleSignInAuthentication gAuth = await gUser.authentication;
      final credential = GoogleAuthProvider.credential(accessToken: gAuth.accessToken, idToken: gAuth.idToken);

      final userEmail = gUser.email.toLowerCase().trim();

      // Check if admin account
      if (userEmail == 'stocksphere@gmail.com') {
        final userCred = await _auth.signInWithCredential(credential);
        final user = userCred.user;
        if (mounted) setState(() => _loading = false);
        if (user != null) {
          _navigate(user.uid, user.email);
        }
        return;
      }

      // IMPORTANT: Check if email exists as staff account BEFORE signing in with Google
      // This prevents staff members from accessing their staff account via Google login
      final existingUserQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: userEmail)
          .limit(1)
          .get();

      bool isStaffAccount = false;
      if (existingUserQuery.docs.isNotEmpty) {
        final existingUserData = existingUserQuery.docs.first.data();
        final existingRole = existingUserData['role'] as String?;
        // Check if this is a staff account (not owner)
        isStaffAccount = existingRole != null && existingRole.toLowerCase() != 'owner';
      }

      // Proceed with Google sign-in
      final userCred = await _auth.signInWithCredential(credential);
      final user = userCred.user;

      if (user != null) {
        if (isStaffAccount) {
          // This email belongs to a staff account - ALWAYS redirect to create new business
          // Staff accounts should use email/password login, not Google
          if (mounted) setState(() => _loading = false);
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (context) => BusinessDetailsPage(
                uid: user.uid,
                email: user.email,
                displayName: user.displayName,
              ),
            ),
          );
        } else {
          // Check if this Google UID has a user document (existing business owner)
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

          if (userDoc.exists) {
            // Existing business owner - proceed to app
            await _firestore_service.notifyStoreDataChanged();
            if (mounted) setState(() => _loading = false);
            _navigate(user.uid, user.email);
          } else {
            // New user - redirect to business registration
            if (mounted) setState(() => _loading = false);
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (context) => BusinessDetailsPage(
                  uid: user.uid,
                  email: user.email,
                  displayName: user.displayName,
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      _showMsg('Google Sign In Error: $e', isError: true);
    }
  }

  Future<void> _resetPass() async {
    if (_emailCtrl.text.isEmpty) {
      _showMsg('Enter email to reset password', isError: true);
      return;
    }
    setState(() => _loading = true);
    try {
      await _auth.sendPasswordResetEmail(email: _emailCtrl.text.trim());
      _showMsg('Reset link sent!');
    } catch (e) {
      _showMsg('Error sending reset link', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // --- UI Build ---

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, langProvider, _) {
        return Scaffold(
          backgroundColor: kWhite,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final screenWidth = constraints.maxWidth;
                // Keep content a readable width on wide screens, and leave small padding on narrow screens
                final double contentWidth = math.min(420.0, screenWidth - 32.0);

                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentWidth),
                    child: SingleChildScrollView(
                      controller: _scrollController,
                       // Add bottom padding equal to keyboard inset so content (e.g. terms) is not hidden when keyboard is open.
                       padding: EdgeInsets.fromLTRB(16, 20, 16, MediaQuery.of(context).viewInsets.bottom + 20),
                       keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                       child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 24),
                          _buildHeader(context, contentWidth),
                          const SizedBox(height: 24),
                          _buildTabs(context),
                          const SizedBox(height: 20),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: _isStaff ? _buildEmailForm(context) : _buildGoogleForm(context),
                          ),
                          const SizedBox(height: 20),
                          _buildPrimaryActionBtn(context),
                          const SizedBox(height: 28),
                          _buildTerms(context),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  // Responsive header: scales image based on available content width
  Widget _buildHeader(BuildContext context, double maxWidth) {
    final double imgWidth = math.min(300.0, maxWidth * 0.75);
    final double imgHeight = imgWidth * 0.58; // keep a nice aspect ratio

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(context.tr('welcome_to'),
            style: const TextStyle(fontSize: 11, color: kBlack54, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
        const SizedBox(height: 12),
        Image.asset(
          'assets/MAX_my_bill_mic.png',
          width: imgWidth,
          height: imgHeight,
          fit: BoxFit.contain,
        ),
      ],
    );
  }

  Widget _buildTabs(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: kGreyBg,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: kPrimaryColor, width: 1.5),
    ),
    child: Row(
      children: [
        _tabItem(context.tr('Sign In / Sign up'), !_isStaff, true),
        _tabItem('${context.tr('staff')} ${context.tr('login')}', _isStaff, false),
      ],
    ),
  );

  Widget _tabItem(String txt, bool active, bool isCustomer) => Expanded(
    child: GestureDetector(
      onTap: () {
        // Toggle tab and then scroll to bottom so the terms are visible when keyboard opens
        setState(() {
          _isStaff = !isCustomer;
          _loading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          try {
            if (_scrollController.hasClients) {
              await _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          } catch (_) {
            // ignore scrolling errors
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 44,
        decoration: BoxDecoration(
          color: active ? kPrimaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          // Avoid deprecated withOpacity; use withAlpha for consistent precision
          boxShadow: active ? [BoxShadow(color: kPrimaryColor.withAlpha((0.3 * 255).round()), blurRadius: 10, offset: const Offset(0, 4))] : null,
        ),
        child: Center(
          child: Text(txt,
              style: TextStyle(
                  color: active ? kWhite : kBlack54,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5)),
        ),
      ),
    ),
  );

  Widget _buildEmailForm(BuildContext context) => Column(
    key: const ValueKey('email_form'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildTextField(
        _emailCtrl,
        context.tr('email'),
        HeroIcons.envelope,
        keyboardType: TextInputType.emailAddress,
      ),
      const SizedBox(height: 16),
      _buildTextField(
        _passCtrl,
        context.tr('password'),
        HeroIcons.lockClosed,
        obscure: _hidePass,
        suffix: IconButton(
          icon: HeroIcon(
            _hidePass ? HeroIcons.eyeSlash : HeroIcons.eye,
            color: kPrimaryColor,
            size: 20,
          ),
          onPressed: () => setState(() => _hidePass = !_hidePass),
        ),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: _loading ? null : _resetPass,
          child: Text(
            context.tr('forgot_password'),
            style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5),
          ),
        ),
      ),
    ],
  );

  Widget _buildGoogleForm(BuildContext context) => Column(
    key: const ValueKey('google_form'),
    children: [
      const SizedBox(height: 8),
      Text(context.tr('Sign In With Google'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: kBlack54, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
      const SizedBox(height: 32),
      SizedBox(
        width: double.infinity,
        height: 56,
        child: OutlinedButton(
          onPressed: _loading ? null : _googleLogin,
          style: OutlinedButton.styleFrom(
            backgroundColor: kGreyBg,
            side: const BorderSide(color: kGrey200, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 24, height: 24,
                child: Image.asset('assets/google.png', errorBuilder: (ctx, err, stack) => CustomPaint(size: const Size(22, 22), painter: GoogleGPainter())),
              ),
              const SizedBox(width: 14),
              const Text('Google Account', style: TextStyle(fontSize: 14, color: kBlack87, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _buildTextField(
      TextEditingController ctrl,
      String label,
      HeroIcons icon, {
        bool obscure = false,
        Widget? suffix,
        TextInputType? keyboardType,
      }) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: ctrl,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextFormField(
          controller: ctrl,
          obscureText: obscure,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 15, color: kBlack87, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Padding(
              padding: const EdgeInsets.all(12.0),
              child: HeroIcon(icon, color: hasText ? kPrimaryColor : kBlack54, size: 20),
            ),
            floatingLabelBehavior: FloatingLabelBehavior.auto,
            labelStyle: TextStyle(color: hasText ? kPrimaryColor : kBlack54, fontSize: 13, fontWeight: FontWeight.w600),
            floatingLabelStyle: const TextStyle(color: kPrimaryColor, fontSize: 11, fontWeight: FontWeight.w900),
            
            
            
            suffixIcon: suffix,
            filled: true,
            fillColor: const Color(0xFFF8F9FA),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: hasText ? kPrimaryColor : kGrey200, width: hasText ? 1.5 : 1.0),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: hasText ? kPrimaryColor : kGrey200, width: hasText ? 1.5 : 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kPrimaryColor, width: 2.0),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPrimaryActionBtn(BuildContext context) {
    String txt = _isStaff ? context.tr('login_staff') : "Continue With Google";
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _loading ? null : (_isStaff ? _emailLogin : _googleLogin),
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: _loading
            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 3, color: kWhite))
            : Text(txt, style: const TextStyle(color: kWhite, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
      ),
    );
  }

  Widget _buildTerms(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(fontSize: 11, color: kBlack54, height: 1.6, fontWeight: FontWeight.w500),
        children: [
          TextSpan(text: "${context.tr('by_proceeding_agree')} "),
          const TextSpan(text: 'Terms & Conditions', style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w900)),
          const TextSpan(text: ', '),
          const TextSpan(text: 'Privacy Policy', style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w900)),
          const TextSpan(text: ' & '),
          const TextSpan(text: 'Refund Policy', style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w900)),
        ],
      ),
    ),
  );
}

class GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = size.width * 0.22;
    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = strokeWidth..strokeCap = StrokeCap.round;

    const double startAngle = -3.14 / 4;
    final double sweep = 3.14 * 1.6;

    paint.color = kGoogleRed;
    canvas.drawArc(rect, startAngle, sweep * 0.23, false, paint);
    paint.color = kOrange;
    canvas.drawArc(rect, startAngle + sweep * 0.23, sweep * 0.23, false, paint);
    paint.color = kGoogleGreen;
    canvas.drawArc(rect, startAngle + sweep * 0.46, sweep * 0.23, false, paint);
    paint.color = kPrimaryColor;
    canvas.drawArc(rect, startAngle + sweep * 0.69, sweep * 0.31, false, paint);

    final innerPaint = Paint()..color = kWhite..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - strokeWidth * 1.25, innerPaint);

    final tailPaint = Paint()..color = kPrimaryColor..style = PaintingStyle.stroke..strokeWidth = strokeWidth * 0.9..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(center.dx + radius * 0.05, center.dy + radius * 0.25), Offset(center.dx + radius * 0.45, center.dy + radius * 0.05), tailPaint);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
