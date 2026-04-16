import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:intl/intl.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/Sales/components/common_widgets.dart';
import 'package:maxbillup/utils/plan_permission_helper.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:maxbillup/Colors.dart';
import 'package:maxbillup/components/app_mini_switch.dart';
import '../../../StockSphere/MaxBillUp/lib/utils/responsive_helper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'dart:convert';

class PaymentReceiptPage extends StatefulWidget {
  final String receiptNumber;
  final DateTime dateTime;
  final String businessName;
  final String businessLocation;
  final String businessPhone;
  final String? businessGSTIN;
  final String customerName;
  final String customerPhone;
  final double previousCredit;
  final double receivedAmount;
  final String paymentMode;
  final double currentCredit;
  final String? invoiceReference;
  final String currency;
  final bool isManualCredit;

  const PaymentReceiptPage({
    super.key,
    required this.receiptNumber,
    required this.dateTime,
    required this.businessName,
    required this.businessLocation,
    required this.businessPhone,
    this.businessGSTIN,
    required this.customerName,
    required this.customerPhone,
    required this.previousCredit,
    required this.receivedAmount,
    required this.paymentMode,
    required this.currentCredit,
    this.invoiceReference,
    required this.currency,
    this.isManualCredit = false,
  });

  @override
  State<PaymentReceiptPage> createState() => _PaymentReceiptPageState();
}

