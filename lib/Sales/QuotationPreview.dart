import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'package:maxbillup/Sales/NewSale.dart';
import 'package:maxbillup/models/cart_item.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/Colors.dart';
import 'package:maxbillup/services/currency_service.dart';

class QuotationPreviewPage extends StatefulWidget {
  final String uid; final String? userEmail; final String quotationNumber; final List<CartItem> items;
  final double subtotal; final double discount; final double total;
  final String? customerName; final String? customerPhone; final String? staffName; final String? quotationDocId;
  final String currencySymbol;

  const QuotationPreviewPage({
    super.key, required this.uid, this.userEmail, required this.quotationNumber,
    required this.items, required this.subtotal, required this.discount, required this.total,
    this.customerName, this.customerPhone, this.staffName, this.quotationDocId, this.currencySymbol = '',
  });

  @override
  State<QuotationPreviewPage> createState() => _QuotationPreviewPageState();
}

class _QuotationPreviewPageState extends State<QuotationPreviewPage> {
  bool _isLoading = true;
  String businessName = 'Business', businessLocation = 'Location', businessPhone = '';

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    final storeDoc = await FirestoreService().getCurrentStoreDoc();
    if (storeDoc != null && storeDoc.exists) {
      final d = storeDoc.data() as Map<String, dynamic>?;
      businessName = d?['businessName'] ?? 'Business';
      businessLocation = d?['businessAddress'] ?? d?['location'] ?? 'Location';
      businessPhone = d?['businessPhone'] ?? '';
    }
    setState(() => _isLoading = false);
  }

  Future<void> _handleShare(BuildContext context) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      final pdf = pw.Document();
      pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a4, build: (pw.Context context) {
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text("Quotation", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF2F7CF6))),
          pw.SizedBox(height: 10),
          pw.Text("From: $businessName"),
          pw.Text("Client: ${widget.customerName ?? 'Guest'}"),
          pw.Divider(),
          pw.Text("Total Payable: ${widget.currencySymbol}${widget.total.toStringAsFixed(2)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
        ]);
      }));
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/QTN_${widget.quotationNumber}.pdf');
      await file.writeAsBytes(await pdf.save());
      Navigator.pop(context);
      await Share.shareXFiles([XFile(file.path)], subject: 'Quotation ${widget.quotationNumber}');
    } catch (e) { Navigator.pop(context); }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(backgroundColor: kWhite, body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        backgroundColor: kPrimaryColor, elevation: 0, centerTitle: true,
        title: const Text('Quotation Preview', style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
        leading: IconButton(icon: const Icon(Icons.close, color: kWhite), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), // Reduced padding
              child: Container(
                decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16), // Reduced padding
                      decoration: BoxDecoration(color: kPrimaryColor.withOpacity(0.03), borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Quotation ID", style: TextStyle(fontSize: 9, color: kBlack54, fontWeight: FontWeight.w700)), Text("${widget.quotationNumber}", style: const TextStyle(fontWeight: FontWeight.w900, color: kPrimaryColor, fontSize: 15))]),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: kGoogleGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: const Text("Draft", style: TextStyle(color: kGoogleGreen, fontSize: 9, fontWeight: FontWeight.w900))),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16), // Reduced from 20
                      child: Column(
                        children: [
                          _buildInfoSection("Issued By", businessName, businessLocation),
                          const Divider(height: 24, color: kGreyBg), // Reduced from 32
                          _buildInfoSection("Quoted To", widget.customerName ?? "Guest", widget.customerPhone ?? "--"),
                          const SizedBox(height: 16), // Reduced gap
                          Container(
                            decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(12)),
                            child: ListView.separated(
                              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                              itemCount: widget.items.length,
                              separatorBuilder: (c, i) => const Divider(height: 1, color: kGreyBg, indent: 12, endIndent: 12),
                              itemBuilder: (c, i) => ListTile(
                                  dense: true,
                                  title: Text(widget.items[i].name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  trailing: Text("${widget.currencySymbol}${widget.items[i].total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _summaryLine("Subtotal", widget.subtotal),
                          _summaryLine("Discounts", -widget.discount, color: kErrorColor),
                          const Divider(height: 24, thickness: 1.5, color: kGrey200),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Estimated Total", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)), Text("${widget.currencySymbol}${widget.total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: kGoogleGreen))]),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _buildBottomActions(context),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String label, String title, String subtitle) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kBlack54, letterSpacing: 0.5)), const SizedBox(height: 4), Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)), Text(subtitle, style: const TextStyle(fontSize: 11, color: kBlack54))]))]);

  Widget _summaryLine(String l, double v, {Color? color}) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(color: kBlack54, fontSize: 12, fontWeight: FontWeight.w500)), Text("${widget.currencySymbol}${v.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.w700, color: color ?? kBlack87, fontSize: 13))]));

  Widget _buildBottomActions(BuildContext context) => Container(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), decoration: BoxDecoration(color: kWhite, border: Border(top: BorderSide(color: kGrey200))), child: Row(children: [Expanded(child: OutlinedButton.icon(onPressed: () => _handleShare(context), icon: const Icon(Icons.share_rounded, size: 16), label: const Text("Share"), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: const BorderSide(color: kPrimaryColor), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))), const SizedBox(width: 10), Expanded(child: ElevatedButton(onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst), style: ElevatedButton.styleFrom(backgroundColor: kGoogleGreen, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0), child: const Text("Done", style: TextStyle(fontWeight: FontWeight.w700))))]));
}