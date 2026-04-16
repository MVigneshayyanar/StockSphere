import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:heroicons/heroicons.dart';
import 'package:maxbillup/Sales/QuickSale.dart';
import 'package:maxbillup/Sales/Saved.dart';
import 'package:maxbillup/Sales/Quotation.dart';
import 'package:maxbillup/Sales/components/sale_app_bar.dart';
import 'package:maxbillup/Sales/components/common_widgets.dart';
import 'package:maxbillup/Sales/saleall.dart';
import 'package:maxbillup/models/cart_item.dart';
import 'package:maxbillup/Colors.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/amount_formatter.dart';
import 'package:maxbillup/utils/responsive_helper.dart';
import 'package:maxbillup/services/currency_service.dart';

class NewQuotationPage extends StatefulWidget {
  final String uid;
  final String? userEmail;
  final String? editQuotationId;
  final Map<String, dynamic>? initialQuotationData;
  final bool isEditMode; // When true, bottom bar shows "Use Items" instead of Quotation
  final void Function(List<CartItem>)? onItemsConfirmed;

  const NewQuotationPage({
    super.key,
    required this.uid,
    this.userEmail,
    this.editQuotationId,
    this.initialQuotationData,
    this.isEditMode = false,
    this.onItemsConfirmed,
  });

  @override
  State<NewQuotationPage> createState() => _NewQuotationPageState();
}

class _NewQuotationPageState extends State<NewQuotationPage> with SingleTickerProviderStateMixin {
  int _selectedTabIndex = 1; // Start with View All tab (index 1)
  List<CartItem>? _sharedCartItems;
  bool _isSearchFocused = false;

  String? _highlightedProductId;
  int _animationCounter = 0;
  AnimationController? _highlightController;
  Animation<Color?>? _highlightAnimation;

  double _cartHeight = 200;
  final double _minCartHeight = 200;
  double _maxCartHeight = 800;

  String? _selectedCustomerPhone;
  String? _selectedCustomerName;
  String? _selectedCustomerGST;
  int _cartVersion = 0;
  String _currencySymbol = '';

  @override
  void initState() {
    super.initState();
    _loadCurrency();

    if (widget.initialQuotationData != null) {
      _selectedCustomerName = widget.initialQuotationData!['customerName'];
      _selectedCustomerPhone = widget.initialQuotationData!['customerPhone'];
      _selectedCustomerGST = widget.initialQuotationData!['customerGST'];

      final items = widget.initialQuotationData!['items'] as List<dynamic>? ?? [];
      _sharedCartItems = items.map((item) {
        List<Map<String, dynamic>>? itemTaxes;
        if (item['taxes'] is List && (item['taxes'] as List).isNotEmpty) {
          itemTaxes = (item['taxes'] as List).map((t) => Map<String, dynamic>.from(t as Map)).toList();
        }
        return CartItem(
          productId: item['productId'] ?? '',
          name: item['name'] ?? '',
          price: (item['price'] ?? 0.0).toDouble(),
          quantity: item['quantity'] ?? 1,
          taxes: itemTaxes,
          taxName: item['taxName'] as String?,
          taxPercentage: item['taxPercentage'] != null ? (item['taxPercentage'] as num).toDouble() : null,
          taxType: item['taxType'] as String?,
        );
      }).toList();
    }

    _highlightController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _highlightAnimation = ColorTween(
      begin: kGoogleGreen.withOpacity(0.2),
      end: Colors.transparent,
    ).animate(CurvedAnimation(
      parent: _highlightController!,
      curve: Curves.easeOut,
    ));
  }

  void _loadCurrency() async {
    final storeId = await FirestoreService().getCurrentStoreId();
    if (storeId == null) return;
    final doc = await FirebaseFirestore.instance.collection('store').doc(storeId).get();
    if (doc.exists && mounted) {
      setState(() => _currencySymbol = CurrencyService.getSymbolWithSpace(doc.data()?['currency']));
    }
  }

  @override
  void dispose() {
    _highlightController?.dispose();
    super.dispose();
  }

