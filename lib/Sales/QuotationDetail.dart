import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:maxbillup/Sales/Bill.dart';
import 'package:maxbillup/models/cart_item.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/Colors.dart';
import 'package:maxbillup/Sales/nq.dart' as maxbillup_nq;

class QuotationDetailPage extends StatefulWidget {
  final String uid;
  final String? userEmail;
  final String quotationId;
  final Map<String, dynamic> quotationData;
  final String currencySymbol;

  const QuotationDetailPage({
    super.key,
    required this.uid,
    this.userEmail,
    required this.quotationId,
    required this.quotationData,
    this.currencySymbol = '',
  });

  @override
  State<QuotationDetailPage> createState() => _QuotationDetailPageState();
}

class _QuotationDetailPageState extends State<QuotationDetailPage> {
  bool _isProcessing = false; // Prevents double-click on Convert/Delete buttons

  String get uid => widget.uid;
  String? get userEmail => widget.userEmail;
  String get quotationId => widget.quotationId;
  Map<String, dynamic> get quotationData => widget.quotationData;
  String get currencySymbol => widget.currencySymbol;

  @override
  Widget build(BuildContext context) {
    final quotationNumber = quotationData['quotationNumber'] ?? 'N/A';
    final customerName = quotationData['customerName'] ?? 'Guest';
    final staffName = quotationData['staffName'] ?? 'Staff';
    final timestamp = quotationData['timestamp'] as Timestamp?;
    final formattedDate = timestamp != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(timestamp.toDate())
        : 'N/A';
    final items = quotationData['items'] as List<dynamic>? ?? [];
    final total = (quotationData['total'] ?? 0.0).toDouble();
    final status = quotationData['status'] ?? 'active';
    final billed = quotationData['billed'] ?? false;

    final isActive = status == 'active' && billed != true;

    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        title: const Text('Quotation Details', style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: kWhite, size: 22), onPressed: () => Navigator.pop(context)),
        actions: [
          if (isActive)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: kWhite, size: 22),
              onPressed: () => _confirmDelete(context),
            ),
        ],
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: kGreyBg,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kWhite,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderRow('$quotationNumber', isActive),
                    const SizedBox(height: 12),
                    _buildDetailRow(Icons.person_rounded, 'Customer', customerName),
                    _buildDetailRow(Icons.badge_rounded, 'Created By', staffName),
                    _buildDetailRow(Icons.calendar_month_rounded, 'Date Issued', formattedDate),
                    _buildDetailRow(Icons.shopping_bag_rounded, 'Items Count', '${items.length} units'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              const Text('Items List', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: kBlack54, letterSpacing: 0.5)),
              const SizedBox(height: 10),
              ...items.map((item) {
                final name = item['name'] ?? 'Unknown Item';
                final qty = item['quantity'] ?? 1;
                final price = (item['price'] ?? 0.0).toDouble();
                final totalWithTax = (item['totalWithTax'] ?? item['total'] ?? 0.0).toDouble();
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kGrey200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kBlack87)),
                            const SizedBox(height: 4),
                            Text('$qty  x  $currencySymbol${price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kBlack54)),
                          ],
                        ),
                      ),
                      Text('$currencySymbol${totalWithTax.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: kPrimaryColor)),
                    ],
                  ),
                );
              }).toList(),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: kWhite,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
          border: const Border(top: BorderSide(color: kGrey200, width: 1)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Valuation Summary Section
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Column(
                  children: [
                    _buildPriceRow('Subtotal', (quotationData['subtotal'] ?? 0.0).toDouble()),
                    _buildPriceRow('Discount', -(quotationData['discount'] ?? 0.0).toDouble(), valueColor: kErrorColor),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1, color: kGrey200, thickness: 1),
                    ),
                    _buildPriceRow('Net Total', total, isBold: true),
                  ],
                ),
              ),
              // Action Buttons Section
              Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: isActive
                    ? Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: SizedBox(
                              height: 52,
                              child: OutlinedButton(
                                onPressed: () => _editQuotation(context),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: kPrimaryColor,
                                  side: const BorderSide(color: kPrimaryColor, width: 2),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: const Text('Edit', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _isProcessing ? null : () => _generateInvoice(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kPrimaryColor,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 0,
                                  disabledBackgroundColor: kPrimaryColor.withOpacity(0.6),
                                ),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: _isProcessing
                                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: kWhite, strokeWidth: 2))
                                      : const Text('Convert To Invoice', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: kWhite, letterSpacing: 0.5)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Container(
                        height: 54,
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(color: kGoogleGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.check_circle, color: kGoogleGreen, size: 22),
                            SizedBox(width: 10),
                            Text('Quotation Settled', style: TextStyle(fontSize: 15, color: kGoogleGreen, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderRow(String ref, bool active) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(ref, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kPrimaryColor)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: active ? kPrimaryColor.withOpacity(0.1) : kGreyBg, borderRadius: BorderRadius.circular(20)),
          child: Text(active ? 'Open' : 'Billed', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: active ? kPrimaryColor : kBlack54)),
        ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: kGrey400),
          const SizedBox(width: 12),
          Text('$label: ', style: const TextStyle(color: kBlack54, fontSize: 12, fontWeight: FontWeight.w500)),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: kBlack87), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, double val, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: isBold ? 14 : 13, fontWeight: isBold ? FontWeight.w700 : FontWeight.w500, color: isBold ? kBlack87 : kBlack54)),
          Text('$currencySymbol${val.toStringAsFixed(2)}', style: TextStyle(fontSize: isBold ? 20 : 14, fontWeight: FontWeight.w800, color: valueColor ?? (isBold ? kPrimaryColor : kBlack87))),
        ],
      ),
    );
  }

  void _generateInvoice(BuildContext context) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final items = quotationData['items'] as List<dynamic>? ?? [];
    final cartItems = items.map((item) => CartItem(
      productId: item['productId'] ?? '', name: item['name'] ?? '',
      price: (item['price'] ?? 0.0).toDouble(), quantity: item['quantity'] ?? 1,
    )).toList();

    final total = (quotationData['total'] ?? 0.0).toDouble();
    final discount = (quotationData['discount'] ?? 0.0).toDouble();

    try {
      final result = await Navigator.push(
        context, CupertinoPageRoute(builder: (context) => BillPage(
        uid: uid, userEmail: userEmail, cartItems: cartItems, totalAmount: total,
        discountAmount: discount, customerPhone: quotationData['customerPhone'],
        customerName: quotationData['customerName'], customerGST: quotationData['customerGST'],
        quotationId: quotationId,
      )),
      );

      if (result == true) {
        await FirestoreService().updateDocument('quotations', quotationId, {'status': 'settled', 'billed': true, 'settledAt': FieldValue.serverTimestamp()});
        if (context.mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order Finalized Successfully'))); Navigator.pop(context); }
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _editQuotation(BuildContext context) {
    Navigator.pushReplacement(
      context,
      CupertinoPageRoute(
        builder: (context) => maxbillup_nq.NewQuotationPage(
          uid: uid,
          userEmail: userEmail,
          editQuotationId: quotationId,
          initialQuotationData: quotationData,
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Delete Quotation', style: TextStyle(fontWeight: FontWeight.w900, color: kBlack87)),
        content: const Text('Are you sure you want to permanently delete this quotation?', style: TextStyle(color: kBlack54, fontWeight: FontWeight.w500)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: kBlack54, fontWeight: FontWeight.w800)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteQuotation(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: kErrorColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Delete', style: TextStyle(color: kWhite, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteQuotation(BuildContext context) async {
    try {
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: kPrimaryColor)));
      await FirestoreService().deleteDocument('quotations', quotationId);
      if (context.mounted) {
        Navigator.pop(context); // Pop loading
        Navigator.pop(context); // Pop detail page
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quotation Deleted Successfully'), backgroundColor: kErrorColor));
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Pop loading
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting: $e'), backgroundColor: kErrorColor));
      }
    }
  }
}