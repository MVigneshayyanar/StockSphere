import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:heroicons/heroicons.dart';
import 'package:maxbillup/Sales/QuickSale.dart';
import 'package:maxbillup/Sales/Saved.dart';
import 'package:maxbillup/Sales/components/sale_app_bar.dart';
import 'package:maxbillup/Sales/saleall.dart';
import 'package:maxbillup/components/common_bottom_nav.dart';
import 'package:maxbillup/models/cart_item.dart';
import 'package:maxbillup/Colors.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/amount_formatter.dart';
import 'package:maxbillup/utils/responsive_helper.dart';
import 'package:maxbillup/services/cart_service.dart';
import 'package:maxbillup/services/referral_service.dart';

class NewSalePage extends StatefulWidget {
  final String uid;
  final String? userEmail;
  final Map<String, dynamic>? savedOrderData;
  final String? savedOrderId;

  const NewSalePage({
    super.key,
    required this.uid,
    this.userEmail,
    this.savedOrderData,
    this.savedOrderId,
  });

  @override
  State<NewSalePage> createState() => _NewSalePageState();
}

class _NewSalePageState extends State<NewSalePage> with SingleTickerProviderStateMixin {
  int _selectedTabIndex = 1;
  List<CartItem>? _sharedCartItems;
  String? _loadedSavedOrderId;
  bool _isSearchFocused = false; // Track search focus state

  // Track specific highlighted product ID
  String? _highlightedProductId;

  // Animation counter to force re-animation of same product
  int _animationCounter = 0;

  // Animation controller for smooth highlight effect
  AnimationController? _highlightController;
  Animation<Color?>? _highlightAnimation;

  int _cartVersion = 0;

  late String _uid;
  String? _userEmail;

  double _cartHeight = 200;
  final double _minCartHeight = 200;
  double _maxCartHeight = 600;

  String? _selectedCustomerPhone;
  String? _selectedCustomerName;
  String? _selectedCustomerGST;

  // Saved order tracking
  int _savedOrderCount = 0;
  String? _savedOrderName; // Track the saved order name


