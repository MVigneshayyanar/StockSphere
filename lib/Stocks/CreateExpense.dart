import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/services/number_generator_service.dart';
import 'package:maxbillup/services/currency_service.dart';
import 'package:heroicons/heroicons.dart';
import 'package:maxbillup/Colors.dart';

// --- UI CONSTANTS ---
const Color _primaryColor = Color(0xFF2F7CF6);
const Color _successColor = Color(0xFF4CAF50);
const Color _errorColor = Color(0xFFFF5252);
const Color _cardBorder = Color(0xFFE3F2FD);
const Color _scaffoldBg = Colors.white;

class CreateExpensePage extends StatefulWidget {
  final String uid;
  final VoidCallback onBack;
  final bool isStockPurchase;

  const CreateExpensePage({
    super.key,
    required this.uid,
    required this.onBack,
    this.isStockPurchase = false,
  });

  @override
  State<CreateExpensePage> createState() => _CreateExpensePageState();
}

class _CreateExpensePageState extends State<CreateExpensePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _billNumberController = TextEditingController();
  final TextEditingController _totalAmountController = TextEditingController();
  final TextEditingController _paidAmountController = TextEditingController();
  final TextEditingController _gstinController = TextEditingController();
  final TextEditingController _gstAmountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // Vendor fields
  final TextEditingController _vendorNameController = TextEditingController();
  final TextEditingController _vendorPhoneController = TextEditingController();
  final TextEditingController _vendorGSTINController = TextEditingController();
  final TextEditingController _vendorAddressController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = 'General';
  String _paymentMode = 'Cash'; // Payment mode: Cash, Online, Credit
  bool _isLoading = false;
  List<String> _categories = ['General', 'Salary', 'EB Bill', 'Stock Purchase', 'Other'];
  String? _selectedVendor;
  List<Map<String, dynamic>> _vendors = [];
  String _currencySymbol = '';

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadVendors();
    _loadCurrency();
    if (widget.isStockPurchase) {
      _selectedCategory = 'Stock Purchase';
    }
  }

  Future<void> _loadCategories() async {
    try {
      final stream = await FirestoreService().getCollectionStream('expenseCategories');
      final snapshot = await stream.first;

      if (mounted) {
        setState(() {
          final loadedCategories = snapshot.docs
              .map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return (data['name'] ?? 'General').toString();
              })
              .toList();

          if (loadedCategories.isNotEmpty) {
            _categories = ['General', 'Salary', 'EB Bill', 'Stock Purchase', 'Other', ...loadedCategories];
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading categories: $e");
    }
  }

  Future<void> _loadVendors() async {
    try {
      final vendorsCollection = await FirestoreService().getStoreCollection('vendors');
      final snapshot = await vendorsCollection.get();

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
              'totalPurchases': data['totalPurchases'] ?? 0.0,
              'purchaseCount': data['purchaseCount'] ?? 0,
              'source': data['source'] ?? '',
            };
          }).toList();
        });
      }
    } catch (e) {
      debugPrint("Error loading vendors: $e");
    }
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

  @override
  void dispose() {
    _nameController.dispose();
    _billNumberController.dispose();
    _totalAmountController.dispose();
    _paidAmountController.dispose();
    _gstinController.dispose();
    _gstAmountController.dispose();
    _notesController.dispose();
    _vendorNameController.dispose();
    _vendorPhoneController.dispose();
    _vendorGSTINController.dispose();
    _vendorAddressController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
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
        _selectedDate = picked;
      });
    }
  }

  void _showVendorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Select Vendor',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: _vendors.isEmpty
                    ? const Center(child: Text('No vendors found'))
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _vendors.length,
                        itemBuilder: (context, index) {
                          final vendor = _vendors[index];
                          final totalPurchases = (vendor['totalPurchases'] ?? 0.0).toDouble();
                          final purchaseCount = vendor['purchaseCount'] ?? 0;
                          final hasStats = totalPurchases > 0 || purchaseCount > 0;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _primaryColor.withValues(alpha: 0.1),
                              child: Text(
                                (vendor['name'] ?? 'V').toString().isNotEmpty
                                    ? vendor['name'][0].toUpperCase()
                                    : 'V',
                                style: const TextStyle(color: _primaryColor),
                              ),
                            ),
                            title: Text(vendor['name'] ?? 'Unknown'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(vendor['phone'] ?? ''),
                                if (hasStats)
                                  Text(
                                    '$purchaseCount bills • ${totalPurchases.toStringAsFixed(0)} total',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                  ),
                              ],
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              setState(() {
                                _selectedVendor = vendor['id'];
                                _vendorNameController.text = vendor['name'];
                                _vendorPhoneController.text = vendor['phone'];
                                _vendorGSTINController.text = vendor['gstin'] ?? '';
                                _vendorAddressController.text = vendor['address'] ?? '';
                              });
                            },
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showAddVendorDialog();
                },
                icon: const HeroIcon(HeroIcons.plus, color: Colors.white),
                label: const Text('Add New Vendor', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showAddVendorDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final gstinCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Add New Vendor', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<TextEditingValue>(
      valueListenable: nameCtrl,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Vendor Name *',
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
      valueListenable: phoneCtrl,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number *',
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
      valueListenable: gstinCtrl,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextField(
                controller: gstinCtrl,
                decoration: InputDecoration(
                  labelText: 'GSTIN',
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
      valueListenable: addressCtrl,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextField(
                controller: addressCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Address',
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name and Phone are required')),
                );
                return;
              }

              try {
                final vendorsCollection = await FirestoreService().getStoreCollection('vendors');
                final docRef = await vendorsCollection.add({
                  'name': nameCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'gstin': gstinCtrl.text.trim().isEmpty ? null : gstinCtrl.text.trim(),
                  'address': addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                  'createdAt': FieldValue.serverTimestamp(),
                });

                await _loadVendors();

                if (mounted) {
                  Navigator.pop(context);
                  setState(() {
                    _selectedVendor = docRef.id;
                    _vendorNameController.text = nameCtrl.text.trim();
                    _vendorPhoneController.text = phoneCtrl.text.trim();
                    _vendorGSTINController.text = gstinCtrl.text.trim();
                    _vendorAddressController.text = addressCtrl.text.trim();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Vendor added successfully'),
                      backgroundColor: _successColor,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final totalAmount = double.tryParse(_totalAmountController.text.trim()) ?? 0.0;
      final paidAmount = _paymentMode == 'Credit'
          ? (double.tryParse(_paidAmountController.text.trim()) ?? 0.0)
          : totalAmount;
      final gstAmount = double.tryParse(_gstAmountController.text.trim()) ?? 0.0;
      final creditAmount = _paymentMode == 'Credit' ? _creditAmount : 0.0;

      // Generate expense number with prefix
      final prefix = await NumberGeneratorService.getExpensePrefix();
      final number = await NumberGeneratorService.generateExpenseNumber();
      final expenseNumber = prefix.isNotEmpty ? '$prefix$number' : number;

      // Use user-entered bill number if provided, otherwise use the generated expense number
      final billNumber = _billNumberController.text.trim().isNotEmpty
          ? _billNumberController.text.trim()
          : expenseNumber;

      final expensesCollection = await FirestoreService().getStoreCollection('expenses');

      await expensesCollection.add({
        'expenseNumber': expenseNumber,
        'name': _nameController.text.trim(),
        'title': _nameController.text.trim(), // For backward compatibility
        'billNumber': billNumber,
        'category': _selectedCategory,
        'paymentMode': _paymentMode,
        'totalAmount': totalAmount,
        'paidAmount': paidAmount,
        'creditAmount': creditAmount,
        'gstAmount': gstAmount,
        'gstin': _gstinController.text.trim().isEmpty ? null : _gstinController.text.trim(),
        'vendorId': _selectedVendor,
        'vendorName': _vendorNameController.text.trim().isEmpty ? null : _vendorNameController.text.trim(),
        'vendorPhone': _vendorPhoneController.text.trim().isEmpty ? null : _vendorPhoneController.text.trim(),
        'vendorGSTIN': _vendorGSTINController.text.trim().isEmpty ? null : _vendorGSTINController.text.trim(),
        'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        'date': Timestamp.fromDate(_selectedDate),
        'timestamp': FieldValue.serverTimestamp(),
        'createdBy': widget.uid,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('expense_added_successfully')),
            backgroundColor: _successColor,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.tr('error')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  double get _creditAmount {
    final total = double.tryParse(_totalAmountController.text.trim()) ?? 0.0;
    final paid = double.tryParse(_paidAmountController.text.trim()) ?? 0.0;
    return (total - paid).clamp(0.0, double.infinity);
  }

  Widget _buildPaymentModeChip(String mode, HeroIcons icon) {
    final isSelected = _paymentMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _paymentMode = mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? _primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HeroIcon(icon, size: 18, color: isSelected ? Colors.white : Colors.grey),
              const SizedBox(width: 6),
              Text(
                mode,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffoldBg,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        title: Text(
          widget.isStockPurchase ? 'Add Stock Purchase' : context.tr('create_expense'),
          style: const TextStyle(color: Colors.white,fontWeight: FontWeight.bold),
        ),
        backgroundColor: _primaryColor,
        leading: IconButton(
          icon: const HeroIcon(HeroIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Selection (at top with color indicator)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _primaryColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Category *',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        
                        
                        
                        
                      ),
                      items: _categories.map((cat) {
                        return DropdownMenuItem(value: cat, child: Text(cat));
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedCategory = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Bill Number (renamed from Invoice Number)
              Text(
                '${widget.isStockPurchase ? 'Purchase Bill Number' : 'Bill Number'} *',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _errorColor),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<TextEditingValue>(
      valueListenable: _billNumberController,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextFormField(
                controller: _billNumberController,
                decoration: InputDecoration(
                  hintText: 'Enter bill number *',
                  prefixIcon: const HeroIcon(HeroIcons.documentText, color: _primaryColor),
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
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Bill number is required';
                  }
                  return null;
                },
              
);
      },
    ),
              const SizedBox(height: 20),

              // Expense Name
              Text(
                'Expense Name *',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<TextEditingValue>(
      valueListenable: _nameController,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Enter expense name *',
                  prefixIcon: const HeroIcon(HeroIcons.tag, color: _primaryColor),
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
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Expense name is required';
                  }
                  return null;
                },
              
);
      },
    ),
              const SizedBox(height: 20),

              // Total Amount
              Text(
                'Total Amount *',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<TextEditingValue>(
      valueListenable: _totalAmountController,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextFormField(
                controller: _totalAmountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: '0.00 *',
                  prefixIcon: const HeroIcon(HeroIcons.currencyRupee, color: _primaryColor),
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
                onChanged: (val) => setState(() {}),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Total amount is required';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Enter a valid amount';
                  }
                  return null;
                },
              
);
      },
    ),
              const SizedBox(height: 20),

              // Payment Mode
              Text(
                'Payment Mode *',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _cardBorder),
                ),
                child: Row(
                  children: [
                    _buildPaymentModeChip('Cash', HeroIcons.banknotes),
                    _buildPaymentModeChip('Online', HeroIcons.qrCode),
                    _buildPaymentModeChip('Credit', HeroIcons.wallet),
                  ],
                ),
              ),

              // Paid Amount & Credit Display (only in Credit mode)
              if (_paymentMode == 'Credit') ...[
                const SizedBox(height: 20),
                Text(
                  'Paid Amount',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<TextEditingValue>(
      valueListenable: _paidAmountController,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextFormField(
                  controller: _paidAmountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: '0.00 *',
                    prefixIcon: const HeroIcon(HeroIcons.bookOpen, color: _successColor),
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
                  onChanged: (val) => setState(() {}),
                  validator: (value) {
                    final paid = double.tryParse(value ?? '') ?? 0.0;
                    final total = double.tryParse(_totalAmountController.text.trim()) ?? 0.0;
                    if (paid > total) {
                      return 'Paid amount cannot exceed total';
                    }
                    return null;
                  },
                
);
      },
    ),
                const SizedBox(height: 12),

                // Credit Amount Display (auto-calculated)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _creditAmount > 0 ? Colors.orange.shade50 : _successColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _creditAmount > 0 ? Colors.orange : _successColor,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          HeroIcon(HeroIcons.wallet, size: 20, color: _creditAmount > 0 ? Colors.orange.shade700 : _successColor),
                          const SizedBox(width: 8),
                          Text(
                            'Credit Amount:',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _creditAmount > 0 ? Colors.orange.shade700 : _successColor,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '$_currencySymbol${_creditAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                         fontWeight: FontWeight.bold,
                          color: _creditAmount > 0 ? Colors.orange.shade700 : _successColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // GSTIN
              Text(
                'GSTIN',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<TextEditingValue>(
      valueListenable: _gstinController,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextFormField(
                controller: _gstinController,
                decoration: InputDecoration(
                  hintText: 'Enter GSTIN *',
                  prefixIcon: const HeroIcon(HeroIcons.documentText, color: _primaryColor),
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
              const SizedBox(height: 20),

              // GST Amount
              Text(
                'GST Amount',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<TextEditingValue>(
      valueListenable: _gstAmountController,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextFormField(
                controller: _gstAmountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: '0.00 *',
                  prefixIcon: const HeroIcon(HeroIcons.calculator, color: _primaryColor),
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
              const SizedBox(height: 20),

              // Vendor Selection
              Text(
                'Vendor (Optional)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _showVendorDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _cardBorder),
                  ),
                  child: Row(
                    children: [
                      const HeroIcon(HeroIcons.userPlus, color: _primaryColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _vendorNameController.text.isEmpty
                              ? 'Select or Add Vendor'
                              : _vendorNameController.text,
                          style: TextStyle(
                            color: _vendorNameController.text.isEmpty
                                ? Colors.grey
                                : Colors.black87,
                          ),
                        ),
                      ),
                      const HeroIcon(HeroIcons.chevronDown, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Date Selection
              Text(
                'Date *',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _selectDate(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _cardBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: _primaryColor),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('dd MMM yyyy').format(_selectedDate),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Notes
              Text(
                'Notes',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<TextEditingValue>(
      valueListenable: _notesController,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Add notes (optional) *',
                  prefixIcon: const Icon(Icons.note, color: _primaryColor),
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
              const SizedBox(height: 30),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveExpense,
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
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          context.tr('save_expense'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                           fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

