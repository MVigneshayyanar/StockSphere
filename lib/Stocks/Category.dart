import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:maxbillup/Colors.dart';
import 'package:maxbillup/Stocks/AddProduct.dart';
import 'package:maxbillup/Stocks/AddCategoryPopup.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/utils/permission_helper.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/services/currency_service.dart';
import 'package:intl/intl.dart';
import 'package:heroicons/heroicons.dart';

class CategoryPage extends StatefulWidget {
  final String uid;
  final String? userEmail;

  const CategoryPage({
    super.key,
    required this.uid,
    this.userEmail,
  });

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _sortAscending = true;
  String _filterType = 'all'; // all, empty, nonEmpty
  String _currencySymbol = '';

  late String _uid;
  String? _userEmail;

  Map<String, dynamic> _permissions = {};
  String _role = 'staff';
  CollectionReference? _productsRef;
  Stream<QuerySnapshot>? _categoryStream;
  Stream<QuerySnapshot>? _productsStream;

  // In-memory count map: categoryName -> count (updated live from products stream)
  Map<String, int> _productCountMap = {};

  // Helper function to format category names: First letter uppercase, rest lowercase
  String _formatCategoryName(String name) {
    if (name.isEmpty) return name;
    return name[0].toUpperCase() + name.substring(1).toLowerCase();
  }