  @override
  void initState() {
    super.initState();
    _uid = widget.uid;
    _userEmail = widget.userEmail;

    // Initialize animation controller
    _highlightController = AnimationController(
      duration: const Duration(milliseconds: 1000),  // Increased from 600ms to 1000ms for better visibility
      vsync: this,
    );

    _highlightAnimation = ColorTween(
      begin: Colors.green.withValues(alpha: 0.6),  // More prominent green (60% opacity)
      end: Colors.green.withValues(alpha: 0.0),    // Fade to transparent
    ).animate(CurvedAnimation(
      parent: _highlightController!,
      curve: Curves.easeOut,  // Smooth fade out
    ));

    // Load cart from CartService (persisted across navigation)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cartService = context.read<CartService>();
      if (cartService.hasItems) {
        setState(() {
          _sharedCartItems = List<CartItem>.from(cartService.cartItems);
          _loadedSavedOrderId = cartService.savedOrderId;
          _selectedCustomerPhone = cartService.customerPhone;
          _selectedCustomerName = cartService.customerName;
          _selectedCustomerGST = cartService.customerGST;
        });
      }

      // Check and show referral popup if needed
      _checkAndShowReferralPopup();
    });

    if (widget.savedOrderData != null) {
      _loadSavedOrderData(widget.savedOrderData!);
      _loadedSavedOrderId = widget.savedOrderId;
      _selectedTabIndex = 1; // Switch to "All" tab to show the cart with items
    }

    // Listen to saved ordecount
    _listenToSavedOrdersCount();

    // Track app launch for referral tracking
    ReferralService.trackAppLaunch();
  }

  Future<void> _checkAndShowReferralPopup() async {
    // Wait a bit for the page to fully load
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final shouldShow = await ReferralService.shouldShowReferral();
    if (shouldShow && mounted) {
      await ReferralService.showReferralDialog(context);
    }
  }

  @override
  void dispose() {
    _highlightController?.dispose();
    super.dispose();
  }

  void _listenToSavedOrdersCount() async {
    try {
      final firestoreService = FirestoreService();
      final stream = await firestoreService.getCollectionStream('savedOrders');
      stream.listen((snapshot) {
        if (mounted) {
          setState(() {
            _savedOrderCount = snapshot.docs.length;
          });
        }
      });
    } catch (e) {
      // Handle error silently
    }
  }


  void _loadSavedOrderData(Map<String, dynamic> orderData) {
    // Extract order name from saved order data
    _savedOrderName = orderData['orderName'] as String?;

    final items = orderData['items'] as List<dynamic>?;
    if (items != null && items.isNotEmpty) {
      final cartItems = items
          .map((item) => CartItem(
        productId: item['productId'] ?? '',
        name: item['name'] ?? '',
        price: (item['price'] ?? 0).toDouble(),
        quantity: (item['quantity'] ?? 1).toDouble(),
        taxName: item['taxName'] as String?,
        taxPercentage: item['taxPercentage'] != null ? (item['taxPercentage'] as num).toDouble() : null,
        taxType: item['taxType'] as String?,
      ))
          .toList();

      // Sync with CartService for persistence
      context.read<CartService>().updateCart(cartItems);
      // ALWAYS set the saved order ID in CartService when loading saved order
      // This ensures it persists even after app restart
      final orderId = _loadedSavedOrderId ?? widget.savedOrderId;
      if (orderId != null) {
        context.read<CartService>().setSavedOrderId(orderId);
      }

      setState(() {
        _sharedCartItems = cartItems;
        // Don't set customer information - this is a saved order, not a customer order
      });
    }
  }

  void _handleTabChange(int index) {
    setState(() {
      _selectedTabIndex = index;
    });
  }

  void _handleLoadSavedOrder(String orderId, Map<String, dynamic> data) {
    // Set the loaded order ID first
    _loadedSavedOrderId = orderId;
    // Load the order data directly
    _loadSavedOrderData(data);
    // Set savedOrderId in CartService
    context.read<CartService>().setSavedOrderId(orderId);

    // Switch to "View All" tab (index 1)
    setState(() {
      _selectedTabIndex = 1;
      _cartVersion++; // Increment to refresh the view
    });
  }

  void _showCustomerInputDialog(String orderId, Map<String, dynamic> data) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: kWhite,
        shape: RoundedRectangleBorder(borderRadius: R.radius(context, 16)),
        title: Text('Customer Information',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: R.sp(context, 16))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Please provide customer name or phone number',
                style: TextStyle(color: kBlack54, fontSize: R.sp(context, 13))),
            SizedBox(height: R.sp(context, 16)),
            ValueListenableBuilder<TextEditingValue>(
      valueListenable: nameController,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Customer Name',
                prefixIcon: const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: HeroIcon(HeroIcons.user, color: kPrimaryColor, size: 20),
                ),
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
                labelStyle: TextStyle(color: hasText ? kPrimaryColor : kBlack54, fontSize: 13, fontWeight: FontWeight.w600),
                floatingLabelStyle: TextStyle(color: hasText ? kPrimaryColor : kPrimaryColor, fontSize: 11, fontWeight: FontWeight.w900),
              ),
            
);
      },
    ),
            const SizedBox(height: 12),
            ValueListenableBuilder<TextEditingValue>(
      valueListenable: phoneController,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: HeroIcon(HeroIcons.phone, color: kPrimaryColor, size: 20),
                ),
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
                labelStyle: TextStyle(color: hasText ? kPrimaryColor : kBlack54, fontSize: 13, fontWeight: FontWeight.w600),
                floatingLabelStyle: TextStyle(color: hasText ? kPrimaryColor : kPrimaryColor, fontSize: 11, fontWeight: FontWeight.w900),
              ),
            
);
      },
    ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: kBlack54, fontWeight: FontWeight.w800)),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();

              if (name.isEmpty && phone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide at least name or phone number'),
                    backgroundColor: kErrorColor,
                  ),
                );
                return;
              }

              // Update data with customer info
              data['customerName'] = name.isEmpty ? 'Guest' : name;
              data['customerPhone'] = phone;

              Navigator.pop(context);

              // Set the loaded order ID first
              _loadedSavedOrderId = orderId;
              // Load the order data
              _loadSavedOrderData(data);
              // Set savedOrderId in CartService
              context.read<CartService>().setSavedOrderId(orderId);

              // Switch to "View All" tab (index 1)
              setState(() {
                _selectedTabIndex = 1;
                _cartVersion++; // Increment to refresh the view
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Continue', style: TextStyle(color: kWhite, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _handleSearchFocusChange(bool isFocused) {
    print('🔍 Search focus changed: $isFocused'); // Debug
    setState(() {
      _isSearchFocused = isFocused;
    });
    print('🔍 State updated - _isSearchFocused: $_isSearchFocused, shouldShowCart: ${_sharedCartItems != null && _sharedCartItems!.isNotEmpty}'); // Debug
  }

  /// Enhanced logic to detect which specific item changed and trigger its highlight.
  void _updateCartItems(List<CartItem> items) {
    print('🔄 _updateCartItems called with ${items.length} items');
    String? triggerId;
    List<CartItem> updatedItems = List<CartItem>.from(items);

    // Sync with CartService for persistence across navigation
    context.read<CartService>().updateCart(updatedItems);

    // Simple approach: The first item in the cart is always the one just added/modified
    // because saleall.dart moves it to index 0
    if (items.isNotEmpty) {
      triggerId = items[0].productId;
      print('✅ Triggering animation for first item (most recently modified): $triggerId');
    }

    print('🎯 Final triggerId: $triggerId');

    // Move the triggered item to the top (should already be there, but ensure it)
    if (triggerId != null) {
      final idx = updatedItems.indexWhere((e) => e.productId == triggerId);
      if (idx != -1 && idx != 0) {
        final item = updatedItems.removeAt(idx);
        updatedItems.insert(0, item);
      }

      // Always trigger highlight - the counter ensures animation restarts even for same item
      print('🟢 Calling _triggerHighlight for $triggerId');
      _triggerHighlight(triggerId, updatedItems);
    } else {
      print('⚠️ No trigger detected, just updating state');
      setState(() {
        _sharedCartItems = updatedItems.isNotEmpty ? updatedItems : null;
      });
    }
  }

  void _triggerHighlight(String productId, List<CartItem> updatedItems) {
    print('🎬 _triggerHighlight called for productId: $productId');
    print('   Current _highlightedProductId: $_highlightedProductId');
    print('   Current _animationCounter: $_animationCounter');

    // Always reset and restart animation, even for same product
    _highlightController?.reset();
    print('   ✓ Animation controller reset');

    setState(() {
      _highlightedProductId = productId;
      _animationCounter++; // Increment to force state change
      _sharedCartItems = updatedItems.isNotEmpty ? updatedItems : null;
      print('   ✓ State updated - new counter: $_animationCounter');
    });

    // Start the highlight animation
    _highlightController?.forward();
    print('   ✓ Animation started forward');

    // Clear highlight after animation completes + delay
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && _highlightedProductId == productId) {
        print('   🔚 Clearing highlight for $productId');
        setState(() {
          _highlightedProductId = null;
        });
      }
    });
  }

  void _removeSingleItem(int idx) {
    if (_sharedCartItems == null) return;
    final updatedList = List<CartItem>.from(_sharedCartItems!);
    updatedList.removeAt(idx);
    setState(() {
      _cartVersion++;
    });
    _updateCartItems(updatedList);
  }

  void _showEditCartItemDialog(int idx) async {
    final cartService = Provider.of<CartService>(context, listen: false);
    final cartItems = cartService.cartItems;

    if (idx < 0 || idx >= cartItems.length) return;

    final item = cartItems[idx];
    final nameController = TextEditingController(text: item.name);
    final priceController = TextEditingController(text: item.price.toString());
    final qtyController = TextEditingController(text: item.quantity.toString());

    // Fetch product data to get stock information
    bool stockEnabled = false;
    double availableStock = 0.0;

    if (item.productId.isNotEmpty && !item.productId.startsWith('qs_')) {
      try {
        final productDoc = await FirestoreService().getDocument('Products', item.productId);
        if (productDoc.exists) {
          final data = productDoc.data() as Map<String, dynamic>;
          stockEnabled = data['stockEnabled'] ?? false;
          availableStock = (data['currentStock'] ?? 0.0).toDouble();
        }
      } catch (e) {
        debugPrint('Error fetching product stock: $e');
      }
    }

    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          final currentQty = double.tryParse(qtyController.text) ?? 1.0;
          final bool exceedsStock = stockEnabled && currentQty > availableStock;

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Edit Cart Item', style: TextStyle(fontWeight: FontWeight.w600, fontSize: R.sp(context, 18))),
                IconButton(
                  icon: const HeroIcon(HeroIcons.xMark, color: Colors.grey),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _dialogLabel('Product Name'),
                  _dialogInput(nameController, 'Enter product name'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _dialogLabel('Price'),
                            _dialogInput(priceController, '0.00', isNumber: true),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _dialogLabel('Quantity'),
                            Container(
                              height: R.sp(context, 48),
                              decoration: BoxDecoration(
                                color: kGreyBg,
                                borderRadius: R.radius(context, 10),
                                border: Border.all(color: kGrey300),
                              ),
                              child: Row(
                                children: [
                                  // Minus button
                                  GestureDetector(
                                    onTap: () {
                                      double current = double.tryParse(qtyController.text) ?? 1.0;
                                      if (current > 0.1) {
                                        double newQty = current >= 1 ? current - 1 : current - 0.1;
                                        if (newQty < 0.1) newQty = 0.1;
                                        setDialogState(() => qtyController.text = newQty.toStringAsFixed(newQty < 1 ? 3 : 1).replaceAll(RegExp(r'\.?0+$'), ''));
                                      } else {
                                        Navigator.of(context).pop();
                                        _removeSingleItem(idx);
                                      }
                                    },
                                    child: Container(
                                      width: R.sp(context, 42),
                                      height: double.infinity,
                                      decoration: BoxDecoration(
                                        color: kGreyBg,
                                        borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(R.sp(context, 9)),
                                          bottomLeft: Radius.circular(R.sp(context, 9)),
                                        ),
                                      ),
                                      child: Center(
                                        child: HeroIcon(
                                          (double.tryParse(qtyController.text) ?? 1.0) <= 0.1
                                              ? HeroIcons.trash
                                              : HeroIcons.minus,
                                          color: (double.tryParse(qtyController.text) ?? 1.0) <= 0.1
                                              ? kErrorColor
                                              : kPrimaryColor,
                                          size: R.sp(context, 18),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Divider
                                  Container(width: 1, color: kGrey300),
                                  // Quantity TextField (no border)
                                  Expanded(
                                    child: TextField(
                                      controller: qtyController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      textAlign: TextAlign.center,
                                      onChanged: (v) => setDialogState(() {}),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: R.sp(context, 16),
                                        color: kBlack87,
                                      ),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: R.sp(context, 4),
                                          vertical: R.sp(context, 12),
                                        ),
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                  // Divider
                                  Container(width: 1, color: kGrey300),
                                  // Plus button
                                  GestureDetector(
                                    onTap: () {
                                      double current = double.tryParse(qtyController.text) ?? 0.0;
                                      double newQty = current >= 1 ? current + 1 : current + 0.1;
                                      if (stockEnabled && newQty > availableStock) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Maximum stock available: ${availableStock.toStringAsFixed(availableStock % 1 == 0 ? 0 : 2)}'),
                                            backgroundColor: kErrorColor,
                                            behavior: SnackBarBehavior.floating,
                                            duration: const Duration(seconds: 2),
                                          ),
                                        );
                                        return;
                                      }
                                      setDialogState(() => qtyController.text = newQty.toStringAsFixed(newQty < 1 ? 3 : 1).replaceAll(RegExp(r'\.?0+$'), ''));
                                    },
                                    child: Container(
                                      width: R.sp(context, 42),
                                      height: double.infinity,
                                      decoration: BoxDecoration(
                                        color: kGreyBg,
                                        borderRadius: BorderRadius.only(
                                          topRight: Radius.circular(R.sp(context, 9)),
                                          bottomRight: Radius.circular(R.sp(context, 9)),
                                        ),
                                      ),
                                      child: Center(
                                        child: HeroIcon(
                                          HeroIcons.plus,
                                          color: kPrimaryColor,
                                          size: R.sp(context, 18),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (exceedsStock) ...[
                              SizedBox(height: R.sp(context, 8)),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: R.sp(context, 8), vertical: R.sp(context, 6)),
                                decoration: BoxDecoration(
                                  color: kErrorColor.withOpacity(0.1),
                                  borderRadius: R.radius(context, 8),
                                  border: Border.all(color: kErrorColor.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    HeroIcon(HeroIcons.exclamationTriangle, color: kErrorColor, size: R.sp(context, 16)),
                                    SizedBox(width: R.sp(context, 6)),
                                    Expanded(
                                      child: Text(
                                        'Only ${availableStock.toStringAsFixed(availableStock % 1 == 0 ? 0 : 2)} kg available in stock',
                                        style: TextStyle(
                                          color: kErrorColor,
                                          fontSize: R.sp(context, 11),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            actions: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: R.sp(context, 4), vertical: R.sp(context, 4)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: exceedsStock ? null : () {
                          final newName = nameController.text.trim();
                          final newPrice = double.tryParse(priceController.text.trim()) ?? item.price;
                          final newQty = double.tryParse(qtyController.text.trim()) ?? 1.0;

                          if (stockEnabled && newQty > availableStock) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Cannot save: Only ${availableStock.toStringAsFixed(availableStock % 1 == 0 ? 0 : 2)} kg available in stock'),
                                backgroundColor: kErrorColor,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }

                          if (newQty <= 0) {
                            Navigator.of(context).pop();
                            _removeSingleItem(idx);
                          } else {
                            final updatedItems = List<CartItem>.from(_sharedCartItems!);
                            updatedItems[idx] = CartItem(
                              productId: item.productId,
                              name: newName,
                              price: newPrice,
                              quantity: newQty,
                              taxName: item.taxName,
                              taxPercentage: item.taxPercentage,
                              taxType: item.taxType,
                            );
                            _updateCartItems(updatedItems);
                            Navigator.of(context).pop();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: exceedsStock ? kGrey300 : kPrimaryColor,
                          shape: RoundedRectangleBorder(borderRadius: R.radius(context, 12)),
                          elevation: 0,
                          padding: EdgeInsets.symmetric(vertical: R.sp(context, 14)),
                        ),
                        child: Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: R.sp(context, 15))),
                      ),
                    ),
                    SizedBox(height: R.sp(context, 8)),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _removeSingleItem(idx);
                        },
                        icon: HeroIcon(HeroIcons.trash, color: kErrorColor, size: R.sp(context, 18)),
                        label: Text('Remove Item', style: TextStyle(color: kErrorColor, fontWeight: FontWeight.bold, fontSize: R.sp(context, 14))),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: kErrorColor.withOpacity(0.4)),
                          shape: RoundedRectangleBorder(borderRadius: R.radius(context, 12)),
                          padding: EdgeInsets.symmetric(vertical: R.sp(context, 12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        });
      },
    );
  }

  void _handleClearCart() {
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Clear Cart?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('This will remove all items from your current order and reset the page.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Keep Items', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Clear Total Cart', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ).then((confirm) {
      if (confirm == true && mounted) {
        context.read<CartService>().clearCart();
        setState(() {
          _sharedCartItems = null;
          _loadedSavedOrderId = null;
          _savedOrderName = null;
          _cartVersion++;
          _highlightedProductId = null;
          _isSearchFocused = false;
          _selectedCustomerPhone = null;
          _selectedCustomerName = null;
          _selectedCustomerGST = null;
        });
        _updateCartItems([]);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) FocusManager.instance.primaryFocus?.unfocus();
        });
      }
    });
  }

  Widget _dialogLabel(String text) => Padding(
    padding: EdgeInsets.only(bottom: R.sp(context, 6), left: R.sp(context, 4)),
    child: Text(text, style: TextStyle(fontSize: R.sp(context, 12), fontWeight: FontWeight.w800, color: Colors.black54)),
  );

  Widget _dialogInput(TextEditingController ctrl, String hint, {bool isNumber = false, bool enabled = true}) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: ctrl,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextField(
      controller: ctrl,
      enabled: enabled,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: TextStyle(
        fontSize: R.sp(context, 15),
       fontWeight: FontWeight.bold,
        color: enabled ? Colors.black : Colors.black45,
      ),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
        contentPadding: EdgeInsets.symmetric(horizontal: R.sp(context, 16), vertical: R.sp(context, 14)),
        border: OutlineInputBorder(
          borderRadius: R.radius(context, 12),
          borderSide: BorderSide(color: hasText ? kPrimaryColor : kGrey200, width: hasText ? 1.5 : 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: R.radius(context, 12),
          borderSide: BorderSide(color: hasText ? kPrimaryColor : kGrey200, width: hasText ? 1.5 : 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: R.radius(context, 12),
          borderSide: const BorderSide(color: kPrimaryColor, width: 2.0),
        ),
        labelStyle: TextStyle(color: hasText ? kPrimaryColor : kBlack54, fontSize: R.sp(context, 13), fontWeight: FontWeight.w600),
        floatingLabelStyle: TextStyle(color: hasText ? kPrimaryColor : kPrimaryColor, fontSize: R.sp(context, 11), fontWeight: FontWeight.w900),
      ),
    
);
      },
    );
  }

  void _setSelectedCustomer(String? phone, String? name, String? gst) {
    // Sync with CartService for persistence
    context.read<CartService>().setCustomer(phone, name, gst);

    setState(() {
      _selectedCustomerPhone = phone;
      _selectedCustomerName = name;
      _selectedCustomerGST = gst;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;

    _maxCartHeight = screenHeight - topPadding - 350;

    // Listen to CartService for changes (e.g., when cart is cleared from Bill page)
    final cartService = Provider.of<CartService>(context);

    // Sync local cart state with CartService
    if (cartService.cartItems.isEmpty && _sharedCartItems != null) {
      // Cart was cleared externally (e.g., from Bill page)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _sharedCartItems = null;
            _selectedCustomerPhone = null;
            _selectedCustomerName = null;
            _selectedCustomerGST = null;
            _loadedSavedOrderId = null;
            _savedOrderName = null; // Clear saved order name when cart is cleared
          });
        }
      });
    } else if (cartService.cartItems.isNotEmpty && (_sharedCartItems == null || _sharedCartItems!.length != cartService.cartItems.length)) {
      // Cart was updated externally, sync it
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _sharedCartItems = List<CartItem>.from(cartService.cartItems);
          });
        }
      });
    }

    // Calculate dynamic cart height based on search focus
    // 120px in search mode: enough for header(40px) + 1 item(40px) + footer(40px)
    final double dynamicCartHeight = _isSearchFocused ? 120 : _cartHeight;
    final bool shouldShowCart = _sharedCartItems != null && _sharedCartItems!.isNotEmpty;

    // Only reserve space for minimum cart height to allow overlay expansion
    final double reservedCartSpace = shouldShowCart ? (_isSearchFocused ? 120 : _minCartHeight) : 0;

    print('🎨 Building NewSale - Focus: $_isSearchFocused, ShowCart: $shouldShowCart, CartHeight: $dynamicCartHeight'); // Debug

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Column(
            children: [
              // Top spacing: only reserve space for minimum cart height
              // This allows cart to expand and overlay other content
              SizedBox(
                height: topPadding+2 + (reservedCartSpace > 0 ? reservedCartSpace + 12 : 0),
              ),

              // AppBar: Only show when search is NOT focused
              if (!_isSearchFocused)
                SaleAppBar(
                  selectedTabIndex: _selectedTabIndex,
                  onTabChanged: _handleTabChange,
                  screenWidth: screenWidth,
                  screenHeight: screenHeight,
                  uid: _uid,
                  userEmail: _userEmail,
                  savedOrderCount: _savedOrderCount,
                ),

              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _selectedTabIndex == 0
                      ? SavedOrdersPage(
                        key: ValueKey('saved_$_cartVersion'),
                        uid: _uid,
                        userEmail: _userEmail,
                        onLoadOrder: _handleLoadSavedOrder,
                      )
                      : _selectedTabIndex == 1
                      ? SaleAllPage(
                        key: ValueKey('all_$_cartVersion'),
                        uid: _uid,
                        userEmail: _userEmail,
                        savedOrderData: _savedOrderName != null
                            ? {'orderName': _savedOrderName}
                            : null, // Pass null when no saved order name
                        onCartChanged: _updateCartItems,
                        initialCartItems: _sharedCartItems,
                        savedOrderId: _loadedSavedOrderId,
                        onSearchFocusChanged: _handleSearchFocusChange,
                        customerPhone: _selectedCustomerPhone,
                        customerName: _selectedCustomerName,
                        customerGST: _selectedCustomerGST,
                        onCustomerChanged: _setSelectedCustomer,
                      )
                      : QuickSalePage(
                        key: ValueKey('quick_$_cartVersion'),
                        uid: _uid,
                        userEmail: _userEmail,
                        initialCartItems: _sharedCartItems,
                        onCartChanged: _updateCartItems,
                        savedOrderId: _loadedSavedOrderId,
                        customerPhone: _selectedCustomerPhone,
                        customerName: _selectedCustomerName,
                        customerGST: _selectedCustomerGST,
                        onCustomerChanged: _setSelectedCustomer,
                      ),
                ),
              ),
            ],
          ),

          // Cart overlay: Always show when there are items (with dynamic height)
          if (shouldShowCart)
            Positioned(
              top: topPadding + 3,
              left: 0,
              right: 0,
              child: _buildCartSection(screenWidth, dynamicCartHeight),
            ),
        ],
      ),
      bottomNavigationBar: CommonBottomNav(
        uid: _uid,
        userEmail: _userEmail,
        currentIndex: 2,
        screenWidth: screenWidth,
      ),
    );
  }

  Widget _buildCartSection(double w, double currentHeight) {
    final bool isSearchFocused = currentHeight <= 150; // Detect if in search focus mode (120px or less)

    return GestureDetector(
      // Disable drag gestures when in search focus mode
      onVerticalDragUpdate: isSearchFocused ? null : (details) {
        setState(() {
          if (details.delta.dy > 10) {
            // User pulled down quickly, expand fully
            _cartHeight = _maxCartHeight;
          } else if (details.delta.dy < -10) {
            // User pulled up quickly, collapse to minimum
            _cartHeight = _minCartHeight;
          } else {
            // Normal drag, keep smooth resizing
            _cartHeight = (_cartHeight + details.delta.dy).clamp(_minCartHeight, _maxCartHeight);
          }
        });
      },
      onDoubleTap: isSearchFocused ? null : () {
        setState(() {
          if (_cartHeight < _maxCartHeight * 0.95) {
            _cartHeight = _maxCartHeight+100;
          } else {
            _cartHeight = _minCartHeight;
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        height: currentHeight,
        margin: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: R.radius(context, 20),
          border: Border.all(color: Color(0xFFE0B646), width: 2),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: R.sp(context, 16),
                vertical: isSearchFocused ? R.sp(context, 6) : R.sp(context, 12),
              ),
              decoration: BoxDecoration(
                color: Color(0xFFE0B646),
                borderRadius: BorderRadius.vertical(top: Radius.circular(R.sp(context, 18))),
              ),
              child: Row(
                children: [
                  Expanded(flex: 4, child: Text('Product', style: TextStyle(fontWeight: FontWeight.w800, fontSize: R.sp(context, isSearchFocused ? 11 : 12), color: Colors.black))),
                  Expanded(flex: 2, child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: R.sp(context, isSearchFocused ? 11 : 12), color: Colors.black))),
                  Expanded(flex: 2, child: Text('Price', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: R.sp(context, isSearchFocused ? 11 : 12), color: Colors.black))),
                  Expanded(flex: 2, child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w800, fontSize: R.sp(context, isSearchFocused ? 11 : 12), color: Colors.black))),
                ],
              ),
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: _highlightAnimation!,
                builder: (context, child) {
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 0),
                    itemCount: _sharedCartItems?.length ?? 0,
                    separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF1F5F9)),
                    itemBuilder: (ctx, idx) {
                      final item = _sharedCartItems![idx];
                      final bool isHighlighted = item.productId == _highlightedProductId;

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _showEditCartItemDialog(idx),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: isSearchFocused ? 4 : 8, // Reduced padding in search mode
                            ),
                            decoration: BoxDecoration(
                              // Use animated color for smooth transition
                              color: isHighlighted ? _highlightAnimation!.value : Colors.transparent,
                              borderRadius: BorderRadius.circular(0),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(item.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: R.sp(context, 13)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      ),
                                      SizedBox(width: R.sp(context, 4)),
                                      HeroIcon(HeroIcons.pencil, color: kPrimaryColor, size: R.sp(context, 16)),
                                    ],
                                  ),
                                ),
                                Expanded(flex: 2, child: Text(
                                  item.quantity % 1 == 0 ? '${item.quantity.toInt()}' : '${item.quantity.toStringAsFixed(item.quantity < 1 ? 3 : 2).replaceAll(RegExp(r'\.?0+$'), '')}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: R.sp(context, 13))
                                )),
                                Expanded(flex: 2, child: Text(AmountFormatter.formatWithSymbol(item.priceWithTax), textAlign: TextAlign.center, style: TextStyle(fontSize: R.sp(context, 12)))),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    AmountFormatter.formatWithSymbol(item.totalWithTax),
                                    textAlign: TextAlign.right,
                                    style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w600, fontSize: R.sp(context, 13)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: R.sp(context, 16),
                vertical: isSearchFocused ? R.sp(context, 4) : R.sp(context, 8),
              ),
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.03),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(R.sp(context, 18))),
                border: Border(top: BorderSide(color: kGrey300.withOpacity(0.5))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _handleClearCart,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            HeroIcon(HeroIcons.trash, color: Colors.redAccent, size: R.sp(context, 18)),
                            SizedBox(width: R.sp(context, 4)),
                            Text('Clear', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w800, fontSize: R.sp(context, 13))),
                          ],
                        ),
                      ),
                    ),
                  ),
                  HeroIcon(HeroIcons.bars3, color: Colors.grey, size: R.sp(context, 24)),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: R.sp(context, 10), vertical: R.sp(context, 4)),
                    decoration: BoxDecoration(color: kPrimaryColor, borderRadius: R.radius(context, 12)),
                    child: Text(
                      '${_sharedCartItems?.length ?? 0} Items',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: R.sp(context, 12)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
