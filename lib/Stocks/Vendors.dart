import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:maxbillup/Colors.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/services/currency_service.dart';
import 'package:heroicons/heroicons.dart';

class VendorsPage extends StatefulWidget {
  final String uid;
  final VoidCallback onBack;

  const VendorsPage({super.key, required this.uid, required this.onBack});

  @override
  State<VendorsPage> createState() => _VendorsPageState();
}

class _VendorsPageState extends State<VendorsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>> _vendors = [];
  bool _isLoading = true;
  String _currencySymbol = '';

  @override
  void initState() {
    super.initState();
    _loadVendors();
    _loadCurrency();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
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
    _searchController.dispose();
    super.dispose();
  }

  // ==========================================
  // LOGIC METHODS (PRESERVED)
  // ==========================================

  Future<void> _loadVendors() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final vendorsCollection = await FirestoreService().getStoreCollection('vendors');
      final snapshot = await vendorsCollection.orderBy('createdAt', descending: true).get();

      if (mounted) {
        setState(() {
          _vendors = snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              'name': data['name'] ?? '',
              'phone': data['phone'] ?? '',
              'gstin': data['gstin'] ?? '',
              'address': data['address'] ?? '',
              'totalPurchases': (data['totalPurchases'] ?? 0.0).toDouble(),
              'purchaseCount': data['purchaseCount'] ?? 0,
              'source': data['source'] ?? '',
              'createdAt': data['createdAt'],
              'lastPurchaseDate': data['lastPurchaseDate'],
            };
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading vendors: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredVendors {
    if (_searchQuery.isEmpty) return _vendors;
    return _vendors.where((vendor) {
      final name = (vendor['name'] ?? '').toString().toLowerCase();
      final phone = (vendor['phone'] ?? '').toString().toLowerCase();
      final gstin = (vendor['gstin'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) ||
          phone.contains(_searchQuery) ||
          gstin.contains(_searchQuery);
    }).toList();
  }

  // ==========================================
  // UI BUILD METHODS (ENTERPRISE FLAT)
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) widget.onBack();
      },
      child: Scaffold(
        backgroundColor: kGreyBg,
        appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
          title: const Text('Suppliers',
              style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
          backgroundColor: kPrimaryColor,
          leading: IconButton(
            icon: const HeroIcon(HeroIcons.arrowLeft, color: kWhite, size: 20),
            onPressed: widget.onBack,
          ),
          centerTitle: true,
          elevation: 0,
        ),
        body: Column(
        children: [
          // ENTERPRISE SEARCH HEADER
          Container(
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
                        hintText: "Search vendors...",
                        hintStyle: TextStyle(color: kBlack54, fontSize: 14),
                        prefixIcon: HeroIcon(HeroIcons.magnifyingGlass, color: kPrimaryColor, size: 20),
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
                const SizedBox(width: 12),
                InkWell(
                  onTap: () => _showAddVendorDialog(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 46,
                    width: 46,
                    decoration: BoxDecoration(
                      color: kPrimaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const HeroIcon(HeroIcons.userPlus, color: kWhite, size: 22),
                  ),
                ),
              ],
            ),
          ),

          // SUMMARY STATS ROW
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            color: kWhite,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat('Vendors', _vendors.length.toString(), HeroIcons.users),
                _buildStat(
                  'Total Spent',
                  '$_currencySymbol${_vendors.fold(0.0, (sum, v) => sum + ((v['totalPurchases'] ?? 0).toDouble())).toStringAsFixed(0)}',
                  HeroIcons.banknotes,
                ),
                _buildStat(
                  'Bills',
                  _vendors.fold(0, (sum, v) => sum + ((v['purchaseCount'] ?? 0) as int)).toString(),
                  HeroIcons.documentText,
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // VENDORS LIST
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
                : _filteredVendors.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              color: kPrimaryColor,
              onRefresh: _loadVendors,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                itemCount: _filteredVendors.length,
                separatorBuilder: (c, i) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  return _buildVendorCard(_filteredVendors[index]);
                },
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildStat(String label, String value, HeroIcons icon) {
    return Column(
      children: [
        HeroIcon(icon, color: kPrimaryColor, size: 18),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: kBlack87)),
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kBlack54, letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildVendorCard(Map<String, dynamic> vendor) {
    final totalPurchases = vendor['totalPurchases'] as double;
    final purchaseCount = vendor['purchaseCount'] as int;
    final isFromStockPurchase = vendor['source'] == 'stock_purchase';
    final phone = (vendor['phone'] ?? '').toString();
    final gstin = (vendor['gstin'] ?? '').toString();

    String lastPurchaseText = '';
    if (vendor['lastPurchaseDate'] != null) {
      try {
        final lastDate = (vendor['lastPurchaseDate'] as Timestamp).toDate();
        lastPurchaseText = DateFormat('dd MMM yyyy').format(lastDate);
      } catch (_) {}
    }

    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGrey200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.push(
            context,
            CupertinoPageRoute(builder: (_) => VendorDetailsPage(vendor: vendor, currencySymbol: _currencySymbol)),
          ).then((_) => _loadVendors()),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(children: [
              // Row 1: vendor name | supplier badge or last purchase date
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [
                  const HeroIcon(HeroIcons.buildingStorefront, size: 14, color: kOrange),
                  const SizedBox(width: 5),
                  Text(
                    (vendor['name'] ?? 'Unknown').toString().length > 22
                        ? '${(vendor['name'] ?? 'Unknown').toString().substring(0, 22)}…'
                        : (vendor['name'] ?? 'Unknown').toString(),
                    style: const TextStyle(fontWeight: FontWeight.w900, color: kOrange, fontSize: 13),
                  ),
                ]),
                if (isFromStockPurchase)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: kGoogleGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Text('Supplier', style: TextStyle(fontSize: 8, color: kGoogleGreen, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  )
                else if (lastPurchaseText.isNotEmpty)
                  Text('Last: $lastPurchaseText', style: const TextStyle(fontSize: 10.5, color: Colors.black, fontWeight: FontWeight.w500)),
              ]),
              const SizedBox(height: 10),
              // Row 2: phone (or gstin) | total spent
              Row(children: [
                Expanded(child: Row(children: [
                  const HeroIcon(HeroIcons.devicePhoneMobile, size: 12, color: kBlack54),
                  const SizedBox(width: 4),
                  Text(phone.isNotEmpty ? phone : (gstin.isNotEmpty ? gstin : '--'),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87)),
                ])),
                Text('$_currencySymbol${totalPurchases.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: kGoogleGreen)),
              ]),
              const Divider(height: 20, color: kGreyBg),
              // Row 3: bills count | popup menu + chevron
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Total bills', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: kBlack54, letterSpacing: 0.5)),
                  Text('$purchaseCount ${purchaseCount == 1 ? 'bill' : 'bills'}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 10, color: kBlack87)),
                ]),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  _buildPopupMenu(vendor),
                  const SizedBox(width: 4),
                  const HeroIcon(HeroIcons.chevronRight, color: kPrimaryColor, size: 16),
                ]),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildPopupMenu(Map<String, dynamic> vendor) {
    return PopupMenuButton<String>(
      icon: const HeroIcon(HeroIcons.ellipsisVertical, color: kGrey400, size: 20),
      elevation: 0,
      offset: const Offset(0, 40),
      color: kWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: kPrimaryColor, width: 1),
      ),
      onSelected: (value) {
        if (value == 'edit') {
          _showEditVendorDialog(context, vendor);
        } else if (value == 'delete') {
          _showDeleteConfirmation(context, vendor);
        }
      },
      itemBuilder: (context) => [
        _buildPopupItem('edit', HeroIcons.pencilSquare, 'Edit Profile', kPrimaryColor),
        const PopupMenuDivider(height: 1),
        _buildPopupItem('delete', HeroIcons.trash, 'Remove Vendor', kErrorColor),
      ],
    );
  }

  PopupMenuItem<String> _buildPopupItem(String value, HeroIcons icon, String label, Color color) {
    return PopupMenuItem(
      value: value,
      height: 50,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: HeroIcon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HeroIcon(HeroIcons.users, size: 64, color: kGrey300),
          const SizedBox(height: 16),
          const Text(
            'No suppliers found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kBlack87),
          ),
          const SizedBox(height: 8),
          const Text(
            'Suppliers will be added automatically\nduring product purchases.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: kBlack54),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // DIALOGS
  // ==========================================

  void _showAddVendorDialog(BuildContext context) {
    final nameCtrl = TextEditingController(), phoneCtrl = TextEditingController(), gstinCtrl = TextEditingController(), addressCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: kWhite,
        title: const Text('Add New Vendor', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSectionLabel("Identity"),
              _buildDialogField(nameCtrl, 'Vendor Name *', HeroIcons.user),
              const SizedBox(height: 12),
              _buildDialogField(phoneCtrl, 'Phone Number', HeroIcons.devicePhoneMobile, type: TextInputType.phone),
              const SizedBox(height: 20),
              _buildSectionLabel("Tax & Location"),
              _buildDialogField(gstinCtrl, 'GSTIN (Optional)', HeroIcons.documentText),
              const SizedBox(height: 12),
              _buildDialogField(addressCtrl, 'Physical Address', HeroIcons.mapPin, maxLines: 2),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.bold, color: kBlack54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              try {
                final vendorsCollection = await FirestoreService().getStoreCollection('vendors');
                await vendorsCollection.add({
                  'name': nameCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'gstin': gstinCtrl.text.trim().isEmpty ? null : gstinCtrl.text.trim(),
                  'address': addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                  'totalPurchases': 0.0,
                  'purchaseCount': 0,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (mounted) { Navigator.pop(context); _loadVendors(); }
              } catch (e) { debugPrint(e.toString()); }
            },
            child: const Text('Add Vendor', style: TextStyle(color: kWhite, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          ),
        ],
      ),
    );
  }

  void _showEditVendorDialog(BuildContext context, Map<String, dynamic> vendor) {
    final nameCtrl = TextEditingController(text: vendor['name']), phoneCtrl = TextEditingController(text: vendor['phone']), gstinCtrl = TextEditingController(text: vendor['gstin']), addressCtrl = TextEditingController(text: vendor['address']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: kWhite,
        title: const Text('Edit Vendor Details', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSectionLabel("Identity"),
              _buildDialogField(nameCtrl, 'Vendor Name', HeroIcons.user),
              const SizedBox(height: 12),
              _buildDialogField(phoneCtrl, 'Phone Number', HeroIcons.devicePhoneMobile, type: TextInputType.phone),
              const SizedBox(height: 20),
              _buildSectionLabel("Tax & Location"),
              _buildDialogField(gstinCtrl, 'GSTIN', HeroIcons.documentText),
              const SizedBox(height: 12),
              _buildDialogField(addressCtrl, 'Physical Address', HeroIcons.mapPin, maxLines: 2),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.bold, color: kBlack54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              try {
                final vendorsCollection = await FirestoreService().getStoreCollection('vendors');
                await vendorsCollection.doc(vendor['id']).update({
                  'name': nameCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'gstin': gstinCtrl.text.trim().isEmpty ? null : gstinCtrl.text.trim(),
                  'address': addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                  'lastUpdated': FieldValue.serverTimestamp(),
                });
                if (mounted) { Navigator.pop(context); _loadVendors(); }
              } catch (e) { debugPrint(e.toString()); }
            },
            child: const Text('Save changes', style: TextStyle(color: kWhite, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Map<String, dynamic> vendor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: kWhite,
        title: const Text('Remove Vendor?', style: TextStyle(fontWeight: FontWeight.w800, color: kBlack87)),
        content: Text('Are you sure you want to remove "${vendor['name']}"? This action cannot be undone.', style: const TextStyle(color: kBlack54, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.bold, color: kBlack54))),
          ElevatedButton(
            onPressed: () async {
              try {
                final vendorsCollection = await FirestoreService().getStoreCollection('vendors');
                await vendorsCollection.doc(vendor['id']).delete();
                if (mounted) { Navigator.pop(context); _loadVendors(); }
              } catch (e) { debugPrint(e.toString()); }
            },
            style: ElevatedButton.styleFrom(backgroundColor: kErrorColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text("Delete", style: TextStyle(color: kWhite,fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) => Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(bottom: 8, left: 4), child: Text(text, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kBlack54, letterSpacing: 0.5))));
 
  Widget _buildNoResults() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const HeroIcon(HeroIcons.magnifyingGlass, size: 64, color: kGrey300), const SizedBox(height: 16), Text('No results for "$_searchQuery"', style: const TextStyle(color: kBlack54))]));

  Widget _buildDialogField(TextEditingController ctrl, String label, HeroIcons icon, {TextInputType type = TextInputType.text, int maxLines = 1}) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: ctrl,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextField(
          controller: ctrl, keyboardType: type, maxLines: maxLines,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kBlack87),
          decoration: InputDecoration(
            hintText: label,
            prefixIcon: HeroIcon(icon, color: hasText ? kPrimaryColor : kBlack54, size: 18),
            filled: true, fillColor: const Color(0xFFF8F9FA),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: hasText ? kPrimaryColor : kGrey200, width: hasText ? 1.5 : 1.0)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: hasText ? kPrimaryColor : kGrey200, width: hasText ? 1.5 : 1.0)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimaryColor, width: 2.0)),
          ),
        );
      },
    );
  }
}

