import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:intl/intl.dart';
import 'package:maxbillup/Colors.dart';
import 'package:provider/provider.dart';

// --- PROJECT IMPORTS ---
import 'package:maxbillup/models/cart_item.dart';
import 'package:maxbillup/Sales/Invoice.dart';
import 'package:maxbillup/Sales/components/common_widgets.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/services/local_stock_service.dart';
import 'package:maxbillup/services/number_generator_service.dart';
import 'package:maxbillup/services/cart_service.dart';
import 'package:maxbillup/services/currency_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/utils/plan_permission_helper.dart';
import 'package:maxbillup/utils/responsive_helper.dart';
import '../utils/amount_formatter.dart';
import 'package:heroicons/heroicons.dart';

// ==========================================
// 1. BILL PAGE (Main State Widget)
// ==========================================
class BillPage extends StatefulWidget {
  final String uid;
  final String? userEmail;
  final List<CartItem> cartItems;
  final double totalAmount;
  final String? savedOrderId;
  final double? discountAmount;
  final String? customerPhone;
  final String? customerName;
  final String? customerGST;
  final String? quotationId;
  final String? existingInvoiceNumber;
  final String? unsettledSaleId;

  const BillPage({
    super.key,
    required this.uid,
    this.userEmail,
    required this.cartItems,
    required this.totalAmount,
    this.savedOrderId,
    this.discountAmount,
    this.customerPhone,
    this.customerName,
    this.customerGST,
    this.quotationId,
    this.existingInvoiceNumber,
    this.unsettledSaleId,
  });

  @override
  State<BillPage> createState() => _BillPageState();
}

class _BillPageState extends State<BillPage> {
  late String _uid;
  String? _selectedCustomerPhone;
  String? _selectedCustomerName;
  String? _selectedCustomerGST;
  double _discountAmount = 0.0;
  double _customerDefaultDiscount = 0.0; // Customer's default discount percentage
  double _additionalDiscount = 0.0; // Additional discount on top of customer default
  String _creditNote = '';
  List<Map<String, dynamic>> _selectedCreditNotes = [];
  double _totalCreditNotesAmount = 0.0;
  String? _existingInvoiceNumber;
  String? _unsettledSaleId;
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _deliveryAddressController = TextEditingController();
  double _deliveryCharge = 0.0;
  bool _isFromQuotation = false; // Track if came from quotation

  // Fast-Fetch Variables
  String _businessName = 'Business';
  String _businessLocation = 'Location';
  String _businessPhone = '';
  String _staffName = 'Staff';
  String _currencySymbol = ''; // Will be loaded from CurrencyService
  StreamSubscription? _storeSub;