  @override
  void initState() {
    super.initState();
    _uid = widget.uid;
    _userEmail = widget.userEmail;

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });

    _loadPermissions();
    _initStreams();
    _loadCurrency();
  }

  void _loadCurrency() async {
    final storeId = await FirestoreService().getCurrentStoreId();
    if (storeId == null) return;
    final doc = await FirebaseFirestore.instance.collection('store').doc(storeId).get();
    if (doc.exists && mounted) {
      final data = doc.data();
      setState(() {
        _currencySymbol = CurrencyService.getSymbolWithSpace(data?['currency']);
      });
    }
  }

  /// Initialize both streams together for fast local-cache hit
  Future<void> _initStreams() async {
    try {
      final catStream = await FirestoreService().getCollectionStream('categories');
      final ref = await FirestoreService().getStoreCollection('Products');
      if (!mounted) return;
      setState(() {
        _categoryStream = catStream;
        _productsRef = ref;
        _productsStream = ref.snapshots();
      });
      // Listen to products stream to keep count map updated live
      _productsStream!.listen((snapshot) {
        if (!mounted) return;
        final newMap = <String, int>{};
        for (final doc in snapshot.docs) {
          final cat = ((doc.data() as Map<String, dynamic>)['category'] ?? '').toString();
          if (cat.isNotEmpty) newMap[cat] = (newMap[cat] ?? 0) + 1;
        }
        setState(() => _productCountMap = newMap);
      });
    } catch (e) {
      debugPrint("Stream init error: $e");
    }
  }

  Future<void> _loadPermissions() async {
    final userData = await PermissionHelper.getUserPermissions(_uid);
    if (mounted) {
      setState(() {
        _permissions = userData['permissions'] as Map<String, dynamic>;
        _role = userData['role'] as String;
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
      floatingActionButton: (_hasPermission('addCategory') || isAdmin)
          ? FloatingActionButton.extended(
        onPressed: () => _showAddCategoryDialog(context),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        icon: const HeroIcon(HeroIcons.plus, color: kWhite, size: 20),
        label: Text(
          context.tr('add_category'),
          style: const TextStyle(color: kWhite, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5),
        ),
      )
          : null,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _buildCategoryList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
                  hintText: context.tr('search_categories'),
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

  Widget _buildCategoryList() {
    if (_categoryStream == null || _productsStream == null) {
      return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _categoryStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        var filteredCategories = snapshot.data!.docs.where((doc) {
          final categoryName = (doc.data() as Map<String, dynamic>)['name'] ?? '';
          return categoryName.toString().toLowerCase().contains(_searchQuery);
        }).toList();

        // Local Sorting logic
        filteredCategories.sort((a, b) {
          final nameA = (a.data() as Map<String, dynamic>)['name']?.toString() ?? '';
          final nameB = (b.data() as Map<String, dynamic>)['name']?.toString() ?? '';
          int res = nameA.compareTo(nameB);
          return _sortAscending ? res : -res;
        });

        if (filteredCategories.isEmpty && _searchQuery.isNotEmpty) {
          return _buildNoResults();
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: filteredCategories.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) => _buildCategoryCard(filteredCategories[index]),
        );
      },
    );
  }

  Widget _buildCategoryCard(QueryDocumentSnapshot categoryDoc) {
    final data = categoryDoc.data() as Map<String, dynamic>;
    final name = data['name'] ?? 'Unknown';

    // ✅ Instant in-memory count — no Firestore call per card
    final int count = _productCountMap[name] ?? 0;

    // Filter logic
    if (_filterType == 'nonEmpty' && count == 0) return const SizedBox.shrink();
    if (_filterType == 'empty' && count > 0) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGrey200),
      ),
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                onTap: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => CategoryDetailsPage(
                        uid: _uid,
                        userEmail: _userEmail,
                        categoryName: name,
                      ),
                    ),
                  );
                },
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: HeroIcon(HeroIcons.tag, color: kPrimaryColor, size: 24),
                  ),
                ),
                title: Text(_formatCategoryName(name), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black)),
                subtitle: Text('$count ${count == 1 ? "Product" : "Products"}',
                    style: const TextStyle(color: kBlack54, fontSize: 12, fontWeight: FontWeight.w600)),
                trailing: (_hasPermission('addCategory') || isAdmin)
                    ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const HeroIcon(HeroIcons.pencilSquare, size: 26, color: kPrimaryColor),
                      onPressed: () => _showEditCategoryDialog(context, categoryDoc.id, name),
                    ),
                    IconButton(
                      icon: const HeroIcon(HeroIcons.trash, size: 22, color: kErrorColor),
                      onPressed: () => _showDeleteConfirmation(context, categoryDoc.id, name),
                    ),
                  ],
                )
                    : const HeroIcon(HeroIcons.chevronRight, size: 14, color: kGrey400),
              ),
              if (_hasPermission('addCategory') || isAdmin) ...[
                const Divider(height: 1, color: kGrey100),
                Container(
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withOpacity(0.02),
                    borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _showAddExistingProductDialog(context, name),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const HeroIcon(HeroIcons.plusCircle, size: 16, color: kPrimaryColor),
                                const SizedBox(width: 8),
                                Text(context.tr('add_existing'),
                                    style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 0.5)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Container(width: 1, height: 16, color: kGrey200),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            Navigator.push(context, CupertinoPageRoute(builder: (c) => AddProductPage(uid: _uid, userEmail: _userEmail, preSelectedCategory: name)));
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const HeroIcon(HeroIcons.plus, size: 16, color: kGoogleGreen),
                                const SizedBox(width: 8),
                                Text(context.tr('create_new'),
                                    style: const TextStyle(color: kGoogleGreen, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 0.5)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
  }

  // ==========================================
  // MODAL MENUS (SORT & FILTER)
  // ==========================================

  void _showSortMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sort Categories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kBlack87)),
              const SizedBox(height: 20),
              _buildSortItem('Name (A-Z)', HeroIcons.barsArrowDown, true),
              _buildSortItem('Name (Z-A)', HeroIcons.barsArrowDown, false),
            ],
          ),
        ),
      ),

    );
  }

  Widget _buildSortItem(String label, HeroIcons icon, bool ascending) {
    bool isSelected = _sortAscending == ascending;
    return ListTile(
      onTap: () {
        setState(() => _sortAscending = ascending);
        Navigator.pop(context);
      },
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: isSelected ? kPrimaryColor.withOpacity(0.1) : kGreyBg, borderRadius: BorderRadius.circular(10)),
        child: HeroIcon(icon, color: isSelected ? kPrimaryColor : kBlack54, size: 20),
      ),
      title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, color: isSelected ? kPrimaryColor : kBlack87, fontSize: 14)),
      trailing: isSelected ? const HeroIcon(HeroIcons.checkCircle, color: kPrimaryColor, size: 20) : null,
    );
  }

  void _showFilterMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Category Filter', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kBlack87)),
              const SizedBox(height: 20),
              _buildFilterItem('All Categories', 'all', HeroIcons.queueList, kPrimaryColor),
              _buildFilterItem('With Products', 'nonEmpty', HeroIcons.cube, kGoogleGreen),
              _buildFilterItem('Empty Categories', 'empty', HeroIcons.archiveBoxXMark, kOrange),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterItem(String label, String value, HeroIcons icon, Color color) {
    bool isSelected = _filterType == value;
    return ListTile(
      onTap: () {
        setState(() => _filterType = value);
        Navigator.pop(context);
      },
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: HeroIcon(icon, color: color, size: 20),
      ),
      title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, color: isSelected ? color : kBlack87, fontSize: 14)),
      trailing: isSelected ? HeroIcon(HeroIcons.checkCircle, color: color, size: 20) : null,
    );
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
                HeroIcons.tag,
                size: 60,
                color: kPrimaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              context.tr('no_categories_yet'),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: kBlack87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Add your first category here and\norganize your products",
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

  Widget _buildNoResults() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const HeroIcon(HeroIcons.magnifyingGlass, size: 64, color: kGrey300), const SizedBox(height: 16), Text(context.tr('no_categories_found'), style: const TextStyle(color: kBlack54, fontWeight: FontWeight.w600))]));

  // ==========================================
  // DIALOGS & POPUPS
  // ==========================================

  void _showAddCategoryDialog(BuildContext context) {
    if (!_hasPermission('addCategory') && !isAdmin) {
      PermissionHelper.showPermissionDeniedDialog(context);
      return;
    }
    showDialog(context: context, builder: (c) => AddCategoryPopup(uid: _uid, userEmail: _userEmail));
  }

  void _showEditCategoryDialog(BuildContext context, String id, String current) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: kWhite,
        title: Text(context.tr('edit_category'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        content: Container(
          decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: kPrimaryColor, width: 1.5)),
          child: ValueListenableBuilder<TextEditingValue>(
      valueListenable: ctrl,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextField(
            controller: ctrl,
            style: const TextStyle(fontWeight: FontWeight.w600),
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
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(context.tr('cancel'), style: const TextStyle(fontWeight: FontWeight.bold, color: kBlack54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              if (ctrl.text.trim().isNotEmpty) {
                await FirestoreService().updateDocument('categories', id, {'name': ctrl.text.trim()});
                Navigator.pop(c);
              }
            },
            child: Text(context.tr('save'), style: const TextStyle(fontWeight: FontWeight.w800, color: kWhite)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, String id, String name) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: kWhite,
        title: Text(context.tr('delete_category'), style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${context.tr('are_you_sure_delete')} "$name"?', style: const TextStyle(color: kBlack54, fontSize: 14)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: kOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const HeroIcon(HeroIcons.informationCircle, color: kOrange, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Products in this category will be moved to Uncategorized.', style: TextStyle(color: kOrange, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(context.tr('cancel'), style: const TextStyle(fontWeight: FontWeight.bold))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kErrorColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              Navigator.pop(c);
              await _deleteCategoryAndUpdateProducts(id, name);
            },
            child: Text(context.tr('delete'), style: const TextStyle(fontWeight: FontWeight.w800, color: kWhite)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCategoryAndUpdateProducts(String categoryId, String categoryName) async {
    try {
      // Update all products in this category to 'Uncategorized'
      if (_productsRef != null) {
        final productsInCategory = await _productsRef!.where('category', isEqualTo: categoryName).get();
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in productsInCategory.docs) {
          batch.update(doc.reference, {'category': 'Uncategorized'});
        }
        if (productsInCategory.docs.isNotEmpty) await batch.commit();
      }
      // Delete the category
      await FirestoreService().deleteDocument('categories', categoryId);
    } catch (e) {
      debugPrint('Error deleting category: $e');
    }
  }

  void _showAddExistingProductDialog(BuildContext context, String categoryName) {
    showDialog(
      context: context,
      builder: (c) => _AddExistingProductDialog(categoryName: categoryName),
    );
  }
}

// ==========================================
// Category Details Page (Enterprise Flat)
// ==========================================

class CategoryDetailsPage extends StatefulWidget {
  final String uid;
  final String? userEmail;
  final String categoryName;

  const CategoryDetailsPage({
    super.key,
    required this.uid,
    this.userEmail,
    required this.categoryName,
  });

  @override
  State<CategoryDetailsPage> createState() => _CategoryDetailsPageState();
}

class _CategoryDetailsPageState extends State<CategoryDetailsPage> {
  CollectionReference? _productsRef;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _currencySymbol = '';

  @override
  void initState() {
    super.initState();
    _initProductCollection();
    _loadCurrency();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  void _loadCurrency() async {
    final storeId = await FirestoreService().getCurrentStoreId();
    if (storeId == null) return;
    final doc = await FirebaseFirestore.instance.collection('store').doc(storeId).get();
    if (doc.exists && mounted) {
      final data = doc.data();
      setState(() {
        _currencySymbol = CurrencyService.getSymbolWithSpace(data?['currency']);
      });
    }
  }

  Future<void> _initProductCollection() async {
    final ref = await FirestoreService().getStoreCollection('Products');
    if (mounted) setState(() => _productsRef = ref);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canAddCategory = PermissionHelper.getUserPermissions(widget.uid).then((userData) {
      final permissions = userData['permissions'] as Map<String, dynamic>;
      final role = userData['role'] as String;
      final r = role.toLowerCase();
      return permissions['addCategory'] == true || r == 'owner';
    });
    return FutureBuilder<bool>(
      future: canAddCategory,
      builder: (context, snapshot) {
        final showAddButton = snapshot.data == true;
        return Scaffold(
          backgroundColor: kGreyBg,
          appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
            title: Text(widget.categoryName, style: const TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
            backgroundColor: kPrimaryColor,
            elevation: 0,
            centerTitle: true,
            iconTheme: const IconThemeData(color: kWhite),
            leading: IconButton(icon: const HeroIcon(HeroIcons.arrowLeft, color: kWhite, size: 20), onPressed: () => Navigator.pop(context)),
          ),
          floatingActionButton: showAddButton
              ? FloatingActionButton.extended(
            onPressed: () => _showAddOptions(context),
            backgroundColor: kPrimaryColor,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            icon: const HeroIcon(HeroIcons.plus, color: kWhite, size: 20),
            label: const Text("Add Item", style: TextStyle(color: kWhite, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5)),
          )
              : null,
          body: Column(
            children: [
              _buildSearchHeader(),
              Expanded(child: _buildProductList()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: const BoxDecoration(color: kWhite, border: Border(bottom: BorderSide(color: kGrey200))),
      child: Container(
        height: 46,
        decoration: BoxDecoration(color: kPrimaryColor.withOpacity(0.04), borderRadius: BorderRadius.circular(12)),
        child: ValueListenableBuilder<TextEditingValue>(
      valueListenable: _searchController,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextField(
          controller: _searchController,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search in ${widget.categoryName}...',
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
    );
  }

  Widget _buildProductList() {
    if (_productsRef == null) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
    return StreamBuilder<QuerySnapshot>(
      stream: _productsRef!.where('category', isEqualTo: widget.categoryName).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
        final products = snapshot.data!.docs.where((doc) => (doc.data() as Map)['itemName'].toString().toLowerCase().contains(_searchQuery)).toList();
        if (products.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const HeroIcon(HeroIcons.magnifyingGlass, size: 64, color: kGrey300), const SizedBox(height: 16), Text("No products found", style: TextStyle(color: kBlack54, fontWeight: FontWeight.w600))]));

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: products.length,
          separatorBuilder: (c, i) => const SizedBox(height: 10),
          itemBuilder: (c, i) => _buildProductRow(products[i]),
        );
      },
    );
  }

  Widget _buildProductRow(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['itemName'] ?? 'Unknown';
    final price = (data['price'] ?? 0.0).toDouble();
    final stock = (data['currentStock'] ?? 0.0).toDouble();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGrey200),
      ),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: kPrimaryColor.withOpacity(0.08), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.inventory_2_rounded, color: kPrimaryColor, size: 20)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kBlack87), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text("$_currencySymbol${price.toStringAsFixed(2)}", style: const TextStyle(color: kPrimaryColor, fontSize: 13, fontWeight: FontWeight.w900)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: (stock > 0 ? kGoogleGreen : kErrorColor).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Text("${stock.toInt()} IN STOCK", style: TextStyle(color: stock > 0 ? kGoogleGreen : kErrorColor, fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: 0.5)),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const HeroIcon(HeroIcons.trash, size: 20, color: kErrorColor),
            tooltip: 'Remove from category',
            onPressed: () => _confirmRemoveFromCategory(doc.id, name),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveFromCategory(String productId, String productName) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Remove from Category', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: Text('Remove "$productName" from ${widget.categoryName}?\n\nThe product will not be deleted.', style: const TextStyle(color: kBlack54, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel', style: TextStyle(color: kBlack54, fontWeight: FontWeight.w600))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kErrorColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              Navigator.pop(c);
              await FirestoreService().updateDocument('Products', productId, {'category': ''});
            },
            child: const Text('Remove', style: TextStyle(fontWeight: FontWeight.w800, color: kWhite)),
          ),
        ],
      ),
    );
  }

  // ...existing code...

  void _showAddExistingProductDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (c) => _AddExistingProductDialog(categoryName: widget.categoryName),
    );
  }

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (c) => SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(color: kWhite, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: kGrey300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            _buildActionTile(Icons.add_box_outlined, 'Add Existing Product', kPrimaryColor, () { Navigator.pop(c); _showAddExistingProductDialog(context); }),
            _buildActionTile(Icons.add_circle_outline_rounded, 'Create New Product', kGoogleGreen, () { Navigator.pop(c); Navigator.push(context, CupertinoPageRoute(builder: (c) => AddProductPage(uid: widget.uid, userEmail: widget.userEmail, preSelectedCategory: widget.categoryName))); }),
          ]),
        ),
      ),
    );
  }

  Widget _buildActionTile(IconData icon, String title, Color color, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 20)),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 14)),
    );
  }
}

