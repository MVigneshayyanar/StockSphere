import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:maxbillup/Colors.dart';
import 'package:maxbillup/Stocks/AddExpenseTypePopup.dart';
import 'package:heroicons/heroicons.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/services/number_generator_service.dart';
import 'package:maxbillup/services/currency_service.dart';

class ExpensesPage extends StatefulWidget {
  final String uid;
  final VoidCallback onBack;

  const ExpensesPage({super.key, required this.uid, required this.onBack});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late Future<Stream<QuerySnapshot>> _expensesStreamFuture;
  String _currencySymbol = '';

  @override
  void initState() {
    super.initState();
    _expensesStreamFuture = FirestoreService().getCollectionStream('expenses');
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    _loadCurrency();
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
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: kPrimaryColor)),
        child: child!,
      ),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
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
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
          title: Text(context.tr('expenses'),
              style: const TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
          backgroundColor: kPrimaryColor,
          leading: IconButton(
            icon: const HeroIcon(HeroIcons.arrowLeft, color: kWhite, size: 20),
            onPressed: widget.onBack,
          ),
          centerTitle: true,
          elevation: 0,
        ),
        body: Column(
        children: [
          // ENTERPRISE HEADER: DATE & NEW BUTTON
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            decoration: const BoxDecoration(
              color: kWhite,
              border: Border(bottom: BorderSide(color: kGrey200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectDate(context),
                    child: Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: kPrimaryColor.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kGrey200),
                      ),
                      child: Row(
                        children: [
                          const HeroIcon(HeroIcons.calendarDays, color: kPrimaryColor, size: 18),
                          const SizedBox(width: 12),
                          Text(
                            DateFormat('dd MMM yyyy').format(_selectedDate),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kBlack87),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (context) => CreateExpensePage(
                          uid: widget.uid,
                          onBack: () => Navigator.pop(context),
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 46,
                    width: 46,
                    decoration: BoxDecoration(color: kPrimaryColor, borderRadius: BorderRadius.circular(12)),
                    child: const HeroIcon(HeroIcons.plus, color: kWhite, size: 24),
                  ),
                ),
              ],
            ),
          ),

          // SEARCH BAR
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            decoration: const BoxDecoration(
              color: kWhite,
              border: Border(bottom: BorderSide(color: kGrey200)),
            ),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ValueListenableBuilder<TextEditingValue>(
      valueListenable: _searchController,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextField(
                controller: _searchController,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kBlack87),
                decoration: InputDecoration(
                  hintText: "Search expense name or type...",
                  hintStyle: TextStyle(color: kBlack54, fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: kPrimaryColor, size: 20),
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
          ),

          // LIST
          Expanded(
            child: FutureBuilder<Stream<QuerySnapshot>>(
              future: _expensesStreamFuture,
              builder: (context, futureSnapshot) {
                if (futureSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                }
                if (!futureSnapshot.hasData) return const Center(child: Text("Unable to load expenses"));

                return StreamBuilder<QuerySnapshot>(
                  stream: futureSnapshot.data!,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyState();

                    final expenses = snapshot.data!.docs.where((doc) {
                      if (_searchQuery.isEmpty) return true;
                      final data = doc.data() as Map<String, dynamic>;
                      final name = (data['expenseName'] ?? '').toString().toLowerCase();
                      final type = (data['expenseType'] ?? '').toString().toLowerCase();
                      return name.contains(_searchQuery) || type.contains(_searchQuery);
                    }).toList();

                    // Sort by date (newest first)
                    expenses.sort((a, b) {
                      final dataA = a.data() as Map<String, dynamic>;
                      final dataB = b.data() as Map<String, dynamic>;
                      final tsA = dataA['timestamp'] as Timestamp?;
                      final tsB = dataB['timestamp'] as Timestamp?;
                      if (tsA == null && tsB == null) return 0;
                      if (tsA == null) return 1;
                      if (tsB == null) return -1;
                      return tsB.compareTo(tsA); // Newest first
                    });

                    if (expenses.isEmpty) return _buildNoResults();

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      itemCount: expenses.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        return _buildExpenseCard(context, expenses[index].id, expenses[index].data() as Map<String, dynamic>);
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

  Widget _buildExpenseCard(BuildContext context, String id, Map<String, dynamic> data) {
    final amount = (data['amount'] ?? 0.0) as num;
    final ts = data['timestamp'] as Timestamp?;
    final dateStr = ts != null ? DateFormat('dd MMM yyyy • hh:mm a').format(ts.toDate()) : 'N/A';
    final expenseNumber = (data['expenseNumber'] ?? data['referenceNumber'] ?? '').toString();

    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGrey200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ExpenseDetailsPage(
                  expenseId: id,
                  expenseData: data,
                  currencySymbol: _currencySymbol,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: [
                    const HeroIcon(HeroIcons.documentText, size: 14, color: kPrimaryColor),
                    const SizedBox(width: 5),
                    Text(expenseNumber.isNotEmpty ? expenseNumber : 'Expense',
                        style: const TextStyle(fontWeight: FontWeight.w900, color: kPrimaryColor, fontSize: 13)),
                  ]),
                  Text(dateStr, style: const TextStyle(fontSize: 10.5, color: Colors.black, fontWeight: FontWeight.w500)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: Text(data['expenseName'] ?? 'Expense',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  Text("$_currencySymbol${amount.toStringAsFixed(2)}",
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: kErrorColor)),
                ]),
                const Divider(height: 20, color: kGreyBg),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text("Type", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: kBlack54, letterSpacing: 0.5)),
                    Text(data['expenseType'] ?? 'General',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 10, color: kBlack87)),
                  ]),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: kErrorColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kErrorColor.withValues(alpha: 0.2)),
                      ),
                      child: Text((data['paymentMode'] ?? 'Cash'),
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kErrorColor)),
                    ),
                    const SizedBox(width: 8),
                    const HeroIcon(HeroIcons.chevronRight, color: kPrimaryColor, size: 16),
                  ]),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [HeroIcon(HeroIcons.documentText, size: 64, color: kGrey300), const SizedBox(height: 16), const Text('No expenses found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kBlack87))]));
  Widget _buildNoResults() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const HeroIcon(HeroIcons.magnifyingGlass, size: 64, color: kGrey300), const SizedBox(height: 16), Text('No matches for "$_searchQuery"', style: const TextStyle(color: kBlack54))]));
}

