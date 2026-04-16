import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Service to manage product stock locally when offline
/// Uses ChangeNotifier pattern for reactive UI updates
class LocalStockService extends ChangeNotifier {
  static final LocalStockService _instance = LocalStockService._internal();
  factory LocalStockService() => _instance;
  LocalStockService._internal();

  static const String _stockPrefix = 'local_stock_';
  static const String _pendingUpdatesKey = 'pending_stock_updates';

  // In-memory cache for fast access
  final Map<String, int> _stockCache = {};
  bool _initialized = false;

  /// Initialize the service and load cached stock from SharedPreferences
  Future<void> init() async {
    if (_initialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      for (final key in keys) {
        if (key.startsWith(_stockPrefix)) {
          final productId = key.replaceFirst(_stockPrefix, '');
          final stock = prefs.getInt(key);
          if (stock != null) {
            _stockCache[productId] = stock;
          }
        }
      }
      _initialized = true;
      print('📦 LocalStockService initialized with ${_stockCache.length} cached items');
    } catch (e) {
      print('❌ Error initializing LocalStockService: $e');
    }
  }

  /// Update stock locally for a product - NOTIFIES LISTENERS
  Future<void> updateLocalStock(String productId, int quantityChange) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_stockPrefix$productId';

      // Get current stock from memory cache or SharedPreferences
      int currentStock = _stockCache[productId] ?? prefs.getInt(key) ?? 0;

      // Calculate new stock (never go below 0)
      final newStock = (currentStock + quantityChange).clamp(0, 999999);

      // Update both memory cache and SharedPreferences
      _stockCache[productId] = newStock;
      await prefs.setInt(key, newStock);

      print('📦 Stock updated for $productId: $currentStock -> $newStock (change: $quantityChange)');

      // Track pending update for sync when online
      await _addPendingUpdate(productId, quantityChange);

      // NOTIFY ALL LISTENE- This triggeUI rebuild in SaleAll page!
      notifyListeners();
    } catch (e) {
      print('❌ Error updating local stock: $e');
    }
  }

  /// Get stock for a product - uses memory cache for instant access
  int getStock(String productId) {
    return _stockCache[productId] ?? 0;
  }

  /// Check if stock is cached for a product
  bool hasStock(String productId) {
    return _stockCache.containsKey(productId);
  }

  /// Cache stock value from Firestore (also saves to SharedPreferences)
  Future<void> cacheStock(String productId, int stock) async {
    try {
      // Only update if different (to avoid unnecessary notifications)
      if (_stockCache[productId] != stock) {
        _stockCache[productId] = stock;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('$_stockPrefix$productId', stock);
      }
    } catch (e) {
      print('❌ Error caching stock: $e');
    }
  }

  /// Bulk cache stock from Firestore products
  Future<void> cacheStockBulk(Map<String, int> stockMap) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      for (final entry in stockMap.entries) {
        _stockCache[entry.key] = entry.value;
        await prefs.setInt('$_stockPrefix${entry.key}', entry.value);
      }

      // Notify after bulk update
      notifyListeners();
    } catch (e) {
      print('❌ Error bulk caching stock: $e');
    }
  }

  /// Refresh stock from Firestore and notify listeners
  Future<void> refreshFromFirestore(Map<String, int> firestoreStock) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      for (final entry in firestoreStock.entries) {
        _stockCache[entry.key] = entry.value;
        await prefs.setInt('$_stockPrefix${entry.key}', entry.value);
      }

      print('🔄 Stock refreshed from Firestore: ${firestoreStock.length} products');

      // Clear pending updates since we have fresh data
      await clearPendingUpdates();

      // Notify all listeneto update UI
      notifyListeners();
    } catch (e) {
      print('❌ Error refreshing from Firestore: $e');
    }
  }

  /// Add pending stock update for later sync
  Future<void> _addPendingUpdate(String productId, int quantityChange) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final updatesJson = prefs.getString(_pendingUpdatesKey) ?? '[]';
      final updates = List<Map<String, dynamic>>.from(json.decode(updatesJson));

      // Check if update for this product already exists
      final existingIndex = updates.indexWhere((u) => u['productId'] == productId);
      if (existingIndex != -1) {
        // Accumulate the change
        updates[existingIndex]['quantityChange'] =
            (updates[existingIndex]['quantityChange'] as int) + quantityChange;
      } else {
        // Add new pending update
        updates.add({
          'productId': productId,
          'quantityChange': quantityChange,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }

      await prefs.setString(_pendingUpdatesKey, json.encode(updates));
    } catch (e) {
      print('❌ Error adding pending update: $e');
    }
  }

  /// Get all pending stock updates
  Future<List<Map<String, dynamic>>> getPendingUpdates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final updatesJson = prefs.getString(_pendingUpdatesKey) ?? '[]';
      return List<Map<String, dynamic>>.from(json.decode(updatesJson));
    } catch (e) {
      print('❌ Error getting pending updates: $e');
      return [];
    }
  }

  /// Clear pending updates after successful sync
  Future<void> clearPendingUpdates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingUpdatesKey);
      print('✅ Pending stock updates cleared');
    } catch (e) {
      print('❌ Error clearing pending updates: $e');
    }
  }

  /// Clear all local stock cache
  Future<void> clearAllLocalStock() async {
    try {
      _stockCache.clear();

      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().toList();
      for (final key in keys) {
        if (key.startsWith(_stockPrefix)) {
          await prefs.remove(key);
        }
      }

      print('✅ All local stock cache cleared');
      notifyListeners();
    } catch (e) {
      print('❌ Error clearing local stock: $e');
    }
  }

  /// Get all cached stock as a map
  Map<String, int> getAllCachedStock() {
    return Map.from(_stockCache);
  }
}