  void _handleTabChange(int index) {
    setState(() {
      _selectedTabIndex = index;
    });
  }

  void _updateCartItems(List<CartItem> items, {String? triggerId}) {
    List<CartItem> updatedItems = List<CartItem>.from(items);

    if (updatedItems.isNotEmpty) {
      // Find the newly added/modified item to highlight
      String highlightId = triggerId ?? updatedItems[0].productId;
      _triggerHighlight(highlightId, updatedItems);
    } else {
      setState(() {
        _sharedCartItems = null;
      });
    }
  }

  void _triggerHighlight(String productId, List<CartItem> updatedItems) {
    _highlightController?.reset();
    setState(() {
      _highlightedProductId = productId;
      _animationCounter++;
      _sharedCartItems = updatedItems.isNotEmpty ? updatedItems : null;
    });

    _highlightController?.forward();

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && _highlightedProductId == productId) {
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
    final item = _sharedCartItems![idx];
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
          final currentQty = int.tryParse(qtyController.text) ?? 1;
          final bool exceedsStock = stockEnabled && currentQty > availableStock;

          return Dialog(
            backgroundColor: kWhite,
            shape: RoundedRectangleBorder(borderRadius: R.radius(context, 16)),
            child: Padding(
              padding: R.all(context, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(context.tr('edit_item'), style: TextStyle(fontWeight: FontWeight.w800, fontSize: R.sp(context, 18), color: kBlack87)),
                      GestureDetector(onTap: () => Navigator.pop(context), child: HeroIcon(HeroIcons.xMark, color: kBlack54, size: R.sp(context, 24))),
                    ],
                  ),
                  SizedBox(height: R.sp(context, 24)),
                  _dialogLabel(context.tr('item_name')),
                  _dialogInput(nameController, 'Enter product name'),
                  SizedBox(height: R.sp(context, 16)),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _dialogLabel(context.tr('price')),
                            _dialogInput(priceController, '0.00', isNumber: true),
                          ],
                        ),
                      ),
                      SizedBox(width: R.sp(context, 12)),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _dialogLabel(context.tr('quantity')),
                            Container(
                              height: R.sp(context, 48),
                              decoration: BoxDecoration(
                                color: kGreyBg,
                                borderRadius: R.radius(context, 10),
                                border: Border.all(color: kGrey200),
                              ),
                              clipBehavior: Clip.hardEdge,
                              child: Row(
                                children: [
                                  // Minus / Trash button
                                  GestureDetector(
                                    onTap: () {
                                      int current = int.tryParse(qtyController.text) ?? 1;
                                      if (current > 1) {
                                        setDialogState(() => qtyController.text = (current - 1).toString());
                                      } else {
                                        Navigator.pop(context);
                                        _removeSingleItem(idx);
                                      }
                                    },
                                    child: Container(
                                      width: R.sp(context, 42),
                                      height: double.infinity,
                                      color: (int.tryParse(qtyController.text) ?? 1) <= 1
                                          ? kErrorColor.withOpacity(0.08)
                                          : kPrimaryColor.withOpacity(0.07),
                                      child: Center(
                                        child: HeroIcon(
                                          (int.tryParse(qtyController.text) ?? 1) <= 1
                                              ? HeroIcons.trash
                                              : HeroIcons.minus,
                                          color: (int.tryParse(qtyController.text) ?? 1) <= 1
                                              ? kErrorColor
                                              : kPrimaryColor,
                                          size: R.sp(context, 18),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Divider
                                  Container(width: 1, height: double.infinity, color: kGrey200),
                                  // Quantity TextField (no border)
                                  Expanded(
                                    child: TextField(
                                      controller: qtyController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      textAlign: TextAlign.center,
                                      onChanged: (v) => setDialogState(() {}),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: R.sp(context, 15),
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
                                  Container(width: 1, height: double.infinity, color: kGrey200),
                                  // Plus button
                                  GestureDetector(
                                    onTap: () {
                                      int current = int.tryParse(qtyController.text) ?? 0;
                                      int newQty = current + 1;
                                      if (stockEnabled && newQty > availableStock) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Maximum stock available: ${availableStock.toInt()}'),
                                            backgroundColor: kErrorColor,
                                            behavior: SnackBarBehavior.floating,
                                            duration: const Duration(seconds: 2),
                                          ),
                                        );
                                        return;
                                      }
                                      setDialogState(() => qtyController.text = newQty.toString());
                                    },
                                    child: Container(
                                      width: R.sp(context, 42),
                                      height: double.infinity,
                                      color: kPrimaryColor.withOpacity(0.07),
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
                            // Stock warning
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
                                        'Only ${availableStock.toInt()} available in stock',
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
                  SizedBox(height: R.sp(context, 32)),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () { Navigator.pop(context); _removeSingleItem(idx); },
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: kErrorColor), padding: EdgeInsets.symmetric(vertical: R.sp(context, 14)), shape: RoundedRectangleBorder(borderRadius: R.radius(context, 12))),
                          child: Text(context.tr('remove'), style: TextStyle(color: kErrorColor, fontWeight: FontWeight.w800, fontSize: R.sp(context, 12))),
                        ),
                      ),
                      SizedBox(width: R.sp(context, 12)),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: exceedsStock ? null : () {
                            final newName = nameController.text.trim();
                            final newPrice = double.tryParse(priceController.text.trim()) ?? item.price;
                            final newQty = double.tryParse(qtyController.text.trim()) ?? 1.0;

                            // Final stock validation
                            if (stockEnabled && newQty > availableStock) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Cannot save: Only ${availableStock.toInt()} available in stock'),
                                  backgroundColor: kErrorColor,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }

                            if (newQty > 0) {
                              final List<CartItem> nextItems = List<CartItem>.from(_sharedCartItems!);
                              nextItems[idx] = CartItem(productId: item.productId, name: newName, price: newPrice, quantity: newQty, taxes: item.taxes.isNotEmpty ? item.taxes : null, taxName: item.taxName, taxPercentage: item.taxPercentage, taxType: item.taxType);
                              _updateCartItems(nextItems);
                            }
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: exceedsStock ? kGrey300 : kPrimaryColor,
                            padding: EdgeInsets.symmetric(vertical: R.sp(context, 14)),
                            shape: RoundedRectangleBorder(borderRadius: R.radius(context, 12)),
                            elevation: 0
                          ),
                          child: Text(context.tr('save'), style: TextStyle(color: kWhite, fontWeight: FontWeight.w800, fontSize: R.sp(context, 12))),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  void _handleClearCart() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: R.radius(context, 16)),
        child: Padding(
          padding: R.all(context, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              HeroIcon(HeroIcons.exclamationTriangle, color: kErrorColor, size: R.sp(context, 40)),
              SizedBox(height: R.sp(context, 16)),
              Text(context.tr('clear_cart'), style: TextStyle(fontWeight: FontWeight.w800, fontSize: R.sp(context, 18), color: kBlack87)),
              SizedBox(height: R.sp(context, 12)),
              Text('Are you sure you want to clear this quotation? All line items will be removed.', textAlign: TextAlign.center, style: TextStyle(color: kBlack54, fontSize: R.sp(context, 14), fontWeight: FontWeight.w500)),
              SizedBox(height: R.sp(context, 24)),
              Row(
                children: [
                  Expanded(child: TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: kBlack54,fontWeight: FontWeight.bold)))),
                  SizedBox(width: R.sp(context, 12)),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(backgroundColor: kErrorColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: R.radius(context, 8))),
                      child: Text(context.tr('clear'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: R.sp(context, 12))),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      setState(() {
        _sharedCartItems = null;
        _cartVersion++;
        _highlightedProductId = null;
        _isSearchFocused = false;
      });
      _updateCartItems([]);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) FocusManager.instance.primaryFocus?.unfocus();
      });
    }
  }

  Widget _dialogLabel(String text) => Padding(
    padding: EdgeInsets.only(bottom: R.sp(context, 8), left: R.sp(context, 4)),
    child: Text(text, style: TextStyle(fontSize: R.sp(context, 10), fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 0.5)),
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
      style: TextStyle(fontSize: R.sp(context, 15), fontWeight: FontWeight.w700, color: enabled ? kBlack87 : Colors.black45),
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

  void _handleSearchFocusChange(bool isFocused) {
    setState(() {
      _isSearchFocused = isFocused;
    });
  }

  void _setSelectedCustomer(String? phone, String? name, String? gst) {
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

    _maxCartHeight = screenHeight - topPadding - 180;

    final double dynamicCartHeight = _isSearchFocused ? 150 : _cartHeight;
    final bool shouldShowCart = _sharedCartItems != null && _sharedCartItems!.isNotEmpty;
    final double reservedCartSpace = shouldShowCart ? (_isSearchFocused ? 150 : _minCartHeight) : 0;

    return Scaffold(
      backgroundColor: kWhite, // Changed from kGreyBg to kWhite
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Column(
            children: [
              SizedBox(height: topPadding + 10 + (reservedCartSpace > 0 ? reservedCartSpace + 10 : 0)),

              if (!_isSearchFocused)
                SaleAppBar(
                  selectedTabIndex: _selectedTabIndex,
                  onTabChanged: _handleTabChange,
                  screenWidth: screenWidth,
                  screenHeight: screenHeight,
                  uid: widget.uid,
                  userEmail: widget.userEmail,
                  hideSavedTab: true,
                  showBackButton: true,
                ),

              Expanded(
                child: _selectedTabIndex == 0
                    ? SavedOrdersPage(uid: widget.uid, userEmail: widget.userEmail)
                    : _selectedTabIndex == 1
                    ? SaleAllPage(
                  key: const ValueKey('sale_all_quotation'),
                  uid: widget.uid,
                  userEmail: widget.userEmail,
                  onCartChanged: _updateCartItems,
                  initialCartItems: _sharedCartItems,
                  isQuotationMode: true,
                  onSearchFocusChanged: _handleSearchFocusChange,
                  customerPhone: _selectedCustomerPhone,
                  customerName: _selectedCustomerName,
                  customerGST: _selectedCustomerGST,
                  onCustomerChanged: _setSelectedCustomer,
                )
                    : QuickSalePage(
                  key: const ValueKey('quick_sale_quotation'),
                  uid: widget.uid,
                  userEmail: widget.userEmail,
                  initialCartItems: _sharedCartItems,
                  onCartChanged: _updateCartItems,
                  isQuotationMode: true,
                  customerPhone: _selectedCustomerPhone,
                  customerName: _selectedCustomerName,
                  customerGST: _selectedCustomerGST,
                  onCustomerChanged: _setSelectedCustomer,
                ),
              ),
            ],
          ),

          if (shouldShowCart)
            Positioned(
              top: topPadding + 10,
              left: 0,
              right: 0,
              child: _buildCartSection(screenWidth, dynamicCartHeight),
            ),
        ],
      ),
      bottomNavigationBar: _buildEnterpriseBottomBar(),
    );
  }

  Widget _buildEnterpriseBottomBar() {
    return Container(
      decoration: const BoxDecoration(
        color: kWhite,
        border: Border(top: BorderSide(color: kGrey200, width: 1)),
      ),
      padding: EdgeInsets.fromLTRB(R.sp(context, 16), R.sp(context, 12), R.sp(context, 16), R.sp(context, 8)),
      child: SafeArea(
        child: Row(
          children: [
            // Enterprise Customer Action Icon
            InkWell(
              onTap: _showCustomerSelectionDialog,
              borderRadius: R.radius(context, 12),
              child: Container(
                height: R.sp(context, 56),
                width: R.sp(context, 56),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withOpacity(0.08),
                  borderRadius: R.radius(context, 12),
                  border: Border.all(color: kPrimaryColor.withOpacity(0.2), width: 1.5),
                ),
                child: HeroIcon(
                  _selectedCustomerName != null && _selectedCustomerName!.isNotEmpty
                      ? HeroIcons.user
                      : HeroIcons.userPlus,
                  color: kPrimaryColor,
                  size: R.sp(context, 26),
                ),
              ),
            ),
            SizedBox(width: R.sp(context, 16)),
            // High-Density Quotation Button
            Expanded(
              child: GestureDetector(
                onTap: widget.isEditMode ? _useItems : _createQuotation,
                child: Container(
                  height: R.sp(context, 56),
                  decoration: BoxDecoration(
                    color: kPrimaryColor,
                    borderRadius: R.radius(context, 12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      HeroIcon(widget.isEditMode ? HeroIcons.checkCircle : HeroIcons.documentText, color: kWhite, size: R.sp(context, 20)),
                      SizedBox(width: R.sp(context, 12)),
                      Text(
                        "$_currencySymbol${AmountFormatter.format(_sharedCartItems?.fold(0.0, (sum, item) => sum + (item.price * item.quantity)) ?? 0.0)}",
                        style: TextStyle(color: kWhite, fontSize: R.sp(context, 18), fontWeight: FontWeight.w900),
                      ),
                      SizedBox(width: R.sp(context, 10)),
                      Container(width: 1, height: R.sp(context, 16), color: kWhite.withOpacity(0.3)),
                      SizedBox(width: R.sp(context, 10)),
                      Text(
                        widget.isEditMode ? 'Update' : (widget.editQuotationId != null ? context.tr('Update') : context.tr('Quote')),
                        style: TextStyle(color: kWhite, fontSize: R.sp(context, 13), fontWeight: FontWeight.w800, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomerSelectionDialog() {
    CommonWidgets.showCustomerSelectionDialog(
      context: context,
      onCustomerSelected: (phone, name, gst) {
        setState(() {
          _selectedCustomerPhone = phone.isEmpty ? null : phone;
          _selectedCustomerName = name.isEmpty ? null : name;
          _selectedCustomerGST = gst;
        });
      },
      selectedCustomerPhone: _selectedCustomerPhone,
    );
  }

  void _useItems() {
    if (_sharedCartItems == null || _sharedCartItems!.isEmpty) {
      CommonWidgets.showSnackBar(context, 'Add items first', bgColor: kOrange);
      return;
    }
    if (widget.onItemsConfirmed != null) {
      widget.onItemsConfirmed!(_sharedCartItems!);
    }
    Navigator.pop(context, _sharedCartItems);
  }

  void _createQuotation() {
    if (_sharedCartItems == null || _sharedCartItems!.isEmpty) {
      CommonWidgets.showSnackBar(context, 'Add items to create quotation', bgColor: kOrange);
      return;
    }

    final total = _sharedCartItems!.fold(0.0, (sum, item) => sum + (item.price * item.quantity));

    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => QuotationPage(
          uid: widget.uid,
          userEmail: widget.userEmail,
          cartItems: _sharedCartItems!,
          totalAmount: total,
          customerPhone: _selectedCustomerPhone,
          customerName: _selectedCustomerName,
          customerGST: _selectedCustomerGST,
          editQuotationId: widget.editQuotationId,
          initialQuotationData: widget.initialQuotationData,
        ),
      ),
    ).then((_) {
      setState(() {
        _sharedCartItems = null;
        _isSearchFocused = false;
      });
      _updateCartItems([]);
    });
  }

  Widget _buildCartSection(double w, double currentHeight) {
    final bool isSearchFocused = currentHeight <= 150;

    return GestureDetector(
      onVerticalDragUpdate: isSearchFocused ? null : (details) {
        setState(() {
          if (details.delta.dy > 10) _cartHeight = _maxCartHeight;
          else if (details.delta.dy < -10) _cartHeight = _minCartHeight;
          else _cartHeight = (_cartHeight + details.delta.dy).clamp(_minCartHeight, _maxCartHeight);
        });
      },
      onDoubleTap: isSearchFocused ? null : () {
        setState(() => _cartHeight = (_cartHeight < _maxCartHeight * 0.95) ? _maxCartHeight : _minCartHeight);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        height: currentHeight,
        margin: EdgeInsets.symmetric(horizontal: R.sp(context, 12)),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: R.radius(context, 20),
          border: Border.all(color: Color(0xFFE0B646), width: 2),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: R.sp(context, 16), vertical: isSearchFocused ? 6 : R.sp(context, 12)),
              decoration: BoxDecoration(
                color: Color(0xFFE0B646),
                borderRadius: BorderRadius.vertical(top: Radius.circular(R.sp(context, 18))),
              ),
              child: Row(
                children: [
                  Expanded(flex: 4, child: Text(context.tr('Product'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: R.sp(context, isSearchFocused ? 11 : 12), color: kBlack87, letterSpacing: 0.5))),
                  Expanded(flex: 2, child: Text(context.tr('Qty'), textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: R.sp(context, isSearchFocused ? 11 : 12), color: kBlack87, letterSpacing: 0.5))),
                  Expanded(flex: 2, child: Text(context.tr('Price'), textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: R.sp(context, isSearchFocused ? 11 : 12), color: kBlack87, letterSpacing: 0.5))),
                  Expanded(flex: 2, child: Text(context.tr('Total'), textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: R.sp(context, isSearchFocused ? 11 : 12), color: kBlack87, letterSpacing: 0.5))),
                ],
              ),
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: _highlightAnimation!,
                builder: (context, child) {
                  return ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: _sharedCartItems?.length ?? 0,
                    separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16, color: kGrey100),
                    itemBuilder: (ctx, idx) {
                      final item = _sharedCartItems![idx];
                      final bool isHighlighted = item.productId == _highlightedProductId;

                      return GestureDetector(
                        onTap: () => _showEditCartItemDialog(idx),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          padding: EdgeInsets.symmetric(horizontal: isSearchFocused ? 16 : R.sp(context, 16), vertical: isSearchFocused ? 4 : R.sp(context, 8)),
                          decoration: BoxDecoration(
                            color: isHighlighted ? _highlightAnimation!.value : Colors.transparent,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Row(
                                  children: [
                                    Expanded(child: Text(item.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: R.sp(context, 13), color: kBlack87), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                    SizedBox(width: R.sp(context, 4)),
                                    HeroIcon(HeroIcons.pencil, color: kPrimaryColor, size: R.sp(context, 20)),
                                  ],
                                ),
                              ),
                              Expanded(flex: 2, child: Text('${item.quantity}', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: R.sp(context, 14), color: kBlack87))),
                              Expanded(flex: 2, child: Text(AmountFormatter.format(item.price), textAlign: TextAlign.center, style: TextStyle(fontSize: R.sp(context, 12), color: kBlack54, fontWeight: FontWeight.w600))),
                              Expanded(flex: 2, child: Text(AmountFormatter.format(item.total), textAlign: TextAlign.right, style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w900, fontSize: R.sp(context, 14)))),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: R.sp(context, 16), vertical: isSearchFocused ? 4 : R.sp(context, 8)),
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.03),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(R.sp(context, 18))),
                border: const Border(top: BorderSide(color: kGrey200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: _handleClearCart,
                    child: Row(
                      children: [
                        HeroIcon(HeroIcons.trash, color: kErrorColor, size: R.sp(context, 18)),
                        SizedBox(width: R.sp(context, 4)),
                        Text(context.tr('clear'), style: TextStyle(color: kErrorColor, fontWeight: FontWeight.w800, fontSize: R.sp(context, 11))),
                      ],
                    ),
                  ),
                  HeroIcon(HeroIcons.bars3, color: kGrey300, size: R.sp(context, 24)),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: R.sp(context, 10), vertical: R.sp(context, 4)),
                    decoration: BoxDecoration(color: kPrimaryColor, borderRadius: R.radius(context, 12)),
                    child: Text('${_sharedCartItems?.length ?? 0} Items', style: TextStyle(color: kWhite, fontWeight: FontWeight.w900, fontSize: R.sp(context, 10), letterSpacing: 0.5)),
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