// ---------------- CreateExpensePage ----------------
class CreateExpensePage extends StatefulWidget {
  final String uid;
  final VoidCallback onBack;

  const CreateExpensePage({super.key, required this.uid, required this.onBack});

  @override
  State<CreateExpensePage> createState() => _CreateExpensePageState();
}

class _CreateExpensePageState extends State<CreateExpensePage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _expenseNameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _paidAmountController = TextEditingController(); // replaces _creditAmountController
  final TextEditingController _advanceNotesController = TextEditingController();
  final TextEditingController _taxNumberController = TextEditingController();
  final TextEditingController _taxAmountController = TextEditingController();
  final TextEditingController _referenceNumberController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _selectedExpenseType = 'Select Expense Type';
  String _paymentMode = 'Cash';
  bool _isLoading = false;
  List<String> _expenseTypes = [];
  List<String> _expenseNameSuggestions = [];
  String _currencySymbol = '';

  // Auto-calculated credit amount (same as StockPurchase)
  double get _creditAmount {
    final total = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final paid = double.tryParse(_paidAmountController.text.trim()) ?? 0.0;
    return (total - paid).clamp(0.0, double.infinity);
  }

  @override
  void initState() {
    super.initState();
    _loadExpenseTypes();
    _loadExpenseNameSuggestions();
    _loadCurrency();
  }

  void _loadCurrency() async {
    final storeId = await FirestoreService().getCurrentStoreId();
    if (storeId == null) return;
    final doc = await FirebaseFirestore.instance.collection('store').doc(storeId).get();
    if (doc.exists && mounted) {
      setState(() => _currencySymbol = CurrencyService.getSymbolWithSpace(doc.data()?['currency']));
    }
  }

  Future<void> _loadExpenseTypes() async {
    try {
      final stream = await FirestoreService().getCollectionStream('expenseCategories');
      final snapshot = await stream.first;
      if (mounted) {
        setState(() {
          _expenseTypes = snapshot.docs.map((doc) => (doc.data() as Map<String, dynamic>)['name'].toString()).toList();
        });
      }
    } catch (e) { debugPrint(e.toString()); }
  }

  Future<void> _loadExpenseNameSuggestions() async {
    try {
      final col = await FirestoreService().getStoreCollection('expenseNames');
      // Try with orderBy first, fallback to plain get if index missing
      QuerySnapshot snap;
      try {
        snap = await col.orderBy('usageCount', descending: true).limit(50).get();
      } catch (_) {
        snap = await col.limit(50).get();
      }
      final names = <String>[];
      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final n = (data['name'] ?? '').toString().trim();
        if (n.isNotEmpty) names.add(n);
      }

      // Also load unique expense names from past expenses as fallback
      if (names.isEmpty) {
        try {
          final expCol = await FirestoreService().getStoreCollection('expenses');
          final expSnap = await expCol.limit(100).get();
          final seen = <String>{};
          for (final doc in expSnap.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final n = (data['expenseName'] ?? '').toString().trim();
            if (n.isNotEmpty && seen.add(n)) names.add(n);
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _expenseNameSuggestions = names;
        });
      }
    } catch (e) {
      debugPrint('Error loading expense names: $e');
      // Last resort: load from expenses collection
      try {
        final expCol = await FirestoreService().getStoreCollection('expenses');
        final expSnap = await expCol.limit(100).get();
        final names = <String>{};
        for (final doc in expSnap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final n = (data['expenseName'] ?? '').toString().trim();
          if (n.isNotEmpty) names.add(n);
        }
        if (mounted) setState(() => _expenseNameSuggestions = names.toList());
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _expenseNameController.dispose();
    _amountController.dispose();
    _paidAmountController.dispose();
    _advanceNotesController.dispose();
    _taxNumberController.dispose();
    _taxAmountController.dispose();
    _referenceNumberController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: kPrimaryColor)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedExpenseType == 'Select Expense Type') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an expense type'), backgroundColor: kErrorColor),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final amount = double.parse(_amountController.text.trim());
      final paidAmount = _paymentMode == 'Credit'
          ? (double.tryParse(_paidAmountController.text.trim()) ?? 0.0)
          : amount;
      final creditAmount = _paymentMode == 'Credit' ? _creditAmount : 0.0;

      // Use user-entered reference number if provided, otherwise generate
      String referenceNumber;
      final bool referenceAutoGenerated;
      if (_referenceNumberController.text.trim().isNotEmpty) {
        referenceNumber = _referenceNumberController.text.trim();
        referenceAutoGenerated = false;
      } else {
        final prefix = await NumberGeneratorService.getExpensePrefix();
        final number = await NumberGeneratorService.generateExpenseNumber();
        referenceNumber = prefix.isNotEmpty ? '$prefix$number' : number;
        referenceAutoGenerated = true;
      }

      final expenseName = _expenseNameController.text.trim();

      await FirestoreService().addDocument('expenses', {
        'expenseName': expenseName,
        'amount': amount,
        'paidAmount': paidAmount,
        'creditAmount': creditAmount,
        'expenseType': _selectedExpenseType,
        'paymentMode': _paymentMode,
        'advanceNotes': _advanceNotesController.text.trim(),
        'taxNumber': _taxNumberController.text.trim(),
        'taxAmount': double.tryParse(_taxAmountController.text.trim()) ?? 0.0,
        'timestamp': Timestamp.fromDate(_selectedDate),
        'uid': widget.uid,
        'referenceNumber': referenceNumber,
        'referenceAutoGenerated': referenceAutoGenerated,
        'expenseNumber': referenceNumber,
      });

      await _saveExpenseName(expenseName);

      // ── Credit tracker: create purchaseCreditNotes entry (same as StockPurchase) ──
      if (_paymentMode == 'Credit' && creditAmount > 0) {
        final creditNoteNumber = await NumberGeneratorService.generatePurchaseCreditNoteNumber();
        await FirestoreService().addDocument('purchaseCreditNotes', {
          'creditNoteNumber': creditNoteNumber,
          'invoiceNumber': referenceNumber,
          'purchaseNumber': referenceNumber,
          'supplierName': 'Expense: $expenseName',
          'supplierPhone': null,
          'amount': creditAmount,   // total − paid → actual credit owed
          'paidAmount': 0,          // starts at 0; incremented by tracker settlements
          'timestamp': Timestamp.fromDate(_selectedDate),
          'status': 'Available',
          'notes': _advanceNotesController.text.trim().isEmpty ? null : _advanceNotesController.text.trim(),
          'uid': widget.uid,
          'type': 'Expense Credit',
          'category': _selectedExpenseType,
          'items': [],
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense saved successfully'), backgroundColor: kGoogleGreen),
        );
        widget.onBack();
      }
    } catch (e) {
      debugPrint(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: kErrorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveExpenseName(String name) async {
    try {
      final col = await FirestoreService().getStoreCollection('expenseNames');
      final query = await col.where('name', isEqualTo: name).limit(1).get();
      if (query.docs.isNotEmpty) {
        await col.doc(query.docs.first.id).update({'usageCount': FieldValue.increment(1), 'lastUsed': FieldValue.serverTimestamp()});
      } else {
        await col.add({'name': name, 'usageCount': 1, 'lastUsed': FieldValue.serverTimestamp(), 'createdAt': FieldValue.serverTimestamp()});
      }
    } catch (e) { debugPrint(e.toString()); }
  }

  List<String> _filterExpenseNameSuggestions(String query) {
    if (query.isEmpty) return _expenseNameSuggestions.take(10).toList();
    return _expenseNameSuggestions
        .where((n) => n.toLowerCase().contains(query.toLowerCase()))
        .take(10)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        title: const Text('New Expense', style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: kPrimaryColor, centerTitle: true, elevation: 0,
        leading: IconButton(icon: const HeroIcon(HeroIcons.arrowLeft, color: kWhite, size: 20), onPressed: widget.onBack),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildSectionLabel("Basic Details"),
                  _buildExpenseTypeDropdown(),
                  const SizedBox(height: 16),
                  _buildAutocompleteExpenseName(),
                  const SizedBox(height: 16),
                  _buildModernField(
                    _amountController, "Total Amount *", HeroIcons.banknotes,
                    type: TextInputType.number,
                    isMandatory: true,
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  _buildModernField(_referenceNumberController, "Reference Invoice No (Optional)", HeroIcons.documentText),
                  const SizedBox(height: 16),
                  _buildDateSelector(),
                  const SizedBox(height: 20),

                  // ── Payment Mode chips (same as StockPurchase) ──────────
                  _buildSectionLabel("Payment Mode"),
                  Container(
                    decoration: BoxDecoration(
                      color: kWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kGrey200),
                    ),
                    child: Row(
                      children: [
                        _buildPaymentModeChip('Cash', HeroIcons.banknotes),
                        _buildPaymentModeChip('Online', HeroIcons.qrCode),
                        _buildPaymentModeChip('Credit', HeroIcons.wallet),
                      ],
                    ),
                  ),

                  // ── Credit split (shown only when Credit is selected) ───
                  if (_paymentMode == 'Credit') ...[
                    const SizedBox(height: 20),
                    _buildSectionLabel("Paid Amount"),
                    _buildModernField(
                      _paidAmountController,
                      'Paid Amount',
                      HeroIcons.bookOpen,
                      type: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: () => setState(() {}),
                      validator: (v) {
                        final paid = double.tryParse(v ?? '') ?? 0.0;
                        final total = double.tryParse(_amountController.text.trim()) ?? 0.0;
                        if (paid > total) return 'Paid amount cannot exceed total';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    // Auto-calculated credit amount display
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _creditAmount > 0 ? Colors.orange.shade50 : kGoogleGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _creditAmount > 0 ? Colors.orange : kGoogleGreen),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              HeroIcon(HeroIcons.wallet, size: 20,
                                  color: _creditAmount > 0 ? Colors.orange.shade700 : kGoogleGreen),
                              const SizedBox(width: 8),
                              Text('Credit Amount:',
                                  style: TextStyle(fontWeight: FontWeight.w600,
                                      color: _creditAmount > 0 ? Colors.orange.shade700 : kGoogleGreen)),
                            ],
                          ),
                          Text(
                            '$_currencySymbol${_creditAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _creditAmount > 0 ? Colors.orange.shade700 : kGoogleGreen),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: _buildSectionLabel("Additional Information"),
                      children: [
                        _buildModernField(_advanceNotesController, "Advance Notes", HeroIcons.documentText, maxLines: 3),
                        const SizedBox(height: 16),
                        _buildModernField(_taxNumberController, "Tax/GST Ref No", HeroIcons.documentText),
                        const SizedBox(height: 16),
                        _buildModernField(_taxAmountController, "Tax Component", HeroIcons.percentBadge, type: TextInputType.number),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _buildBottomAction(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) => Padding(padding: const EdgeInsets.only(bottom: 10, left: 4), child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 0.5)));

  Widget _buildModernField(TextEditingController ctrl, String label, HeroIcons icon,
      {TextInputType type = TextInputType.text,
      int maxLines = 1,
      bool isMandatory = false,
      VoidCallback? onChanged,
      FocusNode? focusNode,
      String? Function(String?)? validator}) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: ctrl,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextFormField(
          controller: ctrl,
          focusNode: focusNode,
          keyboardType: type,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kBlack87),
          onChanged: (v) {
            if (onChanged != null) onChanged();
            setState(() {});
          },
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: HeroIcon(icon, color: hasText ? kPrimaryColor : kBlack54, size: 20),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kErrorColor)),
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
            labelStyle: TextStyle(
                color: hasText ? kPrimaryColor : kBlack54,
                fontSize: 13,
                fontWeight: FontWeight.w600),
            floatingLabelStyle: const TextStyle(
                color: kPrimaryColor, fontSize: 11, fontWeight: FontWeight.w900),
          ),
          validator: validator ?? (isMandatory ? (v) => (v == null || v.isEmpty) ? 'Required' : null : null),
        );
      },
    );
  }

  // ── Payment mode chip (same as StockPurchase) ─────────────────────────
  Widget _buildPaymentModeChip(String mode, HeroIcons icon) {
    final isSelected = _paymentMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _paymentMode = mode;
          if (mode != 'Credit') _paidAmountController.clear();
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? kPrimaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HeroIcon(icon, size: 18, color: isSelected ? kWhite : kBlack54),
              const SizedBox(width: 6),
              Text(
                mode,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? kWhite : kBlack54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAutocompleteExpenseName() {
    return Autocomplete<String>(
      optionsBuilder: (v) => _filterExpenseNameSuggestions(v.text),
      displayStringForOption: (o) => o,
      onSelected: (s) => setState(() => _expenseNameController.text = s),
      fieldViewBuilder: (ctx, ctrl, focus, onSub) {
        if (_expenseNameController.text.isNotEmpty && ctrl.text.isEmpty) ctrl.text = _expenseNameController.text;
        ctrl.addListener(() => _expenseNameController.text = ctrl.text);
        return _buildModernField(ctrl, 'Expense Name *', HeroIcons.tag, isMandatory: true, focusNode: focus);
      },
      optionsViewBuilder: (ctx, onSel, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: MediaQuery.of(context).size.width - 40,
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: kWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kGrey200),
            ),
            child: ListView.separated(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: options.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: kGrey100),
              itemBuilder: (ctx, i) {
                final name = options.elementAt(i);
                return ListTile(
                  dense: true,
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  onTap: () => onSel(name),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpenseTypeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedExpenseType, isExpanded: true, icon: const HeroIcon(HeroIcons.chevronDown, color: kBlack54),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kBlack87),
          items: [
            const DropdownMenuItem(value: 'Select Expense Type', child: Text('Select Expense Type', style: TextStyle(color: kBlack54))),
            const DropdownMenuItem(value: 'Add Expense Type', child: Row(children: [HeroIcon(HeroIcons.plusCircle, size: 18, color: kPrimaryColor), SizedBox(width: 8), Text('New Category', style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w800))])),
            ..._expenseTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))),
          ],
          onChanged: (v) async {
            if (v == 'Add Expense Type') {
              final res = await showDialog<String>(context: context, builder: (_) => AddExpenseTypePopup(uid: widget.uid));
              if (res != null && res.isNotEmpty) { setState(() { _selectedExpenseType = res; if (!_expenseTypes.contains(res)) _expenseTypes.add(res); }); }
            } else if (v != 'Select Expense Type') setState(() => _selectedExpenseType = v!);
          },
        ),
      ),
    );
  }

  Widget _buildDateSelector() => GestureDetector(onTap: () => _selectDate(context), child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14), decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)), child: Row(children: [const HeroIcon(HeroIcons.calendar, size: 16, color: kPrimaryColor), const SizedBox(width: 10), Text(DateFormat('dd MMM yyyy').format(_selectedDate), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))])));
  Widget _buildBottomAction() => SafeArea(child: Container(padding: const EdgeInsets.fromLTRB(20, 12, 20, 12), decoration: const BoxDecoration(color: kWhite, border: Border(top: BorderSide(color: kGrey200))), child: SizedBox(width: double.infinity, height: 56, child: ElevatedButton(onPressed: _isLoading ? null : _saveExpense, style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: _isLoading ? const CircularProgressIndicator(color: kWhite) : const Text('Save expense', style: TextStyle(color: kWhite, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.5))))));
}

