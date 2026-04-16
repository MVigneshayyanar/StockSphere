import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:maxbillup/Colors.dart';
import 'package:maxbillup/Sales/QuotationDetail.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/utils/responsive_helper.dart';
import 'package:maxbillup/services/currency_service.dart';
import 'nq.dart'; // Import for NewQuotationPage

class QuotationsListPage extends StatefulWidget {
  final String uid;
  final String? userEmail;
  final VoidCallback onBack;

  const QuotationsListPage({
    super.key,
    required this.uid,
    this.userEmail,
    required this.onBack,
  });

  @override
  State<QuotationsListPage> createState() => _QuotationsListPageState();
}

enum SortOption { dateNewest, dateOldest, amountHigh, amountLow }
enum FilterStatus { all, available, settled }

class _QuotationsListPageState extends State<QuotationsListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  SortOption _currentSort = SortOption.dateNewest;
  FilterStatus _currentFilter = FilterStatus.all;
  String _currencySymbol = '';

  @override
  void initState() {
    super.initState();
    _loadCurrency();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
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
    _searchController.dispose();
    super.dispose();
  }

  // Processes the raw Firestore documents: filtering and sorting in memory
  List<QueryDocumentSnapshot> _processList(List<QueryDocumentSnapshot> docs) {
    var filtered = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final bool billed = data['billed'] == true || data['status'] == 'settled';

      // Status filter
      if (_currentFilter == FilterStatus.available && billed) return false;
      if (_currentFilter == FilterStatus.settled && !billed) return false;

      // Search filter
      if (_searchQuery.isEmpty) return true;
      final customerName = (data['customerName'] ?? '').toString().toLowerCase();
      final quotationNumber = (data['quotationNumber'] ?? '').toString().toLowerCase();
      return customerName.contains(_searchQuery) || quotationNumber.contains(_searchQuery);
    }).toList();

    filtered.sort((a, b) {
      final dataA = a.data() as Map<String, dynamic>;
      final dataB = b.data() as Map<String, dynamic>;

      switch (_currentSort) {
        case SortOption.amountHigh:
          double valA = (dataA['total'] ?? 0.0).toDouble();
          double valB = (dataB['total'] ?? 0.0).toDouble();
          return valB.compareTo(valA);
        case SortOption.amountLow:
          double valA = (dataA['total'] ?? 0.0).toDouble();
          double valB = (dataB['total'] ?? 0.0).toDouble();
          return valA.compareTo(valB);
        case SortOption.dateOldest:
          Timestamp tA = dataA['timestamp'] ?? Timestamp.now();
          Timestamp tB = dataB['timestamp'] ?? Timestamp.now();
          return tA.compareTo(tB);
        case SortOption.dateNewest:
        default:
          Timestamp tA = dataA['timestamp'] ?? Timestamp.now();
          Timestamp tB = dataB['timestamp'] ?? Timestamp.now();
          return tB.compareTo(tA);
      }
    });

    return filtered;
  }

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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(R.sp(context, 24))),
        ),
          backgroundColor: kPrimaryColor,
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: kWhite, size: R.sp(context, 22)),
            onPressed: widget.onBack,
          ),
          title: Text(context.tr('quotations'),
              style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: R.sp(context, 18))),
        ),
      body: Column(
        children: [
          _buildHeaderSection(),
          Expanded(
            child: FutureBuilder<Stream<QuerySnapshot>>(
              future: FirestoreService().getCollectionStream('quotations'),
              builder: (context, streamSnap) {
                if (!streamSnap.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                return StreamBuilder<QuerySnapshot>(
                  stream: streamSnap.data,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmpty();

                    final processedList = _processList(snapshot.data!.docs);
                    if (processedList.isEmpty) return _buildNoResults();

                    return ListView.separated(
                      padding: EdgeInsets.symmetric(horizontal: R.sp(context, 16), vertical: R.sp(context, 12)),
                      itemCount: processedList.length,
                      separatorBuilder: (c, i) => SizedBox(height: R.sp(context, 10)),
                      itemBuilder: (c, i) => _buildCard(processedList[i]),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Using MaterialPageRoute for faster/smoother transition on press
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NewQuotationPage(
                uid: widget.uid,
                userEmail: widget.userEmail,
              ),
            ),
          );
        },
        backgroundColor: kPrimaryColor,
        icon: const Icon(Icons.add, color: kWhite),
        label: const Text('New Quotation', style: TextStyle(color: kWhite, fontWeight: FontWeight.w700)),
      ),
      ), // WillPopScope closing
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: EdgeInsets.fromLTRB(R.sp(context, 16), R.sp(context, 8), R.sp(context, 16), R.sp(context, 12)),
      decoration: const BoxDecoration(
        color: kWhite,
        border: Border(bottom: BorderSide(color: kGrey200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: R.sp(context, 46),
              decoration: BoxDecoration(
                borderRadius: R.radius(context, 12),
              ),
              child: ValueListenableBuilder<TextEditingValue>(
      valueListenable: _searchController,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: context.tr('search'),
                  hintStyle: TextStyle(color: kBlack54, fontSize: R.sp(context, 14)),
                  prefixIcon: Icon(Icons.search, color: kPrimaryColor, size: R.sp(context, 20)),
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
            ),
          ),
          SizedBox(width: R.sp(context, 10)),
          _buildHeaderActionBtn(Icons.sort_rounded, _showSortMenu),
          SizedBox(width: R.sp(context, 8)),
          _buildHeaderActionBtn(Icons.tune_rounded, _showFilterMenu),
        ],
      ),
    );
  }

  Widget _buildHeaderActionBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: R.radius(context, 12),
      child: Container(
        height: R.sp(context, 46),
        width: R.sp(context, 46),
        decoration: BoxDecoration(
          color: kPrimaryColor.withOpacity(0.08),
          borderRadius: R.radius(context, 12),
          border: Border.all(color: kGrey200),
        ),
        child: Icon(icon, color: kPrimaryColor, size: R.sp(context, 22)),
      ),
    );
  }

  Widget _buildCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final bool billed = data['billed'] == true || data['status'] == 'settled';
    final double total = (data['total'] ?? 0.0).toDouble();
    final String quotedBy = data['staffName'] ?? 'Staff';

    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: R.radius(context, 12),
        border: Border.all(color: kGrey200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (c) => QuotationDetailPage(
                      uid: widget.uid,
                      userEmail: widget.userEmail,
                      quotationId: doc.id,
                      quotationData: data,
                      currencySymbol: _currencySymbol))),
          borderRadius: R.radius(context, 12),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: R.sp(context, 14), vertical: R.sp(context, 12)),
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: [
                    Icon(Icons.description_outlined, size: R.sp(context, 14), color: kPrimaryColor),
                    SizedBox(width: R.sp(context, 5)),
                    Text("${data['quotationNumber']}",
                        style: TextStyle(fontWeight: FontWeight.w900, color: kPrimaryColor, fontSize: R.sp(context, 13))),
                  ]),
                  Text(
                      data['date'] != null
                          ? DateFormat('dd MMM yyyy • hh:mm a').format(DateTime.parse(data['date']))
                          : '',
                      style: TextStyle(fontSize: R.sp(context, 10.5), color: Colors.black, fontWeight: FontWeight.w500)),
                ]),
                SizedBox(height: R.sp(context, 10)),
                Row(children: [
                  Expanded(
                      child: Text(data['customerName'] ?? 'Guest',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: R.sp(context, 14), color: Colors.black87))),
                  Text("$_currencySymbol${total.toStringAsFixed(2)}",
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: R.sp(context, 15), color: kGoogleGreen)),
                ]),
                Divider(height: R.sp(context, 20), color: kGreyBg),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text("Quoted by",
                        style: TextStyle(fontSize: R.sp(context, 8), fontWeight: FontWeight.w700, color: kBlack54, letterSpacing: 0.5)),
                    Text(quotedBy,
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: R.sp(context, 10), color: kBlack87)),
                  ]),
                  Row(children: [
                    _badge(billed),
                    SizedBox(width: R.sp(context, 8)),
                    Icon(Icons.chevron_right, color: kPrimaryColor, size: R.sp(context, 18)),
                  ]),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(bool billed) {
    final Color statusColor = billed ? kErrorColor : kGoogleGreen;

    return Container(
        padding: EdgeInsets.symmetric(horizontal: R.sp(context, 10), vertical: R.sp(context, 4)),
        decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: R.radius(context, 12),
            border: Border.all(color: statusColor.withOpacity(0.2))),
        child: Text(billed ? "Billed" : "Open",
            style: TextStyle(fontSize: R.sp(context, 9), fontWeight: FontWeight.w900, color: statusColor)));
  }

  void _showSortMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(R.sp(context, 20)))),
      builder: (context) => Padding(
        padding: R.all(context, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sort Quotations', style: TextStyle(fontSize: R.sp(context, 18), fontWeight: FontWeight.w900, color: kBlack87)),
            SizedBox(height: R.sp(context, 16)),
            _sortItem("Newest First", SortOption.dateNewest),
            _sortItem("Oldest First", SortOption.dateOldest),
            _sortItem("Amount: High to Low", SortOption.amountHigh),
            _sortItem("Amount: Low to High", SortOption.amountLow),
          ],
        ),
      ),
    );
  }

  Widget _sortItem(String label, SortOption option) {
    bool isSelected = _currentSort == option;
    return ListTile(
      onTap: () {
        setState(() => _currentSort = option);
        Navigator.pop(context);
      },
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? kPrimaryColor : kBlack87)),
      trailing: isSelected ? const Icon(Icons.check_circle, color: kPrimaryColor) : null,
    );
  }

  void _showFilterMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(R.sp(context, 20)))),
      builder: (context) => Padding(
        padding: R.all(context, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filter Status', style: TextStyle(fontSize: R.sp(context, 18), fontWeight: FontWeight.w900, color: kBlack87)),
            SizedBox(height: R.sp(context, 16)),
            _filterItem("All Quotations", FilterStatus.all),
            _filterItem("Open Only", FilterStatus.available),
            _filterItem("Billed Only", FilterStatus.settled),
          ],
        ),
      ),
    );
  }

  Widget _filterItem(String label, FilterStatus status) {
    bool isSelected = _currentFilter == status;
    return ListTile(
      onTap: () {
        setState(() => _currentFilter = status);
        Navigator.pop(context);
      },
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? kPrimaryColor : kBlack87)),
      trailing: isSelected ? const Icon(Icons.check_circle, color: kPrimaryColor) : null,
    );
  }

  Widget _buildEmpty() => Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.description_outlined, size: R.sp(context, 64), color: kGrey300),
        SizedBox(height: R.sp(context, 16)),
        Text(context.tr('no_quotations_found'),
            style: TextStyle(color: kBlack54, fontWeight: FontWeight.w600, fontSize: R.sp(context, 14)))
      ]));

  Widget _buildNoResults() => Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.search_off_rounded, size: R.sp(context, 64), color: kGrey300),
        SizedBox(height: R.sp(context, 16)),
        Text("No matches found for your search",
            style: TextStyle(color: kBlack54, fontWeight: FontWeight.w600, fontSize: R.sp(context, 14)))
      ]));
}