// ==========================================
// VENDOR DETAILS PAGE
// ==========================================
class VendorDetailsPage extends StatefulWidget {
  final Map<String, dynamic> vendor;
  final String currencySymbol;

  const VendorDetailsPage({super.key, required this.vendor, required this.currencySymbol});

  @override
  State<VendorDetailsPage> createState() => _VendorDetailsPageState();
}

class _VendorDetailsPageState extends State<VendorDetailsPage> {
  late Map<String, dynamic> _vendor;
  List<Map<String, dynamic>> _purchases = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _vendor = Map<String, dynamic>.from(widget.vendor);
    _loadPurchases();
  }

  Future<void> _loadPurchases() async {
    setState(() => _isLoading = true);
    try {
      final col = await FirestoreService().getStoreCollection('stockPurchases');
      final supplierName = (_vendor['name'] ?? '').toString();
      final vendorId = (_vendor['id'] ?? '').toString();

      // Try query by supplierName first
      var snap = await col.where('supplierName', isEqualTo: supplierName).orderBy('timestamp', descending: true).get();

      // If no results, try by vendorId
      if (snap.docs.isEmpty && vendorId.isNotEmpty) {
        snap = await col.where('vendorId', isEqualTo: vendorId).orderBy('timestamp', descending: true).get();
      }

      if (mounted) {
        setState(() {
          _purchases = snap.docs.map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>}).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading vendor purchases: $e');
      // Fallback: try without orderBy (index might be missing)
      try {
        final col = await FirestoreService().getStoreCollection('stockPurchases');
        final supplierName = (_vendor['name'] ?? '').toString();
        final snap = await col.where('supplierName', isEqualTo: supplierName).get();
        if (mounted) {
          final docs = snap.docs.map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>}).toList();
          // Sort manually
          docs.sort((a, b) {
            final tsA = a['timestamp'] as Timestamp?;
            final tsB = b['timestamp'] as Timestamp?;
            if (tsA == null || tsB == null) return 0;
            return tsB.compareTo(tsA);
          });
          setState(() {
            _purchases = docs;
            _isLoading = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (_vendor['name'] ?? 'Vendor').toString();
    final phone = (_vendor['phone'] ?? '').toString();
    final gstin = (_vendor['gstin'] ?? '').toString();
    final address = (_vendor['address'] ?? '').toString();
    final totalPurchases = (_vendor['totalPurchases'] ?? 0.0).toDouble();
    final purchaseCount = (_vendor['purchaseCount'] ?? 0) as int;

    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))),
        title: Text(name, style: const TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: kPrimaryColor,
        leading: IconButton(
          icon: const HeroIcon(HeroIcons.arrowLeft, color: kWhite, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const HeroIcon(HeroIcons.pencilSquare, color: kWhite, size: 20),
            onPressed: () => _showEditDialog(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: kPrimaryColor,
        onRefresh: _loadPurchases,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Vendor Info Card
            Container(
              decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  CircleAvatar(
                    backgroundColor: kOrange.withValues(alpha: 0.12),
                    radius: 24,
                    child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'V',
                        style: const TextStyle(color: kOrange, fontWeight: FontWeight.w900, fontSize: 20)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: kBlack87)),
                    if (phone.isNotEmpty) Row(children: [
                      const HeroIcon(HeroIcons.devicePhoneMobile, size: 12, color: kBlack54),
                      const SizedBox(width: 4),
                      Text(phone, style: const TextStyle(fontSize: 12, color: kBlack54, fontWeight: FontWeight.w500)),
                    ]),
                    if (gstin.isNotEmpty) Row(children: [
                      const HeroIcon(HeroIcons.documentText, size: 12, color: kBlack54),
                      const SizedBox(width: 4),
                      Text('GSTIN: $gstin', style: const TextStyle(fontSize: 12, color: kBlack54, fontWeight: FontWeight.w500)),
                    ]),
                    if (address.isNotEmpty) Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const HeroIcon(HeroIcons.mapPin, size: 12, color: kBlack54),
                      const SizedBox(width: 4),
                      Expanded(child: Text(address, style: const TextStyle(fontSize: 12, color: kBlack54, fontWeight: FontWeight.w500))),
                    ]),
                  ])),
                ]),
                const Divider(height: 20, color: kGreyBg),
                // Summary stats row
                Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _buildStat(_purchases.length == 1 ? 'Bill' : 'Bills', _isLoading ? purchaseCount.toString() : _purchases.length.toString(), kPrimaryColor),
                  _buildStat('Total Spent', '${widget.currencySymbol}${totalPurchases.toStringAsFixed(0)}', kGoogleGreen),
                ]),
              ]),
            ),
            const SizedBox(height: 16),

            // Purchase History Header
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 12),
              child: Text('Purchase History', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: kBlack87)),
            ),

            // Purchase Bills
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: kPrimaryColor)))
            else if (_purchases.isEmpty)
              Center(child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(children: [
                  const HeroIcon(HeroIcons.shoppingCart, size: 48, color: kGrey300),
                  const SizedBox(height: 12),
                  const Text('No purchase bills found', style: TextStyle(color: kBlack54, fontWeight: FontWeight.w600)),
                ]),
              ))
            else
              ...List.generate(_purchases.length, (i) {
                final p = _purchases[i];
                final ts = p['timestamp'] as Timestamp?;
                final dateStr = ts != null ? DateFormat('dd MMM yyyy').format(ts.toDate()) : 'N/A';
                final amount = (p['totalAmount'] ?? 0.0).toDouble();
                final paidAmount = (p['paidAmount'] ?? 0.0).toDouble();
                final creditAmount = (amount - paidAmount).clamp(0.0, double.infinity);
                final invoiceNumber = (p['invoiceNumber'] ?? 'N/A').toString();
                final paymentMode = (p['paymentMode'] ?? 'Cash').toString();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Column(children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Row(children: [
                            const HeroIcon(HeroIcons.documentText, size: 14, color: kPrimaryColor),
                            const SizedBox(width: 5),
                            Text(invoiceNumber, style: const TextStyle(fontWeight: FontWeight.w900, color: kPrimaryColor, fontSize: 13)),
                          ]),
                          Text(dateStr, style: const TextStyle(fontSize: 10.5, color: Colors.black, fontWeight: FontWeight.w500)),
                        ]),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(child: Text('Total Amount', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87))),
                          Text('${widget.currencySymbol}${amount.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: kGoogleGreen)),
                        ]),
                        const Divider(height: 20, color: kGreyBg),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Payment mode', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: kBlack54, letterSpacing: 0.5)),
                            Text(paymentMode, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 10, color: kBlack87)),
                          ]),
                          if (creditAmount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: kErrorColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: kErrorColor.withValues(alpha: 0.2))),
                              child: Text('Credit: ${widget.currencySymbol}${creditAmount.toStringAsFixed(0)}',
                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kErrorColor)),
                            ),
                        ]),
                      ]),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(children: [
      Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: color)),
      Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kBlack54, letterSpacing: 0.5)),
    ]);
  }

  void _showEditDialog(BuildContext context) {
    final nameCtrl = TextEditingController(text: _vendor['name']);
    final phoneCtrl = TextEditingController(text: _vendor['phone']);
    final gstinCtrl = TextEditingController(text: _vendor['gstin']);
    final addressCtrl = TextEditingController(text: _vendor['address']);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: kWhite,
        title: const Text('Edit Vendor', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          _buildField(nameCtrl, 'Vendor Name'),
          const SizedBox(height: 12),
          _buildField(phoneCtrl, 'Phone', type: TextInputType.phone),
          const SizedBox(height: 12),
          _buildField(gstinCtrl, 'GSTIN'),
          const SizedBox(height: 12),
          _buildField(addressCtrl, 'Address', maxLines: 2),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: kBlack54, fontWeight: FontWeight.bold))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              try {
                final col = await FirestoreService().getStoreCollection('vendors');
                await col.doc(_vendor['id']).update({
                  'name': nameCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'gstin': gstinCtrl.text.trim().isEmpty ? null : gstinCtrl.text.trim(),
                  'address': addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                  'lastUpdated': FieldValue.serverTimestamp(),
                });
                if (mounted) {
                  setState(() {
                    _vendor['name'] = nameCtrl.text.trim();
                    _vendor['phone'] = phoneCtrl.text.trim();
                    _vendor['gstin'] = gstinCtrl.text.trim();
                    _vendor['address'] = addressCtrl.text.trim();
                  });
                  Navigator.pop(ctx);
                }
              } catch (e) { debugPrint(e.toString()); }
            },
            child: const Text('Save', style: TextStyle(color: kWhite, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String hint, {TextInputType type = TextInputType.text, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      maxLines: maxLines,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: kGreyBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGrey200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGrey200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimaryColor, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