// ---------------- ExpenseDetailsPage ----------------
class ExpenseDetailsPage extends StatelessWidget {
  final String expenseId;
  final Map<String, dynamic> expenseData;
  final String currencySymbol;

  const ExpenseDetailsPage({super.key, required this.expenseId, required this.expenseData, required this.currencySymbol});

  @override
  Widget build(BuildContext context) {
    final date = (expenseData['timestamp'] as Timestamp?)?.toDate();
    final dateStr = date != null ? DateFormat('dd MMM yyyy, hh:mm a').format(date) : 'N/A';
    final total = (expenseData['amount'] ?? 0.0).toDouble();

    return Scaffold(
      backgroundColor: kPrimaryColor,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        title: const Text('Expense Info', style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: kPrimaryColor, centerTitle: true, elevation: 0,
        leading: IconButton(icon: const HeroIcon(HeroIcons.arrowLeft, color: kWhite, size: 20), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(icon: const HeroIcon(HeroIcons.trash, color: kWhite), onPressed: () => _showDeleteDialog(context)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  CircleAvatar(backgroundColor: kOrange.withOpacity(0.1), radius: 18, child: const HeroIcon(HeroIcons.documentText, color: kOrange, size: 18)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(expenseData['expenseName'] ?? 'General Expense', style: const TextStyle(color: kOrange, fontSize: 15, fontWeight: FontWeight.w700)),
                      Text(expenseData['expenseType'] ?? 'Uncategorized', style: const TextStyle(color: kBlack54, fontSize: 11, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: kPrimaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Text((expenseData['paymentMode'] ?? 'Cash'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kPrimaryColor))),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(color: kWhite, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Transaction Details', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: kBlack54, letterSpacing: 0.5)),
                    const SizedBox(height: 12),
                    _buildRow(HeroIcons.hashtag, 'Reference ID', expenseData['referenceNumber'] ?? 'N/A'),
                    _buildRow(HeroIcons.calendarDays, 'Date Recorded', dateStr),
                    _buildRow(HeroIcons.documentText, 'Tax Number', expenseData['taxNumber'] ?? '--'),
                    _buildRow(HeroIcons.documentText, 'Note', expenseData['advanceNotes'] ?? '--'),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: kGrey100)),

                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Total Expense', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: kBlack54)),
                      Text('$currencySymbol${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kErrorColor)),
                    ]),

                    if (expenseData['taxAmount'] != null && expenseData['taxAmount'] != 0.0) ...[
                      const SizedBox(height: 8),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('Tax Amount Included', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kBlack54)),
                        Text('$currencySymbol${expenseData['taxAmount']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kBlack87)),
                      ]),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Delete Expense?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to delete this expense? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await FirestoreService().deleteDocument('expenses', expenseId);
              if (context.mounted) { Navigator.pop(ctx); Navigator.pop(context, true); }
            },
            style: ElevatedButton.styleFrom(backgroundColor: kErrorColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Delete', style: TextStyle(color: kWhite,fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(HeroIcons i, String l, String v) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [HeroIcon(i, size: 14, color: kGrey400), const SizedBox(width: 10), Text('$l: ', style: const TextStyle(color: kBlack54, fontSize: 11, fontWeight: FontWeight.w500)), Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: kBlack87), overflow: TextOverflow.ellipsis))]));
}

