import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/Stocks/AddProduct.dart';
import 'package:maxbillup/utils/permission_helper.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/utils/amount_formatter.dart';
import 'package:maxbillup/services/currency_service.dart';
import 'package:maxbillup/Colors.dart';
import 'package:intl/intl.dart';
import 'package:heroicons/heroicons.dart';

class ProductsPage extends StatefulWidget {
  final String uid;
  final String? userEmail;

  const ProductsPage({
    super.key,
    required this.uid,
    this.userEmail,
  });

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'name';
  bool _sortAscending = true;
  String _filterStock = 'all';

  late String _uid;
  Map<String, dynamic> _permissions = {};
  String _role = 'staff';
  bool _isLoading = true;
  Stream<QuerySnapshot>? _productsStream;

  // Multi-select state
  bool _isMultiSelectMode = false;
  Set<String> _selectedProductIds = {};

  // Currency symbol
  String _currencySymbol = 'Rs ';

  // Helper function to format category names: First letter uppercase, rest lowercase
  String _formatCategoryName(String name) {
    if (name.isEmpty) return name;
    return name[0].toUpperCase() + name.substring(1).toLowerCase();
  }

  @override
  void initState() {
    super.initState();
    _uid = widget.uid;
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    _loadPermissions();
    _initProductsStream();
    _loadCurrencySymbol();
  }

  Future<void> _loadCurrencySymbol() async {
    try {
      final doc = await FirestoreService().getCurrentStoreDoc();
      if (doc != null && doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>?;
        setState(() {
          _currencySymbol = CurrencyService.getSymbolWithSpace(data?['currency']);
        });
      }
    } catch (e) {
      debugPrint('Error loading currency: $e');
    }
  }


  Future<void> _initProductsStream() async {
    try {
      final stream = await FirestoreService().getCollectionStream('Products');
      if (mounted) {
        setState(() {
          _productsStream = stream;
        });
      }
    } catch (e) {
      debugPrint("Error initializing stream: $e");
    }
  }

  Future<void> _loadPermissions() async {
    final userData = await PermissionHelper.getUserPermissions(_uid);
    if (mounted) {
      setState(() {
        _permissions = userData['permissions'] as Map<String, dynamic>;
        _role = userData['role'] as String;
        _isLoading = false;
      });
    }
  }

