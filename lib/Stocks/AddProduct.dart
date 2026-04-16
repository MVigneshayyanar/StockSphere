import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/components/app_mini_switch.dart';
import 'package:maxbillup/components/barcode_scanner.dart';
import 'package:maxbillup/utils/permission_helper.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/Colors.dart';
import 'package:intl/intl.dart';
import 'AddCategoryPopup.dart';
import 'package:maxbillup/services/excel_import_service.dart';
import 'package:maxbillup/utils/plan_permission_helper.dart';
import 'package:heroicons/heroicons.dart';

class AddProductPage extends StatefulWidget {
  final String uid;
  final String? userEmail;
  final String? preSelectedCategory;
  final String? productId;
  final Map<String, dynamic>? existingData;

  const AddProductPage({
    super.key,
    required this.uid,
    this.userEmail,
    this.preSelectedCategory,
    this.productId,
    this.existingData,
  });

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _costPriceController = TextEditingController();
  final TextEditingController _mrpController = TextEditingController();
  final TextEditingController _productCodeController = TextEditingController();
  final TextEditingController _hsnController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _lowStockAlertController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _expiryDateController = TextEditingController();

  DateTime? _selectedExpiryDate;
  String? _selectedCategory;
  bool _stockEnabled = true;
  String? _selectedStockUnit = 'Piece';
  Stream<List<String>>? _unitsStream;
  String _lowStockAlertType = 'Count';
  bool _isFavorite = false;
  bool _isLoading = false;
  bool _advancedExpanded = false;

  // Tax State
  String _selectedTaxType = 'Add Tax at Billing';
  List<Map<String, dynamic>> _fetchedTaxes = [];
  List<String> _selectedTaxIds = []; // Multiple tax selection

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.preSelectedCategory ?? 'General';
    _checkPermission();
    _fetchUnits();
    _fetchTaxesFromBackend();

