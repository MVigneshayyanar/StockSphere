import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:heroicons/heroicons.dart';
import 'package:maxbillup/models/cart_item.dart';
import 'package:maxbillup/Sales/Invoice.dart';
import 'package:maxbillup/Sales/components/common_widgets.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/amount_formatter.dart';
import 'package:maxbillup/Colors.dart';
import 'package:maxbillup/utils/responsive_helper.dart';
import 'package:maxbillup/services/number_generator_service.dart';
import 'package:maxbillup/services/currency_service.dart';

class QuotationPage extends StatefulWidget {
  final String uid;
  final String? userEmail;
  final List<CartItem> cartItems;
  final double totalAmount;
  final String? customerPhone;
  final String? customerName;
  final String? customerGST;
  final String? editQuotationId;
  final Map<String, dynamic>? initialQuotationData;

  const QuotationPage({
    super.key,
    required this.uid,
    this.userEmail,
    required this.cartItems,
    required this.totalAmount,
    this.customerPhone,
    this.customerName,
    this.customerGST,
    this.editQuotationId,
    this.initialQuotationData,
  });

  @override
  State<QuotationPage> createState() => _QuotationPageState();
}

class _QuotationPageState extends State<QuotationPage> {
  String? _selectedCustomerPhone;
  String? _selectedCustomerName;
  String? _selectedCustomerGST;

  bool _isBillWise = true;
  bool _isProcessing = false; // Prevents double-click on generate button

  // Bill Wise state
  double _cashDiscountAmount = 0.0;
  double _percentageDiscount = 0.0;
  final TextEditingController _cashDiscountController = TextEditingController();
  final TextEditingController _percentageController = TextEditingController();

  // Item Wise state
  late List<TextEditingController> _itemDiscountControllers;
  late List<double> _itemDiscounts;
  late List<bool> _isItemDiscountPercentage;
  String _currencySymbol = '';

  @override
  void initState() {
    super.initState();
    _selectedCustomerPhone = widget.customerPhone;
    _selectedCustomerName = widget.customerName;
    _selectedCustomerGST = widget.customerGST;
    _loadCurrency();

    _itemDiscountControllers = List.generate(
      widget.cartItems.length,
          (_) => TextEditingController(),
    );
    _itemDiscounts = List.filled(widget.cartItems.length, 0.0);
    _isItemDiscountPercentage = List.filled(widget.cartItems.length, false);
  }

  void _loadCurrency() async {
    final store = await FirestoreService().getCurrentStoreDoc();
    if (store != null && store.exists && mounted) {
      final data = store.data() as Map<String, dynamic>;
      setState(() => _currencySymbol = CurrencyService.getSymbolWithSpace(data['currency']));
    }
  }