  bool _hasPermission(String permission) => _permissions[permission] == true;
  bool get isAdmin {
    final r = _role.toLowerCase();
    return r == 'owner';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ==========================================
  // UI BUILD METHODS (ENTERPRISE FLAT)
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      floatingActionButton: (isAdmin || _hasPermission('addProduct'))
          ? FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (c) => AddProductPage(uid: _uid, userEmail: widget.userEmail),
          ),
        ),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        icon: const HeroIcon(HeroIcons.plus, color: kWhite, size: 20),
        label: Text(
          context.tr('add_product'),
          style: const TextStyle(color: kWhite, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5),
        ),
      )
          : null,
      body: Column(
        children: [
          _buildHeaderSection(),
          Expanded(
            child: _buildProductList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    if (_isMultiSelectMode) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        decoration: const BoxDecoration(
          color: kWhite,
          border: Border(bottom: BorderSide(color: kGrey200)),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const HeroIcon(HeroIcons.xMark, color: kBlack87),
              onPressed: () => setState(() {
                _isMultiSelectMode = false;
                _selectedProductIds.clear();
              }),
            ),
            Text(
              '${_selectedProductIds.length} selected',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: kBlack87),
            ),
            const Spacer(),
            if (_selectedProductIds.isNotEmpty)
              ElevatedButton.icon(
                onPressed: _showBulkDeleteConfirmDialog,
                icon: const HeroIcon(HeroIcons.trash, size: 18, color: Colors.white),
                label: const Text('Delete', style: TextStyle(color: kWhite, fontWeight: FontWeight.w800, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kErrorColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: const BoxDecoration(
        color: kWhite,
        border: Border(bottom: BorderSide(color: kGrey200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ValueListenableBuilder<TextEditingValue>(
      valueListenable: _searchController,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextField(
                controller: _searchController,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kBlack87),
                decoration: InputDecoration(
                  hintText: context.tr('search'),
                  hintStyle: const TextStyle(color: kBlack54, fontSize: 14),
                  prefixIcon: const HeroIcon(HeroIcons.magnifyingGlass, color: kPrimaryColor, size: 20),
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
            ),
          ),
          const SizedBox(width: 10),
          _buildHeaderActionBtn(HeroIcons.barsArrowUp, _showSortMenu),
          const SizedBox(width: 8),
          _buildHeaderActionBtn(HeroIcons.adjustmentsHorizontal, _showFilterMenu),
          if (isAdmin || _hasPermission('addProduct')) ...[
            const SizedBox(width: 8),
            _buildHeaderActionBtn(HeroIcons.clipboardDocumentCheck, () => setState(() => _isMultiSelectMode = true)),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderActionBtn(HeroIcons icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 46,
        width: 46,
        decoration: BoxDecoration(
          color: kPrimaryColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kGrey200),
        ),
        child: HeroIcon(icon, color: kPrimaryColor, size: 22),
      ),
    );
  }

  Widget _buildProductList() {
    if (_productsStream == null) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));

    return StreamBuilder<QuerySnapshot>(
      stream: _productsStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
        if (snapshot.data!.docs.isEmpty) return _buildEmptyState();

        final products = _filterAndSortProducts(snapshot.data!.docs);
        if (products.isEmpty) return _buildNoResultsState();

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: products.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final doc = products[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildProductCard(doc.id, data, doc);
          },
        );
      },
    );
  }

  Widget _buildProductCard(String id, Map<String, dynamic> data, QueryDocumentSnapshot doc) {
    final name = data['itemName'] ?? 'Unnamed';
    final price = (data['price'] ?? 0.0).toDouble();
    final stockEnabled = data['stockEnabled'] ?? false;
    final stock = (data['currentStock'] ?? 0.0).toDouble();
    final category = data['category'] ?? 'General';
    final isFavorite = data['isFavorite'] ?? false;

    // Read multiple taxes (new format) or fall back to single tax (legacy)
    final List<Map<String, dynamic>> taxesList = [];
    final rawTaxes = data['taxes'];
    if (rawTaxes is List && rawTaxes.isNotEmpty) {
      for (var t in rawTaxes) {
        if (t is Map) taxesList.add(Map<String, dynamic>.from(t));
      }
    } else {
      final taxType = (data['taxName'] ?? '').toString().trim();
      final taxPercent = (data['taxPercentage'] ?? 0.0).toDouble();
      if (taxType.isNotEmpty && taxPercent > 0) {
        taxesList.add({'name': taxType, 'percentage': taxPercent});
      }
    }
    final hasTax = taxesList.isNotEmpty;

    final isOutOfStock = stockEnabled && stock <= 0;
    final isLowStock = stockEnabled && stock > 0 && stock < 10;
    final isSelected = _selectedProductIds.contains(id);

    return Container(
      decoration: BoxDecoration(
        color: isSelected ? kPrimaryColor.withOpacity(0.05) : kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isSelected ? kPrimaryColor : kGrey200, width: isSelected ? 1.5 : 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _isMultiSelectMode
              ? () => setState(() {
                    if (isSelected) {
                      _selectedProductIds.remove(id);
                    } else {
                      _selectedProductIds.add(id);
                    }
                  })
              : (isAdmin || _hasPermission('addProduct'))
                  ? () => _showProductActionMenu(context, doc)
                  : null,
          onLongPress: (isAdmin || _hasPermission('addProduct')) && !_isMultiSelectMode
              ? () => setState(() {
                    _isMultiSelectMode = true;
                    _selectedProductIds.add(id);
                  })
              : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Checkbox or Product Icon
                if (_isMultiSelectMode)
                  Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? kPrimaryColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isSelected ? kPrimaryColor : kGrey300, width: 2),
                    ),
                    child: isSelected
                        ? const HeroIcon(HeroIcons.check, color: kWhite, size: 16)
                        : null,
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kOrange.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const HeroIcon(HeroIcons.cube, color: Color(0xffCC8758), size: 20),
                  ),
                if (!_isMultiSelectMode) const SizedBox(width: 14),
                // Info Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title with favorite blue heart
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: kBlack87),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isFavorite)
                            const HeroIcon(HeroIcons.heart, color: kPrimaryColor, size: 16),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Category and Quantity
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          category == 'Favorite'
                              ? const HeroIcon(HeroIcons.heart, color: kPrimaryColor, size: 14)
                              : Text(
                            _formatCategoryName(category),
                            style: const TextStyle(fontSize: 9, color: kBlack54, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                          ),
                          if (stockEnabled)
                            _buildStockBadge(stock, isOutOfStock, isLowStock),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Amount and Tax
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "$_currencySymbol${AmountFormatter.format(price)}",
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: kPrimaryColor),
                          ),
                          if (hasTax)
                            Flexible(
                              child: Text(
                                taxesList.map((t) => '${t['name']} (${(t['percentage'] as num).toDouble().toStringAsFixed(1)}%)').join(' + '),
                                style: const TextStyle(fontSize: 10, color: kBlack54, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (!_isMultiSelectMode && (isAdmin || _hasPermission('addProduct')))
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Delete button

                      const SizedBox(width: 8),
                      const HeroIcon(HeroIcons.chevronRight, color: kPrimaryColor, size: 16),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStockBadge(double stock, bool isOut, bool isLow) {
    final color = isOut ? kErrorColor : (isLow ? kOrange : kGoogleGreen);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isOut ? 'Out Of Stock' : 'QTY: ${AmountFormatter.format(stock)}',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.2),
      ),
    );
  }

  // --- MODAL SHEETS & DIALOGS ---

  void _showSortMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sort Products', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kBlack87)),
            const SizedBox(height: 20),
            _buildSortOption('Name', 'name', HeroIcons.barsArrowDown),
            _buildSortOption('Price', 'price', HeroIcons.banknotes),
            _buildSortOption('Stock Level', 'stock', HeroIcons.cube),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(String label, String value, HeroIcons icon) {
    bool isSelected = _sortBy == value;
    return ListTile(
      onTap: () {
        setState(() {
          if (_sortBy == value) { _sortAscending = !_sortAscending; }
          else { _sortBy = value; _sortAscending = true; }
        });
        Navigator.pop(context);
      },
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: isSelected ? kPrimaryColor.withOpacity(0.1) : kGreyBg, borderRadius: BorderRadius.circular(10)),
        child: HeroIcon(icon, color: isSelected ? kPrimaryColor : kBlack54, size: 20),
      ),
      title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, color: isSelected ? kPrimaryColor : kBlack87, fontSize: 14)),
      trailing: isSelected ? HeroIcon(_sortAscending ? HeroIcons.arrowUp : HeroIcons.arrowDown, color: kPrimaryColor, size: 16) : null,
    );
  }

  void _showFilterMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Stock Filter', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kBlack87)),
            const SizedBox(height: 20),
            _buildFilterOption(HeroIcons.queueList, 'All Products', 'all', kPrimaryColor),
            _buildFilterOption(HeroIcons.checkCircle, 'In Stock', 'inStock', kGoogleGreen),
            _buildFilterOption(HeroIcons.exclamationTriangle, 'Low Stock Warning', 'lowStock', kOrange),
            _buildFilterOption(HeroIcons.exclamationCircle, 'Out of Stock', 'outOfStock', kErrorColor),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(HeroIcons icon, String title, String value, Color color) {
    bool isSelected = _filterStock == value;
    return ListTile(
      onTap: () {
        setState(() => _filterStock = value);
        Navigator.pop(context);
      },
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: HeroIcon(icon, color: color, size: 20),
      ),
      title: Text(title, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, color: isSelected ? color : kBlack87, fontSize: 14)),
      trailing: isSelected ? HeroIcon(HeroIcons.checkCircle, color: color, size: 20) : null,
    );
  }

  void _showProductActionMenu(BuildContext context, QueryDocumentSnapshot productDoc) {
    final data = productDoc.data() as Map<String, dynamic>;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
          decoration: const BoxDecoration(color: kWhite, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: kGrey300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Text(data['itemName'] ?? 'Product', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: kBlack87)),
              const SizedBox(height: 20),
              _buildActionTile(HeroIcons.pencilSquare, 'Edit Product Details', kPrimaryColor, () {
                Navigator.pop(context);
                Navigator.push(context, CupertinoPageRoute(builder: (c) => AddProductPage(uid: _uid, userEmail: widget.userEmail, productId: productDoc.id, existingData: data)));
              }),
              _buildActionTile(HeroIcons.cube, 'Quick Stock Update', kOrange, () {
                Navigator.pop(context);
                _showUpdateQuantityDialog(context, productDoc.id, data['itemName'], (data['currentStock'] ?? 0.0).toDouble());
              }),
              _buildActionTile(HeroIcons.trash, 'Delete Product', kErrorColor, () {
                Navigator.pop(context);
                _showDeleteConfirmDialog(context, productDoc);
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile(HeroIcons icon, String title, Color color, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: HeroIcon(icon, color: color, size: 20)),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 14)),
    );
  }

  // --- REFINED DIALOGS ---

  void _showUpdateQuantityDialog(BuildContext context, String id, String name, double current) {
    final ctrl = TextEditingController(text: AmountFormatter.format(current));
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: kWhite,
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: kBlack87)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Adjust Stock Level", style: TextStyle(fontSize: 12,fontWeight: FontWeight.bold, color: kBlack54)),
              const SizedBox(height: 20),
              Row(
                children: [
                  _qtyBtn(HeroIcons.minus, () {
                    double v = double.tryParse(ctrl.text) ?? current;
                    if (v > 0) setDialogState(() => ctrl.text = AmountFormatter.format(v - 1));
                  }),
                  Expanded(
                    child: ValueListenableBuilder<TextEditingValue>(
      valueListenable: ctrl,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextField(
                        controller: ctrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                        decoration: InputDecoration(
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
                  ),
                  _qtyBtn(HeroIcons.plus, () {
                    double v = double.tryParse(ctrl.text) ?? current;
                    setDialogState(() => ctrl.text = AmountFormatter.format(v + 1));
                  }),
                ],
              ),
              const SizedBox(height: 12),
              Text('Current in record: ${AmountFormatter.format(current)}', style: const TextStyle(color: kBlack54, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold, color: kBlack54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () async {
                final val = double.tryParse(ctrl.text) ?? current;
                if (val < 0) return;
                await FirestoreService().updateDocument('Products', id, {'currentStock': val});
                Navigator.pop(context);
              },
              child: const Text('Save', style: TextStyle(color: kWhite, fontWeight: FontWeight.w800)),
            )
          ],
        ),
      ),
    );
  }

  Widget _qtyBtn(HeroIcons i, VoidCallback onTap) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10), child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: kPrimaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: HeroIcon(i, color: kPrimaryColor, size: 24)));

  void _showDeleteConfirmDialog(BuildContext context, QueryDocumentSnapshot productDoc) {

   final data = productDoc.data() as Map<String, dynamic>;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Delete Product?', style: TextStyle(color: kBlack87, fontWeight: FontWeight.w800, fontSize: 18)),
        content: Text('Are you sure you want to delete "${data['itemName']}"? This action is permanent.', style: const TextStyle(color: kBlack54, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold, color: kBlack54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kErrorColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              await FirestoreService().deleteDocument('Products', productDoc.id);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: kWhite, fontWeight: FontWeight.w800)),
          )
        ],
      ),
    );
  }

  void _showBulkDeleteConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Delete Multiple Products?', style: TextStyle(color: kBlack87, fontWeight: FontWeight.w800, fontSize: 18)),
        content: Text('Are you sure you want to delete ${_selectedProductIds.length} products? This action is permanent and cannot be undone.', style: const TextStyle(color: kBlack54, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold, color: kBlack54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kErrorColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              Navigator.pop(context);
              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(child: CircularProgressIndicator(color: kPrimaryColor)),
              );

              try {
                // Delete all selected products
                for (final productId in _selectedProductIds) {
                  await FirestoreService().deleteDocument('Products', productId);
                }

                if (mounted) {
                  Navigator.pop(context); // Close loading
                  setState(() {
                    _isMultiSelectMode = false;
                    _selectedProductIds.clear();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${_selectedProductIds.length} products deleted successfully'),
                      backgroundColor: kGoogleGreen,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context); // Close loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting products: $e'),
                      backgroundColor: kErrorColor,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }
              }
            },
            child: const Text('Delete all', style: TextStyle(color: kWhite, fontWeight: FontWeight.w800)),
          )
        ],
      ),
    );
  }

  List<QueryDocumentSnapshot> _filterAndSortProducts(List<QueryDocumentSnapshot> items) {
    var list = items.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name = (data['itemName'] ?? '').toString().toLowerCase();
      final barcode = (data['barcode'] ?? '').toString().toLowerCase();
      if (!name.contains(_searchQuery) && !barcode.contains(_searchQuery)) return false;
      if (_filterStock == 'all') return true;
      final stock = (data['currentStock'] ?? 0.0).toDouble();
      if (_filterStock == 'outOfStock') return stock <= 0;
      if (_filterStock == 'lowStock') return stock > 0 && stock < 10;
      if (_filterStock == 'inStock') return stock >= 10;
      return true;
    }).toList();

    list.sort((a, b) {
      final dA = a.data() as Map<String, dynamic>;
      final dB = b.data() as Map<String, dynamic>;
      int res = 0;
      if (_sortBy == 'name') {
        // Sort by productCode ascending (handles int or string stored in Firestore)
        final rawA = dA['productCode'];
        final rawB = dB['productCode'];
        final numA = rawA is int ? rawA : int.tryParse(rawA?.toString() ?? '');
        final numB = rawB is int ? rawB : int.tryParse(rawB?.toString() ?? '');
        if (numA != null && numB != null) res = numA.compareTo(numB);
        else if (numA != null) res = -1;
        else if (numB != null) res = 1;
        else res = (rawA?.toString() ?? '').compareTo(rawB?.toString() ?? '');
      } else if (_sortBy == 'price') {
        res = (dA['price'] ?? 0).compareTo(dB['price'] ?? 0);
      } else {
        res = (dA['currentStock'] ?? 0).compareTo(dB['currentStock'] ?? 0);
      }
      return _sortAscending ? res : -res;
    });
    return list;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const HeroIcon(
                HeroIcons.cube,
                size: 60,
                color: Color(0xffCC8758),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "No Products Yet",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: kBlack87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Add your first product here and\ngrow your business",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: kBlack54,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HeroIcon(HeroIcons.magnifyingGlass, size: 64, color: kGrey300),
          const SizedBox(height: 16),
          Text('No results for "$_searchQuery"', style: TextStyle(color: kBlack54, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}