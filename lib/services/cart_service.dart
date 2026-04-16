import 'package:flutter/foundation.dart';
import 'package:maxbillup/models/cart_item.dart';

/// CartService - Persists cart items across navigation
/// Uses ChangeNotifier for reactive updates with Provider
class CartService extends ChangeNotifier {
  List<CartItem> _cartItems = [];
  String? _savedOrderId;
  String? _customerPhone;
  String? _customerName;
  String? _customerGST;

  // Getters
  List<CartItem> get cartItems => List.unmodifiable(_cartItems);
  String? get savedOrderId => _savedOrderId;
  String? get customerPhone => _customerPhone;
  String? get customerName => _customerName;
  String? get customerGST => _customerGST;
  bool get hasItems => _cartItems.isNotEmpty;
  int get itemCount => _cartItems.length;
  double get totalAmount => _cartItems.fold(0.0, (sum, item) => sum + item.total);

  /// Update cart items
  void updateCart(List<CartItem> items) {
    _cartItems = List<CartItem>.from(items);
    notifyListeners();
  }

  /// Add item to cart
  void addItem(CartItem item) {
    final idx = _cartItems.indexWhere((e) => e.productId == item.productId);
    if (idx != -1) {
      _cartItems[idx].quantity++;
      // Move to top
      final existingItem = _cartItems.removeAt(idx);
      _cartItems.insert(0, existingItem);
    } else {
      _cartItems.insert(0, item);
    }
    notifyListeners();
  }

  /// Remove item from cart by index
  void removeItemAt(int index) {
    if (index >= 0 && index < _cartItems.length) {
      _cartItems.removeAt(index);
      notifyListeners();
    }
  }

  /// Update item at index
  void updateItemAt(int index, CartItem item) {
    if (index >= 0 && index < _cartItems.length) {
      _cartItems[index] = item;
      notifyListeners();
    }
  }

  /// Clear all cart items
  void clearCart() {
    _cartItems.clear();
    _savedOrderId = null;
    _customerPhone = null;
    _customerName = null;
    _customerGST = null;
    notifyListeners();
  }

  /// Set saved order ID (when loading a saved order)
  void setSavedOrderId(String? orderId) {
    _savedOrderId = orderId;
    notifyListeners();
  }

  /// Set customer information
  void setCustomer(String? phone, String? name, String? gst) {
    _customerPhone = phone;
    _customerName = name;
    _customerGST = gst;
    notifyListeners();
  }

  /// Load saved order data into cart
  void loadSavedOrder(String orderId, Map<String, dynamic> orderData) {
    final items = orderData['items'] as List<dynamic>?;
    if (items != null && items.isNotEmpty) {
      _cartItems = items
          .map((item) {
            List<Map<String, dynamic>>? itemTaxes;
            if (item['taxes'] is List && (item['taxes'] as List).isNotEmpty) {
              itemTaxes = (item['taxes'] as List).map((t) => Map<String, dynamic>.from(t as Map)).toList();
            }
            return CartItem(
                productId: item['productId'] ?? '',
                name: item['name'] ?? '',
                price: (item['price'] ?? 0.0).toDouble(),
                cost: (item['cost'] ?? 0.0).toDouble(),
                quantity: (item['quantity'] ?? 1).toDouble(),
                taxes: itemTaxes,
                taxName: item['taxName'],
                taxPercentage: item['taxPercentage']?.toDouble(),
                taxType: item['taxType'],
              );
          })
          .toList();
    }
    _savedOrderId = orderId;
    _customerPhone = orderData['customerPhone'] as String?;
    _customerName = orderData['customerName'] as String?;
    _customerGST = orderData['customerGST'] as String?;
    notifyListeners();
  }
}