  @override
  void dispose() {
    _cashDiscountController.dispose();
    _percentageController.dispose();
    for (var controller in _itemDiscountControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  double get _discountAmount {
    if (_isBillWise) {
      if (_cashDiscountAmount > 0) return _cashDiscountAmount;
      if (_percentageDiscount > 0) return widget.totalAmount * (_percentageDiscount / 100);
    } else {
      double totalItemDiscount = 0;
      for (int i = 0; i < widget.cartItems.length; i++) {
        if (i >= _isItemDiscountPercentage.length) break;
        if (_isItemDiscountPercentage[i]) {
          totalItemDiscount += widget.cartItems[i].total * (_itemDiscounts[i] / 100);
        } else {
          totalItemDiscount += _itemDiscounts[i];
        }
      }
      return totalItemDiscount;
    }
    return 0.0;
  }

  double get _discountPercentage {
    if (widget.totalAmount == 0) return 0.0;
    return (_discountAmount / widget.totalAmount) * 100;
  }


  void _updateItemDiscount(int index, String value) {
    setState(() {
      final discount = double.tryParse(value) ?? 0.0;
      if (_isItemDiscountPercentage[index]) {
        _itemDiscounts[index] = discount.clamp(0.0, 100.0);
      } else {
        final maxDiscount = widget.cartItems[index].total;
        _itemDiscounts[index] = discount.clamp(0.0, maxDiscount);
      }
    });
  }

  void _toggleItemDiscountMode(int index) {
    setState(() {
      _isItemDiscountPercentage[index] = !_isItemDiscountPercentage[index];
      _itemDiscounts[index] = 0.0;
      _itemDiscountControllers[index].clear();
    });
  }

  void _updateCashDiscount(String v) {
    setState(() {
      _cashDiscountAmount = double.tryParse(v) ?? 0.0;
      if (_cashDiscountAmount > 0) {
        _percentageDiscount = 0.0;
        _percentageController.clear();
      }
    });
  }

  void _updatePercentageDiscount(String v) {
    setState(() {
      _percentageDiscount = double.tryParse(v) ?? 0.0;
      if (_percentageDiscount > 0) {
        _cashDiscountAmount = 0.0;
        _cashDiscountController.clear();
      }
    });
  }

  void _showCustomerDialog() {
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

  Future<Map<String, String?>> _fetchBusinessDetails() async {
    try {
      final firestoreService = FirestoreService();
      final storeDoc = await firestoreService.getCurrentStoreDoc();

      if (storeDoc != null && storeDoc.exists) {
        final data = storeDoc.data() as Map<String, dynamic>?;
        return {
          'businessName': data?['businessName'] as String?,
          'location': data?['location'] as String? ?? data?['businessLocation'] as String? ?? data?['businessAddress'] as String?,
          'businessPhone': data?['businessPhone'] as String?,
          'gstin': data?['gstin'] as String?,
        };
      }
      return {'businessName': null, 'location': null, 'businessPhone': null, 'gstin': null};
    } catch (e) {
      debugPrint('Error fetching business details: $e');
      return {'businessName': null, 'location': null, 'businessPhone': null, 'gstin': null};
    }
  }

  Future<void> _generateQuotation() async {
    if (_isProcessing) return; // Prevent double-click
    setState(() => _isProcessing = true);
    try {
      // 1. Show Loading Indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator(color: kPrimaryColor)),
      );

      // 2. Identity Verification & Store Fetch
      final firestoreService = FirestoreService();
      final storeId = await firestoreService.getCurrentStoreId();

      if (storeId == null) {
        if (mounted) Navigator.pop(context); // Close loading
        throw Exception('Identity Error: Store ID not found. Please setup your profile in Settings.');
      }

      final storeDoc = await firestoreService.getCurrentStoreDoc();
      final storeData = storeDoc?.data() as Map<String, dynamic>?;
      final staffName = storeData?['ownerName'] ?? 'Staff';

      // Generate quotation number with prefix using the service or reuse existing
      final quotationNumber = widget.editQuotationId != null 
          ? (widget.initialQuotationData?['quotationNumber'] ?? 'N/A')
          : await () async {
              final prefix = await NumberGeneratorService.getQuotationPrefix();
              final number = await NumberGeneratorService.generateQuotationNumber();
              return prefix.isNotEmpty ? '$prefix$number' : number;
            }();

      // Calculate tax information from cart items — multi-tax support
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

      // Calculate subtotal (without tax) and total with tax
      final subtotalAmount = widget.cartItems.fold(0.0, (sum, item) {
        if (item.taxType == 'Tax Included in Price' || item.taxType == 'Price includes Tax') {
          return sum + (item.basePrice * item.quantity);
        } else {
          return sum + item.total;
        }
      });
      final totalWithTax = widget.cartItems.fold(0.0, (sum, item) => sum + item.totalWithTax);

      // 3. Prepare Data
      final List<Map<String, dynamic>> itemsList = widget.cartItems.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;

        double calculatedItemDiscountValue = _isBillWise
            ? 0.0
            : (_isItemDiscountPercentage[index]
            ? (item.total * (_itemDiscounts[index] / 100))
            : _itemDiscounts[index]);

        return {
          'productId': item.productId,
          'name': item.name,
          'price': item.price,
          'quantity': item.quantity,
          'total': item.total,
          'taxes': item.taxes,
          'taxName': item.taxName,
          'taxPercentage': item.taxPercentage ?? 0,
          'taxAmount': item.taxAmount,
          'taxType': item.taxType,
          'totalWithTax': item.totalWithTax,
          'discount': calculatedItemDiscountValue,
          'discountInputType': _isBillWise ? 'none' : (_isItemDiscountPercentage[index] ? 'percentage' : 'cash'),
          'finalTotal': item.total - calculatedItemDiscountValue,
        };
      }).toList();

      final quotationData = {
        'quotationNumber': quotationNumber,
        'items': itemsList,
        'subtotal': subtotalAmount,
        'discount': _discountAmount,
        'discountPercentage': _discountPercentage,
        'taxes': taxList,
        'totalTax': totalTax,
        'total': totalWithTax - _discountAmount,
        'discountMode': _isBillWise ? 'billWise' : 'itemWise',
        'billWiseCashDiscount': _cashDiscountAmount,
        'billWisePercDiscount': _percentageDiscount,
        'customerPhone': _selectedCustomerPhone,
        'customerName': _selectedCustomerName ?? 'Guest',
        'customerGST': (_selectedCustomerGST?.isEmpty ?? true) ? null : _selectedCustomerGST,
        'timestamp': FieldValue.serverTimestamp(),
        'date': DateTime.now().toIso8601String(),
        'staffId': widget.uid,
        'staffName': staffName,
        'status': 'active',
        'billed': false,
      };

      // 4. Save to Subcollection of Store
      if (widget.editQuotationId != null) {
        await firestoreService.updateDocument('quotations', widget.editQuotationId!, quotationData);
      } else {
        final docRef = await firestoreService.addDocument('quotations', quotationData);
        // Secondary update to store the generated ID inside the document
        await firestoreService.updateDocument('quotations', docRef.id, {'quotationId': docRef.id});
      }
      if (mounted) {
        Navigator.pop(context); // Remove loading indicator

        // Fetch business details for invoice
        final businessDetails = await _fetchBusinessDetails();
        final businessName = businessDetails['businessName'] ?? 'Business';
        final businessLocation = businessDetails['location'] ?? 'Location';
        final businessPhone = businessDetails['businessPhone'] ?? '';
        final businessGSTIN = businessDetails['gstin'];

        // Navigate to Invoice page with isQuotation=true and complete tax information
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => InvoicePage(
              uid: widget.uid,
              userEmail: widget.userEmail,
              businessName: businessName,
              businessLocation: businessLocation,
              businessPhone: businessPhone,
              businessGSTIN: businessGSTIN,
              invoiceNumber: quotationNumber,
              dateTime: DateTime.now(),
              items: widget.cartItems.map((e) => {
                'name': e.name,
                'quantity': e.quantity,
                'price': e.price,
                'total': e.totalWithTax,
                'taxPercentage': e.taxPercentage ?? 0,
                'taxAmount': e.taxAmount,
              }).toList(),
              subtotal: subtotalAmount,
              discount: _discountAmount,
              taxes: taxList,
              total: totalWithTax - _discountAmount,
              paymentMode: 'Quotation',
              cashReceived: 0.0,
              customerName: _selectedCustomerName,
              customerPhone: _selectedCustomerPhone,
              customerGSTIN: _selectedCustomerGST,
              isQuotation: true, // Mark this as a quotation
              showCelebration: false,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Remove loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Submission Error: ${e.toString()}'),
              backgroundColor: kErrorColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: R.radius(context, 12)),
            )
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasCustomer = _selectedCustomerName != null && _selectedCustomerName!.isNotEmpty;

    return Scaffold(
      backgroundColor: kGreyBg,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: HeroIcon(HeroIcons.arrowLeft, color: kWhite, size: R.sp(context, 22)), onPressed: () => Navigator.pop(context)),
        title: Text('New Quotation', style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: R.sp(context, 18))),
      ),
      body: Column(
        children: [
          Padding(
            padding: R.all(context, 12),
            child: InkWell(
              onTap: _showCustomerDialog,
              borderRadius: R.radius(context, 16),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: R.sp(context, 16), vertical: R.sp(context, 12)),
                decoration: BoxDecoration(
                  color: kWhite,
                  borderRadius: R.radius(context, 16),
                  border: Border.all(color: hasCustomer ? kPrimaryColor : kOrange, width: hasCustomer ? 1 : 1.5),
                ),
                child: Row(
                  children: [
                    HeroIcon(hasCustomer ? HeroIcons.user : HeroIcons.userPlus, color: hasCustomer ? kPrimaryColor : kOrange, size: R.sp(context, 24)),
                    SizedBox(width: R.sp(context, 12)),
                    Expanded(
                      child: Text(
                        hasCustomer ? _selectedCustomerName! : 'Assign Customer',
                        style: TextStyle(color: hasCustomer ? kPrimaryColor : kOrange, fontSize: R.sp(context, 15), fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (hasCustomer)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedCustomerPhone = null;
                            _selectedCustomerName = null;
                            _selectedCustomerGST = null;
                          });
                        },
                        child: HeroIcon(HeroIcons.xCircle, color: kErrorColor, size: R.sp(context, 20)),
                      )
                    else
                      HeroIcon(HeroIcons.chevronRight, color: kGrey400, size: R.sp(context, 14)),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.vertical(top: Radius.circular(R.sp(context, 24)))),
              child: SingleChildScrollView(
                padding: R.all(context, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Discounting Strategy', style: TextStyle(fontSize: R.sp(context, 13), fontWeight: FontWeight.w700, color: kBlack54, letterSpacing: 0.5)),
                    SizedBox(height: R.sp(context, 12)),
                    Row(
                      children: [
                        _buildToggleBtn('Bill Wise', _isBillWise, () => setState(() => _isBillWise = true)),
                        SizedBox(width: R.sp(context, 10)),
                        _buildToggleBtn('Item Wise', !_isBillWise, () => setState(() => _isBillWise = false)),
                      ],
                    ),
                    SizedBox(height: R.sp(context, 20)),
                    if (_isBillWise) ...[
                      _buildSummaryRow('Initial Total', widget.totalAmount),
                      SizedBox(height: R.sp(context, 24)),
                      _buildInputLabel('Fixed Cash Discount'),
                      _buildTextField(_cashDiscountController, '0.00', _updateCashDiscount, HeroIcons.banknotes),
                      SizedBox(height: R.sp(context, 16)),
                      Center(child: Text('OR', style: TextStyle(color: kGrey400, fontWeight: FontWeight.w800, fontSize: R.sp(context, 10)))),
                      SizedBox(height: R.sp(context, 16)),
                      _buildInputLabel('Percentage (%) Discount'),
                      _buildTextField(_percentageController, '0%', _updatePercentageDiscount, HeroIcons.receiptPercent),
                    ] else ...[
                      _buildItemWiseTable(),
                    ],
                    SizedBox(height: R.sp(context, 200)),
                  ],
                ),
              ),
            ),
          ),
          // Sticky bottom summary area - now outside the scrollable content
          SafeArea(
            child: _buildBottomSummaryArea(),
          ),
        ],
      ),
    );
  }

  Widget _buildItemWiseTable() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(vertical: R.sp(context, 10), horizontal: R.sp(context, 8)),
          decoration: BoxDecoration(color: kGreyBg, borderRadius: R.radius(context, 12)),
          child: Row(
            children: [
              Expanded(flex: 3, child: Text('Product', style: TextStyle(fontSize: R.sp(context, 10), fontWeight: FontWeight.w800, color: kBlack54))),
              Expanded(flex: 2, child: Text('Qty/rate', style: TextStyle(fontSize: R.sp(context, 10), fontWeight: FontWeight.w800, color: kBlack54))),
              Expanded(flex: 2, child: Text('Total', style: TextStyle(fontSize: R.sp(context, 10), fontWeight: FontWeight.w800, color: kBlack54))),
              Expanded(flex: 3, child: Text('Disc', textAlign: TextAlign.right, style: TextStyle(fontSize: R.sp(context, 10), fontWeight: FontWeight.w800, color: kBlack54))),
            ],
          ),
        ),
        SizedBox(height: R.sp(context, 4)),
        ...widget.cartItems.asMap().entries.map((entry) => _buildItemTableRow(entry.key, entry.value)),
      ],
    );
  }

  Widget _buildItemTableRow(int index, CartItem item) {
    final bool isPerc = _isItemDiscountPercentage[index];
    return Container(
      padding: EdgeInsets.symmetric(vertical: R.sp(context, 8), horizontal: R.sp(context, 4)),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kGreyBg))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: Text(
                item.name,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: R.sp(context, 12), color: kBlack87),
                maxLines: 2, overflow: TextOverflow.ellipsis
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
                '${item.quantity}x${AmountFormatter.format(item.price)}',
                style: TextStyle(fontSize: R.sp(context, 11), color: kBlack54, fontWeight: FontWeight.w700)
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
                AmountFormatter.format(item.total),
                style: TextStyle(fontSize: R.sp(context, 12), fontWeight: FontWeight.w800, color: kBlack87)
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () => _toggleItemDiscountMode(index),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: R.sp(context, 6), vertical: R.sp(context, 6)),
                    decoration: BoxDecoration(color: kPrimaryColor.withValues(alpha: (0.1 * 255).toDouble()), borderRadius: R.radius(context, 6)),
                    child: Text(isPerc ? "%" : "Amt", style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold, fontSize: R.sp(context, 10))),
                  ),
                ),
                SizedBox(width: R.sp(context, 6)),
                SizedBox(
                  width: R.sp(context, 70),
                  height: R.sp(context, 32),
                  child: TextField(
                    controller: _itemDiscountControllers[index],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) => _updateItemDiscount(index, v),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: R.sp(context, 11)),
                    decoration: const InputDecoration(
                      hintText: '0',
                      isDense: true,
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

  Widget _buildBottomSummaryArea() {
    return Container(
      padding: R.all(context, 16),
      decoration: const BoxDecoration(
        color: kWhite,
        border: Border(top: BorderSide(color: kGrey200)),
      ),
      child: Column(
        children: [
          _buildFinalSummary(),
          SizedBox(height: R.sp(context, 16)),
          SizedBox(
            width: double.infinity, height: R.sp(context, 54),
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _generateQuotation,
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, shape: RoundedRectangleBorder(borderRadius: R.radius(context, 12)), elevation: 0, disabledBackgroundColor: kPrimaryColor.withOpacity(0.6)),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _isProcessing
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: kWhite, strokeWidth: 2.5))
                    : Text(widget.editQuotationId != null ? 'Update Quotation' : 'Generate Quotation', style: TextStyle(color: kWhite, fontSize: R.sp(context, 15), fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleBtn(String label, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: R.sp(context, 8)),
          decoration: BoxDecoration(
            color: isSelected ? kPrimaryColor : Colors.transparent,
            borderRadius: R.radius(context, 8),
            border: Border.all(color: isSelected ? kPrimaryColor : kGrey200),
          ),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: isSelected ? kWhite : kBlack54, fontWeight: FontWeight.w700, fontSize: R.sp(context, 11))),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) => Padding(padding: EdgeInsets.only(bottom: R.sp(context, 6), left: R.sp(context, 4)), child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: R.sp(context, 12), color: kBlack87)));

  Widget _buildTextField(TextEditingController ctrl, String hint, Function(String) onChange, HeroIcons icon) {
    return SizedBox(
      height: R.sp(context, 48),
      child: ValueListenableBuilder<TextEditingValue>(
      valueListenable: ctrl,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextField(
        controller: ctrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: onChange,
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: R.sp(context, 14)),
        decoration: InputDecoration(
          hintText: hint, prefixIcon: Padding(
            padding: R.all(context, 12),
            child: HeroIcon(icon, color: kPrimaryColor, size: R.sp(context, 18)),
          ),
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
    ),
    );
  }

  Widget _buildSummaryRow(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: kBlack54, fontWeight: FontWeight.w600, fontSize: R.sp(context, 13))),
        Text('$_currencySymbol${amount.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: R.sp(context, 15), color: kBlack87)),
      ],
    );
  }

  Widget _buildFinalSummary() {
    // Calculate tax information from cart items — multi-tax support
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
    final totalTax = taxMap.values.fold(0.0, (a, b) => a + b);

    // Calculate subtotal (without tax) and total with tax
    final subtotalAmount = widget.cartItems.fold(0.0, (sum, item) {
      if (item.taxType == 'Tax Included in Price' || item.taxType == 'Price includes Tax') {
        return sum + (item.basePrice * item.quantity);
      } else {
        return sum + item.total;
      }
    });
    final totalWithTax = widget.cartItems.fold(0.0, (sum, item) => sum + item.totalWithTax);
    final finalTotal = totalWithTax - _discountAmount;

    final perc = _discountPercentage;
    return Column(
      children: [
        // Subtotal
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Subtotal', style: TextStyle(fontWeight: FontWeight.w600, color: kBlack54, fontSize: R.sp(context, 13))),
            Text('$_currencySymbol${subtotalAmount.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: R.sp(context, 14), color: kBlack87))
          ]
        ),
        SizedBox(height: R.sp(context, 8)),

        // Tax lines (individual breakdowns)
        if (totalTax > 0) ...[
          ...taxMap.entries.map((entry) => Padding(
            padding: EdgeInsets.only(bottom: R.sp(context, 4)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(entry.key, style: TextStyle(fontWeight: FontWeight.w600, color: kBlack54, fontSize: R.sp(context, 13))),
                Text('$_currencySymbol${entry.value.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: R.sp(context, 14), color: kBlack87))
              ]
            ),
          )),
          SizedBox(height: R.sp(context, 4)),
        ],

        // Discount
        if (_discountAmount > 0) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Discount (${perc.toStringAsFixed(1)}%)', style: TextStyle(fontWeight: FontWeight.w600, color: kBlack54, fontSize: R.sp(context, 13))),
              Text('- $_currencySymbol${_discountAmount.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.w700, color: kErrorColor, fontSize: R.sp(context, 14)))
            ]
          ),
          SizedBox(height: R.sp(context, 8)),
        ],

        Divider(color: kGrey200, height: R.sp(context, 16)),

        // Net Total
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Net Total', style: TextStyle(fontWeight: FontWeight.w800, fontSize: R.sp(context, 16), color: kBlack87)),
            Text('$_currencySymbol${finalTotal.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: R.sp(context, 20), color: kPrimaryColor))
          ]
        ),
      ],
    );
  }
}

