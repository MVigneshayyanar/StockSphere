import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:heroicons/heroicons.dart';
import 'package:intl/intl.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/Colors.dart';
import 'package:maxbillup/services/excel_import_service.dart';
import 'package:maxbillup/utils/plan_permission_helper.dart';

// --- UI CONSTANTS ---
const Color _primaryColor = kPrimaryColor;
const Color _successColor = kGoogleGreen;
const Color _cardBorder = kGrey200;
const Color _scaffoldBg = kWhite;

class AddCustomerPage extends StatefulWidget {
  final String uid;
  final VoidCallback? onBack;
  final Map<String, dynamic>? customerData; // For edit mode
  final String? customerId; // For edit mode (phone number)
  final bool isEditMode;

  const AddCustomerPage({
    super.key,
    required this.uid,
    this.onBack,
    this.customerData,
    this.customerId,
    this.isEditMode = false,
  });

  @override
  State<AddCustomerPage> createState() => _AddCustomerPageState();
}

class _AddCustomerPageState extends State<AddCustomerPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _gstinController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _lastDueController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  DateTime? _selectedDOB;
  int _selectedRating = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill data if in edit mode
    if (widget.isEditMode && widget.customerData != null) {
      _nameController.text = widget.customerData!['name'] ?? '';
      _phoneController.text = widget.customerData!['phone'] ?? widget.customerId ?? '';
      _gstinController.text = widget.customerData!['gstin'] ?? widget.customerData!['gst'] ?? '';
      _addressController.text = widget.customerData!['address'] ?? '';
      _discountController.text = (widget.customerData!['defaultDiscount'] ?? 0).toString();
      _selectedRating = (widget.customerData!['rating'] ?? 0) as int;

      // Handle DOB
      if (widget.customerData!['dob'] != null) {
        if (widget.customerData!['dob'] is Timestamp) {
          _selectedDOB = (widget.customerData!['dob'] as Timestamp).toDate();
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _gstinController.dispose();
    _addressController.dispose();
    _lastDueController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  // ==========================================
  // LOGIC METHODS (PRESERVED BIT-BY-BIT)
  // ==========================================

  Future<void> _selectDOB(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDOB ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: _primaryColor),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDOB = picked;
      });
    }
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final phone = _phoneController.text.trim();
      final customersCollection = await FirestoreService().getStoreCollection('customers');
      final defaultDiscount = double.tryParse(_discountController.text.trim()) ?? 0.0;

      if (widget.isEditMode) {
        // Update existing customer
        await customersCollection.doc(widget.customerId ?? phone).update({
          'name': _nameController.text.trim(),
          'phone': phone,
          'gstin': _gstinController.text.trim().isEmpty ? null : _gstinController.text.trim(),
          'gst': _gstinController.text.trim().isEmpty ? null : _gstinController.text.trim(),
          'address': _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
          'defaultDiscount': defaultDiscount,
          'rating': _selectedRating,
          'dob': _selectedDOB != null ? Timestamp.fromDate(_selectedDOB!) : null,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Customer updated successfully'),
              backgroundColor: _successColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        // Check if customer already exists
        final existing = await customersCollection.doc(phone).get();
        if (existing.exists) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Already customer is there'),
                backgroundColor: kOrange,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          setState(() => _isLoading = false);
          return;
        }

        final lastDue = double.tryParse(_lastDueController.text.trim()) ?? 0.0;

        // Create customer document
        await customersCollection.doc(phone).set({
          'name': _nameController.text.trim(),
          'phone': phone,
          'gstin': _gstinController.text.trim().isEmpty ? null : _gstinController.text.trim(),
          'gst': _gstinController.text.trim().isEmpty ? null : _gstinController.text.trim(),
          'address': _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
          'balance': lastDue,
          'totalSales': lastDue,
          'defaultDiscount': defaultDiscount,
          'rating': _selectedRating,
          'dob': _selectedDOB != null ? Timestamp.fromDate(_selectedDOB!) : null,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (lastDue > 0) {
          final creditsCollection = await FirestoreService().getStoreCollection('credits');
          await creditsCollection.add({
            'customerId': phone,
            'customerName': _nameController.text.trim(),
            'amount': lastDue,
            'type': 'add_credit',
            'method': 'Manual',
            'timestamp': FieldValue.serverTimestamp(),
            'date': DateTime.now().toIso8601String(),
            'note': 'Opening Balance - Last Due Added',
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Customer added successfully'),
              backgroundColor: _successColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: kErrorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _importFromContacts() async {
    // Plan check
    final canImport = await PlanPermissionHelper.canImportContacts();
    if (!canImport) {
      if (mounted) PlanPermissionHelper.showUpgradeDialog(context, 'Import Contacts');
      return;
    }
    try {
      if (!await FlutterContacts.requestPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permission denied'),
              backgroundColor: kOrange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      final contacts = await FlutterContacts.getContacts(withProperties: true, withPhoto: false);
      if (mounted) _showContactsDialog(contacts);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: kErrorColor, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  void _showContactsDialog(List<Contact> contacts) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Select Contact', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.separated(
            itemCount: contacts.length,
            separatorBuilder: (c, i) => const Divider(height: 1, color: kGrey100),
            itemBuilder: (context, index) {
              final contact = contacts[index];
              final phone = contact.phones.isNotEmpty ? contact.phones.first.number : '';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: _primaryColor.withValues(alpha: 0.1),
                  child: Text(
                    contact.displayName.isNotEmpty ? contact.displayName[0].toUpperCase() : '?',
                    style: const TextStyle(color: _primaryColor,fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(contact.displayName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(phone, style: const TextStyle(fontSize: 12, color: kBlack54)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _nameController.text = contact.displayName;
                    _phoneController.text = phone.replaceAll(RegExp(r'[^0-9+]'), '');
                  });
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Future<void> _importFromExcel() async {
    // Plan check
    final canImport = await PlanPermissionHelper.canImportContacts();
    if (!canImport) {
      if (mounted) PlanPermissionHelper.showUpgradeDialog(context, 'Import Customers');
      return;
    }
    _showImportExcelDialog();
  }

  void _showImportExcelDialog() {
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
                  HeroIcons.documentPlus,
                  color: kPrimaryColor,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                'Import Customers',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: kBlack87,
                ),
              ),
              const SizedBox(height: 8),

              // Description
              const Text(
                'Download the template, fill it with customer data, and upload it back.',
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
                    final result = await ExcelImportService.downloadCustomerTemplate();
                    if (!mounted) return;

                    // Close the import dialog
                    Navigator.pop(dialogContext);

                    if (result != null && !result.startsWith('Error') && !result.toLowerCase().contains('denied')) {
                      // Show success dialog using STATE context
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
                                        colors: [kGoogleGreen, kGoogleGreen.withOpacity(0.7)],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: kGoogleGreen.withOpacity(0.3),
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
                                    'Customer template has been downloaded to Downloads/MAXmybill folder',
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
                                      color: kGoogleGreen.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: kGoogleGreen.withOpacity(0.3)),
                                    ),
                                    child: const Row(
                                      children: [
                                        HeroIcon(HeroIcons.folder, color: kGoogleGreen, size: 18),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Check Downloads/MAXmybill folder',
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
                      print('📂 Opening file picker...');
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
                                      HeroIcons.documentPlus,
                                      color: kPrimaryColor,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  const Text(
                                    'Importing Customers',
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
                      print('🔄 Processing Excel file...');
                      final result = await ExcelImportService.processCustomersExcel(fileBytes, widget.uid);
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
                                      const HeroIcon(HeroIcons.userPlus, color: kGoogleGreen, size: 24),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          '$successCount customer${successCount != 1 ? 's' : ''} added successfully',
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
                      print('💥 Error in customer import: $e');
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

  Future<void> _confirmDeleteCustomer(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Delete Customer?', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kErrorColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const HeroIcon(HeroIcons.exclamationTriangle, color: kErrorColor, size: 48),
            ),
            const SizedBox(height: 16),
            const Text(
              'This will permanently delete this customer and all associated data. This action cannot be undone.',
              textAlign: TextAlign.center,
              style: TextStyle(color: kBlack54, fontSize: 14, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w800, color: kBlack54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kErrorColor,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete', style: TextStyle(color: kWhite, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirm == true && widget.customerId != null) {
      try {
        await FirestoreService().deleteDocument('customers', widget.customerId!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Customer deleted successfully', style: TextStyle(fontWeight: FontWeight.w600)),
              backgroundColor: _successColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context); // Go back after deletion
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting customer: $e'),
              backgroundColor: kErrorColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  // ==========================================
  // UI BUILD METHODS
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffoldBg,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        title: Text(
          widget.isEditMode ? 'Edit Customer' : 'Add Customer',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: _primaryColor,
        leading: IconButton(
          icon: const HeroIcon(HeroIcons.arrowLeft, color: Colors.white, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        elevation: 0,
        actions: widget.isEditMode ? [
          IconButton(
            icon: const HeroIcon(HeroIcons.trash, color: Colors.red),
            onPressed: () => _confirmDeleteCustomer(context),
            tooltip: 'Delete Customer',
          ),
        ] : [
          IconButton(
            icon: const HeroIcon(HeroIcons.documentArrowUp, color: Colors.white, size: 22),
            onPressed: () => _importFromExcel(),
            tooltip: 'Import from Excel',
          ),
          PopupMenuButton<String>(
            icon: const HeroIcon(HeroIcons.ellipsisVertical, color: Colors.white),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: kGrey200),
            ),
            onSelected: (value) {
              if (value == 'contacts') {
                _importFromContacts();
              } else if (value == 'excel') {
                _importFromExcel();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'contacts',
                child: Row(
                  children: [
                    HeroIcon(HeroIcons.users, color: _primaryColor, size: 20),
                    SizedBox(width: 12),
                    Text('Import from Contacts', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'excel',
                child: Row(
                  children: [
                    HeroIcon(HeroIcons.tableCells, color: _successColor, size: 20),
                    SizedBox(width: 12),
                    Text('Import from Excel', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSectionHeader("Basic Details"),
                  const SizedBox(height: 12),
                  _buildModernTextField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    hint: 'Enter phone number',
                    icon: HeroIcons.phone,
                    keyboardType: TextInputType.phone,
                    isRequired: true,
                  ),
                  const SizedBox(height: 16),
                  _buildModernTextField(
                    controller: _nameController,
                    label: 'Name',
                    hint: 'Enter name',
                    icon: HeroIcons.user,
                    isRequired: true,
                  ),
                  const SizedBox(height: 24),

                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      title: _buildSectionHeader("Advanced Details"),
                      children: [
                        const SizedBox(height: 16),
                        _buildModernTextField(
                          controller: _gstinController,
                          label: 'Tax No',
                          hint: 'Enter Tax No',
                          icon: HeroIcons.banknotes,
                        ),
                        const SizedBox(height: 16),
                        _buildModernTextField(
                          controller: _addressController,
                          label: 'Address',
                          hint: 'Enter address',
                          icon: HeroIcons.mapPin,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        _buildModernTextField(
                          controller: _discountController,
                          label: 'Default Discount %',
                          hint: '0',
                          icon: HeroIcons.receiptPercent,
                          iconColor: kGoogleGreen,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                        if (!widget.isEditMode) ...[
                        const SizedBox(height: 16),
                        _buildModernTextField(
                          controller: _lastDueController,
                          label: 'Last Due',
                          hint: '0.00',
                          icon: HeroIcons.banknotes,
                          iconColor: kOrange,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                        ],
                        const SizedBox(height: 16),
                        _buildSectionHeader('Date of Birth'),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _selectDOB(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: kGreyBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: _selectedDOB != null ? _primaryColor : _cardBorder,
                                  width: _selectedDOB != null ? 1.5 : 1.0
                              ),
                            ),
                            child: Row(
                              children: [
                                const HeroIcon(HeroIcons.cake, color: _primaryColor, size: 20),
                                const SizedBox(width: 12),
                                Text(
                                  _selectedDOB != null
                                      ? DateFormat('dd MMM yyyy').format(_selectedDOB!)
                                      : 'Select Date',
                                  style: TextStyle(
                                    color: _selectedDOB != null ? kBlack87 : kBlack54,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildSectionHeader('Customer Rating'),
                        const SizedBox(height: 8),
                        _buildStarRating(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 80),
                ],
              ),
            ),
            _buildBottomSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildStarRating() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: kGreyBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _selectedRating > 0 ? kOrange : _cardBorder,
          width: _selectedRating > 0 ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          const HeroIcon(HeroIcons.star, color: kOrange, size: 20, style: HeroIconStyle.solid),
          const SizedBox(width: 12),
          const Text(
            'Rating:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kBlack87),
          ),
          const Spacer(),
          ...List.generate(5, (index) {
            return GestureDetector(
              onTap: () {
                setState(() {
                  // If tapping the same star, deselect it (set to 0)
                  // Otherwise, set to the tapped star number
                  if (_selectedRating == index + 1) {
                    _selectedRating = 0;
                  } else {
                    _selectedRating = index + 1;
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: HeroIcon(
                  HeroIcons.star,
                  size: 28,
                  color: index < _selectedRating ? kOrange : kGrey300,
                  style: index < _selectedRating ? HeroIconStyle.solid : HeroIconStyle.outline,
                ),
              ),
            );
          }),
          // Add a clear button to remove rating
          if (_selectedRating > 0) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedRating = 0;
                });
              },
              child: const HeroIcon(
                HeroIcons.xMark,
                size: 20,
                color: kGrey400,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: kBlack54,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required HeroIcons icon,
    bool isRequired = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    Color? iconColor,
  }) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        final bool isFilled = value.text.isNotEmpty;
        return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kBlack87),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            hintStyle: const TextStyle(color: kBlack54, fontSize: 14, fontWeight: FontWeight.normal),
            prefixIcon: Padding(
              padding: const EdgeInsets.all(12.0),
              child: HeroIcon(icon, color: iconColor ?? _primaryColor, size: 20),
            ),
            
            
            
            
            
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

  Widget _buildBottomSaveButton() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: kWhite,
        border: Border(top: BorderSide(color: kGrey200)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _saveCustomer,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryColor,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          )
              : Text(
            widget.isEditMode ? 'Update customer' : 'Save customer',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
