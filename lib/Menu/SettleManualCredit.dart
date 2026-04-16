import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:heroicons/heroicons.dart';
import 'package:intl/intl.dart';
import 'package:maxbillup/Colors.dart';
import 'package:maxbillup/utils/amount_formatter.dart';
import 'package:maxbillup/services/currency_service.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:maxbillup/Receipts/PaymentReceiptPage.dart';
import 'package:maxbillup/utils/responsive_helper.dart';
import '../utils/ledger_helper.dart';

class SettleManualCreditPage extends StatefulWidget {
  final String customerId;
  final Map<String, dynamic> customerData;
  final double currentBalance;
  final String? invoiceNumber; // Optional for individual bill settlement
  final double? billAmount;     // Optional for individual bill settlement
  final String? creditDocId;   // Optional for individual bill settlement
  final String? receiptNumber; // Pre-generated receipt number from credit_sale

  const SettleManualCreditPage({
    super.key,
    required this.customerId,
    required this.customerData,
    required this.currentBalance,
    this.invoiceNumber,
    this.billAmount,
    this.creditDocId,
    this.receiptNumber,
  });

  @override
  State<SettleManualCreditPage> createState() => _SettleManualCreditPageState();
}

class _SettleManualCreditPageState extends State<SettleManualCreditPage> {
  late TextEditingController _amountController;
  String _paymentMode = 'Cash';
  bool _isReceivedChecked = true;
  double _enteredAmount = 0.0;
  String _currencySymbol = '₹';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: '0');
    _enteredAmount = 0.0;
    _amountController.addListener(() {
      final baseAmount = widget.billAmount ?? widget.currentBalance;
      double parsed = double.tryParse(_amountController.text) ?? 0.0;
      // Clamp: never allow more than the outstanding balance
      if (parsed > baseAmount) {
        parsed = baseAmount;
        _amountController.value = _amountController.value.copyWith(
          text: baseAmount.toStringAsFixed(2),
          selection: TextSelection.collapsed(offset: baseAmount.toStringAsFixed(2).length),
        );
      }
      setState(() { _enteredAmount = parsed; });
    });
    _loadCurrency();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _loadCurrency() async {
    final store = await FirestoreService().getCurrentStoreDoc();
    if (store != null && store.exists && mounted) {
      final data = store.data() as Map<String, dynamic>;
      setState(() => _currencySymbol = CurrencyService.getSymbolWithSpace(data['currency']));
    }
  }

  Future<void> _handleSettle() async {
    final baseAmount = widget.billAmount ?? widget.currentBalance;
    if (_enteredAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount'), backgroundColor: kErrorColor),
      );
      return;
    }
    if (_enteredAmount > baseAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Amount cannot exceed the balance of $_currencySymbol${baseAmount.toStringAsFixed(2)}'),
          backgroundColor: kErrorColor,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final firestoreService = FirestoreService();
      final creditsRef = await firestoreService.getStoreCollection('credits');
      final customersRef = await firestoreService.getStoreCollection('customers');
      final paymentReceiptsRef = await firestoreService.getStoreCollection('paymentReceipts');

      // 1. Generate/Use Payment Receipt Number
      // Use pre-stored receipt number from credit_sale if available
      String fullReceiptNumber;
      if (widget.receiptNumber != null && widget.receiptNumber!.isNotEmpty) {
        fullReceiptNumber = widget.receiptNumber!;
      } else {
        // Fetch prefix and number together from same doc to avoid race condition
        final storeDocForNumber = await FirestoreService().getCurrentStoreDoc(forceRefresh: true);
        String receiptPrefix = '';
        int receiptNumInt = 100001;
        if (storeDocForNumber != null && storeDocForNumber.exists) {
          final d = storeDocForNumber.data() as Map<String, dynamic>?;
          receiptPrefix = (d?['paymentReceiptPrefix'] ?? '').toString();
          receiptNumInt = int.tryParse((d?['nextPaymentReceiptNumber'] ?? 100001).toString()) ?? 100001;
          // Increment the counter for next time
          await storeDocForNumber.reference.update({'nextPaymentReceiptNumber': receiptNumInt + 1});
        }
        final receiptNum = receiptNumInt.toString();
        fullReceiptNumber = receiptPrefix.isNotEmpty
            ? '$receiptPrefix$receiptNum'
            : 'PR$receiptNum';
      }

      // 2. Add to credits collection (Settlement Record for Ledger)
      await creditsRef.add({
        'customerId': widget.customerId,
        'customerName': widget.customerData['name'] ?? 'Unknown',
        'amount': _enteredAmount,
        'type': 'settlement',
        'method': _paymentMode,
        'timestamp': FieldValue.serverTimestamp(),
        'date': DateTime.now().toIso8601String(),
        'note': widget.invoiceNumber != null 
            ? 'Settlement for Invoice #${widget.invoiceNumber}'
            : 'Manual credit settlement',
        if (widget.invoiceNumber != null) 'invoiceNumber': widget.invoiceNumber,
        if (widget.creditDocId != null) 'relatedCreditId': widget.creditDocId,
      });

      // 3. Create Payment Receipt Record
      await paymentReceiptsRef.add({
        'receiptNumber': fullReceiptNumber,
        'customerId': widget.customerId,
        'customerName': widget.customerData['name'] ?? 'Unknown',
        'amount': _enteredAmount,
        'paymentMethod': _paymentMode,
        'type': widget.invoiceNumber != null ? 'bill_settlement' : 'manual_settlement',
        if (widget.invoiceNumber != null) 'relatedInvoiceNumber': widget.invoiceNumber,
        if (widget.creditDocId != null) 'relatedCreditId': widget.creditDocId,
        'timestamp': FieldValue.serverTimestamp(),
        'date': DateTime.now().toIso8601String(),
        'note': widget.invoiceNumber != null 
            ? 'Payment received for Invoice #${widget.invoiceNumber}'
            : 'Manual credit settlement',
      });

      // 4. Update individual bill if applicable
      if (widget.creditDocId != null) {
        final creditDoc = await creditsRef.doc(widget.creditDocId).get();
        if (creditDoc.exists) {
          final data = creditDoc.data() as Map<String, dynamic>?;
          final currentAmount = (data?['amount'] ?? 0.0).toDouble();
          if (currentAmount <= _enteredAmount) {
            await creditsRef.doc(widget.creditDocId).update({
              'isSettled': true,
              'status': 'Settled',
              'settledAt': FieldValue.serverTimestamp(),
              'settledAmount': currentAmount,
              'settlementMethod': _paymentMode,
              'receiptNumber': fullReceiptNumber,
            });
          } else {
             await creditsRef.doc(widget.creditDocId).update({
              'amount': currentAmount - _enteredAmount,
              'partiallySettledAt': FieldValue.serverTimestamp(),
              'lastPartialAmount': _enteredAmount,
              'lastPartialMethod': _paymentMode,
              'receiptNumber': fullReceiptNumber,
            });
          }
        }
      }

      // 5. Update Customer Overall Balance
      final customerDoc = await customersRef.doc(widget.customerId).get();
      double customerPreviousBalance = 0.0;
      if (customerDoc.exists) {
        final data = customerDoc.data() as Map<String, dynamic>?;
        customerPreviousBalance = (data?['balance'] ?? 0.0).toDouble();
        await customersRef.doc(widget.customerId).update({
          'balance': customerPreviousBalance - _enteredAmount,
        });
      }

      // 6. Force sync ledger balance to Firestore
      await LedgerHelper.computeClosingBalance(widget.customerId, syncToFirestore: true);

      // Load store data for receipt page
      final storeDoc = await FirestoreService().getCurrentStoreDoc();
      final storeData = storeDoc?.data() as Map<String, dynamic>?;

      if (mounted) {
        setState(() => _isSaving= false);
        
        // Navigation: Use the specific bill/manual balance as 'previousCredit' for the receipt
        final double receiptPreviousCredit = widget.billAmount ?? widget.currentBalance;

        // Navigate to Payment Receipt Page
        Navigator.pushReplacement(
          context,
          CupertinoPageRoute(
            builder: (_) => PaymentReceiptPage(
              receiptNumber: fullReceiptNumber,
              dateTime: DateTime.now(),
              businessName: storeData?['businessName'] ?? '',
              businessLocation: storeData?['businessLocation'] ?? '',
              businessPhone: storeData?['businessPhone'] ?? '',
              businessGSTIN: storeData?['taxType'] ?? storeData?['gstin'],
              customerName: widget.customerData['name'] ?? 'Customer',
              customerPhone: widget.customerId,
              previousCredit: receiptPreviousCredit,
              receivedAmount: _enteredAmount,
              paymentMode: _paymentMode,
              currentCredit: receiptPreviousCredit - _enteredAmount,
              invoiceReference: widget.invoiceNumber,
              currency: _currencySymbol,
            ),
          ),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Balance settled successfully'), backgroundColor: kGoogleGreen),
        );
      }
    } catch (e) {
      debugPrint('Error settling balance: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: kErrorColor),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseAmount = widget.billAmount ?? widget.currentBalance;
    final double balanceDue = baseAmount - _enteredAmount;

    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(

        title: Text(
          widget.invoiceNumber != null ? 'Bill Settlement' : 'Manual Settlement',
          style: TextStyle(color: kWhite, fontWeight: FontWeight.w700,
              fontSize: R.adaptive(context, phone: 17.0, tablet: 19.0))
        ),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: kWhite),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final hPad = R.paddingH(context);
      return SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: R.maxContentWidth(context)),
        child: Column(
          children: [
            // Top Summary Backdrop
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(bottom: 24, left: hPad, right: hPad, top: 10),
              decoration: const BoxDecoration(
                color: kPrimaryColor,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  Text(
                    widget.customerData['name'] ?? 'Customer',
                    style: TextStyle(color: kWhite,
                        fontSize: R.sp(context, 13), fontWeight: FontWeight.w600, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$_currencySymbol${AmountFormatter.format(baseAmount)}',
                    style: TextStyle(color: kWhite,
                        fontSize: R.sp(context, 28), fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.invoiceNumber != null ? 'Invoice #${widget.invoiceNumber} Pending' : 'Total Manual Credit',
                    style: TextStyle(color: kWhite.withValues(alpha: 0.8),
                        fontSize: R.sp(context, 11), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

            Transform.translate(
              offset: const Offset(0, -20),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                child: Column(
                  children: [
                    // Amount Entry Card
                    _buildPremiumCard(
                      title: 'Received Amount',
                      icon: HeroIcons.banknotes,
                      iconColor: kGoogleGreen,
                      child: Column(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 4),
                            decoration: BoxDecoration(
                              color: kGreyBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: kGrey200),
                            ),
                            child: Row(
                              children: [
                                Text(_currencySymbol, style: TextStyle(
                                    fontSize: R.sp(context, 20),
                                    fontWeight: FontWeight.w900, color: kBlack87)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _amountController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: TextStyle(
                                        fontSize: R.sp(context, 22),
                                        fontWeight: FontWeight.w900, color: kPrimaryColor),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      hintText: '0',
                                      hintStyle: TextStyle(color: kGrey400),
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _amountController.text = baseAmount.toStringAsFixed(2),
                                  icon: const HeroIcon(HeroIcons.checkCircle, color: kPrimaryColor, size: 20),
                                  tooltip: 'Full Amount',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildQuickAmountBtn('Clear', () => _amountController.text = '0'),
                              _buildQuickAmountBtn('Pay Full', () => _amountController.text = baseAmount.toStringAsFixed(2)),
                              _buildQuickAmountBtn('Pay Half', () => _amountController.text = (baseAmount / 2).toStringAsFixed(2)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Payment Mode selection
                    _buildPremiumCard(
                      title: 'Payment Mode',
                      icon: HeroIcons.creditCard,
                      iconColor: kOrange,
                      child: Row(
                        children: [
                          _buildModernChip('Cash', HeroIcons.banknotes, _paymentMode == 'Cash'),
                          const SizedBox(width: 12),
                          _buildModernChip('Online', HeroIcons.globeAlt, _paymentMode == 'Online'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Summary Card
                    _buildPremiumCard(
                      title: 'Settlement Summary',
                      icon: HeroIcons.documentText,
                      iconColor: kPrimaryColor,
                      child: Column(
                        children: [
                          _buildSummaryRow('Previous Balance', baseAmount, color: kBlack87),
                          const SizedBox(height: 8),
                          _buildSummaryRow('Received Amount', _enteredAmount, color: kGoogleGreen, isNegative: true),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Divider(color: kGrey200),
                          ),
                          _buildSummaryRow('Remaining Due', balanceDue > 0 ? balanceDue : 0.0, color: kErrorColor, isBold: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
          ),
        ),
      );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kWhite,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _handleSettle,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: kWhite)
                  : const Text('Process Settlement', style: TextStyle(color: kWhite, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumCard({required String title, required HeroIcons icon, required Color iconColor, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kGrey200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 6, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: HeroIcon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: kBlack87)),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildModernChip(String label, HeroIcons icon, bool isSelected) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _paymentMode = label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? kPrimaryColor : kGreyBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isSelected ? kPrimaryColor : kGrey200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HeroIcon(icon, color: isSelected ? kWhite : kBlack54, size: 16),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: isSelected ? kWhite : kBlack54, fontWeight: FontWeight.w700, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {required Color color, bool isNegative = false, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: kBlack54, fontWeight: isBold ? FontWeight.w800 : FontWeight.w600)),
        Text(
          '${isNegative ? "- " : ""}$_currencySymbol${AmountFormatter.format(amount)}',
          style: TextStyle(fontSize: isBold ? 14 : 12, fontWeight: isBold ? FontWeight.w900 : FontWeight.w700, color: color),
        ),
      ],
    );
  }

  Widget _buildQuickAmountBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kGrey200),
        ),
        child: Text(label, style: const TextStyle(color: kBlack54, fontSize: 10, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
