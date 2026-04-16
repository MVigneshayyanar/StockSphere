import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cache to store the ID in memory for 0ms access
  String? _cachedStoreId;
  DocumentSnapshot? _cachedStoreDoc;
  Map<String, dynamic>? _cachedStoreData;

  // Stream controller to notify listenewhen store data changes
  final _storeDataController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get storeDataStream => _storeDataController.stream;

  /// Clear all cache on logout/login
  void clearCache() {
    _cachedStoreId = null;
    _cachedStoreDoc = null;
    _cachedStoreData = null;
  }

  /// Notify listenethat store data has changed (e.g., logo updated)
  Future<void> notifyStoreDataChanged() async {
    // Force refresh the cache
    clearCache();
    final doc = await getCurrentStoreDoc(forceRefresh: true);
    if (doc != null && doc.exists) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data != null) {
        _storeDataController.add(data);
        debugPrint('FirestoreService: Store data updated and notified to listeners');
      }
    }
  }

  /// Clear cache and prefetch fresh data on login
  Future<void> refreshCacheOnLogin() async {
    clearCache();
    await prefetchStoreId();
    await getCurrentStoreDoc();
  }

  /// Force fetch the store ID and cache it.
  Future<void> prefetchStoreId() async {
    await getCurrentStoreId(forceRefresh: true);
  }

  /// Get the current user's store ID
  Future<String?> getCurrentStoreId({bool forceRefresh = false}) async {
    // 1. Return cached ID immediately if available
    if (!forceRefresh && _cachedStoreId != null) {
      return _cachedStoreId;
    }

    final user = _auth.currentUser;
    final uid = user?.uid;
    final email = user?.email;
    if (uid == null) return null;

    try {
      // 2. Try usecollection first
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        final storeId = data?['storeId']?.toString() ?? data?['storeDocId']?.toString();

        if (storeId != null && storeId.isNotEmpty) {
          _cachedStoreId = storeId;
          return _cachedStoreId;
        }
      }

      // 3. Fallback: Search 'store' collection by Owner UID
      final byUid = await _firestore
          .collection('store')
          .where('ownerUid', isEqualTo: uid)
          .limit(1)
          .get();

      if (byUid.docs.isNotEmpty) {
        final doc = byUid.docs.first;
        _cachedStoreId = doc.data()['storeId']?.toString() ?? doc.id;
        return _cachedStoreId;
      }

      // 4. Fallback: Search 'store' collection by Email
      if (email != null && email.isNotEmpty) {
        final byEmail = await _firestore
            .collection('store')
            .where('ownerEmail', isEqualTo: email)
            .limit(1)
            .get();

        if (byEmail.docs.isNotEmpty) {
          final doc = byEmail.docs.first;
          _cachedStoreId = doc.data()['storeId']?.toString() ?? doc.id;
          return _cachedStoreId;
        }
      }
    } catch (e) {
      print('Error getting store ID: $e');
    }

    return null;
  }

  /// Get the whole store document
  Future<DocumentSnapshot?> getCurrentStoreDoc({bool forceRefresh = false}) async {
    // Return cached doc if available
    if (!forceRefresh && _cachedStoreDoc != null) {
      return _cachedStoreDoc;
    }

    final storeId = await getCurrentStoreId();
    if (storeId == null) return null;

    try {
      final doc = await _firestore.collection('store').doc(storeId).get();
      if (doc.exists) {
        _cachedStoreDoc = doc;
        _cachedStoreData = doc.data() as Map<String, dynamic>?;
        return doc;
      }

      final byField = await _firestore
          .collection('store')
          .where('storeId', isEqualTo: storeId)
          .limit(1)
          .get();
      if (byField.docs.isNotEmpty) {
        _cachedStoreDoc = byField.docs.first;
        _cachedStoreData = byField.docs.first.data() as Map<String, dynamic>?;
        return byField.docs.first;
      }
    } catch (e) {
      print('Error getting store document: $e');
    }
    return null;
  }

  Future<void> setUserStoreId(String storeId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('No authenticated user');

    await _firestore.collection('users').doc(uid).set({
      'storeId': storeId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _cachedStoreId = storeId;
  }

  // =========================================================
  // CORE HELPER METHODS (Store Scoped)
  // =========================================================

  /// Get reference to a store-scoped collection
  Future<CollectionReference> getStoreCollection(String collectionName) async {
    final storeId = await getCurrentStoreId();
    if (storeId == null) {
      throw Exception('No store ID found for current user');
    }
    return _firestore.collection('store').doc(storeId).collection(collectionName);
  }

  /// ✅ THIS WAS MISSING: Get a document reference wrapper
  /// This fixes the error in SalesHistoryPage, Bill.dart, etc.
  Future<DocumentReference> getDocumentReference(String collectionName, String docId) async {
    final collection = await getStoreCollection(collectionName);
    return collection.doc(docId);
  }

  Future<Stream<QuerySnapshot>> getCollectionStream(String collectionName) async {
    final collection = await getStoreCollection(collectionName);
    return collection.snapshots();
  }

  Future<DocumentSnapshot> getDocument(String collectionName, String docId) async {
    final collection = await getStoreCollection(collectionName);
    return collection.doc(docId).get();
  }

  Future<DocumentReference> addDocument(String collectionName, Map<String, dynamic> data) async {
    final collection = await getStoreCollection(collectionName);
    return collection.add(data);
  }

  Future<void> updateDocument(String collectionName, String docId, Map<String, dynamic> data) async {
    final collection = await getStoreCollection(collectionName);
    return collection.doc(docId).update(data);
  }

  Future<void> setDocument(String collectionName, String docId, Map<String, dynamic> data) async {
    final collection = await getStoreCollection(collectionName);
    return collection.doc(docId).set(data);
  }

  Future<void> deleteDocument(String collectionName, String docId) async {
    final collection = await getStoreCollection(collectionName);
    return collection.doc(docId).delete();
  }

  /// Get the next invoice number for the current store (starting from 100001)
  Future<int> getNextInvoiceNumber() async {
    final collection = await getStoreCollection('sales');
    final query = await collection.orderBy('invoiceNumber', descending: true).limit(1).get();
    if (query.docs.isEmpty) return 100001;
    final maxNum = int.tryParse(query.docs.first['invoiceNumber'].toString()) ?? 10000;
    return maxNum < 100001 ? 100001 : maxNum + 1;
  }

  /// Get the next quotation number for the current store (starting from 100001)
  Future<int> getNextQuotationNumber() async {
    final collection = await getStoreCollection('quotations');
    final query = await collection.orderBy('quotationNumber', descending: true).limit(1).get();
    if (query.docs.isEmpty) return 100001;
    final maxNum = int.tryParse(query.docs.first['quotationNumber'].toString()) ?? 10000;
    return maxNum < 100001 ? 100001 : maxNum + 1;
  }

  // Direct access to top-level collections
  CollectionReference get usersCollection => _firestore.collection('users');
  CollectionReference get storeCollection => _firestore.collection('store');
}