    if (widget.existingData != null) {
      _loadExistingData();
    } else {
      _generateProductCode();
      // Ensure new products have a default cost of 0 so reports can calculate safely
      _costPriceController.text = '0';
    }
  }

  // ==========================================
  // LOGIC METHODS
  // ==========================================

  Future<void> _fetchTaxesFromBackend() async {
    try {
      final storeId = await FirestoreService().getCurrentStoreId();
      if (storeId == null) return;
      final snapshot = await FirebaseFirestore.instance
          .collection('store')
          .doc(storeId)
          .collection('taxes')
          .get();
      setState(() {
        _fetchedTaxes = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'] ?? 'Unnamed',
            'percentage': (data['percentage'] ?? 0.0).toDouble(),
          };
        }).toList();
        if (widget.existingData != null) {
          // Load multiple taxes (new format)
          final existingTaxes = widget.existingData!['taxes'];
          if (existingTaxes is List && existingTaxes.isNotEmpty) {
            _selectedTaxIds = existingTaxes
                .map((t) => t['id']?.toString() ?? '')
                .where((id) => id.isNotEmpty)
                .toList();
          }
          // Fallback: load single tax (legacy format)
          else if (widget.existingData!['taxId'] != null) {
            _selectedTaxIds = [widget.existingData!['taxId'].toString()];
          }
        }
      });
    } catch (e) { debugPrint('Error: $e'); }
  }

  Future<void> _addNewTaxToBackend(String name, double percentage) async {
    try {
      final storeId = await FirestoreService().getCurrentStoreId();
      if (storeId == null) return;
      final newTaxDoc = {
        'name': name, 'percentage': percentage, 'isActive': true, 'productCount': 0,
        'createdAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp(),
      };
      final docRef = await FirebaseFirestore.instance.collection('store').doc(storeId).collection('taxes').add(newTaxDoc);
      await _fetchTaxesFromBackend();
      setState(() { _selectedTaxIds.add(docRef.id); });
    } catch (e) { debugPrint('Error: $e'); }
  }

  Future<void> _checkPermission() async {
    final userData = await PermissionHelper.getUserPermissions(widget.uid);
    final r = userData['role'].toLowerCase();
    final isAdmin = r == 'owner';
    if (userData['permissions']['addProduct'] != true && !isAdmin && mounted) {
      Navigator.pop(context);
      PermissionHelper.showPermissionDeniedDialog(context);
    }
  }

  void _fetchUnits() async {
    final storeId = await FirestoreService().getCurrentStoreId();
    if (storeId == null) return;
    setState(() {
      _unitsStream = FirebaseFirestore.instance.collection('store').doc(storeId).collection('units').snapshots()
          .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
    });
  }

  void _generateProductCode() async {
    try {
      final productsCollection = await FirestoreService().getStoreCollection('Products');
      final snap = await productsCollection.orderBy('productCode', descending: true).limit(1).get();
      int next = 1001;
      if (snap.docs.isNotEmpty) {
        final code = snap.docs.first['productCode'].toString();
        final numPart = int.tryParse(code.replaceAll(RegExp(r'[^0-9]'), ''));
        if (numPart != null) next = numPart + 1;
      }
      setState(() => _productCodeController.text = '$next');
    } catch (e) {
      setState(() => _productCodeController.text = '${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}');
    }
  }

  Future<bool> _checkProductCodeExists(String code) async {
    try {
      final productsCollection = await FirestoreService().getStoreCollection('Products');
      final existingProduct = await productsCollection.where('productCode', isEqualTo: code).get();
      if (existingProduct.docs.isNotEmpty) {
        final data = existingProduct.docs.first.data() as Map<String, dynamic>?;
        final productName = data?['itemName'] ?? 'Unknown Product';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Code is already mapped with $productName'),
              backgroundColor: kErrorColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        return true;
      }
      return false;
    } catch (e) { return false; }
  }

  Future<void> _scanBarcode() async {
    final result = await Navigator.push(context, CupertinoPageRoute(
      builder: (context) => BarcodeScannerPage(onBarcodeScanned: (barcode) => Navigator.pop(context, barcode)),
    ));
    if (result != null && mounted) setState(() => _barcodeController.text = result);
  }

  void _showImportExcelDialog() async {
    // Plan check - Bulk Product Upload requires paid plan
    final canBulkUpload = await PlanPermissionHelper.canUseBulkInventory();
    if (!canBulkUpload) {
      if (mounted) PlanPermissionHelper.showUpgradeDialog(context, 'Bulk Product Upload');
      return;
    }
    if (!mounted) return;

    // IMPORTANT: Capture State's context BEFORE showing any dialog
    final stateContext = context;
    final stateNavigator = Navigator.of(context, rootNavigator: true);
    final stateScaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: stateContext,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const HeroIcon(
                  HeroIcons.documentArrowUp,
                  color: kPrimaryColor,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                'Import Products',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: kBlack87,
                ),
              ),
              const SizedBox(height: 8),

              // Description
              const Text(
                'Download the template, fill it with product data, and upload it back.',
                style: TextStyle(
                  fontSize: 13,
                  color: kBlack54,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Download Template Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    // Download first, then close dialog and show result
                    final result = await ExcelImportService.downloadProductTemplate();
                    if (!mounted) return;

                    // Close the import dialog
                    Navigator.pop(dialogContext);

                    if (result != null && !result.startsWith('Error') && !result.toLowerCase().contains('denied')) {
                      // Show success dialog using STATE context
                      if (!mounted) return;
                      showDialog(
                        context: stateContext,
                        builder: (BuildContext successDialogContext) {
                          final fileName = result.split(RegExp(r'[/\\]')).last;
                          return AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            backgroundColor: Colors.white,
                            title: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [kGoogleGreen, kGoogleGreen.withValues(alpha: 0.7)],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: kGoogleGreen.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const HeroIcon(HeroIcons.checkCircle, color: Colors.white, size: 28),
                                ),
                                const SizedBox(width: 16),
                                const Expanded(
                                  child: Text(
                                    'Success!',
                                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Product template has been downloaded to your Downloads folder',
                                  style: TextStyle(fontSize: 14, color: kBlack54, height: 1.4),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.blue.shade50, Colors.blue.shade100],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.blue.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: kPrimaryColor,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const HeroIcon(HeroIcons.documentText, color: Colors.white, size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              fileName,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black87,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 2,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Excel Template',
                                              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: kGoogleGreen.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: kGoogleGreen.withValues(alpha: 0.3)),
                                  ),
                                  child: const Row(
                                    children: [
                                      HeroIcon(HeroIcons.folder, color: kGoogleGreen, size: 18),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Check your Downloads folder',
                                          style: TextStyle(fontSize: 14, color: kGoogleGreen, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(successDialogContext),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                ),
                                child: const Text('Close', style: TextStyle(color: kBlack54, fontSize: 14)),
                              ),
                            ],
                          );
                        },
                      );
                    } else {
                      stateScaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text(result ?? 'Failed to download template'),
                          backgroundColor: kErrorColor,
                        ),
                      );
                    }
                  },
                  icon: const HeroIcon(HeroIcons.arrowDownTray, size: 20),
                  label: const Text(
                    'Download Template',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kPrimaryColor,
                    side: const BorderSide(color: kPrimaryColor, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Upload Excel Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: const HeroIcon(HeroIcons.arrowUpTray, size: 20),
                  label: const Text(
                    'Upload Excel',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: kWhite,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    try {
                      // First, pick the Excel file (BEFORE closing import dialog)
                      print('📂 Opening file picker for products...');
                      final fileBytes = await ExcelImportService.pickExcelFile();
                      print('📂 File picked: ${fileBytes != null ? '${fileBytes.length} bytes' : 'null (cancelled)'}');

                      // If user cancelled file picker, just return (import dialog stays open)
                      if (fileBytes == null) {
                        print('📂 User cancelled file selection');
                        return;
                      }

                      // Now close the import dialog since we have a file
                      if (!mounted) return;
                      Navigator.pop(dialogContext); // Close import dialog using dialog's context

                      // File was selected, now show loading dialog
                      if (!mounted) return;

                      print('⏳ Showing loading dialog...');

                      // Use mounted check with fresh context reference
                      if (!mounted) return;

                      showDialog(
                        context: context, // Use fresh context from mounted widget
                        barrierDismissible: false,
                        builder: (loadingContext) => PopScope(
                          canPop: false,
                          child: Dialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            backgroundColor: Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.all(28),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: kPrimaryColor.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const HeroIcon(
                                      HeroIcons.documentArrowUp,
                                      color: kPrimaryColor,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  const Text(
                                    'Importing Products',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: kBlack87,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Processing your Excel file...',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 24),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: const LinearProgressIndicator(
                                      backgroundColor: kGrey200,
                                      valueColor: AlwaysStoppedAnimation<Color>(kPrimaryColor),
                                      minHeight: 6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );

                      // Process the Excel file bytes
                      print('🔄 Processing Excel file for products...');
                      final result = await ExcelImportService.processProductsExcel(fileBytes, widget.uid);
                      print('✅ Result: ${result['success']}, Success: ${result['successCount']}, Failed: ${result['failCount']}');

                      // Close loading dialog
                      if (!mounted) return;
                      Navigator.of(context).pop();
                      print('❌ Loading dialog closed');

                      if (!mounted) return;

                      if (result['success']) {
                        final successCount = result['successCount'] ?? 0;
                        final failCount = result['failCount'] ?? 0;
                        final errors = result['errors'] as List<String>? ?? [];

                        // Show success message
                        if (!mounted) return;
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (successDialogContext) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            backgroundColor: Colors.white,
                            title: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [kGoogleGreen, kGoogleGreen.withValues(alpha: 0.7)],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: kGoogleGreen.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const HeroIcon(HeroIcons.checkCircle, color: Colors.white, size: 28),
                                ),
                                const SizedBox(width: 16),
                                const Expanded(
                                  child: Text(
                                    'Import Complete!',
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.green.shade50, Colors.green.shade100],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const HeroIcon(HeroIcons.cube, color: kGoogleGreen, size: 24),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          '$successCount product${successCount != 1 ? 's' : ''} added successfully',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: kGoogleGreen,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (failCount > 0) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        const HeroIcon(HeroIcons.exclamationTriangle, color: kOrange, size: 24),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            '$failCount row${failCount != 1 ? 's' : ''} skipped',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: kOrange,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (errors.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  const Text('Issues:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  const SizedBox(height: 8),
                                  Container(
                                    constraints: const BoxConstraints(maxHeight: 120),
                                    child: SingleChildScrollView(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: errors.take(5).map((e) => Padding(
                                          padding: const EdgeInsets.only(bottom: 4),
                                          child: Text('• $e', style: const TextStyle(fontSize: 12, color: kBlack54)),
                                        )).toList(),
                                      ),
                                    ),
                                  ),
                                  if (errors.length > 5)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        '... and ${errors.length - 5} more',
                                        style: const TextStyle(fontSize: 11, color: kBlack54, fontStyle: FontStyle.italic),
                                      ),
                                    ),
                                ],
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(successDialogContext); // Close success dialog
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  backgroundColor: kPrimaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Done',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        );
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(result['message'] ?? 'Import failed'),
                              backgroundColor: kErrorColor,
                            ),
                          );
                        }
                      }
                    } catch (e, stackTrace) {
                      // Catch any error in the flow
                      print('💥 Error in product import: $e');
                      print('Stack trace: $stackTrace');

                      // Try to close loading dialog if it's open
                      if (mounted) {
                        try {
                          Navigator.of(context).pop();
                        } catch (_) {}

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error during import: ${e.toString()}'),
                            backgroundColor: kErrorColor,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Cancel Button
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kBlack54,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // UI BUILD METHODS
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        title: Text(context.tr(widget.productId != null ? 'edit_product' : 'add_product'),
            style: const TextStyle(fontWeight: FontWeight.w700, color: kWhite, fontSize: 18)),
        leading: IconButton(icon: const HeroIcon(HeroIcons.arrowLeft, color: kWhite, size: 20), onPressed: () => Navigator.pop(context)),
        actions: widget.productId == null ? [
          IconButton(
            icon: const HeroIcon(HeroIcons.arrowUpTray, color: kWhite, size: 22),
            onPressed: () => _showImportExcelDialog(),
            tooltip: 'Import from Excel',
          ),
        ] : null,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader("Basic Details"),
                    _buildCategoryDropdown(),
                    const SizedBox(height: 16),
                    _buildItemNameWithFavorite(),
                    const SizedBox(height: 16),
                    _buildProductCodeField(),
                    const SizedBox(height: 16),
                    _buildModernTextField(
                      controller: _priceController,
                      label: "Price",
                      icon: HeroIcons.banknotes,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      isRequired: true,
                      hint: "0.00",
                    ),
                    const SizedBox(height: 16),
                    _buildTrackStockAndQuantity(),
                    const SizedBox(height: 16),
                    _buildUnitDropdown(),
                    const SizedBox(height: 24),

                    // ADVANCED SECTION
                    _buildAdvancedSection(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            _buildBottomSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tappable header row
        InkWell(
          onTap: () => setState(() => _advancedExpanded = !_advancedExpanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(child: _buildSectionHeader("Advanced Details")),
                AnimatedRotation(
                  turns: _advancedExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: Icon(
                    Icons.expand_more,
                    color: _advancedExpanded ? kPrimaryColor : kBlack54,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Animated expand/collapse — keeps widgets in tree so ListView count is stable
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: Offstage(
            offstage: !_advancedExpanded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                _buildModernTextField(
                  controller: _barcodeController,
                  label: "Barcode String",
                  icon: HeroIcons.qrCode,
                  hint: "Scan or type barcode",
                  suffixIcon: HeroIcons.viewfinderCircle,
                  onSuffixTap: _scanBarcode,
                ),
                const SizedBox(height: 16),
                _buildModernTextField(
                  controller: _costPriceController,
                  label: "Total Cost Price",
                  icon: HeroIcons.shoppingCart,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  hint: "0.00",
                ),
                const SizedBox(height: 16),
                _buildModernTextField(
                  controller: _mrpController,
                  label: "MRP",
                  icon: HeroIcons.tag,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  hint: "Maximum Retail Price",
                ),
                const SizedBox(height: 16),
                _buildTaxDropdown(),
                const SizedBox(height: 16),
                _buildTaxTypeSelector(),
                const SizedBox(height: 16),
                _buildModernTextField(
                  controller: _locationController,
                  label: "Product Location",
                  icon: HeroIcons.mapPin,
                  hint: "e.g. Shelf A3, Warehouse B",
                ),
                const SizedBox(height: 16),
                _buildExpiryDateField(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 10,
          color: kBlack54,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildKnobSwitch(bool value, Function(bool) onChanged) {
    return AppMiniSwitch(value: value, onChanged: onChanged);
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required HeroIcons icon,
    bool isRequired = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? hint,
    HeroIcons? suffixIcon,
    VoidCallback? onSuffixTap,
    Color? iconColor,
  }) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final bool isFilled = value.text.isNotEmpty;
        return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kBlack87),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            prefixIcon: HeroIcon(icon, color: isFilled ? (iconColor ?? kPrimaryColor) : kBlack54, size: 20),
            suffixIcon: suffixIcon != null
                ? IconButton(icon: HeroIcon(suffixIcon, color: kPrimaryColor, size: 20), onPressed: onSuffixTap)
                : null,
            
            
            
            
            
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kErrorColor),
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
          validator: isRequired ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
        
);
      },
    );
      },
    );
  }

  Widget _buildItemNameWithFavorite() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildModernTextField(
            controller: _itemNameController,
            label: "Item Name",
            icon: HeroIcons.shoppingBag,
            isRequired: true,
            hint: "Enter product name",
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: () => setState(() => _isFavorite = !_isFavorite),
          child: Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: _isFavorite ? kPrimaryColor.withValues(alpha: 0.1) : kWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _isFavorite ? kPrimaryColor : kGrey200, width: 1.5),
            ),
            child: HeroIcon(
              HeroIcons.heart,
              style: _isFavorite ? HeroIconStyle.solid : HeroIconStyle.outline,
              color: _isFavorite ? kPrimaryColor : kBlack54,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductCodeField() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildModernTextField(
            controller: _productCodeController,
            label: "Product Code",
            icon: HeroIcons.qrCode,
            isRequired: true,
            hint: "Unique ID",
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: _generateProductCode,
          child: Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: kPrimaryColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const HeroIcon(HeroIcons.arrowPath, color: kWhite, size: 22),
          ),
        ),
      ],
    );
  }

  Widget _buildTrackStockAndQuantity() {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: kWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kGrey200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Track Stock", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: kBlack87)),
                    _buildKnobSwitch(_stockEnabled, (v) => setState(() => _stockEnabled = v)),
                  ],
                ),
              ),
            ),
            if (_stockEnabled) ...[
              const SizedBox(width: 12),
              Expanded(
                child: _buildModernTextField(
                  controller: _quantityController,
                  label: "Initial Stock",
                  icon: HeroIcons.archiveBox,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  isRequired: true,
                  hint: "0.00",
                ),
              ),
            ],
          ],
        ),
        if (!_stockEnabled) ...[
          const SizedBox(height: 12),
          _buildInfinityStockIndicator(),
        ],
        // RESTORED: Low Stock Alert row
        if (_stockEnabled) ...[
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _buildModernTextField(
                  controller: _lowStockAlertController,
                  label: "Low Stock Alert",
                  icon: HeroIcons.bellAlert,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  hint: "0.00",
                  iconColor: kOrange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _wrapDropdown(
                  "Alert Type",
                  DropdownButton<String>(
                    value: ['Count', 'Percentage'].contains(_lowStockAlertType) ? _lowStockAlertType : 'Count',
                    isExpanded: true,
                    isDense: true,
                    items: const [
                      DropdownMenuItem(value: 'Count', child: Text('Count')),
                      DropdownMenuItem(value: 'Percentage', child: Text('Percentage')),
                    ],
                    onChanged: (val) => setState(() => _lowStockAlertType = val!),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildInfinityStockIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kGoogleGreen.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGoogleGreen.withOpacity(0.2)),
      ),
      child: const Row(
        children: [
          HeroIcon(HeroIcons.arrowPath, color: kGoogleGreen, size: 18),
          SizedBox(width: 12),
          Text("Infinity Stock Enabled", style: TextStyle(color: kGoogleGreen, fontWeight: FontWeight.w800, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return FutureBuilder<Stream<QuerySnapshot>>(
      future: FirestoreService().getCollectionStream('categories'),
      builder: (context, streamSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: streamSnapshot.data,
          builder: (context, snapshot) {
            List<String> categories = ['General'];
            if (snapshot.hasData) {
              categories.addAll(snapshot.data!.docs
                  .map((doc) => (doc.data() as Map<String, dynamic>)['name'] as String)
                  .where((name) => name != 'General')
                  .toList());
            }
            return _wrapDropdown(
              "Category",
              DropdownButton<String>(
                value: categories.contains(_selectedCategory) ? _selectedCategory : categories.first,
                isExpanded: true,
                isDense: true,
                items: [
                  ...categories.map((e) => DropdownMenuItem(value: e, child: Text(e))),
                  const DropdownMenuItem(value: '__create_new__', child: Text('+ New Category', style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold))),
                ],
                onChanged: (val) async {
                  if (val == '__create_new__') {
                    final newCategory = await showDialog<String>(context: context, builder: (ctx) => AddCategoryPopup(uid: widget.uid));
                    if (newCategory != null && newCategory.isNotEmpty) setState(() => _selectedCategory = newCategory);
                  } else {
                    setState(() => _selectedCategory = val!);
                  }
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUnitDropdown() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getUnitsWithMetadata(),
      builder: (context, snapshot) {
        // Default units that cannot be deleted
        final defaultUnits = ['Piece', 'Kg', 'Liter', 'Box', 'Nos', 'Meter', 'Feet', 'Gram', 'ML'];
        final customUnits = snapshot.data ?? [];
        final allUnits = [...defaultUnits, ...customUnits.map((u) => u['name'] as String)];

        return _wrapDropdown(
          "Measurement Unit",
          DropdownButton<String>(
            value: allUnits.contains(_selectedStockUnit) ? _selectedStockUnit : allUnits.first,
            isExpanded: true,
            isDense: true,
            items: allUnits.map((unit) {
              final isCustom = customUnits.any((u) => u['name'] == unit);
              return DropdownMenuItem(
                value: unit,
                child: Row(
                  children: [
                    Expanded(child: Text(unit)),
                    if (isCustom)
                      GestureDetector(
                        onTap: () => _showDeleteUnitDialog(unit),
                        child: const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: HeroIcon(HeroIcons.trash, color: kErrorColor, size: 18),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (v) => setState(() => _selectedStockUnit = v),
          ),
          onAdd: _showAddUnitDialog,
        );
      },
    );
  }

  Stream<List<Map<String, dynamic>>> _getUnitsWithMetadata() async* {
    final storeId = await FirestoreService().getCurrentStoreId();
    if (storeId == null) {
      yield [];
      return;
    }
    yield* FirebaseFirestore.instance
        .collection('store')
        .doc(storeId)
        .collection('units')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {'name': doc.id, 'id': doc.id}).toList());
  }

  void _showDeleteUnitDialog(String unitName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("Delete Unit?", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: Text('Are you sure you want to delete "$unitName"? Products using this unit will not be affected.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final storeId = await FirestoreService().getCurrentStoreId();
              if (storeId != null) {
                await FirebaseFirestore.instance
                    .collection('store')
                    .doc(storeId)
                    .collection('units')
                    .doc(unitName)
                    .delete();
              }
              if (mounted) {
                // Reset to default if deleted unit was selected
                if (_selectedStockUnit == unitName) {
                  setState(() => _selectedStockUnit = 'Piece');
                }
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Unit "$unitName" deleted'),
                    backgroundColor: kGoogleGreen,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: kErrorColor),
            child: const Text("Delete", style: TextStyle(color: kWhite, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildTaxDropdown() {
    final selectedTaxes = _fetchedTaxes.where((t) => _selectedTaxIds.contains(t['id'])).toList();
    final combinedPercentage = selectedTaxes.fold<double>(0.0, (sum, t) => sum + (t['percentage'] as double));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text("Tax Rates", style: TextStyle(color: kBlack54, fontSize: 13, fontWeight: FontWeight.w600)),
            const Spacer(),
            if (combinedPercentage > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Total: ${combinedPercentage.toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: kPrimaryColor),
                ),
              ),
            const SizedBox(width: 8),
            InkWell(
              onTap: _showAddTaxDialog,
              child: const HeroIcon(HeroIcons.plusCircle, color: kPrimaryColor, size: 22),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_fetchedTaxes.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(10)),
            child: const Text('No taxes defined. Tap + to add.', style: TextStyle(color: kBlack54, fontSize: 12)),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _fetchedTaxes.map((tax) {
              final isSelected = _selectedTaxIds.contains(tax['id']);
              return FilterChip(
                label: Text(
                  "${tax['name']} (${(tax['percentage'] as double).toStringAsFixed(1)}%)",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? kWhite : kBlack87,
                  ),
                ),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedTaxIds.add(tax['id']);
                    } else {
                      _selectedTaxIds.remove(tax['id']);
                    }
                  });
                },
                selectedColor: kPrimaryColor,
                backgroundColor: kGreyBg,
                checkmarkColor: kWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: isSelected ? kPrimaryColor : kGrey200),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildTaxTypeSelector() {
    final items = ['Tax Included in Price', 'Add Tax at Billing', 'No Tax Applied', 'Exempt from Tax'];
    return _wrapDropdown(
      "Tax Treatment",
      DropdownButton<String>(
        value: items.contains(_selectedTaxType) ? _selectedTaxType : items[1],
        isExpanded: true,
        isDense: true,
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: (v) => setState(() => _selectedTaxType = v!),
      ),
    );
  }

  Widget _buildExpiryDateField() {
    return GestureDetector(
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: _selectedExpiryDate ?? DateTime.now().add(const Duration(days: 365)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 3650)),
          builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: kPrimaryColor)),
            child: child!,
          ),
        );
        if (picked != null) {
          setState(() {
            _selectedExpiryDate = picked;
            _expiryDateController.text = DateFormat('dd/MM/yyyy').format(picked);
          });
        }
      },
      child: AbsorbPointer(
        child: _buildModernTextField(
          controller: _expiryDateController,
          label: "Expiry Date",
          icon: HeroIcons.calendar,
          hint: "Select date",
          suffixIcon: HeroIcons.calendarDays,
        ),
      ),
    );
  }

  Widget _wrapDropdown(String label, Widget child, {VoidCallback? onAdd}) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: kBlack54, fontSize: 13),
        
        
        

        
        suffixIcon: onAdd != null ? IconButton(icon: const HeroIcon(HeroIcons.plusCircle, color: kPrimaryColor, size: 22), onPressed: onAdd) : null,
        floatingLabelStyle: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w800),
      ),
      child: DropdownButtonHideUnderline(child: child),
    );
  }

  void _showAddUnitDialog() {
    final unitController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("New Unit", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: ValueListenableBuilder<TextEditingValue>(
      valueListenable: unitController,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextField(
          controller: unitController,
          style: const TextStyle(fontWeight: FontWeight.w600),
          decoration: InputDecoration(hintText: "e.g. Dozen, Box",
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
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (unitController.text.trim().isEmpty) return;
              final storeId = await FirestoreService().getCurrentStoreId();
              if (storeId != null) {
                await FirebaseFirestore.instance.collection('store').doc(storeId).collection('units').doc(unitController.text.trim()).set({'createdAt': FieldValue.serverTimestamp()});
              }
              if (mounted) { setState(() => _selectedStockUnit = unitController.text.trim()); Navigator.pop(ctx); }
            },
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
            child: const Text("Add", style: TextStyle(color: kWhite, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  void _showAddTaxDialog() {
    final nameC = TextEditingController();
    final rateC = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("New Tax Rate", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<TextEditingValue>(
      valueListenable: nameC,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextField(controller: nameC, style: const TextStyle(fontWeight: FontWeight.w600), decoration: InputDecoration(hintText: "Tax Name (e.g. VAT)",
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
      valueListenable: rateC,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextField(controller: rateC, style: const TextStyle(fontWeight: FontWeight.w600), keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(hintText: "Percentage (%)",
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if(nameC.text.isNotEmpty && rateC.text.isNotEmpty) {
                _addNewTaxToBackend(nameC.text, double.parse(rateC.text));
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
            child: const Text("Create", style: TextStyle(color: kWhite, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildBottomSaveButton() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        decoration: const BoxDecoration(color: kWhite, border: Border(top: BorderSide(color: kGrey200))),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveProduct,
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: _isLoading
                ? const CircularProgressIndicator(color: kWhite)
                : Text(context.tr(widget.productId != null ? 'update' : 'add'), style: const TextStyle(color: kWhite, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          ),
        ),
      ),
    );
  }

  void _loadExistingData() {
    final d = widget.existingData!;
    _itemNameController.text = d['itemName'] ?? '';
    _priceController.text = d['price']?.toString() ?? '';
    // If costPrice is missing or null, show 0 so downstream reports treat it as zero
    _costPriceController.text = d['costPrice']?.toString() ?? '0';
    _mrpController.text = d['mrp']?.toString() ?? '';
    _productCodeController.text = d['productCode'] ?? '';
    _hsnController.text = d['hsn'] ?? '';
    _barcodeController.text = d['barcode'] ?? '';
    _quantityController.text = d['currentStock']?.toString() ?? '';
    _lowStockAlertController.text = d['lowStockAlert']?.toString() ?? '';
    _locationController.text = d['location'] ?? '';
    _selectedCategory = d['category'];
    _stockEnabled = d['stockEnabled'] ?? true;

    // Validate stockUnit - must be one of the valid values
    final defaultUnits = ['Piece', 'Kg', 'Liter', 'Box', 'Nos', 'Meter', 'Feet', 'Gram', 'ML'];
    final loadedStockUnit = d['stockUnit']?.toString() ?? 'Piece';
    _selectedStockUnit = defaultUnits.contains(loadedStockUnit) ? loadedStockUnit : 'Piece';

    // Validate taxType - must be one of the valid values (support both old and new naming)
    final loadedTaxType = d['taxType']?.toString() ?? 'Add Tax at Billing';
    final validTaxTypes = [
      'Tax Included in Price', 'Add Tax at Billing', 'No Tax Applied', 'Exempt from Tax',
      'Price includes Tax', 'Price is without Tax', 'Zero Rated Tax', 'Exempt Tax' // Legacy support
    ];
    if (validTaxTypes.contains(loadedTaxType)) {
      // Map old names to new names
      if (loadedTaxType == 'Price includes Tax') {
        _selectedTaxType = 'Tax Included in Price';
      } else if (loadedTaxType == 'Price is without Tax') {
        _selectedTaxType = 'Add Tax at Billing';
      } else if (loadedTaxType == 'Zero Rated Tax') {
        _selectedTaxType = 'No Tax Applied';
      } else if (loadedTaxType == 'Exempt Tax') {
        _selectedTaxType = 'Exempt from Tax';
      } else {
        _selectedTaxType = loadedTaxType;
      }
    } else {
      _selectedTaxType = 'Add Tax at Billing';
    }

    // Validate lowStockAlertType - must be 'Count' or 'Percentage'
    final loadedAlertType = d['lowStockAlertType']?.toString() ?? 'Count';
    _lowStockAlertType = ['Count', 'Percentage'].contains(loadedAlertType)
        ? loadedAlertType
        : 'Count';

    _isFavorite = d['isFavorite'] ?? false;
    if (d['expiryDate'] != null) {
      _selectedExpiryDate = DateTime.tryParse(d['expiryDate'].toString());
      if (_selectedExpiryDate != null) _expiryDateController.text = DateFormat('dd/MM/yyyy').format(_selectedExpiryDate!);
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    // Build taxes array from selected tax IDs
    final List<Map<String, dynamic>> selectedTaxes = _selectedTaxIds
        .map((id) => _fetchedTaxes.firstWhere((t) => t['id'] == id, orElse: () => {}))
        .where((t) => t.isNotEmpty)
        .map((t) => {'id': t['id'], 'name': t['name'], 'percentage': t['percentage']})
        .toList();

    // Backward-compatible single tax fields (combined values)
    final String combinedTaxName = selectedTaxes.map((t) => t['name']).join(' + ');
    final double combinedTaxPercentage = selectedTaxes.fold<double>(0.0, (sum, t) => sum + ((t['percentage'] ?? 0.0) as num).toDouble());
    final String? firstTaxId = selectedTaxes.isNotEmpty ? selectedTaxes.first['id'] : null;

    final pData = {
      'itemName': _itemNameController.text.trim(),
      'price': double.tryParse(_priceController.text) ?? 0.0,
      'costPrice': double.tryParse(_costPriceController.text) ?? 0.0,
      'mrp': double.tryParse(_mrpController.text) ?? 0.0,
      'category': _selectedCategory ?? 'General',
      'productCode': _productCodeController.text.trim(),
      'stockEnabled': _stockEnabled,
      'currentStock': _stockEnabled ? (double.tryParse(_quantityController.text) ?? 0.0) : 0.0,
      'lowStockAlert': double.tryParse(_lowStockAlertController.text) ?? 0.0,
      'lowStockAlertType': _lowStockAlertType,
      'hsn': _hsnController.text.trim(),
      'barcode': _barcodeController.text.trim(),
      'stockUnit': _selectedStockUnit ?? 'Piece',
      // NEW: Multiple taxes array
      'taxes': selectedTaxes,
      // LEGACY: Keep single-tax fields for backward compatibility
      'taxId': firstTaxId,
      'taxType': _selectedTaxType,
      'taxName': combinedTaxName.isEmpty ? 'GST' : combinedTaxName,
      'taxPercentage': combinedTaxPercentage,
      'location': _locationController.text.trim(),
      'expiryDate': _selectedExpiryDate?.toIso8601String(),
      'isFavorite': _isFavorite,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (widget.productId != null) await FirestoreService().updateDocument('Products', widget.productId!, pData);
    else await FirestoreService().addDocument('Products', pData);
    if (mounted) Navigator.pop(context);
  }
}