class _PaymentReceiptPageState extends State<PaymentReceiptPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── Settings (same as Invoice.dart) ──────────────
  bool _showBusinessLocation = true;
  bool _showBusinessPhone = true;
  bool _showBusinessGSTIN = true;
  bool _showCustomerPhone = true;
  bool _showPaymentMode = true;
  bool _showInvoiceReference = true;
  String _footerText = 'Thank You';
  bool _isPaidPlan = true; // default true — avoids flash of watermark

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPlanStatus();
  }

  Future<void> _loadPlanStatus() async {
    final canRemove = await PlanPermissionHelper.canRemoveWatermark();
    if (mounted) setState(() => _isPaidPlan = canRemove);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showReceiptSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Sheet header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: kPrimaryColor,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long_rounded, color: kWhite, size: 22),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('Receipt Settings',
                            style: TextStyle(
                                color: kWhite, fontSize: 16,
                                fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: kWhite),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _sheetSectionLabel('Header Info'),
                      _sheetTile('Business Location', _showBusinessLocation, (v) {
                        setState(() => _showBusinessLocation = v);
                        setModalState(() => _showBusinessLocation = v);
                      }),
                      _sheetTile('Phone Number', _showBusinessPhone, (v) {
                        setState(() => _showBusinessPhone = v);
                        setModalState(() => _showBusinessPhone = v);
                      }),
                      _sheetTile('GST / Tax Number', _showBusinessGSTIN, (v) {
                        setState(() => _showBusinessGSTIN = v);
                        setModalState(() => _showBusinessGSTIN = v);
                      }),
                      const SizedBox(height: 16),
                      _sheetSectionLabel('Receipt Details'),
                      _sheetTile('Customer Phone', _showCustomerPhone, (v) {
                        setState(() => _showCustomerPhone = v);
                        setModalState(() => _showCustomerPhone = v);
                      }),
                      _sheetTile('Payment Mode', _showPaymentMode, (v) {
                        setState(() => _showPaymentMode = v);
                        setModalState(() => _showPaymentMode = v);
                      }),
                      _sheetTile('Invoice Reference', _showInvoiceReference, (v) {
                        setState(() => _showInvoiceReference = v);
                        setModalState(() => _showInvoiceReference = v);
                      }),
                      const SizedBox(height: 16),
                      _sheetSectionLabel('Footer'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: kGreyBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kGrey200),
                        ),
                        child: TextField(
                          controller: TextEditingController(text: _footerText)
                            ..selection = TextSelection.collapsed(offset: _footerText.length),
                          onChanged: (v) {
                            _footerText = v;
                            setState(() {});
                          },
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Thank You',
                            hintStyle: TextStyle(color: kGrey400),
                            isDense: true,
                          ),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kBlack87),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimaryColor,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Done',
                              style: TextStyle(fontSize: 14, color: kWhite, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sheetSectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 4),
        child: Text(text,
            style: const TextStyle(
                fontSize: 10, fontWeight: FontWeight.w900,
                color: kBlack54, letterSpacing: 1.0)),
      );

  Widget _sheetTile(String title, bool value, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGrey200),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kBlack87)),
        trailing: AppMiniSwitch(value: value, onChanged: onChanged),
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Payment Receipt',
          style: TextStyle(
              color: kWhite, fontWeight: FontWeight.w700,
              fontSize: 16, fontFamily: 'NotoSans'),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kWhite, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: kWhite, size: 22),
            onPressed: _showReceiptSettings,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Container(
            decoration: const BoxDecoration(
              color: kPrimaryColor,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              height: 48,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: kGreyBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kGrey200),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: kPrimaryColor,
                ),
                dividerColor: Colors.transparent,
                labelColor: kWhite,
                unselectedLabelColor: kBlack54,
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5),
                tabs: const [
                  Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.print_rounded, size: 16),
                    SizedBox(width: 8),
                    Text('Thermal'),
                  ])),
                  Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.picture_as_pdf_rounded, size: 16),
                    SizedBox(width: 8),
                    Text('A4 / PDF'),
                  ])),
                ],
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          LayoutBuilder(builder: (context, _) => SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(R.paddingH(context), 16, R.paddingH(context), 40),
            child: _buildThermalPreview(),
          )),
          LayoutBuilder(builder: (context, _) => SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(R.paddingH(context), 16, R.paddingH(context), 40),
            child: _buildA4Preview(),
          )),
        ],
      ),
      bottomNavigationBar: _buildBottomActionBar(),
    );
  }

  // ── THERMAL PREVIEW (paper-style) ────────────────
  Widget _buildThermalPreview() {
    final dateStr = DateFormat('dd-MM-yyyy').format(widget.dateTime);
    final timeStr = DateFormat('hh:mm a').format(widget.dateTime);

    TextStyle tStyle({double size = 11, FontWeight weight = FontWeight.normal, Color color = kBlack87}) =>
        TextStyle(fontSize: size, fontWeight: weight, color: color, fontFamily: 'NotoSans');

    // Two-column row with Expanded widgets to prevent overflow
    Widget twoCol(String label, String value, {bool bold = false, double labelSize = 11, double valueSize = 11}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Text(label, style: tStyle(size: labelSize, weight: bold ? FontWeight.w700 : FontWeight.w500)),
            ),
            Expanded(
              flex: 4,
              child: Text(value, style: tStyle(size: valueSize, weight: bold ? FontWeight.w800 : FontWeight.w600), textAlign: TextAlign.right),
            ),
          ],
        ),
      );
    }

    Widget thickLine() => Container(margin: const EdgeInsets.symmetric(vertical: 6), height: 1.5, color: kBlack87);
    Widget thinLine() => Container(margin: const EdgeInsets.symmetric(vertical: 5), height: 0.8, color: kBlack54);

    return Center(
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: kBlack87, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Business Name ──
            Text(widget.businessName, style: tStyle(size: 17, weight: FontWeight.w900), textAlign: TextAlign.center),
            if (_showBusinessLocation && widget.businessLocation.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(widget.businessLocation, style: tStyle(size: 11), textAlign: TextAlign.center),
            ],
            if (_showBusinessPhone && widget.businessPhone.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text('Tel: ${widget.businessPhone}', style: tStyle(size: 11), textAlign: TextAlign.center),
            ],
            if (_showBusinessGSTIN && widget.businessGSTIN != null && widget.businessGSTIN!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(widget.businessGSTIN!, style: tStyle(size: 11, weight: FontWeight.w600), textAlign: TextAlign.center),
            ],

            thickLine(),

            // ── Title ──
            Text('Payment Receipt', style: tStyle(size: 14, weight: FontWeight.w900), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text('#${widget.receiptNumber}', style: tStyle(size: 13, weight: FontWeight.w900), textAlign: TextAlign.center),

            thickLine(),

            // ── Date & Receipt No ──
            twoCol('Date:', '$dateStr  $timeStr'),

            thinLine(),

            // ── Received From ──
            Text('Received From', style: tStyle(size: 11, weight: FontWeight.w800)),
            const SizedBox(height: 4),
            Align(alignment: Alignment.centerLeft, child: Text(widget.customerName, style: tStyle(size: 11, weight: FontWeight.w600))),
            if (_showCustomerPhone)
              Align(alignment: Alignment.centerLeft, child: Text('Contact: ${widget.customerPhone}', style: tStyle(size: 10, color: kBlack54))),

            thinLine(),

            // ── Credit Details ──
            twoCol('Previous Credit', '${widget.currency}${widget.previousCredit.toStringAsFixed(2)}'),
            const SizedBox(height: 2),
            twoCol(widget.isManualCredit ? 'Amount Given' : 'Received', '${widget.currency}${widget.receivedAmount.toStringAsFixed(2)}', bold: true),
            if (_showPaymentMode) ...[
              const SizedBox(height: 2),
              twoCol('Payment Mode', widget.paymentMode),
            ],

            thickLine(),

            // ── Current Credit ──
            twoCol('Balance Amount', '${widget.currency}${widget.currentCredit.toStringAsFixed(2)}', bold: true, labelSize: 13, valueSize: 13),

            thickLine(),

            // ── Invoice Reference ──
            if (_showInvoiceReference && widget.invoiceReference != null && widget.invoiceReference!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('For Invoice: ${widget.invoiceReference}', style: tStyle(size: 10, color: kBlack54).copyWith(fontStyle: FontStyle.italic), textAlign: TextAlign.center),
            ],

            const SizedBox(height: 10),

            // ── Footer ──
            Text(_footerText.isNotEmpty ? _footerText : 'Thank You', style: tStyle(size: 13, weight: FontWeight.w700), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _thermalRow(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: kBlack87,
                fontFamily: 'NotoSans')),
        Text(value,
            style: TextStyle(
                fontSize: 11,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: kBlack87,
                fontFamily: 'NotoSans')),
      ],
    );
  }

  // ── A4 PREVIEW ───────────────────────────────────
  Widget _buildA4Preview() {
    final dateStr = DateFormat('dd/MM/yyyy hh:mm a').format(widget.dateTime);

    return Center(
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kGrey200),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top accent strip — always visible at very top
            Container(
              width: double.infinity,
              height: 4,
              color: kPrimaryColor,
            ),

            // Header — white bg, bottom divider, dark text
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: kWhite,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.businessName,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w900,
                                color: kBlack87, fontFamily: 'NotoSans')),
                        if (_showBusinessLocation && widget.businessLocation.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(widget.businessLocation,
                              style: const TextStyle(
                                  fontSize: 11, color: kBlack54, fontFamily: 'NotoSans')),
                        ],
                        if (_showBusinessPhone && widget.businessPhone.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text('Tel: ${widget.businessPhone}',
                              style: const TextStyle(
                                  fontSize: 11, color: kBlack54, fontFamily: 'NotoSans')),
                        ],
                        if (_showBusinessGSTIN && widget.businessGSTIN != null &&
                            widget.businessGSTIN!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text('${widget.businessGSTIN}',
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w700,
                                  color: kBlack87, fontFamily: 'NotoSans')),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: kPrimaryColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Payment Receipt',
                            style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w900,
                                color: kWhite, fontFamily: 'NotoSans')),
                      ),
                      const SizedBox(height: 6),
                      Text('#${widget.receiptNumber}',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w900,
                              color: kBlack87, fontFamily: 'NotoSans')),
                      const SizedBox(height: 2),
                      Text(dateStr,
                          style: const TextStyle(
                              fontSize: 10, color: kBlack54, fontFamily: 'NotoSans')),
                    ],
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Received From box — plain grey
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Received From',
                            style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.w900,
                                color: kBlack54, letterSpacing: 1.2,
                                fontFamily: 'NotoSans')),
                        const SizedBox(height: 6),
                        Text(widget.customerName,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w900,
                                color: kBlack87, fontFamily: 'NotoSans')),
                        if (_showCustomerPhone) ...[
                          const SizedBox(height: 2),
                          Text('Contact: ${widget.customerPhone}',
                              style: const TextStyle(
                                  fontSize: 12, color: kBlack54,
                                  fontFamily: 'NotoSans')),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Payment details table
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      children: [
                        // Table header — keep theme colour here (perfect per user)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: const BoxDecoration(
                            color: kPrimaryColor,
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(8)),
                          ),
                          child: const Row(
                            children: [
                              Expanded(
                                child: Text('Payment Details',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        color: kWhite,
                                        fontFamily: 'NotoSans')),
                              ),
                              Text('Amount',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: kWhite,
                                      fontFamily: 'NotoSans')),
                            ],
                          ),
                        ),
                        _a4Row('Previous Credit',
                            '${widget.currency}${widget.previousCredit.toStringAsFixed(2)}',
                            isAlt: false),
                        _a4Row(widget.isManualCredit ? 'Amount Given' : 'Amount Received',
                            '${widget.currency}${widget.receivedAmount.toStringAsFixed(2)}',
                            isBold: true),
                        if (_showPaymentMode)
                          _a4Row('Payment Mode', widget.paymentMode, isAlt: true),
                        Container(height: 1, color: const Color(0xFFE5E7EB)),
                        _a4Row('Current Credit Balance',
                            '${widget.currency}${widget.currentCredit.toStringAsFixed(2)}',
                            isBold: true, isLarge: true),
                      ],
                    ),
                  ),

                  // Invoice reference — plain grey
                  if (_showInvoiceReference && widget.invoiceReference != null &&
                      widget.invoiceReference!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.receipt_long_outlined,
                              size: 16, color: kBlack54),
                          const SizedBox(width: 8),
                          Text('For Invoice: ${widget.invoiceReference}',
                              style: const TextStyle(
                                  fontSize: 12, fontStyle: FontStyle.italic,
                                  color: kBlack87, fontFamily: 'NotoSans')),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Footer — light grey bg, dark text, left accent border
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(6),
                      border: const Border(left: BorderSide(color: kPrimaryColor, width: 4)),
                    ),
                    child: Column(
                      children: [
                        Text(_footerText.isNotEmpty ? _footerText : 'Thank You',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700,
                                color: kBlack87, fontFamily: 'NotoSans')),
                        const SizedBox(height: 4),
                        const Text('www.maxmybill.com',
                            style: TextStyle(
                                fontSize: 9, color: kBlack54,
                                fontFamily: 'NotoSans')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _a4Row(String label, String value,
      {bool isAlt = false, bool isBold = false, bool isLarge = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: isAlt ? const Color(0xFFF7F8FA) : kWhite,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: isLarge ? 13 : 12,
                  fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
                  color: kBlack87,
                  fontFamily: 'NotoSans')),
          Text(value,
              style: TextStyle(
                  fontSize: isLarge ? 14 : 12,
                  fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
                  color: kBlack87,
                  fontFamily: 'NotoSans')),
        ],
      ),
    );
  }

  // ── BOTTOM ACTION BAR (same style as Invoice.dart) ─
  Widget _buildBottomActionBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: kWhite,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, -5)),
          ],
        ),
        child: Row(
          children: [
            _buildBtn(Icons.print_rounded, 'Print',
                () => _handleThermalPrint(context), true),
            const SizedBox(width: 12),
            _buildBtn(Icons.picture_as_pdf_rounded, 'A4 / PDF',
                () => _handleA4Print(context), true),
            const SizedBox(width: 12),
            _buildBtn(Icons.share_rounded, 'Share',
                () => _handleShare(context), false),
          ],
        ),
      ),
    );
  }

  Widget _buildBtn(
      IconData icon, String label, VoidCallback onTap, bool isSec) {
    return Expanded(
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: isSec ? kWhite : kPrimaryColor,
          foregroundColor: isSec ? kPrimaryColor : kWhite,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isSec
                ? const BorderSide(color: kPrimaryColor, width: 1.5)
                : BorderSide.none,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  // ── THERMAL PRINT ─────────────────────────────────
  Future<void> _handleThermalPrint(BuildContext context) async {
    try {
      BluetoothAdapterState adapterState =
          await FlutterBluePlus.adapterState.first;
      if (adapterState == BluetoothAdapterState.off && Platform.isAndroid) {
        try {
          await FlutterBluePlus.turnOn();
          await Future.delayed(const Duration(seconds: 1));
          adapterState = await FlutterBluePlus.adapterState.first;
        } catch (_) {}
      }
      if (adapterState != BluetoothAdapterState.on) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              title: const Text('Bluetooth Required',
                  style: TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 16)),
              content: const Text(
                  'Bluetooth is currently disabled. Please enable it to connect your printer.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('OK',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: kPrimaryColor))),
              ],
            ),
          );
        }
        return;
      }

      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircularProgressIndicator(color: kPrimaryColor),
                  SizedBox(height: 16),
                  Text('PRINTING...',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: kPrimaryColor)),
                ]),
              ),
            ),
          ),
        );
      }

      final prefs = await SharedPreferences.getInstance();
      final selectedPrinterId = prefs.getString('selected_printer_id');
      final printerWidth = prefs.getString('printer_width') ?? '58mm';
      final int lineWidth = printerWidth == '80mm' ? 48 : 42;

      int numberOfCopies = 1;
      try {
        final storeDoc = await FirestoreService().getCurrentStoreDoc();
        if (storeDoc != null && storeDoc.exists) {
          final data = storeDoc.data() as Map<String, dynamic>?;
          numberOfCopies = data?['thermalNumberOfCopies'] ?? 1;
        }
      } catch (_) {}

      if (selectedPrinterId == null) {
        if (context.mounted) Navigator.pop(context);
        if (context.mounted)
          CommonWidgets.showSnackBar(context, 'No printer configured',
              bgColor: kOrange);
        return;
      }

      final devices = await FlutterBluePlus.bondedDevices;
      final device = devices.firstWhere(
        (d) => d.remoteId.toString() == selectedPrinterId,
        orElse: () => throw Exception('Printer not found'),
      );
      if (!device.isConnected) {
        await device.connect(timeout: const Duration(seconds: 10));
        await Future.delayed(const Duration(milliseconds: 500));
      }

      final bytes = _buildThermalBytes(lineWidth);

      final services = await device.discoverServices();
      BluetoothCharacteristic? writeChar;
      for (var s in services) {
        for (var c in s.characteristics) {
          if (c.properties.write) {
            writeChar = c;
            break;
          }
        }
        if (writeChar != null) break;
      }

      if (writeChar != null) {
        for (int copy = 0; copy < numberOfCopies; copy++) {
          const chunk = 20;
          for (int i = 0; i < bytes.length; i += chunk) {
            final end =
                (i + chunk < bytes.length) ? i + chunk : bytes.length;
            await writeChar.write(bytes.sublist(i, end),
                withoutResponse: true);
            await Future.delayed(const Duration(milliseconds: 20));
          }
          if (copy < numberOfCopies - 1) {
            await Future.delayed(const Duration(milliseconds: 500));
          }
        }
      }

      if (context.mounted) Navigator.pop(context);
      if (context.mounted)
        CommonWidgets.showSnackBar(
          context,
          numberOfCopies > 1
              ? '$numberOfCopies copies printed!'
              : 'Receipt printed successfully',
          bgColor: kGoogleGreen,
        );
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted)
        CommonWidgets.showSnackBar(context, 'Printing failed: $e',
            bgColor: kErrorColor);
    }
  }

  /// Convert string to thermal-printer-safe ASCII —
  /// replaces Unicode currency symbols and other multi-byte chars so
  /// ESC/POS printers (CP437 / CP850) render them correctly.
  String _toThermalSafe(String text) {
    return text
        .replaceAll('₹', 'Rs.')
        .replaceAll('€', 'EUR')
        .replaceAll('£', 'GBP')
        .replaceAll('¥', 'Jpy')
        .replaceAll('₩', 'Krw')
        .replaceAll('₪', 'Ils')
        .replaceAll('₺', 'Try')
        .replaceAll('₴', 'Uah')
        .replaceAll('₸', 'Kzt')
        .replaceAll('₮', 'Mnt')
        .replaceAll('₭', 'Lak')
        .replaceAll('₱', 'Php')
        .replaceAll('₦', 'Ngn')
        .replaceAll('₡', 'Crc')
        .replaceAll('₲', 'Pyg')
        .replaceAll('₼', 'Azn')
        .replaceAll('₾', 'Gel')
        .replaceAll('₽', 'Rub')
        .replaceAll('฿', 'Thb')
        .replaceAll('﷼', 'Sar')
        .replaceAll('₨', 'Rs.')
        .replaceAll('৳', 'Bdt')
        .replaceAll('₫', 'Vnd')
        .replaceAll('₵', 'Ghs')
        // Strip any remaining non-ASCII chars (codepoint > 127)
        .replaceAll(RegExp(r'[^\x00-\x7F]'), '?');
  }

  List<int> _buildThermalBytes(int lineWidth) {
    final dateStr = DateFormat('dd-MM-yyyy hh:mm a').format(widget.dateTime);
    final divider = '=' * lineWidth;
    final thin = '-' * lineWidth;
    const esc = 0x1B;
    const gs = 0x1D;
    const lf = 0x0A;
    List<int> bytes = [];

    // Safe encoder — converts Unicode symbols to ASCII before encoding
    List<int> enc(String s) => utf8.encode(_toThermalSafe(s));
    // Thermal-safe currency (e.g. "Rs." for ₹)
    final tCur = _toThermalSafe(widget.currency).trim();

    bytes.addAll([esc, 0x40]); // init printer
    // Font A for 80mm (large, clear), Font B for 58mm (smaller, more chars fit)
    bytes.addAll([esc, 0x4D, lineWidth == 48 ? 0x00 : 0x01]);
    // For 58mm: set character size to 1x1 (smallest) using GS ! command
    if (lineWidth != 48) {
      bytes.addAll([gs, 0x21, 0x00]); // GS ! 0x00 = 1x width, 1x height (minimum size)
    }

    // ── HEADER (center) ──────────────────────────────
    bytes.addAll([esc, 0x61, 0x01]); // center
    // 80mm: double-height+bold (0x30) | 58mm: just bold (0x08)
    bytes.addAll([esc, 0x21, lineWidth == 48 ? 0x30 : 0x08]);
    bytes.addAll(enc(_trunc(widget.businessName, lineWidth ~/ (lineWidth == 48 ? 2 : 1))));
    bytes.add(lf);
    bytes.addAll([esc, 0x21, 0x00]); // normal

    if (_showBusinessLocation && widget.businessLocation.isNotEmpty) {
      for (final line in _wrapLine(widget.businessLocation, lineWidth)) {
        bytes.addAll(enc(line));
        bytes.add(lf);
      }
    }
    if (_showBusinessPhone && widget.businessPhone.isNotEmpty) {
      bytes.addAll(enc('Tel: ${widget.businessPhone}'));
      bytes.add(lf);
    }
    if (_showBusinessGSTIN && widget.businessGSTIN != null && widget.businessGSTIN!.isNotEmpty) {
      bytes.addAll([esc, 0x21, 0x08]); // bold
      bytes.addAll(enc(_toThermalSafe(widget.businessGSTIN!)));
      bytes.addAll([esc, 0x21, 0x00]);
      bytes.add(lf);
    }
    bytes.add(lf);

    // ── TITLE ────────────────────────────────────────
    bytes.addAll([esc, 0x61, 0x01]);
    // 80mm: double-height+bold (0x18) | 58mm: just bold (0x08)
    bytes.addAll([esc, 0x21, lineWidth == 48 ? 0x18 : 0x08]);
    bytes.addAll(enc('Payment Receipt'));
    bytes.addAll([esc, 0x21, 0x00]);
    bytes.add(lf);
    bytes.addAll(enc(divider));
    bytes.add(lf);

    // ── DATE & RECEIPT NO ────────────────────────────
    bytes.addAll([esc, 0x61, 0x00]); // left
    bytes.addAll(enc(_twoCols('Date:', dateStr, lineWidth)));
    bytes.add(lf);
    bytes.addAll(enc(_twoCols('Receipt No:', widget.receiptNumber, lineWidth)));
    bytes.add(lf);
    bytes.addAll(enc(thin));
    bytes.add(lf);

    // ── RECEIVED FROM ────────────────────────────────
    bytes.addAll([esc, 0x61, 0x01]);
    bytes.addAll([esc, 0x21, 0x08]); // bold
    bytes.addAll(enc('Received From'));
    bytes.addAll([esc, 0x21, 0x00]);
    bytes.add(lf);
    bytes.addAll([esc, 0x61, 0x00]);
    for (final line in _wrapLine(widget.customerName, lineWidth)) {
      bytes.addAll(enc(line));
      bytes.add(lf);
    }
    if (_showCustomerPhone) {
      for (final line in _wrapLine('Contact: ${widget.customerPhone}', lineWidth)) {
        bytes.addAll(enc(line));
        bytes.add(lf);
      }
    }
    bytes.addAll(enc(thin));
    bytes.add(lf);

    // ── CREDIT DETAILS ───────────────────────────────
    bytes.addAll(enc(_twoCols('Previous Credit',
        '$tCur ${widget.previousCredit.toStringAsFixed(2)}', lineWidth)));
    bytes.add(lf);

    bytes.addAll([esc, 0x21, 0x08]); // bold
    bytes.addAll(enc(_twoCols(
        widget.isManualCredit ? 'Amount Given' : 'Received',
        '$tCur ${widget.receivedAmount.toStringAsFixed(2)}', lineWidth)));
    bytes.addAll([esc, 0x21, 0x00]);
    bytes.add(lf);

    if (_showPaymentMode) {
      bytes.addAll(enc(_twoCols('Payment Mode', widget.paymentMode, lineWidth)));
      bytes.add(lf);
    }

    bytes.addAll(enc(divider));
    bytes.add(lf);

    // ── CURRENT CREDIT ───────────────────────────────
    // 80mm: double-height+bold (0x18) | 58mm: just bold (0x08)
    bytes.addAll([esc, 0x21, lineWidth == 48 ? 0x18 : 0x08]);
    bytes.addAll(enc(_twoCols('Balance Amount',
        '$tCur ${widget.currentCredit.toStringAsFixed(2)}', lineWidth)));
    bytes.addAll([esc, 0x21, 0x00]);
    bytes.add(lf);
    bytes.addAll(enc(divider));
    bytes.add(lf);

    // ── INVOICE REFERENCE ────────────────────────────
    if (_showInvoiceReference && widget.invoiceReference != null &&
        widget.invoiceReference!.isNotEmpty) {
      bytes.add(lf);
      bytes.addAll([esc, 0x61, 0x01]);
      for (final line in _wrapLine('For Invoice: ${widget.invoiceReference}', lineWidth)) {
        bytes.addAll(enc(line));
        bytes.add(lf);
      }
      bytes.addAll([esc, 0x61, 0x00]);
    }

    // ── FOOTER ───────────────────────────────────────
    bytes.addAll([esc, 0x61, 0x01]);
    bytes.add(lf);
    bytes.addAll([esc, 0x21, 0x08]); // bold
    final footerStr = _footerText.isNotEmpty ? _footerText : 'Thank You';
    for (final line in _wrapLine(footerStr, lineWidth)) {
      bytes.addAll(enc(line));
      bytes.add(lf);
    }
    bytes.addAll([esc, 0x21, 0x00]);

    bytes.add(lf);
    bytes.add(lf);
    bytes.add(lf);
    bytes.addAll([gs, 0x56, 0x00]); // cut

    return bytes;
  }

  String _trunc(String t, int max) =>
      t.length <= max ? t : '${t.substring(0, max - 1)}.';

  /// Prints [left] left-aligned and [right] right-aligned on the same line.
  /// [right] is never truncated; [left] is truncated if needed to make room.
  String _twoCols(String left, String right, int width) {
    // Clamp right to width
    final safeRight = right.length > width ? right.substring(0, width) : right;
    final availLeft = width - safeRight.length - 1; // need at least 1 space

    if (availLeft <= 0) {
      return safeRight.padLeft(width);
    }

    final safeLeft = left.length > availLeft
        ? '${left.substring(0, availLeft - 1)}.'
        : left;

    final spaces = width - safeLeft.length - safeRight.length;
    return '$safeLeft${' ' * spaces}$safeRight';
  }

  /// Wrap a line of text at word boundaries to fit within maxWidth
  List<String> _wrapLine(String text, int maxWidth) {
    if (maxWidth <= 0) return [text];
    if (text.length <= maxWidth) return [text];

    List<String> lines = [];
    List<String> words = text.split(' ');
    String currentLine = '';

    for (String word in words) {
      if (currentLine.isEmpty) {
        if (word.length > maxWidth) {
          int start = 0;
          while (start < word.length) {
            int end = (start + maxWidth < word.length) ? start + maxWidth : word.length;
            lines.add(word.substring(start, end));
            start = end;
          }
        } else {
          currentLine = word;
        }
      } else if (currentLine.length + 1 + word.length <= maxWidth) {
        currentLine += ' $word';
      } else {
        lines.add(currentLine);
        if (word.length > maxWidth) {
          int start = 0;
          while (start < word.length) {
            int end = (start + maxWidth < word.length) ? start + maxWidth : word.length;
            lines.add(word.substring(start, end));
            start = end;
          }
          currentLine = '';
        } else {
          currentLine = word;
        }
      }
    }

    if (currentLine.isNotEmpty) {
      lines.add(currentLine);
    }

    return lines;
  }

  // ── A4 / PDF ──────────────────────────────────────
  Future<void> _handleA4Print(BuildContext context) async {
    try {
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircularProgressIndicator(color: kPrimaryColor),
                  SizedBox(height: 16),
                  Text('Generating PDF...',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ),
        );
      }

      final pdf = await _generateA4Pdf();
      final output = await getTemporaryDirectory();
      final file = File(
          '${output.path}/payment_receipt_${widget.receiptNumber}.pdf');
      await file.writeAsBytes(await pdf.save());

      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Payment Receipt #${widget.receiptNumber}',
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted)
        CommonWidgets.showSnackBar(context, 'Error generating PDF: $e',
            bgColor: kErrorColor);
    }
  }

  Future<pw.Document> _generateA4Pdf() async {
    final fontData = await rootBundle.load('fonts/NotoSans-Regular.ttf');
    final ttf = pw.Font.ttf(fontData);
    final fontBoldData = await rootBundle.load('fonts/NotoSans-Bold.ttf');
    final ttfBold = pw.Font.ttf(fontBoldData);

    final pdf = pw.Document();
    final dateStr = DateFormat('dd/MM/yyyy').format(widget.dateTime);
    final timeStr = DateFormat('hh:mm a').format(widget.dateTime);
    final primaryPdf = PdfColor.fromInt(kPrimaryColor.toARGB32());
    const greyBg = PdfColor.fromInt(0xFFF7F8FA);
    const pageMargin = pw.EdgeInsets.zero;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pageMargin,
        theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ── HEADER — white bg, top accent border ──
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  border: pw.Border(
                    top: pw.BorderSide(color: primaryPdf, width: 5),
                    bottom: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                  ),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    // Business info (left)
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(widget.businessName,
                              style: pw.TextStyle(
                                  font: ttfBold, fontSize: 22,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.black)),
                          if (_showBusinessLocation && widget.businessLocation.isNotEmpty) ...[
                            pw.SizedBox(height: 4),
                            pw.Text(widget.businessLocation,
                                style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                          ],
                          if (_showBusinessPhone && widget.businessPhone.isNotEmpty) ...[
                            pw.SizedBox(height: 2),
                            pw.Text('Tel: ${widget.businessPhone}',
                                style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                          ],
                          if (_showBusinessGSTIN && widget.businessGSTIN != null && widget.businessGSTIN!.isNotEmpty) ...[
                            pw.SizedBox(height: 2),
                            pw.Text('${widget.businessGSTIN}',
                                style: pw.TextStyle(font: ttfBold, fontSize: 11,
                                    fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                          ],
                        ],
                      ),
                    ),
                    // Receipt badge (right)
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: pw.BoxDecoration(
                              color: primaryPdf,
                              borderRadius: pw.BorderRadius.circular(4)),
                          child: pw.Text('Payment Receipt',
                              style: pw.TextStyle(
                                  font: ttfBold, color: PdfColors.white,
                                  fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text('#${widget.receiptNumber}',
                            style: pw.TextStyle(
                                font: ttfBold, fontSize: 14,
                                fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                        pw.SizedBox(height: 2),
                        pw.Text(dateStr,
                            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        pw.Text(timeStr,
                            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      ],
                    ),
                  ],
                ),
              ),

              // ── CONTENT AREA ──────────────────────────
              pw.Expanded(
                child: pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(40),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Received From — plain grey
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.all(16),
                        decoration: pw.BoxDecoration(
                            color: greyBg,
                            border: pw.Border.all(color: PdfColors.grey300),
                            borderRadius: pw.BorderRadius.circular(8)),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Received From',
                                style: pw.TextStyle(
                                    font: ttfBold, fontSize: 9,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.grey600,
                                    letterSpacing: 1.2)),
                            pw.SizedBox(height: 6),
                            pw.Text(widget.customerName,
                                style: pw.TextStyle(
                                    font: ttfBold, fontSize: 16,
                                    fontWeight: pw.FontWeight.bold)),
                            if (_showCustomerPhone) ...[
                              pw.SizedBox(height: 2),
                              pw.Text('Contact: ${widget.customerPhone}',
                                  style: pw.TextStyle(font: ttf, fontSize: 12, color: PdfColors.grey700)),
                            ],
                          ],
                        ),
                      ),

                      pw.SizedBox(height: 28),

                      // Payment details table
                      pw.Container(
                        width: double.infinity,
                        decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey300),
                            borderRadius: pw.BorderRadius.circular(8)),
                        child: pw.Column(
                          children: [
                            // Table header
                            pw.Container(
                              width: double.infinity,
                              padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              decoration: pw.BoxDecoration(
                                color: primaryPdf,
                                borderRadius: const pw.BorderRadius.only(
                                  topLeft: pw.Radius.circular(8),
                                  topRight: pw.Radius.circular(8),
                                ),
                              ),
                              child: pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text('Payment Details',
                                      style: pw.TextStyle(
                                          font: ttfBold, fontSize: 12,
                                          fontWeight: pw.FontWeight.bold,
                                          color: PdfColors.white)),
                                  pw.Text('Amount',
                                      style: pw.TextStyle(
                                          font: ttfBold, fontSize: 12,
                                          fontWeight: pw.FontWeight.bold,
                                          color: PdfColors.white)),
                                ],
                              ),
                            ),
                            _pdfFullRow('Previous Credit',
                                '${widget.currency}${widget.previousCredit.toStringAsFixed(2)}',
                                ttf, ttfBold, isAlt: false),
                            _pdfFullRow(widget.isManualCredit ? 'Amount Given' : 'Amount Received',
                                '${widget.currency}${widget.receivedAmount.toStringAsFixed(2)}',
                                ttf, ttfBold, isBold: true),
                            if (_showPaymentMode)
                              _pdfFullRow('Payment Mode', widget.paymentMode,
                                  ttf, ttfBold, isAlt: true),
                            pw.Container(height: 1, color: PdfColors.grey300),
                            _pdfFullRow('Current Credit Balance',
                                '${widget.currency}${widget.currentCredit.toStringAsFixed(2)}',
                                ttf, ttfBold, isBold: true, isLarge: true),
                          ],
                        ),
                      ),

                      if (_showInvoiceReference && widget.invoiceReference != null &&
                          widget.invoiceReference!.isNotEmpty) ...[
                        pw.SizedBox(height: 20),
                        pw.Container(
                          width: double.infinity,
                          padding: const pw.EdgeInsets.all(14),
                          decoration: pw.BoxDecoration(
                              color: greyBg,
                              border: pw.Border.all(color: PdfColors.grey300),
                              borderRadius: pw.BorderRadius.circular(8)),
                          child: pw.Row(
                            children: [
                              pw.Text('For Invoice:  ',
                                  style: pw.TextStyle(
                                      font: ttfBold, fontSize: 11,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColors.grey700)),
                              pw.Text(widget.invoiceReference!,
                                  style: pw.TextStyle(
                                      font: ttf, fontSize: 11,
                                      fontStyle: pw.FontStyle.italic,
                                      color: PdfColors.grey800)),
                            ],
                          ),
                        ),
                      ],

                      pw.Spacer(),

                      pw.SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // ── FOOTER — light grey, dark text, left accent ──
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFF7F8FA),
                  border: pw.Border(
                    top: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                    left: pw.BorderSide(color: primaryPdf, width: 5),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        _footerText.isNotEmpty ? _footerText : 'Thank You',
                        style: pw.TextStyle(font: ttfBold, fontSize: 13,
                            fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    if (!_isPaidPlan)
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('Generated by Maxmybill',
                              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                          pw.Text('www.maxmybill.com',
                              style: pw.TextStyle(font: ttfBold, fontSize: 8,
                                  fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  pw.Widget _pdfFullRow(String label, String value, pw.Font ttf, pw.Font ttfBold,
      {bool isAlt = false, bool isBold = false, bool isLarge = false}) {
    // Use plain grey for alt rows, white for everything else — no theme tint
    final bg = isAlt ? const PdfColor.fromInt(0xFFF7F8FA) : PdfColors.white;
    return pw.Container(
      color: bg,
      padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  font: isBold ? ttfBold : ttf,
                  fontSize: isLarge ? 13 : 11,
                  fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: PdfColors.black)),
          pw.Text(value,
              style: pw.TextStyle(
                  font: isBold ? ttfBold : ttf,
                  fontSize: isLarge ? 15 : 11,
                  fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: PdfColors.grey800)),
        ],
      ),
    );
  }

  // ── SHARE (text) ──────────────────────────────────
  Future<void> _handleShare(BuildContext context) async {
    final dateStr =
        DateFormat('dd-MM-yyyy hh:mm a').format(widget.dateTime);
    final text = '''
PAYMENT RECEIPT

Receipt No: ${widget.receiptNumber}
Date: $dateStr

${widget.businessName}
${widget.businessLocation}
Tel: ${widget.businessPhone}
${widget.businessGSTIN != null ? '${widget.businessGSTIN}' : ''}

Received From:
${widget.customerName}
Contact: ${widget.customerPhone}

Previous Credit: ${widget.currency}${widget.previousCredit.toStringAsFixed(2)}
${widget.isManualCredit ? 'Amount Given' : 'Received'}: ${widget.currency}${widget.receivedAmount.toStringAsFixed(2)}
Payment Mode: ${widget.paymentMode}
Balance Amount: ${widget.currency}${widget.currentCredit.toStringAsFixed(2)}

${widget.invoiceReference != null ? 'For Invoice: ${widget.invoiceReference}' : ''}

Thank You
''';
    await Share.share(text,
        subject: 'Payment Receipt - ${widget.receiptNumber}');
  }
}