// ==========================================
// Shared: Fast Add Existing Product Dialog
// ==========================================

class _AddExistingProductDialog extends StatefulWidget {
  final String categoryName;
  const _AddExistingProductDialog({required this.categoryName});

  @override
  State<_AddExistingProductDialog> createState() => _AddExistingProductDialogState();
}

class _AddExistingProductDialogState extends State<_AddExistingProductDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  CollectionReference? _productsRef;

  @override
  void initState() {
    super.initState();
    _init();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.toLowerCase());
    });
  }

  Future<void> _init() async {
    final ref = await FirestoreService().getStoreCollection('Products');
    if (mounted) setState(() => _productsRef = ref);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: kWhite,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
          maxWidth: 480,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const HeroIcon(HeroIcons.plusCircle, color: kPrimaryColor, size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Add Existing Product', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kBlack87)),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: kBlack54, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Category: ${widget.categoryName}', style: const TextStyle(fontSize: 12, color: kBlack54, fontWeight: FontWeight.w500)),
            const SizedBox(height: 14),
            // Search bar
            TextField(
              controller: _searchCtrl,
              autofocus: false,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kBlack87),
              decoration: InputDecoration(
                hintText: 'Search products...',
                hintStyle: const TextStyle(color: kBlack54, fontSize: 13),
                prefixIcon: const HeroIcon(HeroIcons.magnifyingGlass, color: kPrimaryColor, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18, color: kBlack54),
                        onPressed: () => _searchCtrl.clear(),
                      )
                    : null,
                filled: true,
                fillColor: kGreyBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: kGrey200)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kPrimaryColor, width: 1.5)),
              ),
            ),
            const SizedBox(height: 12),
            // Product list
            Expanded(
              child: _productsRef == null
                  ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
                  : StreamBuilder<QuerySnapshot>(
                      stream: _productsRef!.snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                        }
                        final products = snapshot.data!.docs.where((doc) {
                          final d = doc.data() as Map<String, dynamic>;
                          if ((d['category'] ?? '') == widget.categoryName) return false;
                          if (_searchQuery.isEmpty) return true;
                          return (d['itemName'] ?? '').toString().toLowerCase().contains(_searchQuery);
                        }).toList();

                        if (products.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const HeroIcon(HeroIcons.magnifyingGlass, size: 48, color: kGrey300),
                                const SizedBox(height: 12),
                                Text(
                                  _searchQuery.isNotEmpty ? 'No products matching "$_searchQuery"' : 'No products available to add',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: kBlack54, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          itemCount: products.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: kGrey100),
                          itemBuilder: (ctx, i) {
                            final d = products[i].data() as Map<String, dynamic>;
                            final itemName = d['itemName'] ?? 'Unknown';
                            final currentCat = d['category'] ?? '';
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              leading: Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(color: kPrimaryColor.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.inventory_2_rounded, color: kPrimaryColor, size: 18),
                              ),
                              title: Text(itemName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kBlack87)),
                              subtitle: currentCat.isNotEmpty
                                  ? Text('In: $currentCat', style: const TextStyle(fontSize: 11, color: kBlack54))
                                  : const Text('Uncategorized', style: TextStyle(fontSize: 11, color: kBlack54)),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kPrimaryColor,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () async {
                                  await FirestoreService().updateDocument('Products', products[i].id, {'category': widget.categoryName});
                                  if (context.mounted) Navigator.pop(context);
                                },
                                child: const Text('Add', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: kWhite, letterSpacing: 0.5)),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