  @override
  void initState() {
    super.initState();
    _uid = widget.uid;
    if (widget.discountAmount != null) _discountAmount = widget.discountAmount!;
    if (widget.customerPhone != null) {
      _selectedCustomerPhone = widget.customerPhone;
      _selectedCustomerName = widget.customerName;
      _selectedCustomerGST = widget.customerGST;
      // Fetch customer's default discount when customer is passed from saleall.dart
      _fetchCustomerDefaultDiscount(widget.customerPhone!);
    }
    _existingInvoiceNumber = widget.existingInvoiceNumber;
    _unsettledSaleId = widget.unsettledSaleId;
    _isFromQuotation = widget.quotationId != null;

    _initFastFetch();

    // Sync widget.cartItems to CartService (for when coming from QuotationDetail)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.cartItems.isNotEmpty && _isFromQuotation) {
        final cartService = Provider.of<CartService>(context, listen: false);
        cartService.updateCart(widget.cartItems);
      }
    });
  }

  Future<void> _fetchCustomerDefaultDiscount(String customerPhone) async {
    try {
      final customersCollection = await FirestoreService().getStoreCollection('customers');
      final customerDoc = await customersCollection.doc(customerPhone).get();
      if (customerDoc.exists) {
        final data = customerDoc.data() as Map<String, dynamic>?;
        final defaultDiscount = (data?['defaultDiscount'] ?? 0.0).toDouble();
        if (mounted) {
          setState(() {
            _customerDefaultDiscount = defaultDiscount;
            _recalculateDiscount();
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching customer discount: $e');
    }
  }

  void _initFastFetch() {
    final fs = FirestoreService();
    fs.getCurrentStoreDoc().then((doc) {
      if (doc != null && doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _businessName = data['businessName'] ?? 'Business';
          _businessLocation = data['location'] ?? data['businessLocation'] ?? 'Location';
          _businessPhone = data['businessPhone'] ?? '';
          _currencySymbol = CurrencyService.getSymbolWithSpace(data['currency']);
        });
      }
    });
    FirebaseFirestore.instance.collection('users').doc(_uid).get(const GetOptions(source: Source.cache)).then((doc) {
      if (doc.exists && mounted) {
        setState(() => _staffName = doc.data()?['name'] ?? 'Staff');
      }
    });
    _storeSub = fs.storeDataStream.listen((data) {
      if (mounted) {
        setState(() {
          _businessName = data['businessName'] ?? 'Business';
          _businessLocation = data['location'] ?? data['businessLocation'] ?? 'Location';
          _businessPhone = data['businessPhone'] ?? '';
          _currencySymbol = CurrencyService.getSymbolWithSpace(data['currency']);
        });
      }
    });
  }

  @override
  void dispose() {
    _storeSub?.cancel();
    _notesController.dispose();
    _deliveryAddressController.dispose();
    super.dispose();
  }

  void _deselectCustomer() {
    setState(() {
      _selectedCustomerPhone = null;
      _selectedCustomerName = null;
      _selectedCustomerGST = null;
      _selectedCreditNotes = [];
      _totalCreditNotesAmount = 0.0;
      _creditNote = '';
      _customerDefaultDiscount = 0.0;
      _recalculateDiscount();
    });
  }

  void _recalculateDiscount() {
    // Total discount = customer default discount amount + additional discount
    final cartService = Provider.of<CartService>(context, listen: false);
    final totalWithTax = cartService.cartItems.fold(0.0, (sum, item) => sum + item.totalWithTax);
    final customerDiscountAmount = (totalWithTax * _customerDefaultDiscount / 100);
    _discountAmount = customerDiscountAmount + _additionalDiscount;
  }

  Future<void> _proceedToPayment(String paymentMode) async {
    // Credit payment requires a customer to be selected
    if (paymentMode == 'Credit' && (_selectedCustomerPhone == null || _selectedCustomerPhone!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a customer for Credit payment', style: TextStyle(fontWeight: FontWeight.w600)),
          backgroundColor: kOrange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          action: SnackBarAction(
            label: 'Select',
            textColor: kWhite,
            onPressed: _showCustomerDialog,
          ),
        ),
      );
      return;
    }

    // Get current cart items from CartService
    final cartService = Provider.of<CartService>(context, listen: false);
    final cartItems = cartService.cartItems;

    // Calculate final values - step by step
    final totalWithTax = cartItems.fold(0.0, (sum, item) => sum + item.totalWithTax);
    final customerDiscountAmount = (totalWithTax * _customerDefaultDiscount / 100);
    final amountAfterCustomerDiscount = totalWithTax - customerDiscountAmount;
    final amountAfterAllDiscounts = amountAfterCustomerDiscount - _additionalDiscount;
    final creditToApply = _totalCreditNotesAmount > amountAfterAllDiscounts ? amountAfterAllDiscounts : _totalCreditNotesAmount;
    final finalAmount = ((amountAfterAllDiscounts - creditToApply) + _deliveryCharge).clamp(0.0, double.infinity);
    final actualCreditUsed = _totalCreditNotesAmount > amountAfterAllDiscounts ? amountAfterAllDiscounts : _totalCreditNotesAmount;

    // Total discount for payment page = customer discount + additional discount
    final totalDiscountAmount = customerDiscountAmount + _additionalDiscount;

    if (paymentMode == 'Split') {
      final result = await Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => SplitPaymentPage(
            uid: _uid,
            userEmail: widget.userEmail,
            cartItems: cartItems,
            totalAmount: finalAmount,
            customerPhone: _selectedCustomerPhone,
            customerName: _selectedCustomerName,
            customerGST: _selectedCustomerGST,
            discountAmount: totalDiscountAmount,
            creditNote: _creditNote,
            customNote: _notesController.text.trim(),
            deliveryAddress: _deliveryAddressController.text.trim().isNotEmpty ? _deliveryAddressController.text.trim() : null,
            savedOrderId: widget.savedOrderId,
            selectedCreditNotes: _selectedCreditNotes,
            quotationId: widget.quotationId,
            existingInvoiceNumber: _existingInvoiceNumber,
            unsettledSaleId: _unsettledSaleId,
            businessName: _businessName,
            businessLocation: _businessLocation,
            businessPhone: _businessPhone,
            staffName: _staffName,
            actualCreditUsed: actualCreditUsed,
            deliveryCharge: _deliveryCharge,
          ),
        ),
      );

      // If we are in edit mode and the update was successful, go back to history
      if (result != null && result is Map && result['success'] == true && _unsettledSaleId != null) {
        if (mounted) Navigator.pop(context, true);
      }
    } else {
      final result = await Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => PaymentPage(
            uid: _uid,
            userEmail: widget.userEmail,
            cartItems: cartItems,
            totalAmount: finalAmount,
            paymentMode: paymentMode,
            customerPhone: _selectedCustomerPhone,
            customerName: _selectedCustomerName,
            customerGST: _selectedCustomerGST,
            discountAmount: totalDiscountAmount,
            creditNote: _creditNote,
            customNote: _notesController.text.trim(),
            deliveryAddress: _deliveryAddressController.text.trim().isNotEmpty ? _deliveryAddressController.text.trim() : null,
            savedOrderId: widget.savedOrderId,
            selectedCreditNotes: _selectedCreditNotes,
            quotationId: widget.quotationId,
            existingInvoiceNumber: _existingInvoiceNumber,
            unsettledSaleId: _unsettledSaleId,
            businessName: _businessName,
            businessLocation: _businessLocation,
            businessPhone: _businessPhone,
            staffName: _staffName,
            actualCreditUsed: actualCreditUsed,
            deliveryCharge: _deliveryCharge,
          ),
        ),
      );

      // Handle successful update for non-split payments too
      if (result != null && result is Map && result['success'] == true && _unsettledSaleId != null) {
        if (mounted) Navigator.pop(context, true);
      }
    }
  }

  void _clearOrder() {
    showDialog(context: context, builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: R.radius(context, 16)),
      child: Padding(
        padding: R.all(context, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HeroIcon(HeroIcons.exclamationTriangle, color: kErrorColor, size: R.sp(context, 40)),
            SizedBox(height: R.sp(context, 16)),
            Text('Clear Order?', style: TextStyle(fontSize: R.sp(context, 18), fontWeight: FontWeight.w900, color: kBlack87, letterSpacing: 0.5)),
            SizedBox(height: R.sp(context, 12)),
            Text('Are you sure you want to discard this bill? All progress will be lost.', textAlign: TextAlign.center, style: TextStyle(color: kBlack54, fontSize: R.sp(context, 13), height: 1.5, fontWeight: FontWeight.w500)),
            SizedBox(height: R.sp(context, 24)),
            Row(
              children: [
                Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(fontWeight: FontWeight.w800, color: kBlack54, fontSize: R.sp(context, 12))))),
                SizedBox(width: R.sp(context, 12)),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: kErrorColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: R.radius(context, 8))),
                    onPressed: () {
                      // Clear the cart using CartService
                      final cartService = Provider.of<CartService>(context, listen: false);
                      cartService.clearCart();

                      Navigator.pop(context); // Close dialog
                      Navigator.pop(context); // Go back to previous screen
                    },
                    child: Text('Discard', style: TextStyle(color: kWhite, fontWeight: FontWeight.w900, fontSize: R.sp(context, 12))),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    ));
  }

  void _showEditCartItemDialog(int idx) async {
    final cartService = Provider.of<CartService>(context, listen: false);
    final cartItems = cartService.cartItems;

    if (idx < 0 || idx >= cartItems.length) return;

    final item = cartItems[idx];
    final nameController = TextEditingController(text: item.name);
    final priceController = TextEditingController(text: item.price.toString());
    final qtyController = TextEditingController(text: item.quantity.toString());

    // Debug: Log item tax info
    debugPrint('🔍 Edit Dialog - Item Tax Info:');
    debugPrint('   taxName: ${item.taxName}');
    debugPrint('   taxPercentage: ${item.taxPercentage}');
    debugPrint('   taxType: ${item.taxType}');

    // Fetch available taxes
    List<Map<String, dynamic>> availableTaxes = [];
    try {
      final taxesSnapshot = await FirestoreService().getStoreCollection('taxes').then((col) => col.get());
      availableTaxes = taxesSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Tax',
          'percentage': (data['percentage'] ?? 0).toDouble(),
        };
      }).toList();
      debugPrint('📋 Available taxes: ${availableTaxes.length}');
      for (var tax in availableTaxes) {
        debugPrint('   - ${tax['name']} (${tax['percentage']}%) [ID: ${tax['id']}]');
      }
    } catch (e) {
      debugPrint('❌ Error fetching taxes: $e');
    }

    // Current tax selection - find matching tax by name and percentage
    String? selectedTaxId;
    if (item.taxName != null && item.taxPercentage != null) {
      debugPrint('🔎 Searching for tax: ${item.taxName} with ${item.taxPercentage}%');
      try {
        final matchingTax = availableTaxes.firstWhere(
              (tax) {
            final nameMatch = tax['name'] == item.taxName;
            // Handle both integer and double percentages
            final taxPercentage = (tax['percentage'] as num).toDouble();
            final itemPercentage = item.taxPercentage!.toDouble();
            final percentageMatch = (taxPercentage - itemPercentage).abs() < 0.01; // Allow small floating point differences
            debugPrint('   Checking: ${tax['name']} (${tax['percentage']}%) - nameMatch: $nameMatch, percentageMatch: $percentageMatch');
            return nameMatch && percentageMatch;
          },
        );
        selectedTaxId = matchingTax['id'] as String?;
        debugPrint('✅ Found matching tax: ${matchingTax['name']} [ID: $selectedTaxId]');
      } catch (e) {
        // No matching tax found, will show as "No Tax"
        debugPrint('❌ No matching tax found for ${item.taxName} ${item.taxPercentage}%');
        debugPrint('   Error: $e');
        selectedTaxId = null;
      }
    } else {
      debugPrint('ℹ️ Item has no tax (taxName or taxPercentage is null)');
    }

    // Tax type
    String selectedTaxType = item.taxType ?? 'Add Tax at Billing';
    final taxTypes = ['Tax Included in Price', 'Add Tax at Billing', 'No Tax Applied', 'Exempt from Tax'];

    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: R.radius(context, 20)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Edit Cart Item', style: TextStyle(fontWeight: FontWeight.w900, fontSize: R.sp(context, 18))),
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
                  _buildDialogLabel('Product Name'),
                  _buildDialogInput(nameController, 'Enter product name', setDialogState),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDialogLabel('Price'),
                            _buildDialogInput(priceController, '0.00', setDialogState, isNumber: true),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDialogLabel('Quantity'),
                            Container(
                              decoration: BoxDecoration(
                                color: kGreyBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: kGrey200),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      int current = int.tryParse(qtyController.text) ?? 1;
                                      if (current > 1) {
                                        setDialogState(() => qtyController.text = (current - 1).toString());
                                      } else {
                                        Navigator.of(context).pop();
                                        _removeCartItem(idx);
                                      }
                                    },
                                    icon: HeroIcon(
                                      (int.tryParse(qtyController.text) ?? 1) <= 1 ? HeroIcons.trash : HeroIcons.minus,
                                      color: (int.tryParse(qtyController.text) ?? 1) <= 1 ? kErrorColor : kPrimaryColor,
                                      size: 20,
                                    ),
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: qtyController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      textAlign: TextAlign.center,
                                      onChanged: (v) => setDialogState(() {}),
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        filled: false,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      int current = int.tryParse(qtyController.text) ?? 0;
                                      setDialogState(() => qtyController.text = (current + 1).toString());
                                    },
                                    icon: const HeroIcon(HeroIcons.plus, color: kPrimaryColor, size: 20),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Tax Options - Show different UI based on whether tax is present
                  if (selectedTaxId != null) ...[
                    // Product has tax - Show option to deselect
                    _buildDialogLabel('Tax Applied'),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: kGreyBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kGrey200),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  availableTaxes.firstWhere(
                                        (tax) => tax['id'] == selectedTaxId,
                                    orElse: () => {'name': 'Tax', 'percentage': 0},
                                  )['name'] ?? 'Tax',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kBlack87),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${availableTaxes.firstWhere(
                                        (tax) => tax['id'] == selectedTaxId,
                                    orElse: () => {'name': 'Tax', 'percentage': 0},
                                  )['percentage']}%',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kBlack54),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              setDialogState(() => selectedTaxId = null);
                            },
                            icon: const HeroIcon(HeroIcons.xMark, size: 16, color: kErrorColor),
                            label: const Text('Remove Tax', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kErrorColor)),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDialogLabel('Tax Type'),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: kGreyBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kGrey200),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedTaxType,
                          isExpanded: true,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kBlack87),
                          items: taxTypes.map((type) {
                            return DropdownMenuItem<String>(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() => selectedTaxType = value);
                            }
                          },
                        ),
                      ),
                    ),
                  ] else ...[
                    // Product has no tax - Show option to add tax
                    _buildDialogLabel('Tax'),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: kGreyBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kGrey200),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'No tax applied',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kBlack54),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              // Show tax selection dialog
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  title: const Text('Select Tax', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: availableTaxes.map((tax) {
                                      return ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(tax['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                                        subtitle: Text('${tax['percentage']}%', style: const TextStyle(fontSize: 12)),
                                        onTap: () {
                                          setDialogState(() {
                                            selectedTaxId = tax['id'];
                                            selectedTaxType = 'Add Tax at Billing'; // Default tax type
                                          });
                                          Navigator.pop(ctx);
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ),
                              );
                            },
                            icon: const HeroIcon(HeroIcons.plusCircle, size: 16, color: kPrimaryColor),
                            label: const Text('Add Tax', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kPrimaryColor)),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
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
                        onPressed: () {
                          final newName = nameController.text.trim();
                          final newPrice = double.tryParse(priceController.text.trim()) ?? item.price;
                          final newQty = double.tryParse(qtyController.text.trim()) ?? 1.0;

                          if (newQty <= 0) {
                            Navigator.of(context).pop();
                            _removeCartItem(idx);
                          } else {
                            String? taxName;
                            double? taxPercentage;
                            String? taxType;

                            if (selectedTaxId != null) {
                              final selectedTax = availableTaxes.firstWhere(
                                    (tax) => tax['id'] == selectedTaxId,
                                orElse: () => {},
                              );
                              taxName = selectedTax['name'];
                              taxPercentage = selectedTax['percentage'];
                              taxType = selectedTaxType;
                            }

                            _updateCartItemWithTax(idx, newName, newPrice, newQty, taxName, taxPercentage, taxType);
                            Navigator.of(context).pop();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryColor,
                          shape: RoundedRectangleBorder(borderRadius: R.radius(context, 12)),
                          elevation: 0,
                          padding: EdgeInsets.symmetric(vertical: R.sp(context, 14)),
                        ),
                        child: Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: R.sp(context, 15))),
                      ),
                    ),
                    SizedBox(height: R.sp(context, 8)),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _removeCartItem(idx);
                        },
                        icon: HeroIcon(HeroIcons.trash, color: kErrorColor, size: R.sp(context, 18)),
                        label: Text('Remove Item', style: TextStyle(color: kErrorColor, fontWeight: FontWeight.w700, fontSize: R.sp(context, 14))),
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

  Widget _buildDialogLabel(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: R.sp(context, 8)),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.w700, fontSize: R.sp(context, 13), color: kBlack54)),
    );
  }

  Widget _buildDialogInput(TextEditingController controller, String hint, StateSetter setDialogState, {bool isNumber = false}) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextField(
          controller: controller,
          keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          onChanged: (v) => setDialogState(() {}),
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: R.sp(context, 14)),
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

  void _updateCartItem(int idx, String newName, double newPrice, double newQty) {
    final cartService = Provider.of<CartService>(context, listen: false);
    final cartItems = cartService.cartItems;

    if (idx < 0 || idx >= cartItems.length) return;

    final item = cartItems[idx];
    final updatedItem = CartItem(
      productId: item.productId,
      name: newName,
      price: newPrice,
      quantity: newQty,
      taxName: item.taxName,
      taxPercentage: item.taxPercentage,
      taxType: item.taxType,
    );

    // Update in CartService - Provider will notify listeneautomatically
    final updatedItems = List<CartItem>.from(cartItems);
    updatedItems[idx] = updatedItem;
    cartService.updateCart(updatedItems);
  }

  void _updateCartItemWithTax(int idx, String newName, double newPrice, double newQty, String? taxName, double? taxPercentage, String? taxType) {
    final cartService = Provider.of<CartService>(context, listen: false);
    final cartItems = cartService.cartItems;

    if (idx < 0 || idx >= cartItems.length) return;

    final item = cartItems[idx];
    final updatedItem = CartItem(
      productId: item.productId,
      name: newName,
      price: newPrice,
      quantity: newQty,
      taxes: item.taxes.isNotEmpty ? item.taxes : null,
      taxName: taxName,
      taxPercentage: taxPercentage,
      taxType: taxType,
    );

    // Update in CartService - Provider will notify listeners automatically
    final updatedItems = List<CartItem>.from(cartItems);
    updatedItems[idx] = updatedItem;
    cartService.updateCart(updatedItems);
  }

  void _removeCartItem(int idx) {
    final cartService = Provider.of<CartService>(context, listen: false);
    final cartItems = cartService.cartItems;

    if (idx < 0 || idx >= cartItems.length) return;

    // Update in CartService - Provider will notify listeneautomatically
    final updatedItems = List<CartItem>.from(cartItems);
    updatedItems.removeAt(idx);
    cartService.updateCart(updatedItems);

    // If cart is empty, go back to NewSale
    if (updatedItems.isEmpty) {
      Navigator.pop(context);
    }
  }

  void _showCustomerDialog() {
    CommonWidgets.showCustomerSelectionDialog(
      context: context,
      onCustomerSelected: (phone, name, gst) async {
        // Fetch customer data to get default discount
        try {
          final customersCollection = await FirestoreService().getStoreCollection('customers');
          final customerDoc = await customersCollection.doc(phone).get();
          double defaultDiscount = 0.0;
          if (customerDoc.exists) {
            final data = customerDoc.data() as Map<String, dynamic>?;
            defaultDiscount = (data?['defaultDiscount'] ?? 0.0).toDouble();
          }

          if (mounted) {
            setState(() {
              _selectedCustomerPhone = phone;
              _selectedCustomerName = name;
              _selectedCustomerGST = gst;
              _customerDefaultDiscount = defaultDiscount;
              _recalculateDiscount();
            });
          }
        } catch (e) {
          // Fallback if fetch fails
          if (mounted) {
            setState(() {
              _selectedCustomerPhone = phone;
              _selectedCustomerName = name;
              _selectedCustomerGST = gst;
            });
          }
        }
      },
      selectedCustomerPhone: _selectedCustomerPhone,
    );
  }

  void _showDiscountDialog() {
    // Get current cart items from CartService
    final cartService = Provider.of<CartService>(context, listen: false);
    final cartItems = cartService.cartItems;
    final double billTotal = cartItems.fold(0.0, (sum, item) => sum + item.totalWithTax);
    final double customerDiscountAmount = (billTotal * _customerDefaultDiscount / 100);
    final double amountAfterCustomerDiscount = billTotal - customerDiscountAmount;

    final TextEditingController cashController = TextEditingController(text: _additionalDiscount > 0 ? _additionalDiscount.toStringAsFixed(2) : '');
    final double initialPerc = amountAfterCustomerDiscount > 0 ? (_additionalDiscount / amountAfterCustomerDiscount) * 100 : 0.0;
    final TextEditingController percController = TextEditingController(text: initialPerc > 0 ? initialPerc.toStringAsFixed(1) : '');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: kWhite,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Apply Discount', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: kBlack87, letterSpacing: 0.5)),
                  GestureDetector(onTap: () => Navigator.pop(context), child: const HeroIcon(HeroIcons.xMark, size: 24, color: kBlack54)),
                ]),
                const SizedBox(height: 16),
                // Show customer default discount if available
                if (_customerDefaultDiscount > 0) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kGoogleGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kGoogleGreen.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const HeroIcon(HeroIcons.user, color: kGoogleGreen, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Customer Default: ${_customerDefaultDiscount.toStringAsFixed(1)}% ($_currencySymbol${customerDiscountAmount.toStringAsFixed(2)})',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kGoogleGreen),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Additional Discount', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 0.5)),
                  const SizedBox(height: 12),
                ],
                _buildPopupTextField(
                    controller: cashController,
                    label: _customerDefaultDiscount > 0 ? 'Additional Discount (Amount)' : 'Discount in Amount',
                    hint: '0.00',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) {
                      final val = double.tryParse(v) ?? 0.0;
                      if (amountAfterCustomerDiscount > 0) {
                        percController.text = ((val / amountAfterCustomerDiscount) * 100).toStringAsFixed(1);
                      }
                    }
                ),
                const SizedBox(height: 12),
                const Text('OR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kGrey400)),
                const SizedBox(height: 12),
                _buildPopupTextField(
                    controller: percController,
                    label: _customerDefaultDiscount > 0 ? 'Additional Discount (%)' : 'Discount in %',
                    hint: '0%',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) {
                      final val = double.tryParse(v) ?? 0.0;
                      cashController.text = (amountAfterCustomerDiscount * (val / 100)).toStringAsFixed(2);
                    }
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _additionalDiscount = double.tryParse(cashController.text) ?? 0.0;
                        _recalculateDiscount();
                      });
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
                    child: const Text('Apply', style: TextStyle(color: kWhite, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCreditNotesDialog() {
    if (_selectedCustomerPhone == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a customer first')));
      return;
    }
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Credit Notes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  GestureDetector(onTap: () => Navigator.pop(context), child: const HeroIcon(HeroIcons.xMark)),
                ]),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 350),
                  child: FutureBuilder<Stream<QuerySnapshot>>(
                    future: FirestoreService().getCollectionStream('creditNotes'),
                    builder: (context, futureSnapshot) {
                      if (!futureSnapshot.hasData) return const Center(child: CircularProgressIndicator());
                      return StreamBuilder<QuerySnapshot>(
                        stream: futureSnapshot.data!,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                          final creditNotes = snapshot.data?.docs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            return data['customerPhone'] == _selectedCustomerPhone && data['status'] == 'Available';
                          }).toList() ?? [];
                          if (creditNotes.isEmpty) return const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Text('No available notes', style: TextStyle(fontWeight: FontWeight.w600, color: kBlack54)));
                          return ListView.builder(
                            shrinkWrap: true,
                            itemCount: creditNotes.length,
                            itemBuilder: (context, index) {
                              final doc = creditNotes[index];
                              final data = doc.data() as Map<String, dynamic>;
                              final isSelected = _selectedCreditNotes.any((cn) => cn['id'] == doc.id);
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? kPrimaryColor : kGrey200, width: isSelected ? 1.5 : 1)),
                                child: CheckboxListTile(
                                  activeColor: kPrimaryColor,
                                  title: Text(data['creditNoteNumber'] ?? 'CN-N/A', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: kBlack87)),
                                  subtitle: Text('Valued at ${(data['amount'] ?? 0.0).toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                                  value: isSelected,
                                  onChanged: (val) {
                                    setDialogState(() {
                                      if (val == true) { _selectedCreditNotes.add({'id': doc.id, 'amount': (data['amount'] ?? 0.0).toDouble()}); }
                                      else { _selectedCreditNotes.removeWhere((cn) => cn['id'] == doc.id); }
                                      _totalCreditNotesAmount = _selectedCreditNotes.fold(0.0, (sum, cn) => sum + ((cn['amount'] ?? 0).toDouble()));
                                    });
                                  },
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: () { setState(() {}); Navigator.pop(context); },
                    style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: const Text('Apply Selected', style: TextStyle(color: kWhite, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPopupTextField({required TextEditingController controller, required String label, String? hint, TextInputType keyboardType = TextInputType.text, int maxLines = 1, Function(String)? onChanged}) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kBlack87),
      decoration: InputDecoration(
        labelText: label, hintText: hint,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get cart items from CartService for real-time updates
    final cartService = Provider.of<CartService>(context);
    final cartItems = cartService.cartItems;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && _isFromQuotation) {
          final cartService = Provider.of<CartService>(context, listen: false);
          cartService.clearCart();
        }
      },
      child: Scaffold(
        backgroundColor: kGreyBg,
        appBar: AppBar(
          backgroundColor: kPrimaryColor,
          elevation: 0,
          centerTitle: true,
          title: Text(context.tr('Bill Summary'), style: TextStyle(color: kWhite, fontWeight: FontWeight.w900, fontSize: R.sp(context, 15), letterSpacing: 1.0)),
          leading: IconButton(icon: HeroIcon(HeroIcons.arrowLeft, color: kWhite, size: R.sp(context, 18)), onPressed: () {
            // Clear cart when going back from quotation to prevent items persisting
            if (_isFromQuotation) {
              final cartService = Provider.of<CartService>(context, listen: false);
              cartService.clearCart();
            }
            Navigator.pop(context);
          }),
          actions: [IconButton(icon: HeroIcon(HeroIcons.trash, color: kWhite, size: R.sp(context, 22)), onPressed: _clearOrder)],
        ),
      body: Column(
        children: [
          _buildCustomerSection(),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(R.sp(context, 16), R.sp(context, 16), R.sp(context, 16), R.sp(context, 100)),
              itemCount: cartItems.length,
              separatorBuilder: (ctx, i) => SizedBox(height: R.sp(context, 10)),
              itemBuilder: (ctx, i) => _buildItemRow(cartItems[i], i),
            ),
          ),
          SafeArea(
            top: false,
            child: _buildBottomPanel(cartItems),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildCustomerSection() {
    final bool hasCustomer = _selectedCustomerName != null && _selectedCustomerName!.isNotEmpty;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(color: kWhite, border: Border(bottom: BorderSide(color: kGrey200))),
      padding: EdgeInsets.symmetric(horizontal: R.sp(context, 16), vertical: R.sp(context, 8)),
      child: InkWell(
        onTap: _showCustomerDialog,
        borderRadius: R.radius(context, 16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: EdgeInsets.symmetric(horizontal: R.sp(context, 14), vertical: R.sp(context, 10)),
          decoration: BoxDecoration(
            color: hasCustomer ? kPrimaryColor.withOpacity(0.15) : kWhite,
            borderRadius: R.radius(context, 16),
            border: Border.all(color: hasCustomer ? kPrimaryColor.withOpacity(0.15) : kOrange, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: R.sp(context, 38), height: R.sp(context, 38),
                decoration: BoxDecoration(color: hasCustomer ? kPrimaryColor : kOrange.withOpacity(0.15), shape: BoxShape.circle),
                child: HeroIcon(hasCustomer ? HeroIcons.user : HeroIcons.userPlus, color: hasCustomer ? kWhite : kOrange, size: R.sp(context, 20)),
              ),
              SizedBox(width: R.sp(context, 12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hasCustomer ? _selectedCustomerName! : 'Add Customer', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: hasCustomer ? kBlack87 : kOrange)),
                    if (hasCustomer) Text(_selectedCustomerPhone ?? '', style: const TextStyle(fontSize: 10, color: kBlack54, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              if (hasCustomer) ...[
                GestureDetector(
                  onTap: _deselectCustomer,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.all(6), margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: kBlack87.withOpacity(0.15)),
                    child: const HeroIcon(HeroIcons.xMark, size: 14, color: kBlack54),
                  ),
                ),
              ],
              const HeroIcon(HeroIcons.chevronRight, color: kGrey400, size: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemRow(CartItem item, int idx) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGrey200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(8)),
            child: Text('${item.quantity}x', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: kBlack87)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: kBlack87), maxLines: 2, overflow: TextOverflow.ellipsis),
                Row(
                  children: [
                    Text('@ ${AmountFormatter.format(item.price)}', style: const TextStyle(color: kOrange, fontSize: 11, fontWeight: FontWeight.w600)),
                    if (item.taxAmount > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '+${AmountFormatter.format(item.taxAmount)} (Tax ${item.taxPercentage?.toInt() ?? 0}%)',
                        style: const TextStyle(
                          color: kBlack54,
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('${AmountFormatter.format(item.totalWithTax)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: kPrimaryColor)),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => _showEditCartItemDialog(idx),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const HeroIcon(HeroIcons.pencil, color: kPrimaryColor, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  void _showNoteBottomSheet(BuildContext context, TextEditingController controller, String title, String hint) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: kWhite,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: kGrey200, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kBlack87)),
                const SizedBox(height: 16),
                ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextField(
                    controller: controller,
                    maxLines: 3,
                    autofocus: true,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: TextStyle(color: kBlack54.withOpacity(0.15), fontSize: 13),
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
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity, height: 48,
                  child: ElevatedButton(
                    onPressed: () { Navigator.pop(ctx); setState(() {}); },
                    style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                    child: const Text('Save', style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeliveryChargeBottomSheet(BuildContext context) {
    final controller = TextEditingController(text: _deliveryCharge > 0 ? _deliveryCharge.toStringAsFixed(2) : '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: kWhite,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: kGrey200, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                const Text('Delivery Charge', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kBlack87)),
                const SizedBox(height: 16),
                ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      hintStyle: TextStyle(color: kBlack54, fontSize: 18),
                      prefixIcon: Icon(Icons.local_shipping_outlined, color: kBlack54),
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (_deliveryCharge > 0)
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed: () { Navigator.pop(ctx); setState(() => _deliveryCharge = 0.0); },
                            style: OutlinedButton.styleFrom(side: const BorderSide(color: kErrorColor), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            child: const Text('Remove', style: TextStyle(color: kErrorColor, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                    if (_deliveryCharge > 0) const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            final val = double.tryParse(controller.text) ?? 0.0;
                            Navigator.pop(ctx);
                            setState(() => _deliveryCharge = val);
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                          child: const Text('Save', style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomPanel(List<CartItem> cartItems) {
    // Calculate values from current cart items
    final totalWithTax = cartItems.fold(0.0, (sum, item) => sum + item.totalWithTax);

    // Step-by-step calculation
    // 1. Subtotal
    final subtotal = totalWithTax;

    // 2. Customer Discount Amount (applied on subtotal)
    final customerDiscountAmount = (subtotal * _customerDefaultDiscount / 100);
    final amountAfterCustomerDiscount = subtotal - customerDiscountAmount;

    // 3. Additional Discount Amount (applied on amount after customer discount)
    final additionalDiscountAmount = _additionalDiscount;
    final amountAfterAllDiscounts = amountAfterCustomerDiscount - additionalDiscountAmount;

    // 4. Credit Applied
    final creditToApply = _totalCreditNotesAmount > amountAfterAllDiscounts ? amountAfterAllDiscounts : _totalCreditNotesAmount;
    final amountAfterCredit = (amountAfterAllDiscounts - creditToApply).clamp(0.0, double.infinity);
    final actualCreditUsed = _totalCreditNotesAmount > amountAfterAllDiscounts ? amountAfterAllDiscounts : _totalCreditNotesAmount;

    // 5. Delivery Charge
    final finalAmount = amountAfterCredit + _deliveryCharge;

    final bool hasCustomer = _selectedCustomerPhone != null;

    return Container(
      decoration: const BoxDecoration(
        color: kWhite,
        border: Border(top: BorderSide(color: kGrey200, width: 2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: R.sp(context, 16), vertical: R.sp(context, 12)),
            child: Column(
              children: [
                // Note Buttons Row
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showNoteBottomSheet(context, _notesController, 'Bill Note', 'Add bill notes / description...'),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: R.sp(context, 8), vertical: R.sp(context, 10)),
                          decoration: BoxDecoration(
                            color: _notesController.text.isNotEmpty ? kPrimaryColor.withOpacity(0.15): kGreyBg,
                            borderRadius: R.radius(context, 10),
                            border: Border.all(color: _notesController.text.isNotEmpty ? kPrimaryColor.withOpacity(0.15) : kGrey200),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              HeroIcon(_notesController.text.isNotEmpty ? HeroIcons.checkCircle : HeroIcons.plus, color: _notesController.text.isNotEmpty ? kPrimaryColor : kBlack54, size: R.sp(context, 14)),
                              SizedBox(width: R.sp(context, 4)),
                              Flexible(child: Text(_notesController.text.isNotEmpty ? 'Note ✓' : 'Note', style: TextStyle(fontSize: R.sp(context, 10), fontWeight: FontWeight.w700, color: _notesController.text.isNotEmpty ? kPrimaryColor : kBlack54), overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: R.sp(context, 6)),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showNoteBottomSheet(context, _deliveryAddressController, 'Customer Note', 'Add customer note...'),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: R.sp(context, 8), vertical: R.sp(context, 10)),
                          decoration: BoxDecoration(
                            color: _deliveryAddressController.text.isNotEmpty ? kOrange.withOpacity(0.15) : kGreyBg,
                            borderRadius: R.radius(context, 10),
                            border: Border.all(color: _deliveryAddressController.text.isNotEmpty ? kOrange.withOpacity(0.15) : kGrey200),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              HeroIcon(_deliveryAddressController.text.isNotEmpty ? HeroIcons.checkCircle : HeroIcons.plus, color: _deliveryAddressController.text.isNotEmpty ? kOrange : kBlack54, size: R.sp(context, 14)),
                              SizedBox(width: R.sp(context, 4)),
                              Flexible(child: Text(_deliveryAddressController.text.isNotEmpty ? 'Cust. Note ✓' : 'Cust. Note', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _deliveryAddressController.text.isNotEmpty ? kOrange : kBlack54), overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showDeliveryChargeBottomSheet(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          decoration: BoxDecoration(
                            color: _deliveryCharge > 0 ? kGoogleGreen.withOpacity(0.15) : kGreyBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _deliveryCharge > 0 ? kGoogleGreen.withOpacity(0.15) : kGrey200),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              HeroIcon(_deliveryCharge > 0 ? HeroIcons.checkCircle : HeroIcons.plus, color: _deliveryCharge > 0 ? kGoogleGreen : kBlack54, size: 14),
                              const SizedBox(width: 4),
                              Flexible(child: Text(_deliveryCharge > 0 ? 'Delivery ✓' : 'Delivery', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _deliveryCharge > 0 ? kGoogleGreen : kBlack54), overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        ),
                      ),

                    )],
                ),
                const SizedBox(height: 8),

                // Bill Summary Breakdown
                // 1. Subtotal (Total with Tax)
                _buildSummaryRow('Subtotal', AmountFormatter.format(subtotal)),

                // 2. Customer Discount (if available)
                if (_customerDefaultDiscount > 0) ...[
                  _buildSummaryRow(
                    'Customer Discount (${AmountFormatter.format(_customerDefaultDiscount, maxDecimals: 1)}%)',
                    '- ${AmountFormatter.format(customerDiscountAmount)}',
                    color: kGoogleGreen,
                  ),
                  const SizedBox(height: 2),
                ],

                // 3. Additional Discount (clickable to edit)
                _buildSummaryRow(
                  _customerDefaultDiscount > 0 ? 'Additional Discount' : 'Discount',
                  '- ${AmountFormatter.format(additionalDiscountAmount)}',
                  color: kGoogleGreen,
                  isClickable: true,
                  onTap: _showDiscountDialog,
                ),
                const SizedBox(height: 2),

                // 4. Credit Notes (only if customer is selected)
                if (hasCustomer)
                  _buildSummaryRow(
                    'Return Credit',
                    '- ${AmountFormatter.format(actualCreditUsed)}',
                    color: kOrange,
                    isClickable: true,
                    onTap: _showCreditNotesDialog,
                  ),

                const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Divider(height: 1, color: kGrey100)),

                // 5. Delivery Charge (if added)
                if (_deliveryCharge > 0) ...[  
                  _buildSummaryRow(
                    'Delivery Charge',
                    '+ ${AmountFormatter.format(_deliveryCharge)}',
                    color: Colors.black,
                    isClickable: true,
                    onTap: () => _showDeliveryChargeBottomSheet(context),
                  ),
                  const SizedBox(height: 2),
                ],

                // Total Amount Payable
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Amount', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: kBlack87)),
                    Text('$_currencySymbol${AmountFormatter.format(finalAmount)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: kPrimaryColor)),
                  ],
                ),
                const SizedBox(height: 12),

                // Checkout Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: cartItems.isEmpty ? null : () => _showPaymentMethodSheet(context, finalAmount),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      disabledBackgroundColor: kGrey200,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_unsettledSaleId != null ? 'Update' : 'Checkout', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kWhite, letterSpacing: 0.3)),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                          child: Text('$_currencySymbol${AmountFormatter.format(finalAmount)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: kWhite)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? color, bool isClickable = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Text(label, style: const TextStyle(color: kBlack54, fontSize: 13, fontWeight: FontWeight.w600)),
              if (isClickable) Padding(padding: const EdgeInsets.only(left: 6), child: HeroIcon(HeroIcons.pencilSquare, size: 16, color: color ?? kPrimaryColor)),
            ]),
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color ?? kBlack87)),
          ],
        ),
      ),
    );
  }


  void _showPaymentMethodSheet(BuildContext context, double amount) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: kWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 5),
              const Text('Select Payment Method', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kBlack87)),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildPayIcon(HeroIcons.banknotes, 'Cash', 'Pay with cash', () { Navigator.pop(ctx); _proceedToPayment('Cash'); }),
                  const SizedBox(width: 16),
                  _buildPayIcon(HeroIcons.qrCode, 'Online', 'UPI / Card / Net banking', () { Navigator.pop(ctx); _proceedToPayment('Online'); }),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildPayIcon(HeroIcons.bookOpen, 'Credit', 'Pay later', () { Navigator.pop(ctx); _proceedToPayment('Credit'); }),
                  const SizedBox(width: 16),
                  _buildPayIcon(HeroIcons.arrowsRightLeft, 'Split', 'Multiple methods', () { Navigator.pop(ctx); _proceedToPayment('Split'); }),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaymentMethodTile(BuildContext ctx, HeroIcons icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.pop(ctx);
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
                child: Center(child: HeroIcon(icon, color: color, size: 20)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 11, color: kBlack54)),
                  ],
                ),
              ),
              HeroIcon(HeroIcons.chevronRight, color: color.withOpacity(0.5), size: 20),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildPayIcon(HeroIcons icon, String label, String subtitle, VoidCallback onTap) {
    // Define colors: Cash=green, Online=blue, Credit=orange, Split=purple
    Color themeColor;
    if (label == 'Cash') {
      themeColor = const Color(0xFF34A853);
    } else if (label == 'Online') {
      themeColor = kPrimaryColor;
    } else if (label == 'Credit') {
      themeColor = kOrange;
    } else {
      themeColor = Colors.purple;
    }

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 1.0, // Make it a perfect square
              child: Container(
                decoration: BoxDecoration(
                  color: kGreyBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: themeColor.withOpacity(0.15), width: 1.5),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 56, // Increased size
                      height: 56, // Increased size
                      decoration: BoxDecoration(
                        color: themeColor.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: HeroIcon(icon, color: themeColor, size: 28), // Increased icon size
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14, // Increased text size
                        fontWeight: FontWeight.w800,
                        color: themeColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: kBlack54,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 2. CUSTOMER SELECTION DIALOG (REMASTERED)
// ==========================================
class _CustomerSelectionDialog extends StatefulWidget {
  final String uid;
  final Function(String phone, String name, String? gst) onCustomerSelected;
  const _CustomerSelectionDialog({required this.uid, required this.onCustomerSelected});
  @override
  State<_CustomerSelectionDialog> createState() => _CustomerSelectionDialogState();
}

class _CustomerSelectionDialogState extends State<_CustomerSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() => _searchQuery = _searchController.text.toLowerCase()));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _importFromContacts() async {
    final canImport = await PlanPermissionHelper.canImportContacts();
    if (!canImport) { PlanPermissionHelper.showUpgradeDialog(context, 'Import Contacts'); return; }

    if (!await FlutterContacts.requestPermission()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contacts permission denied'), backgroundColor: Colors.red));
      return;
    }
    final contacts = await FlutterContacts.getContacts(withProperties: true);
    if (contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No contacts found'), backgroundColor: Colors.orange));
      return;
    }
    showDialog(
      context: context,
      builder: (context) {
        List<Contact> filteredContacts = contacts;
        final TextEditingController contactSearchController = TextEditingController();
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: SizedBox(
                width: 350, height: 500,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Select Contact', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                          GestureDetector(onTap: () => Navigator.pop(context), child: const HeroIcon(HeroIcons.xMark)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: ValueListenableBuilder<TextEditingValue>(
      valueListenable: contactSearchController,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextField(
                        controller: contactSearchController,
                        decoration: InputDecoration(hintText: 'Search contacts...', prefixIcon: HeroIcon(HeroIcons.magnifyingGlass),
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
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredContacts.length,
                        itemBuilder: (context, index) {
                          final c = filteredContacts[index];
                          final phone = c.phones.isNotEmpty ? c.phones.first.number.replaceAll(RegExp(r'[^0-9+]'), '') : '';
                          return ListTile(
                            title: Text(c.displayName),
                            subtitle: Text(phone),
                            onTap: phone.isNotEmpty ? () {
                              Navigator.pop(context);
                              _showAddCustomerDialog(prefillName: c.displayName, prefillPhone: phone);
                            } : null,
                            enabled: phone.isNotEmpty,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddCustomerDialog({String? prefillName, String? prefillPhone}) {
    final nameCtrl = TextEditingController(text: prefillName ?? '');
    final phoneCtrl = TextEditingController(text: prefillPhone ?? '');
    final gstCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('New Customer', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                  GestureDetector(onTap: () => Navigator.pop(context), child: const HeroIcon(HeroIcons.xMark)),
                ],
              ),
              const SizedBox(height: 20),
              ValueListenableBuilder<TextEditingValue>(
      valueListenable: nameCtrl,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextField(controller: nameCtrl, decoration: InputDecoration(labelText: 'Name',
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
              const SizedBox(height: 16),
              ValueListenableBuilder<TextEditingValue>(
      valueListenable: phoneCtrl,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: 'Phone',
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
              const SizedBox(height: 16),
              ValueListenableBuilder<TextEditingValue>(
      valueListenable: gstCtrl,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextField(controller: gstCtrl, decoration: InputDecoration(labelText: 'GST (Optional)',
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
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: () async {
                    if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty) return;
                    await FirestoreService().setDocument('customers', phoneCtrl.text.trim(), {
                      'name': nameCtrl.text.trim(), 'phone': phoneCtrl.text.trim(), 'gst': gstCtrl.text.trim().isEmpty ? null : gstCtrl.text.trim(),
                      'balance': 0.0, 'totalSales': 0.0, 'purchaseCount': 0, 'timestamp': FieldValue.serverTimestamp(), 'lastUpdated': FieldValue.serverTimestamp(),
                    });
                    if (mounted) { Navigator.pop(context); widget.onCustomerSelected(phoneCtrl.text.trim(), nameCtrl.text.trim(), gstCtrl.text.trim()); }
                  },
                  child: const Text('Add Customer', style: TextStyle(color: kWhite, fontWeight: FontWeight.w600)),
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: kWhite,
      child: Container(
        height: 600,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Select Customer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: kBlack87, letterSpacing: 0.5)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const HeroIcon(HeroIcons.xMark, color: kBlack54)),
            ]),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ValueListenableBuilder<TextEditingValue>(
      valueListenable: _searchController,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextFormField(
                      controller: _searchController,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: context.tr('search'),
                        prefixIcon: const HeroIcon(HeroIcons.magnifyingGlass, color: kPrimaryColor),
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
                const SizedBox(width: 8),
                _squareActionBtn(HeroIcons.userPlus, _showAddCustomerDialog, kPrimaryColor),
                const SizedBox(width: 8),
                _squareActionBtn(HeroIcons.phone, _importFromContacts, kGoogleGreen),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<Stream<QuerySnapshot>>(
                future: FirestoreService().getCollectionStream('customers'),
                builder: (ctx, streamSnap) {
                  if (!streamSnap.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                  return StreamBuilder<QuerySnapshot>(
                    stream: streamSnap.data,
                    builder: (ctx, snap) {
                      if (!snap.hasData) return const Center(child: Text('No records', style: TextStyle(fontWeight: FontWeight.w600, color: kBlack54)));
                      final filtered = snap.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return data['name'].toString().toLowerCase().contains(_searchQuery) || data['phone'].toString().contains(_searchQuery);
                      }).toList();
                      return ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(color: kGrey100, height: 1),
                        itemBuilder: (ctx, i) {
                          final data = filtered[i].data() as Map<String, dynamic>;
                          final balance = (data['balance'] ?? 0.0) as num;
                          return ListTile(
                            onTap: () { widget.onCustomerSelected(data['phone'], data['name'], data['gst']); Navigator.pop(context); },
                            leading: CircleAvatar(backgroundColor: kPrimaryColor.withOpacity(0.15), child: Text(data['name'][0].toUpperCase(), style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w900))),
                            title: Text(data['name'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                            subtitle: Text(data['phone'], style: const TextStyle(fontSize: 11, color: kBlack54, fontWeight: FontWeight.w500)),
                            trailing: Text('${balance.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.w900, color: balance > 0 ? kErrorColor : kGoogleGreen, fontSize: 13)),
                          );
                        },
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

  Widget _squareActionBtn(HeroIcons icon, VoidCallback onTap, Color color) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 48, width: 48,
        decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.15))),
        child: HeroIcon(icon, color: color, size: 20),
      ),
    );
  }
}

// ==========================================
// 3. PAYMENT PAGE
// ==========================================
class PaymentPage extends StatefulWidget {
  final String uid; final String? userEmail; final List<CartItem> cartItems; final double totalAmount; final String paymentMode; final String? customerPhone; final String? customerName; final String? customerGST; final double discountAmount; final String creditNote; final String customNote; final String? deliveryAddress; final String? savedOrderId; final List<Map<String, dynamic>> selectedCreditNotes; final String? quotationId; final String? existingInvoiceNumber; final String? unsettledSaleId;
  final String businessName; final String businessLocation; final String businessPhone; final String staffName;
  final double actualCreditUsed;
  final double deliveryCharge;

  const PaymentPage({super.key, required this.uid, this.userEmail, required this.cartItems, required this.totalAmount, required this.paymentMode, this.customerPhone, this.customerName, this.customerGST, required this.discountAmount, required this.creditNote, this.customNote = '', this.deliveryAddress, this.savedOrderId, this.selectedCreditNotes = const [], this.quotationId, this.existingInvoiceNumber, this.unsettledSaleId, required this.businessName, required this.businessLocation, required this.businessPhone, required this.staffName, required this.actualCreditUsed, this.deliveryCharge = 0.0});
  @override State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  double _cashReceived = 0.0;
  final TextEditingController _displayController = TextEditingController(text: '0.0');
  double get _change => _cashReceived - widget.totalAmount;
  DateTime? _creditDueDate;
  bool _isProcessing = false;

  String _currencySymbol = 'Rs '; // Default currency

  @override
  void initState() {
    super.initState();
    _loadCurrency();
    if (widget.paymentMode != 'Credit') {
      _cashReceived = widget.totalAmount;
      _displayController.text = widget.totalAmount.toStringAsFixed(1);
    } else {
      // Don't set default due date - let user choose or skip
      _creditDueDate = null;
    }
  }

  Future<void> _loadCurrency() async {
    try {
      final store = await FirestoreService().getCurrentStoreDoc();
      if (store != null && store.exists && mounted) {
        final data = store.data() as Map<String, dynamic>;
        setState(() {
          _currencySymbol = CurrencyService.getSymbolWithSpace(data['currency']);
        });
      }
    } catch (e) {
      debugPrint('Error loading currency: $e');
    }
  }

  void _onKeyTap(String val) {
    setState(() {
      String cur = _displayController.text;
      if (val == 'back') { if (cur.length > 1) _displayController.text = cur.substring(0, cur.length - 1); else _displayController.text = '0'; }
      else if (val == '.') { if (!cur.contains('.')) _displayController.text += '.'; }
      else { if (cur == '0' || cur == '0.0') _displayController.text = val; else _displayController.text += val; }
      _cashReceived = double.tryParse(_displayController.text) ?? 0.0;
    });
  }

  Future<void> _completeSale() async {
    if (_isProcessing) return;
    if (widget.paymentMode == 'Credit' && widget.customerPhone == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer required for Credit'))); return; }
    if (widget.paymentMode != 'Credit' && _cashReceived < widget.totalAmount - 0.01) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment insufficient'), backgroundColor: Colors.red)); return; }

    setState(() => _isProcessing = true);

    // Generate invoice number with prefix
    String invoiceNumber;
    if (widget.existingInvoiceNumber != null) {
      invoiceNumber = widget.existingInvoiceNumber!;
    } else {
      final prefix = await NumberGeneratorService.getInvoicePrefix();
      final number = await NumberGeneratorService.generateInvoiceNumber();
      invoiceNumber = prefix.isNotEmpty ? '$prefix$number' : number;
    }

    // Calculate tax data — uses taxBreakdown for multi-tax per item
    final Map<String, double> taxMap = {};
    for (var item in widget.cartItems) {
      final breakdown = item.taxBreakdown;
      if (breakdown.isNotEmpty) {
        breakdown.forEach((name, amount) {
          taxMap[name] = (taxMap[name] ?? 0.0) + amount;
        });
      } else if (item.taxAmount > 0 && item.taxName != null) {
        final pct = item.taxPercentage ?? 0;
        final label = pct > 0 ? '${item.taxName!} @${pct % 1 == 0 ? pct.toInt() : pct}%' : item.taxName!;
        taxMap[label] = (taxMap[label] ?? 0.0) + item.taxAmount;
      }
    }
    final taxList = taxMap.entries.map((e) => {'name': e.key, 'amount': e.value}).toList();
    final totalTax = taxMap.values.fold(0.0, (a, b) => a + b);

    // Navigate immediately - don't wait for Firebase
  if (mounted) {
    if (widget.unsettledSaleId != null) {
      Navigator.pop(context, {'success': true});
    } else {
      Navigator.popUntil(context, (route) => route.isFirst);
      Navigator.push(context, CupertinoPageRoute(builder: (_) => InvoicePage(
          uid: widget.uid, userEmail: widget.userEmail, businessName: widget.businessName, businessLocation: widget.businessLocation, businessPhone: widget.businessPhone, invoiceNumber: invoiceNumber, dateTime: DateTime.now(),
          items: widget.cartItems.map((e)=>{'name':e.name, 'quantity':e.quantity, 'price':e.price, 'total':e.totalWithTax, 'taxPercentage':e.taxPercentage ?? 0, 'taxAmount':e.taxAmount}).toList(),
          subtotal: widget.totalAmount + widget.discountAmount + widget.actualCreditUsed - totalTax, discount: widget.discountAmount, taxes: taxList, total: widget.totalAmount, paymentMode: widget.paymentMode, cashReceived: _cashReceived,
          cashReceived_partial: widget.paymentMode == 'Credit' && _cashReceived > 0 && _cashReceived < widget.totalAmount ? _cashReceived : null,
          creditIssued_partial: widget.paymentMode == 'Credit' && _cashReceived > 0 && _cashReceived < widget.totalAmount ? widget.totalAmount - _cashReceived : null,
          customerName: widget.customerName, customerPhone: widget.customerPhone, customNote: widget.customNote, deliveryAddress: widget.deliveryAddress, deliveryCharge: widget.deliveryCharge)));
    }
  }

    // Fire-and-forget: Run all Firebase operations in background
    _saveDataInBackground(invoiceNumber, taxList, totalTax);
  }

  /// Saves all data to Firebase in background without blocking UI
  Future<void> _saveDataInBackground(String invoiceNumber, List<Map<String, dynamic>> taxList, double totalTax) async {
    try {
      final baseSaleData = {
        'invoiceNumber': invoiceNumber, 'items': widget.cartItems.map((e)=> {'productId':e.productId, 'name':e.name, 'quantity':e.quantity, 'price':e.price, 'cost': e.cost, 'total':e.total, 'taxes': e.taxes, 'taxPercentage': e.taxPercentage ?? 0, 'taxAmount': e.taxAmount, 'taxName': e.taxName, 'taxType': e.taxType}).toList(),
        'subtotal': widget.totalAmount + widget.discountAmount + widget.actualCreditUsed, 'discount': widget.discountAmount, 'creditUsed': widget.actualCreditUsed, 'total': widget.totalAmount, 'taxes': taxList, 'totalTax': totalTax,
        'paymentMode': widget.paymentMode, 'cashReceived': _cashReceived, 'change': _change > 0 ? _change : 0.0,
        if (widget.paymentMode == 'Credit') ...{
          // Always save creditAmount for ALL credit sales (full or partial)
          'creditAmount': widget.totalAmount - _cashReceived,
        },
        if (widget.paymentMode == 'Credit' && _cashReceived > 0 && _cashReceived < widget.totalAmount) ...{
          'cashReceived_partial': _cashReceived,
          'creditIssued_partial': widget.totalAmount - _cashReceived,
        },
        'customerPhone': widget.customerPhone, 'customerName': widget.customerName, 'customerGST': widget.customerGST, 'creditNote': widget.creditNote, 'customNote': widget.customNote, 'deliveryAddress': widget.deliveryAddress, 'deliveryCharge': widget.deliveryCharge, 'date': DateTime.now().toIso8601String(), 'staffId': widget.uid, 'staffName': widget.staffName, 'businessName': widget.businessName, 'businessLocation': widget.businessLocation, 'businessPhone': widget.businessPhone, 'timestamp': FieldValue.serverTimestamp(),
      };

      // Run all operations in parallel
      final futures = <Future>[];

      // Save/update sale document
      if (widget.unsettledSaleId != null) {
        futures.add(FirestoreService().updateDocument('sales', widget.unsettledSaleId!, {...baseSaleData, 'paymentStatus': 'settled', 'settledAt': FieldValue.serverTimestamp()}));
      } else {
        futures.add(FirestoreService().addDocument('sales', baseSaleData));
        futures.add(_updateProductStock());
      }

      // Customer-related updates
      if (widget.paymentMode == 'Credit') {
        futures.add(_updateCustomerCredit(widget.customerPhone!, widget.totalAmount - _cashReceived, invoiceNumber, _creditDueDate));
      }
      if (widget.customerPhone != null && widget.customerPhone!.isNotEmpty) {
        futures.add(_updateCustomerTotalSales(widget.customerPhone!, widget.totalAmount));
        futures.add(_addPaymentLogEntry(widget.customerPhone!, widget.customerName, widget.totalAmount, widget.paymentMode, invoiceNumber));
      }

      // Cleanup operations
      if (widget.savedOrderId != null) {
        futures.add(FirestoreService().deleteDocument('savedOrders', widget.savedOrderId!));
      }
      if (widget.selectedCreditNotes.isNotEmpty) {
        futures.add(_markCreditNotesAsUsed(invoiceNumber, widget.selectedCreditNotes, widget.actualCreditUsed));
      }
      if (widget.quotationId != null && widget.quotationId!.isNotEmpty) {
        futures.add(FirestoreService().updateDocument('quotations', widget.quotationId!, {'status': 'settled', 'billed': true, 'settledAt': FieldValue.serverTimestamp()}));
      }

      // Wait for all operations to complete
      await Future.wait(futures);
    } catch (e) {
      debugPrint('Background save error: $e');
    }
  }

  Future<void> _updateCustomerCredit(String phone, double amount, String invoiceNumber, DateTime? creditDueDate) async {
    final customerRef = await FirestoreService().getDocumentReference('customers', phone);
    final creditsCollection = await FirestoreService().getStoreCollection('credits');

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final customerDoc = await transaction.get(customerRef);
      if (customerDoc.exists) {
        final data = customerDoc.data() as Map<String, dynamic>?;
        final currentBalance = ((data?['balance'] as num?) ?? 0).toDouble();
        transaction.update(customerRef, {
          'balance': currentBalance + amount,
          'lastUpdated': FieldValue.serverTimestamp()
        });
      }
    });

    // Add credit entry for ledger and payment log tracking
    await creditsCollection.add({
      'customerId': phone,
      'customerName': widget.customerName ?? 'Customer',
      'amount': amount,
      'type': 'credit_sale',
      'method': 'Credit Sale',
      'invoiceNumber': invoiceNumber,
      'timestamp': FieldValue.serverTimestamp(),
      'date': DateTime.now().toIso8601String(),
      'note': 'Credit sale - Invoice #$invoiceNumber',
      'creditDueDate': creditDueDate?.toIso8601String(),
      'isSettled': false,
    });
  }

  /// Updates customer totalSales for ALL payment types (Cash, Online, Credit, Split)
  Future<void> _updateCustomerTotalSales(String phone, double amount) async {
    final customerRef = await FirestoreService().getDocumentReference('customers', phone);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final customerDoc = await transaction.get(customerRef);
      if (customerDoc.exists) {
        final data = customerDoc.data() as Map<String, dynamic>?;
        final currentTotalSales = ((data?['totalSales'] as num?) ?? 0).toDouble();
        transaction.update(customerRef, {
          'totalSales': currentTotalSales + amount,
          'lastUpdated': FieldValue.serverTimestamp()
        });
      }
    });
  }

  Future<void> _addPaymentLogEntry(String phone, String? customerName, double amount, String paymentMode, String invoiceNumber) async {
    // Skip if it's a Credit sale (already handled by _updateCustomerCredit)
    if (paymentMode == 'Credit') return;

    final creditsCollection = await FirestoreService().getStoreCollection('credits');

    String type;
    String method;
    String note;

    if (paymentMode == 'Cash') {
      type = 'sale_payment';
      method = 'Cash';
      note = 'Cash payment - Invoice #$invoiceNumber';
    } else if (paymentMode == 'Online') {
      type = 'sale_payment';
      method = 'Online';
      note = 'Online payment - Invoice #$invoiceNumber';
    } else {
      type = 'sale_payment';
      method = paymentMode;
      note = '$paymentMode payment - Invoice #$invoiceNumber';
    }

    await creditsCollection.add({
      'customerId': phone,
      'customerName': customerName ?? 'Customer',
      'amount': amount,
      'type': type,
      'method': method,
      'invoiceNumber': invoiceNumber,
      'timestamp': FieldValue.serverTimestamp(),
      'date': DateTime.now().toIso8601String(),
      'note': note,
    });
  }

  Future<void> _updateProductStock() async { final localStockService = context.read<LocalStockService>(); for (var cartItem in widget.cartItems) { if (cartItem.productId.startsWith('qs_')) continue; final productRef = await FirestoreService().getDocumentReference('Products', cartItem.productId); await productRef.update({'currentStock': FieldValue.increment(-(cartItem.quantity.toInt()))}); await localStockService.updateLocalStock(cartItem.productId, -cartItem.quantity.toInt()); } }

  /// Restores partial usage: deducts amount required from credit note(s).
  Future<void> _markCreditNotesAsUsed(String invoiceNumber, List<Map<String, dynamic>> selectedCreditNotes, double amountToDeduct) async {
    double remainingToDeduct = amountToDeduct;
    for (var creditNote in selectedCreditNotes) {
      if (remainingToDeduct <= 0) break;
      final double noteAmount = (creditNote['amount'] ?? 0).toDouble();

      if (noteAmount <= remainingToDeduct) {
        // Fully used
        await FirestoreService().updateDocument('creditNotes', creditNote['id'], {
          'status': 'Used',
          'usedInInvoice': invoiceNumber,
          'usedAt': FieldValue.serverTimestamp(),
          'amount': 0.0
        });
        remainingToDeduct -= noteAmount;
      } else {
        // Partially used: Keep remaining balance
        await FirestoreService().updateDocument('creditNotes', creditNote['id'], {
          'amount': noteAmount - remainingToDeduct,
          'lastPartialUseAt': FieldValue.serverTimestamp(),
          'lastPartialInvoice': invoiceNumber
        });
        remainingToDeduct = 0;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool canPay = widget.paymentMode == 'Credit' || _cashReceived >= widget.totalAmount - 0.01;
    
    // Theme colors based on payment mode
    Color primaryThemeColor;
    Color secondaryThemeColor;
    HeroIcons headerIcon;
    
    if (widget.paymentMode == 'Cash') {
      primaryThemeColor = const Color(0xFF34A853);
      secondaryThemeColor = const Color(0xFF1B5E20);
      headerIcon = HeroIcons.banknotes;
    } else if (widget.paymentMode == 'Online') {
      primaryThemeColor = kPrimaryColor;
      secondaryThemeColor = const Color(0xFF1565C0);
      headerIcon = HeroIcons.qrCode;
    } else {
      primaryThemeColor = kOrange;
      secondaryThemeColor = const Color(0xFFE65100);
      headerIcon = HeroIcons.bookOpen;
    }

    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        title: Text('${widget.paymentMode} Payment', style: const TextStyle(color: kWhite, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        backgroundColor: primaryThemeColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: const HeroIcon(HeroIcons.arrowLeft, color: kWhite, size: 20), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
            decoration: BoxDecoration(
              color: primaryThemeColor,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
              boxShadow: [BoxShadow(color: primaryThemeColor.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 8))],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -10, top: -10,
                  child: HeroIcon(headerIcon, color: Colors.white.withOpacity(0.15), size: 100),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                          child: const Text('Total Due', style: TextStyle(color: kWhite, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                        ),
                      ],
                    ),
                    if (widget.deliveryCharge > 0) ...[
                      const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                    child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_shipping_outlined, size: 12, color: kWhite),
                          const SizedBox(width: 4),
                          Text('+${widget.deliveryCharge.toStringAsFixed(2)} del.', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kWhite)),
                        ],
                      ),
                    ),
                    ],
                    const SizedBox(height: 16),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6, right: 4),
                          child: Text(_currencySymbol, style: TextStyle(color: Colors.white.withOpacity(0.15), fontSize: 20, fontWeight: FontWeight.w700)),
                        ),
                        Text(widget.totalAmount.toString(), style: const TextStyle(color: kWhite, fontSize: 40, fontWeight: FontWeight.w900, height: 1)),
                      ],
                    ),
                    if (widget.paymentMode != 'Credit') ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                        decoration: BoxDecoration(
                          color: kWhite, 
                          borderRadius: BorderRadius.circular(20), 
                        ),
                        child: Column(
                          children: [
                            const Text('Amount Received', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kBlack54, letterSpacing: 1.0)),
                            const SizedBox(height: 8),
                            Text(
                              _displayController.text, 
                              style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: canPay ? primaryThemeColor : kBlack87, letterSpacing: -1, height: 1)
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    if (widget.paymentMode != 'Credit') ...[
                      const SizedBox(height: 16),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('CHANGE: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white70, letterSpacing: 0.5)),
                              Text('$_currencySymbol${_change > 0 ? _change.toStringAsFixed(2) : "0.00"}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _change >= 0 ? kWhite : const Color(0xFFFF8A80))),
                            ],
                          ),
                        ),
                      ),
                    ],

                  ],
                ),
              ],
            ),
          ),
          
          Expanded(
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Center(
                        child: widget.paymentMode == 'Credit' 
                          ? _buildCreditDueDateMainSelector() 
                          : _buildKeyPad()
                      )
                    ),
                    const SizedBox(height: 12),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: canPay ? primaryThemeColor : kGrey200,
                        boxShadow: canPay ? [BoxShadow(color: primaryThemeColor.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6))] : [],
                      ),
                      child: ElevatedButton(
                        onPressed: (canPay && !_isProcessing) ? _completeSale : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _isProcessing
                            ? const SizedBox(
                                key: ValueKey('loading'),
                                width: 26, height: 26,
                                child: CircularProgressIndicator(color: kWhite, strokeWidth: 2.5),
                              )
                            : Row(
                                key: const ValueKey('content'),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(canPay ? (widget.unsettledSaleId != null ? 'Update' : 'Confirm Payment') : 'Incomplete Payment', style: TextStyle(color: canPay ? kWhite : kBlack54, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.0)),
                            if (canPay) ...[
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                                child: const HeroIcon(HeroIcons.arrowRight, color: kWhite, size: 18),
                              ),
                            ]
                          ],
                        ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditDueDateMainSelector() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 400),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: kOrange.withOpacity(0.15), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: kOrange.withOpacity(0.15),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Column(
              children: [
                const Text(
                  'SET DUE DATE (OPTIONAL)74',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _creditDueDate != null
                      ? DateFormat('dd MMM yyyy').format(_creditDueDate!)
                      : 'Not Selected',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: _creditDueDate != null ? kOrange : kBlack54,
                  ),
                ),
              ],
            ),
          ),
          Theme(
            data: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: kOrange,
                primary: kOrange,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: kBlack87,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: CalendarDatePicker(
                key: ValueKey(_creditDueDate?.toIso8601String() ?? 'none'),
                initialDate: _creditDueDate ?? DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                currentDate: DateTime.now(),
                onDateChanged: (DateTime date) {
                  setState(() {
                    _creditDueDate = date;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _selectCreditDueDate(BuildContext context) async {
    // This method is now legacy as we use inline selection, 
    // but kept for compatibility or manual triggers
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _creditDueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _creditDueDate = picked;
      });
    }
  }

  Widget _buildKeyPad() {
    final List<String> keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0', 'back'];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: keys.length,
      itemBuilder: (ctx, i) => _buildKey(keys[i]),
    );
  }

  Widget _buildKey(String key) {
    final bool isBack = key == 'back';
    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onKeyTap(key),
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: isBack
                ? const HeroIcon(HeroIcons.backspace, color: kErrorColor, size: 24)
                : Text(
                    key,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kBlack87),
                  ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 4. SPLIT PAYMENT PAGE
// ==========================================
class SplitPaymentPage extends StatefulWidget {
  final String uid; final String? userEmail; final List<CartItem> cartItems; final double totalAmount; final String? customerPhone; final String? customerName; final String? customerGST; final double discountAmount; final String creditNote; final String customNote; final String? deliveryAddress; final String? savedOrderId; final List<Map<String, dynamic>> selectedCreditNotes; final String? quotationId; final String? existingInvoiceNumber; final String? unsettledSaleId;
  final String businessName; final String businessLocation; final String businessPhone; final String staffName;
  final double actualCreditUsed;
  final double deliveryCharge;

  // Add fields for edit mode prefill
  final double? cashReceived_split;
  final double? onlineReceived_split;
  final double? creditIssued_split;

  const SplitPaymentPage({
    super.key,
    required this.uid,
    this.userEmail,
    required this.cartItems,
    required this.totalAmount,
    this.customerPhone,
    this.customerName,
    this.customerGST,
    required this.discountAmount,
    required this.creditNote,
    this.customNote = '',
    this.deliveryAddress,
    this.savedOrderId,
    this.selectedCreditNotes = const [],
    this.quotationId,
    this.existingInvoiceNumber,
    this.unsettledSaleId,
    required this.businessName,
    required this.businessLocation,
    required this.businessPhone,
    required this.staffName,
    required this.actualCreditUsed,
    this.deliveryCharge = 0.0,
    this.cashReceived_split,
    this.onlineReceived_split,
    this.creditIssued_split,
  });

  @override State<SplitPaymentPage> createState() => _SplitPaymentPageState();
}

class _SplitPaymentPageState extends State<SplitPaymentPage> {
  final TextEditingController _cashController = TextEditingController(text: '');
  final TextEditingController _onlineController = TextEditingController(text: '');
  final TextEditingController _creditController = TextEditingController(text: '');

  double _cashAmount = 0.0;
  double _onlineAmount = 0.0;
  double _creditAmount = 0.0;
  double get _totalPaid => _cashAmount + _onlineAmount + _creditAmount;
  double get _dueAmount => widget.totalAmount - _totalPaid;
  DateTime? _creditDueDate;
  String _currencySymbol = 'Rs '; // Default currency
  bool _isProcessing = false;
  bool _updatingCredit = false; // Guard flag to prevent re-entrant credit updates

  // Treat as edit mode when either unsettledSaleId is provided OR an existingInvoiceNumber is provided
  bool get isEditMode => widget.unsettledSaleId != null || (widget.existingInvoiceNumber != null && widget.existingInvoiceNumber!.isNotEmpty);

  @override
  void initState() {
    super.initState();
    _loadCurrency();
    // Prefill values if editing
    if (isEditMode) {
      _cashAmount = widget.cashReceived_split ?? 0.0;
      _onlineAmount = widget.onlineReceived_split ?? 0.0;
      _creditAmount = widget.creditIssued_split ?? 0.0;
      _cashController.text = _cashAmount > 0 ? _cashAmount.toStringAsFixed(2) : '';
      _onlineController.text = _onlineAmount > 0 ? _onlineAmount.toStringAsFixed(2) : '';
      _creditController.text = _creditAmount > 0 ? _creditAmount.toStringAsFixed(2) : '';
    }
    _cashController.addListener(_onCashChanged);
    _onlineController.addListener(_onOnlineChanged);
    _creditController.addListener(_onCreditChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !isEditMode) _updateCreditAmount();
    });
  }

  void _onCashChanged() {
    final val = double.tryParse(_cashController.text) ?? 0.0;
    if (val != _cashAmount) {
      setState(() {
        _cashAmount = val;
      });
      _updateCreditAmount();
    }
  }

  void _onOnlineChanged() {
    final val = double.tryParse(_onlineController.text) ?? 0.0;
    if (val != _onlineAmount) {
      setState(() {
        _onlineAmount = val;
      });
      _updateCreditAmount();
    }
  }

  void _onCreditChanged() {
    if (_updatingCredit) return; // Ignore changes triggered by _updateCreditAmount
    final val = double.tryParse(_creditController.text) ?? 0.0;
    if (val != _creditAmount) {
      setState(() {
        _creditAmount = val;
      });
    }
  }

  @override
  void dispose() {
    _cashController.removeListener(_onCashChanged);
    _onlineController.removeListener(_onOnlineChanged);
    _creditController.removeListener(_onCreditChanged);
    _cashController.dispose();
    _onlineController.dispose();
    _creditController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrency() async {
    try {
      final store = await FirestoreService().getCurrentStoreDoc();
      if (store != null && store.exists && mounted) {
        final data = store.data() as Map<String, dynamic>;
        setState(() {
          _currencySymbol = CurrencyService.getSymbolWithSpace(data['currency']);
        });
      }
    } catch (e) {
      debugPrint('Error loading currency: $e');
    }
  }

  void _updateCreditAmount() {
    // Auto-calculate credit amount as remaining balance
    final paidAmount = _cashAmount + _onlineAmount;
    final remainingDue = widget.totalAmount - paidAmount;

    _updatingCredit = true;
    if (remainingDue > 0 && widget.customerPhone != null) {
      _creditAmount = remainingDue;
      _creditController.text = remainingDue.toStringAsFixed(2);
    } else {
      _creditAmount = 0.0;
      _creditController.text = '';
    }
    _updatingCredit = false;

    if (mounted) setState(() {});
  }

      Future<void> _processSplitSale() async {
        if (_isProcessing) return;
        // Calculate change - overpayment
        final paidAmount = _cashAmount + _onlineAmount;
        final changeAmount = paidAmount > widget.totalAmount && _creditAmount == 0 ? paidAmount - widget.totalAmount : 0.0;

        // Allow payment if exact match OR overpayment (change > 0)
        if (_dueAmount > 0.01 && changeAmount == 0) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment insufficient')));
          return;
        }
        if (_creditAmount > 0 && widget.customerPhone == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer required for Credit')));
          return;
        }

        try {
          setState(() => _isProcessing = true);

          // Generate invoice number with prefix
          String invoiceNumber;
          if (widget.existingInvoiceNumber != null && widget.existingInvoiceNumber!.isNotEmpty) {
            invoiceNumber = widget.existingInvoiceNumber!;
          } else {
            final prefix = await NumberGeneratorService.getInvoicePrefix();
            final number = await NumberGeneratorService.generateInvoiceNumber();
            invoiceNumber = prefix.isNotEmpty ? '$prefix$number' : number;
          }

          final Map<String, double> taxMap = {};
          for (var item in widget.cartItems) {
            final breakdown = item.taxBreakdown;
            if (breakdown.isNotEmpty) {
              breakdown.forEach((name, amount) {
                taxMap[name] = (taxMap[name] ?? 0.0) + amount;
              });
            } else if (item.taxAmount > 0 && item.taxName != null) {
              final pct = item.taxPercentage ?? 0;
              final label = pct > 0 ? '${item.taxName!} @${pct % 1 == 0 ? pct.toInt() : pct}%' : item.taxName!;
              taxMap[label] = (taxMap[label] ?? 0.0) + item.taxAmount;
            }
          }
          final taxList = taxMap.entries.map((e) => {'name': e.key, 'amount': e.value}).toList();
          final totalTax = taxMap.values.fold(0.0, (a, b) => a + b);

          final baseSaleData = {
            'invoiceNumber': invoiceNumber,
            'items': widget.cartItems.map((e)=> {'productId':e.productId, 'name':e.name, 'quantity':e.quantity, 'price':e.price, 'total':e.total, 'taxes': e.taxes, 'taxPercentage': e.taxPercentage ?? 0, 'taxAmount': e.taxAmount, 'taxName': e.taxName, 'taxType': e.taxType}).toList(),
            'subtotal': widget.totalAmount + widget.discountAmount + widget.actualCreditUsed,
            'discount': widget.discountAmount,
            'creditUsed': widget.actualCreditUsed,
            'total': widget.totalAmount,
            'taxes': taxList,
            'totalTax': totalTax,
            'paymentMode': 'Split',
            'cashReceived': _totalPaid - _creditAmount,
            'change': changeAmount > 0 ? changeAmount : 0.0, // Add change field
            'cashReceived_split': _cashAmount,
            'onlineReceived_split': _onlineAmount,
            'creditIssued_split': _creditAmount,
            'customerPhone': widget.customerPhone,
            'customerName': widget.customerName,
            'customerGST': widget.customerGST,
            'creditNote': widget.creditNote,
            'customNote': widget.customNote, 'deliveryCharge': widget.deliveryCharge,
            'deliveryAddress': widget.deliveryAddress,
            'date': DateTime.now().toIso8601String(),
            'staffId': widget.uid,
            'staffName': widget.staffName,
            'businessName': widget.businessName,
            'businessLocation': widget.businessLocation,
            'businessPhone': widget.businessPhone,
            'timestamp': FieldValue.serverTimestamp(),
          };

          if (_creditAmount > 0) await _updateCustomerCredit(widget.customerPhone!, _creditAmount, invoiceNumber, _creditDueDate);

          // Update customer totalSales and add payment log entry for split payment when customer is linked
          if (widget.customerPhone != null && widget.customerPhone!.isNotEmpty) {
            await _updateCustomerTotalSales(widget.customerPhone!, widget.totalAmount);
            await _addSplitPaymentLogEntry(widget.customerPhone!, widget.customerName, _cashAmount, _onlineAmount, _creditAmount, invoiceNumber);
          }

          // Decide whether to update existing sale or create new
          final salesCollection = await FirestoreService().getStoreCollection('sales');

          if (widget.unsettledSaleId != null) {
            await FirestoreService().updateDocument('sales', widget.unsettledSaleId!, {...baseSaleData, 'paymentStatus': 'settled', 'settledAt': FieldValue.serverTimestamp()});
          } else if (widget.existingInvoiceNumber != null && widget.existingInvoiceNumber!.isNotEmpty) {
            // Try to find sale by invoiceNumber and update it
            final query = await salesCollection.where('invoiceNumber', isEqualTo: widget.existingInvoiceNumber).get();
            if (query.docs.isNotEmpty) {
              await salesCollection.doc(query.docs.first.id).update(baseSaleData);
            } else {
              await salesCollection.add(baseSaleData);
              await _updateProductStock();
            }
          } else {
            await salesCollection.add(baseSaleData);
            await _updateProductStock();
          }

          if (widget.savedOrderId != null) await FirestoreService().deleteDocument('savedOrders', widget.savedOrderId!);
          if (widget.selectedCreditNotes.isNotEmpty) await _markCreditNotesAsUsed(invoiceNumber, widget.selectedCreditNotes, widget.actualCreditUsed);
          if (widget.quotationId != null && widget.quotationId!.isNotEmpty) {
            await FirestoreService().updateDocument('quotations', widget.quotationId!, {'status': 'settled', 'billed': true, 'settledAt': FieldValue.serverTimestamp()});
          }

          if (mounted) {
            Navigator.of(context, rootNavigator: true).pop();
            if (isEditMode) {
              // Return to caller (Edit page) with success so it can refresh
              Navigator.pop(context, {'success': true});
            } else {
              // For regular flow, show invoice page as before
              Navigator.popUntil(context, (route) => route.isFirst);
              Navigator.push(context, CupertinoPageRoute(builder: (_) => InvoicePage(
                  uid: widget.uid, userEmail: widget.userEmail, businessName: widget.businessName, businessLocation: widget.businessLocation, businessPhone: widget.businessPhone, invoiceNumber: invoiceNumber, dateTime: DateTime.now(),
                  items: widget.cartItems.map((e)=> {'name':e.name, 'quantity':e.quantity, 'price':e.price, 'total':e.totalWithTax, 'taxPercentage':e.taxPercentage ?? 0, 'taxAmount':e.taxAmount}).toList(),
                  subtotal: widget.totalAmount + widget.discountAmount + widget.actualCreditUsed - totalTax, discount: widget.discountAmount, taxes: taxList, total: widget.totalAmount, paymentMode: 'Split', cashReceived: _totalPaid - _creditAmount,
                  cashReceived_split: _cashAmount, onlineReceived_split: _onlineAmount, creditIssued_split: _creditAmount,
                  customerName: widget.customerName, customerPhone: widget.customerPhone, customNote: widget.customNote, deliveryAddress: widget.deliveryAddress, deliveryCharge: widget.deliveryCharge)));
            }
          }
        } catch (e) { if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)); } }
      }

  Future<void> _updateCustomerCredit(String phone, double amount, String invoiceNumber, DateTime? creditDueDate) async {
    final customerRef = await FirestoreService().getDocumentReference('customers', phone);
    final creditsCollection = await FirestoreService().getStoreCollection('credits');

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final customerDoc = await transaction.get(customerRef);
      if (customerDoc.exists) {
        final data = customerDoc.data() as Map<String, dynamic>?;
        final currentBalance = ((data?['balance'] as num?) ?? 0).toDouble();
        transaction.update(customerRef, {
          'balance': currentBalance + amount,
          'lastUpdated': FieldValue.serverTimestamp()
        });
      }
    });

    // Add credit entry for ledger and payment log tracking
    await creditsCollection.add({
      'customerId': phone,
      'customerName': widget.customerName ?? 'Customer',
      'amount': amount,
      'type': 'credit_sale',
      'method': 'Split Payment Credit',
      'invoiceNumber': invoiceNumber,
      'timestamp': FieldValue.serverTimestamp(),
      'date': DateTime.now().toIso8601String(),
      'note': 'Split payment credit - Invoice #$invoiceNumber',
      'creditDueDate': creditDueDate?.toIso8601String(),
      'isSettled': false,
    });
  }

  /// Updates customer totalSales for Split payments
  Future<void> _updateCustomerTotalSales(String phone, double amount) async {
    final customerRef = await FirestoreService().getDocumentReference('customers', phone);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final customerDoc = await transaction.get(customerRef);
      if (customerDoc.exists) {
        final data = customerDoc.data() as Map<String, dynamic>?;
        final currentTotalSales = ((data?['totalSales'] as num?) ?? 0).toDouble();
        transaction.update(customerRef, {
          'totalSales': currentTotalSales + amount,
          'lastUpdated': FieldValue.serverTimestamp()
        });
      }
    });
  }

  Future<void> _addSplitPaymentLogEntry(String phone, String? customerName, double cashAmount, double onlineAmount, double creditAmount, String invoiceNumber) async {
    final creditsCollection = await FirestoreService().getStoreCollection('credits');
    final totalPaid = cashAmount + onlineAmount;

    // Only add entry for paid portion (Cash + Online), credit portion is handled separately
    if (totalPaid > 0) {
      String method = '';
      if (cashAmount > 0 && onlineAmount > 0) {
        method = 'Cash ($_currencySymbol${cashAmount.toStringAsFixed(0)}) + Online ($_currencySymbol${onlineAmount.toStringAsFixed(0)})';
      } else if (cashAmount > 0) {
        method = 'Cash';
      } else {
        method = 'Online';
      }

      await creditsCollection.add({
        'customerId': phone,
        'customerName': customerName ?? 'Customer',
        'amount': totalPaid,
        'type': 'sale_payment',
        'method': method,
        'invoiceNumber': invoiceNumber,
        'timestamp': FieldValue.serverTimestamp(),
        'date': DateTime.now().toIso8601String(),
        'note': 'Split payment - Invoice #$invoiceNumber',
      });
    }
  }

  Future<void> _updateProductStock() async { final localStockService = context.read<LocalStockService>(); for (var cartItem in widget.cartItems) { if (cartItem.productId.startsWith('qs_')) continue; final productRef = await FirestoreService().getDocumentReference('Products', cartItem.productId); await productRef.update({'currentStock': FieldValue.increment(-(cartItem.quantity.toInt()))}); await localStockService.updateLocalStock(cartItem.productId, -cartItem.quantity.toInt()); } }

  Future<void> _markCreditNotesAsUsed(String invoiceNumber, List<Map<String, dynamic>> selectedCreditNotes, double amountToDeduct) async {
    double remainingToDeduct = amountToDeduct;
    for (var creditNote in selectedCreditNotes) {
      if (remainingToDeduct <= 0) break;
      final double noteAmount = (creditNote['amount'] ?? 0).toDouble();
      if (noteAmount <= remainingToDeduct) {
        await FirestoreService().updateDocument('creditNotes', creditNote['id'], {
          'status': 'Used',
          'usedInInvoice': invoiceNumber,
          'usedAt': FieldValue.serverTimestamp(),
          'amount': 0.0
        });
        remainingToDeduct -= noteAmount;
      } else {
        await FirestoreService().updateDocument('creditNotes', creditNote['id'], {
          'amount': noteAmount - remainingToDeduct,
          'lastPartialUseAt': FieldValue.serverTimestamp(),
          'lastPartialInvoice': invoiceNumber
        });
        remainingToDeduct = 0;
      }
    }
  }

    @override
    Widget build(BuildContext context) {
    final paidAmount = _cashAmount + _onlineAmount;
    final changeAmount = paidAmount > widget.totalAmount && _creditAmount == 0 ? paidAmount - widget.totalAmount : 0.0;
    bool canPay = (_dueAmount <= 0.01 && _dueAmount >= -0.01) || changeAmount > 0;

    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        title: Text(isEditMode ? 'Update Split Payment' : 'Split Payment', style: const TextStyle(color: kWhite, fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: kPrimaryColor,
        iconTheme: const IconThemeData(color: kWhite),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: kPrimaryColor,
              borderRadius: BorderRadius.circular(24),
            ),
              child: Stack(
                children: [
                  Positioned(
                    right: -15, top: -15,
                    child: HeroIcon(HeroIcons.receiptPercent, color: Colors.white.withOpacity(0.15), size: 100),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                              child: const Text('Total Amount', style: TextStyle(color: kWhite, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                          ),
                        ],
                      ),
                      if (widget.deliveryCharge >0) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                        child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.local_shipping_outlined, size: 12, color: kWhite),
                              const SizedBox(width: 4),
                              Text('+${widget.deliveryCharge.toStringAsFixed(2)} del.', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kWhite)),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6, right: 4),
                              child: Text(_currencySymbol, style: TextStyle(color: Colors.white.withOpacity(0.15), fontSize: 20, fontWeight: FontWeight.w700)),
                          ),
                          Text(AmountFormatter.format(widget.totalAmount), style: const TextStyle(color: kWhite, fontSize: 40, fontWeight: FontWeight.w900, height: 1)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildSummaryItem('Paid', _totalPaid, Colors.white),
                          ],
                        ),
                      )
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildPaymentRow('Cash Received', HeroIcons.banknotes, const Color(0xFF34A853), _cashController),
            _buildPaymentRow('Online / UPI', HeroIcons.qrCode, kPrimaryColor, _onlineController),
            _buildPaymentRow('Credit Book', HeroIcons.bookOpen, kOrange, _creditController, enabled: widget.customerPhone != null),

            // Show change amount when overpaid
            if (changeAmount > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF34A853).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF34A853).withOpacity(0.15), width: 1.5),
                    ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFF34A853).withOpacity(0.15), shape: BoxShape.circle),
                      child: const HeroIcon(HeroIcons.banknotes, color: Color(0xFF34A853), size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Cash To Return', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF34A853), letterSpacing: 1.0)),
                          const SizedBox(height: 2),
                          Text('$_currencySymbol${changeAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF34A853))),
                        ],
                      ),
                    ),
                    const HeroIcon(HeroIcons.checkCircle, color: Color(0xFF34A853), size: 32),
                  ],
                ),
              ),
            ],

            // Credit Due Date Selector
            if (_creditAmount > 0) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _selectCreditDueDate(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: kOrange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kOrange.withOpacity(0.15), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: kOrange.withOpacity(0.15), shape: BoxShape.circle),
                        child: const HeroIcon(HeroIcons.calendar, color: kOrange, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Credit Due Date', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kOrange, letterSpacing: 0.5)),
                            const SizedBox(height: 2),
                            Text(
                              _creditDueDate != null
                                  ? '${_creditDueDate!.day.toString().padLeft(2, '0')}-${_creditDueDate!.month.toString().padLeft(2, '0')}-${_creditDueDate!.year}'
                                  : 'Select Date',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kBlack87),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: kWhite, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4, offset: const Offset(0, 2))]),
                        child: const HeroIcon(HeroIcons.pencil, color: kOrange, size: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          decoration: const BoxDecoration(color: kGreyBg),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: canPay ? kPrimaryColor : kGrey200,
              boxShadow: canPay ? [BoxShadow(color: kPrimaryColor.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6))] : [],
            ),
            child: ElevatedButton(
              onPressed: (canPay && !_isProcessing) ? _processSplitSale : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _isProcessing
                  ? const SizedBox(
                      key: ValueKey('loading'),
                      width: 26, height: 26,
                      child: CircularProgressIndicator(color: kWhite, strokeWidth: 2.5),
                    )
                  : Row(
                      key: const ValueKey('content'),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(canPay ? (isEditMode ? 'Update' : 'Confirm Payment') : 'Incomplete Payment', style: TextStyle(color: canPay ? kWhite : kBlack54, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.0)),
                  if (canPay) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                      child: const HeroIcon(HeroIcons.arrowRight, color: kWhite, size: 18),
                    ),
                  ]
                ],
              ),
              ),
            ),
          ),
        ),
      ),
    );
    }

  Future<void> _selectCreditDueDate(BuildContext context) async {
    // Show dialog asking user if they want to set a date or skip
    final shouldSetDate = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Credit Due Date', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: kBlack87)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Would you like to set a due date for this credit?', style: TextStyle(fontSize: 13, color: kBlack54)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kOrange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kOrange.withOpacity(0.15)),
                ),
                child: Row(
                  children: [
                    const HeroIcon(HeroIcons.informationCircle, color: kOrange, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You can skip this and set it later',
                        style: TextStyle(fontSize: 11, color: kBlack87, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Skip', style: TextStyle(color: kBlack54, fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Select Date', style: TextStyle(color: kWhite, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );

    if (shouldSetDate == true) {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: kPrimaryColor,
                onPrimary: kWhite,
                surface: kWhite,
                onSurface: kBlack87,
              ),
            ),
            child: child!,
          );
        },
      );
      if (picked != null) {
        setState(() {
          _creditDueDate = picked;
        });
      }
    }
  }

  Widget _buildPaymentRow(String title, HeroIcons icon, Color tintColor, TextEditingController ctrl, {bool enabled = true}) {
    final double amount = double.tryParse(ctrl.text) ?? 0.0;
    final bool hasValue = amount > 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: enabled ? kWhite : kGrey100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: enabled && hasValue ? kBlack87.withOpacity(0.15) : (enabled ? kGrey200 : kGrey100), width: hasValue ? 2.0 : 1.5),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: enabled ? tintColor.withOpacity(0.15) : kGrey200,
              shape: BoxShape.circle,
            ),
            child: HeroIcon(icon, color: enabled ? tintColor : kBlack54, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: enabled ? kBlack87 : kBlack54)),
                if (!enabled) const Text('Customer required', style: TextStyle(fontSize: 10, color: kOrange, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          SizedBox(
            width: 120,
            child: ValueListenableBuilder<TextEditingValue>(
      valueListenable: ctrl,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextFormField(
              controller: ctrl,
              enabled: enabled,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: enabled ? kBlack87 : kBlack54),
              decoration: InputDecoration(
                prefixStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: enabled ? kBlack87 : kBlack54),
                
                isDense: true,
                filled: true,
                fillColor: const Color(0xFFF8F9FA),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: hasText ? kBlack87 : kGrey200, width: hasText ? 1.5 : 1.0),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: hasText ? kBlack87 : kGrey200, width: hasText ? 1.5 : 1.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kBlack87, width: 2.0),
                ),
                labelStyle: TextStyle(color: hasText ? kBlack87 : kBlack54, fontSize: 13, fontWeight: FontWeight.w600),
                floatingLabelStyle: TextStyle(color: hasText ? kBlack87 : kBlack87, fontSize: 11, fontWeight: FontWeight.w900),
              ),
            
);
      },
    ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, double amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: TextStyle(color: color.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text('$_currencySymbol${amount.toStringAsFixed(2)}', style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900)),
      ],
    );
  }
}
