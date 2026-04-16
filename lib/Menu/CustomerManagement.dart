import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:heroicons/heroicons.dart';
import 'package:intl/intl.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/ledger_helper.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/Colors.dart';
import 'package:maxbillup/Menu/AddCustomer.dart';
import 'package:maxbillup/Menu/Menu.dart' hide kWhite, kPrimaryColor, kErrorColor, kGoogleGreen, kOrange, kGrey200, kGrey300, kGrey400, kGreyBg, kBlack87, kBlack54, kGrey100;
import 'package:maxbillup/services/currency_service.dart';
import 'package:maxbillup/services/number_generator_service.dart';
import 'package:maxbillup/Receipts/PaymentReceiptPage.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

// =============================================================================
// MAIN PAGE: CUSTOMER DETAILS
// =============================================================================

class CustomerDetailsPage extends StatefulWidget {
  final String customerId;
  final Map<String, dynamic> customerData;

  const CustomerDetailsPage({super.key, required this.customerId, required this.customerData});

  @override
  State<CustomerDetailsPage> createState() => _CustomerDetailsPageState();
}

class _CustomerDetailsPageState extends State<CustomerDetailsPage> {
  String _currencySymbol = '';
  @override
  void initState() {
    super.initState();
    _loadCurrency();
    _syncBalanceInBackground();
  }

  Future<void> _syncBalanceInBackground() async {
    try {
      await LedgerHelper.computeClosingBalance(widget.customerId, syncToFirestore: true);
    } catch (e) {
      debugPrint('Error quietly syncing balance: $e');
    }
  }

  void _loadCurrency() async {
    final store = await FirestoreService().getCurrentStoreDoc();
    if (store != null && store.exists && mounted) {
      final data = store.data() as Map<String, dynamic>;
      setState(() => _currencySymbol = CurrencyService.getSymbolWithSpace(data['currency']));
    }
  }

  // --- POPUPS (Professional Redesign) ---

  Future<void> _confirmDelete(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: kWhite,
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Delete Customer", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: kBlack87)),
                  GestureDetector(onTap: () => Navigator.pop(context), child: const HeroIcon(HeroIcons.xMark, size: 24, color: kBlack54)),
                ],
              ),
              const SizedBox(height: 24),
              const HeroIcon(HeroIcons.exclamationTriangle, color: kErrorColor, size: 48),
              const SizedBox(height: 16),
              const Text("This action cannot be undone. All customer data and credit history will be removed.",
                  textAlign: TextAlign.center, style: TextStyle(color: kBlack54, fontSize: 14, height: 1.4)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    await FirestoreService().deleteDocument('customers', widget.customerId);
                    if (mounted) { Navigator.pop(context); Navigator.pop(context); }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: kErrorColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text("Delete Permanently", style: TextStyle(color: kWhite, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, String currentName, String? currentGst) {
    final nameController = TextEditingController(text: currentName);
    final gstController = TextEditingController(text: currentGst ?? '');

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: kWhite,
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Edit Details", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: kBlack87)),
                  GestureDetector(onTap: () => Navigator.pop(context), child: const HeroIcon(HeroIcons.xMark, size: 24, color: kBlack54)),
                ],
              ),
              const SizedBox(height: 24),
              _buildPopupTextField(controller: nameController, label: "Name", icon: HeroIcons.user),
              const SizedBox(height: 16),
              _buildPopupTextField(controller: gstController, label: "GST Number", icon: HeroIcons.documentText),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    await FirestoreService().updateDocument('customers', widget.customerId, {
                      'name': nameController.text.trim(),
                      'gst': gstController.text.trim().isEmpty ? null : gstController.text.trim(),
                    });
                    if (mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text("Update Details", style: TextStyle(color: kWhite, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddCreditModal(BuildContext context, double currentBalance, double currentTotalSales) {
    final amountController = TextEditingController();
    String selectedMethod = "Cash";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(color: kWhite, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Add New Credit", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: kBlack87)),
                  GestureDetector(onTap: () => Navigator.pop(context), child: const HeroIcon(HeroIcons.xMark, size: 24, color: kBlack54)),
                ],
              ),
              const SizedBox(height: 24), _buildPopupTextField(controller: amountController, label: "Amount to Add", icon: HeroIcons.plusCircle, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildPaymentToggle("Cash", HeroIcons.banknotes, selectedMethod, (v) => setModalState(() => selectedMethod = v)),
                  _buildPaymentToggle("Online", HeroIcons.qrCode, selectedMethod, (v) => setModalState(() => selectedMethod = v)),
                  // _buildPaymentToggle("Waive", HeroIcons.handRaised, selectedMethod, (v) => setModalState(() => selectedMethod = v)),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text) ?? 0.0;
                    if (amount <= 0) return;
                    // Pop the modal first before processing to avoid context conflicts
                    Navigator.pop(context);
                    await _processTransaction(amount, currentBalance, currentTotalSales, selectedMethod);
                  },
                  child: const Text("Confirm Credit", style: TextStyle(color: kWhite, fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildPopupTextField({required TextEditingController controller, required String label, required HeroIcons icon, TextInputType keyboardType = TextInputType.text, int maxLines = 1}) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kBlack87),
      decoration: InputDecoration(
        labelText: label, prefixIcon: Padding(
          padding: const EdgeInsets.all(12.0),
          child: HeroIcon(icon, color: kPrimaryColor, size: 20),
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
    
);
      },
    );
  }

  Widget _buildPaymentToggle(String label, HeroIcons icon, String selected, Function(String) onSelect) {
    bool isActive = selected == label;
    return GestureDetector(
      onTap: () => onSelect(label),
      child: Column(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 54, height: 54,
          decoration: BoxDecoration(
            color: isActive ? kPrimaryColor : kWhite,
            shape: BoxShape.circle,
            border: Border.all(color: isActive ? kPrimaryColor : kGrey200, width: 1.5),
          ),
          child: Center(child: HeroIcon(icon, color: isActive ? kWhite : kBlack54, size: 22)),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: isActive ? FontWeight.w600 : FontWeight.w500, color: isActive ? kPrimaryColor : kBlack54)),
      ]),
    );
  }

  Widget _buildRatingSection(Map<String, dynamic> data) {
    final rating = (data['rating'] ?? 0) as num;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kGreyBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kGrey200),
      ),
      child: Row(
        children: [
          const HeroIcon(HeroIcons.star, color: kOrange, size: 18, style: HeroIconStyle.solid),
          const SizedBox(width: 8),
          const Text(
            'Customer Rating:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: kBlack87,
            ),
          ),
          const SizedBox(width: 12),
          ...List.generate(5, (i) => HeroIcon(
            HeroIcons.star,
            size: 18,
            color: i < rating ? kOrange : kGrey300,
            style: i < rating ? HeroIconStyle.solid : HeroIconStyle.outline,
          )),
        ],
      ),
    );
  }

  void _showEditRatingDialog(Map<String, dynamic> customerData) {
    int selectedRating = (customerData['rating'] ?? 0) as int;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            title: const Text(
              'Rate Customer',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: kBlack87,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Customer info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kGreyBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: kPrimaryColor.withValues(alpha: 0.1),
                        radius: 20,
                        child: Text(
                          (customerData['name'] ?? 'C')[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: kPrimaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customerData['name'] ?? 'Customer',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: kBlack87,
                              ),
                            ),
                            Text(
                              customerData['phone'] ?? '',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: kBlack54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 5-star rating
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return GestureDetector(
                      onTap: () {
                        setDialogState(() {
                          selectedRating = index + 1;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: HeroIcon(
                          HeroIcons.star,
                          size: 40,
                          color: index < selectedRating ? kOrange : kGrey300,
                          style: index < selectedRating ? HeroIconStyle.solid : HeroIconStyle.outline,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),

                // Rating text
                Text(
                  selectedRating == 0
                      ? 'No rating'
                      : selectedRating == 1
                      ? 'Poor'
                      : selectedRating == 2
                      ? 'Fair'
                      : selectedRating == 3
                      ? 'Good'
                      : selectedRating == 4
                      ? 'Very Good'
                      : 'Excellent!',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: selectedRating > 0 ? kPrimaryColor : kBlack54,
                  ),
                ),
              ],
            ),
            actions: [
              // Remove rating button
              if (customerData['rating'] != null && (customerData['rating'] as num) > 0)
                TextButton(
                  onPressed: () {
                    _updateCustomerRating(0);
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Remove',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: kErrorColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

              // Cancel button
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: kBlack54,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              // Save button
              ElevatedButton(
                onPressed: selectedRating > 0
                    ? () {
                  _updateCustomerRating(selectedRating);
                  Navigator.pop(context);
                }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  disabledBackgroundColor: kGrey200,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _updateCustomerRating(int rating) async {
    try {
      final customersCollection = await FirestoreService().getStoreCollection('customers');

      if (rating > 0) {
        await customersCollection.doc(widget.customerId).update({
          'rating': rating,
          'ratedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const HeroIcon(HeroIcons.star, color: kOrange, size: 20, style: HeroIconStyle.solid),
                  const SizedBox(width: 8),
                  Text(
                    'Customer rated $rating star${rating > 1 ? 's' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              backgroundColor: kGoogleGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } else {
        // Remove rating
        await customersCollection.doc(widget.customerId).update({
          'rating': FieldValue.delete(),
          'ratedAt': FieldValue.delete(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rating removed', style: TextStyle(fontWeight: FontWeight.w600)),
              backgroundColor: kOrange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating rating: $e'),
            backgroundColor: kErrorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // --- LOGIC ---

  Future<void> _processTransaction(double amount, double oldBalance, double oldTotalSales, String method) async {
    try {
      final customersCollection = await FirestoreService().getStoreCollection('customers');
      final creditsCollection = await FirestoreService().getStoreCollection('credits');
      final customerRef = customersCollection.doc(widget.customerId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        transaction.update(customerRef, {
          'balance': oldBalance + amount,
          'totalSales': oldTotalSales + amount,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      });

      // Generate payment receipt number first
      final paymentReceiptPrefix = await NumberGeneratorService.getPaymentReceiptPrefix();
      final paymentReceiptNumber = await NumberGeneratorService.generatePaymentReceiptNumber();
      final fullReceiptNumber = '$paymentReceiptPrefix$paymentReceiptNumber';

      await creditsCollection.add({
        'customerId': widget.customerId,
        'customerName': widget.customerData['name'],
        'amount': amount,
        'type': 'add_credit',
        'method': method,
        'timestamp': FieldValue.serverTimestamp(),
        'date': DateTime.now().toIso8601String(),
        'note': 'Sales Credit Added via Customer Management',
        'receiptNumber': fullReceiptNumber,
      });

      // Create payment receipt record
      final paymentReceipts = await FirestoreService().getStoreCollection('paymentReceipts');
      await paymentReceipts.add({
        'receiptNumber': fullReceiptNumber,
        'customerId': widget.customerId,
        'customerName': widget.customerData['name'],
        'amount': amount,
        'paymentMethod': method,
        'type': 'payment_received',
        'timestamp': FieldValue.serverTimestamp(),
        'date': DateTime.now().toIso8601String(),
        'note': 'Payment received - Sales Credit Added',
      });

      // Load store data
      final storeDoc = await FirestoreService().getCurrentStoreDoc();
      final storeData = storeDoc?.data() as Map<String, dynamic>?;

      // Calculate previous and current credit balance
      final previousCredit = oldBalance;
      final currentCredit = oldBalance + amount;

      if (mounted) {
        // Navigate to Payment Receipt page
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (_) => PaymentReceiptPage(
              receiptNumber: fullReceiptNumber,
              dateTime: DateTime.now(),
              businessName: storeData?['businessName'] ?? '',
              businessLocation: storeData?['businessLocation'] ?? '',
              businessPhone: storeData?['businessPhone'] ?? '',
              businessGSTIN: storeData?['taxType'] ?? storeData?['gstin'],
              customerName: widget.customerData['name'],
              customerPhone: widget.customerId,
              previousCredit: previousCredit,
              receivedAmount: amount,
              paymentMode: method,
              currentCredit: currentCredit,
              currency: CurrencyService.getSymbolWithSpace(storeData?['currency']),
              isManualCredit: true,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error in _processTransaction: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding credit: ${e.toString()}'),
            backgroundColor: kErrorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use initial customerData to avoid white screen, then stream for updates
    return FutureBuilder<DocumentReference>(
      future: FirestoreService().getDocumentReference('customers', widget.customerId),
      builder: (context, docRefSnapshot) {
        // Show initial data immediately while loading reference
        if (docRefSnapshot.connectionState == ConnectionState.waiting) {
          return _buildCustomerUI(context, widget.customerData);
        }

        if (!docRefSnapshot.hasData) {
          // Fallback to initial data if reference fails
          return _buildCustomerUI(context, widget.customerData);
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: docRefSnapshot.data!.snapshots(),
          initialData: null,
          builder: (context, snapshot) {
            // Use stream data if available, otherwise use initial customerData
            Map<String, dynamic> data;
            if (snapshot.hasData && snapshot.data!.exists) {
              data = snapshot.data!.data() as Map<String, dynamic>;
              // Preserve the dynamically calculated totalSales from widget.customerData 
              // instead of using the raw database 'totalSales' field which might not have subtracted cancelled bills yet.
              if (widget.customerData.containsKey('totalSales')) {
                data['totalSales'] = widget.customerData['totalSales'];
              }
            } else {
              data = widget.customerData;
            }
            return _buildCustomerUI(context, data);
          },
        );
      },
    );
  }

  Widget _buildCustomerUI(BuildContext context, Map<String, dynamic> data) {
    double balance = (data['balance'] ?? 0).toDouble();
    double totalSales = (data['totalSales'] ?? 0).toDouble();

    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        title: Text(context.tr('customerdetails'), style: const TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: kPrimaryColor, elevation: 0, centerTitle: true,
        iconTheme: const IconThemeData(color: kWhite),
        actions: [
          IconButton(
            icon: const HeroIcon(HeroIcons.trash, color: Colors.white),
            onPressed: () => _confirmDelete(context),
            tooltip: 'Delete Customer',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCreditModal(context, balance, totalSales),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        icon: const HeroIcon(HeroIcons.plus, color: kWhite, size: 20),
        label: const Text(
          'Add New Credit',
          style: TextStyle(color: kWhite, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5),
        ),
      ),
      body: Column(
        children: [
          Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 8), // Reduced gap
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                CircleAvatar(
                                  backgroundColor: kOrange.withValues(alpha: 0.1),
                                  radius: 24,
                                  child: const HeroIcon(HeroIcons.user, color: kOrange, size: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Text(data['name'] ?? 'Unknown', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kOrange))),
                                IconButton(
                                  icon: const HeroIcon(HeroIcons.pencil, color: kPrimaryColor, size: 24),
                                  onPressed: () => _navigateToEditCustomer(context, data)
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Customer Rating Display
                            _buildRatingSection(data),
                            const Divider(height: 32, color: kGrey100),
                            _buildInfoRow(HeroIcons.phone, "Phone", data['phone'] ?? '--'),
                            const SizedBox(height: 10),
                            _buildInfoRow(HeroIcons.documentText, "GST No", data['gst'] ?? data['gstin'] ?? 'Not Provided'),
                            const SizedBox(height: 10),
                            _buildInfoRow(HeroIcons.mapPin, "Address", data['address'] ?? 'Not Provided'),
                            const SizedBox(height: 10),
                            _buildInfoRow(HeroIcons.receiptPercent, "Default Discount", "${(data['defaultDiscount'] ?? 0).toString()}%"),
                            const SizedBox(height: 10),
                            _buildInfoRow(HeroIcons.cake, "Date of Birth", _formatDOB(data['dob'])),
                            const SizedBox(height: 24),
                            Row(children: [
                              _buildStatBox("Total Sales", totalSales, kGoogleGreen),
                              const SizedBox(width: 12),
                              _buildStatBox("Credit due", balance, kErrorColor),
                            ])
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildMenuItem(
                        context,
                        "Credit History",
                        HeroIcons.bookOpen,
                        color: kOrange,
                        onTap: () {
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (context) => CustomerCreditDetailsPage(
                                customerId: widget.customerId,
                                customerData: widget.customerData,
                                currentBalance: balance,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildMenuItem(context, "Bill History", HeroIcons.banknotes),
                      const SizedBox(height: 10),
                      _buildMenuItem(context, "Payment History", HeroIcons.clock),
                      const SizedBox(height: 10),
                      _buildMenuItem(context, "Ledger Account", HeroIcons.buildingLibrary),
                      const SizedBox(height: 100), // Space for FAB
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
  }

  void _navigateToEditCustomer(BuildContext context, Map<String, dynamic> data) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => AddCustomerPage(
          uid: '',
          isEditMode: true,
          customerId: widget.customerId,
          customerData: data,
        ),
      ),
    ).then((result) {
      if (result == true) {
        setState(() {}); // Refresh
      }
    });
  }

  String _formatDOB(dynamic dob) {
    if (dob == null) return 'Not Provided';
    if (dob is Timestamp) {
      return DateFormat('dd MMM yyyy').format(dob.toDate());
    }
    return 'Not Provided';
  }

  Widget _buildInfoRow(HeroIcons icon, String label, String value) {
    return Row(children: [
      HeroIcon(icon, size: 16, color: kBlack54),
      const SizedBox(width: 10),
      Text("$label: ", style: const TextStyle(color: kBlack54, fontSize: 12, fontWeight: FontWeight.w500)),
      Text(value, style: const TextStyle(color: kBlack87, fontSize: 13, fontWeight: FontWeight.w700)),
    ]);
  }

  Widget _buildStatBox(String lbl, double amt, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.15))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(lbl, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            const SizedBox(height: 6),
            Text("$_currencySymbol${amt.toStringAsFixed(2)}", style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, String title, HeroIcons icon, {Color color = kPrimaryColor, VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
      child: ListTile(
        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)), child: HeroIcon(icon, color: color, size: 20)),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kBlack87)),
        trailing: const HeroIcon(HeroIcons.chevronRight, size: 14, color: kGrey400),
        onTap: onTap ?? () {
          if (title=="Bill History") {
            Navigator.push(context, CupertinoPageRoute(builder: (_) => CustomerBillsPage(phone: widget.customerId)));
          } else if (title.contains("Payment")) Navigator.push(context, CupertinoPageRoute(builder: (_) => CustomerCreditsPage(customerId: widget.customerId)));
          else Navigator.push(context, CupertinoPageRoute(builder: (_) => CustomerLedgerPage(customerId: widget.customerId, customerName: widget.customerData['name'])));
        },
      ),
    );
  }


}

// =============================================================================
// SUB-PAGE: RECEIVE CREDIT FORM
// =============================================================================

class _ReceiveCreditPage extends StatefulWidget {
  final String customerId; final Map<String, dynamic> customerData; final double currentBalance;
  const _ReceiveCreditPage({required this.customerId, required this.customerData, required this.currentBalance});
  @override State<_ReceiveCreditPage> createState() => _ReceiveCreditPageState();
}

class _ReceiveCreditPageState extends State<_ReceiveCreditPage> {
  final TextEditingController _amountController = TextEditingController();
  double _amt = 0.0;
  String _currencySymbol = '';

  @override
  void initState() {
    super.initState();
    _loadCurrency();
  }

  void _loadCurrency() async {
    final store = await FirestoreService().getCurrentStoreDoc();
    if (store != null && store.exists && mounted) {
      final data = store.data() as Map<String, dynamic>;
      setState(() => _currencySymbol = CurrencyService.getSymbolWithSpace(data['currency']));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),title: const Text("Receive Payment", style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)), backgroundColor: kPrimaryColor, centerTitle: true, elevation: 0, iconTheme: const IconThemeData(color: kWhite)),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.customerData['name'] ?? 'Customer', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kOrange)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text("Credit due", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kBlack54)),
              Text("$_currencySymbol${widget.currentBalance.toStringAsFixed(2)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: kErrorColor)),
            ]),
          ),
          const SizedBox(height: 32),
          const Text("Enter Amount Received", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: kBlack54, letterSpacing: 0.5)),
          const SizedBox(height: 12),
          ValueListenableBuilder<TextEditingValue>(
      valueListenable: _amountController,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextField(
            controller: _amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) => setState(() => _amt = double.tryParse(v) ?? 0.0),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: kPrimaryColor),
            decoration: InputDecoration(prefixText: "",
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
          SizedBox(width: double.infinity, height: 60, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              if (_amt <= 0) return;
              final cCol = await FirestoreService().getStoreCollection('customers');
              final crCol = await FirestoreService().getStoreCollection('credits');
              await cCol.doc(widget.customerId).update({'balance': widget.currentBalance - _amt});
              await crCol.add({'customerId': widget.customerId, 'customerName': widget.customerData['name'], 'amount': _amt, 'type': 'payment_received', 'method': 'Cash', 'timestamp': FieldValue.serverTimestamp()});
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Save payment", style: TextStyle(color: kWhite, fontSize: 16, fontWeight: FontWeight.w900)),
          )),
        ]),
      ),
    );
  }
}

// =============================================================================
// SUB-PAGE: RECONCILED LEDGER
// =============================================================================

class LedgerEntry {
  final DateTime date; final String type; final String desc; final double debit; final double credit; final double balanceImpact; double balance;
  LedgerEntry({required this.date, required this.type, required this.desc, required this.debit, required this.credit, this.balanceImpact = 0, this.balance = 0});
}

class CustomerLedgerPage extends StatefulWidget {
  final String customerId; final String customerName;
  const CustomerLedgerPage({super.key, required this.customerId, required this.customerName});
  @override State<CustomerLedgerPage> createState() => _CustomerLedgerPageState();
}

class _CustomerLedgerPageState extends State<CustomerLedgerPage> {
  List<LedgerEntry> _entries = []; bool _loading = true;
  String _currencySymbol = '';

  @override
  void initState() {
    super.initState();
    _loadCurrency();
    _loadLedger();
  }

  void _loadCurrency() async {
    final store = await FirestoreService().getCurrentStoreDoc();
    if (store != null && store.exists && mounted) {
      final data = store.data() as Map<String, dynamic>;
      setState(() => _currencySymbol = CurrencyService.getSymbolWithSpace(data['currency']));
    }
  }

  Future<void> _loadLedger() async {
    final sales = await FirestoreService().getStoreCollection('sales').then((c) => c.where('customerPhone', isEqualTo: widget.customerId).get());
    final credits = await FirestoreService().getStoreCollection('credits').then((c) => c.where('customerId', isEqualTo: widget.customerId).get());
    List<LedgerEntry> entries = [];
    for (var doc in sales.docs) {
      final d = doc.data() as Map<String, dynamic>;
      final date = (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
      final total = (d['total'] ?? 0.0).toDouble();
      final mode = d['paymentMode'] ?? 'Unknown';
      final isCancelled = d['status'] == 'cancelled';
      if (isCancelled) {
        entries.add(LedgerEntry(date: date, type: 'Inv', desc: "Invoice #${d['invoiceNumber']} (CANCELLED)", debit: 0, credit: 0, balanceImpact: 0));
      } else if (mode == 'Cash' || mode == 'Online') {
        // Fully paid sale - sale in debit, no credit used, balance unchanged
        entries.add(LedgerEntry(date: date, type: 'Inv', desc: "Invoice #${d['invoiceNumber']} ($mode)", debit: total, credit: 0, balanceImpact: 0));
      } else if (mode == 'Credit') {
        // Full credit sale - sale in debit, full amount as credit used
        entries.add(LedgerEntry(date: date, type: 'Inv', desc: "Invoice #${d['invoiceNumber']} (Credit)", debit: total, credit: total, balanceImpact: total));
      } else if (mode == 'Split') {
        final cashPaid = (d['cashReceived'] ?? 0.0).toDouble();
        final onlinePaid = (d['onlineReceived'] ?? 0.0).toDouble();
        final creditAmt = total - cashPaid - onlinePaid;
        // Split sale - sale in debit, only credit portion in credit column
        entries.add(LedgerEntry(date: date, type: 'Inv', desc: "Invoice #${d['invoiceNumber']} (Split)", debit: total, credit: creditAmt > 0 ? creditAmt : 0, balanceImpact: creditAmt > 0 ? creditAmt : 0));
      } else {
        entries.add(LedgerEntry(date: date, type: 'Inv', desc: "Invoice #${d['invoiceNumber']}", debit: total, credit: 0, balanceImpact: 0));
      }
    }
    for (var doc in credits.docs) {
      final d = doc.data() as Map<String, dynamic>;
      final date = (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
      final amt = (d['amount'] ?? 0.0).toDouble();
      final type = d['type'] ?? '';
      final method = d['method'] ?? '';
      final isCancelled = d['status'] == 'cancelled';
      
      if (isCancelled) {
        entries.add(LedgerEntry(date: date, type: 'Pay', desc: "Cancelled Payment (${method.isNotEmpty ? method : 'Cash'})", debit: 0, credit: 0, balanceImpact: 0));
      } else if (type == 'payment_received') {
        // Payment received - shows in debit (green), reduces outstanding
        entries.add(LedgerEntry(date: date, type: 'Pay', desc: "Payment Received (${method.isNotEmpty ? method : 'Cash'})", debit: amt, credit: 0, balanceImpact: -amt));
      } else if (type == 'settlement') {
        // Credit received/settled - shows in debit (green), reduces outstanding
        entries.add(LedgerEntry(date: date, type: 'Pay', desc: "Credit Received (${method.isNotEmpty ? method : 'Cash'})", debit: amt, credit: 0, balanceImpact: -amt));
      } else if (type == 'add_credit') {
        // Manual credit added - shows in credit (red), increases outstanding
        entries.add(LedgerEntry(date: date, type: 'CR', desc: "Manual Credit Added", debit: 0, credit: amt, balanceImpact: amt));
      }
      // Note: credit_sale and sale_payment entries are skipped here since they're already tracked via sales collection
    }
    entries.sort((a, b) => a.date.compareTo(b.date));
    double running = 0;
    for (var e in entries) {
      running += e.balanceImpact;
      e.balance = running;
    }
    if (mounted) setState(() { _entries = entries.reversed.toList(); _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWhite,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),title: Text("${widget.customerName} Ledger", style: const TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 16)), backgroundColor: kPrimaryColor, centerTitle: true, elevation: 0, iconTheme: const IconThemeData(color: kWhite)),
      body: _loading ? const Center(child: CircularProgressIndicator(color: kPrimaryColor)) : Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          color: kPrimaryColor.withValues(alpha: 0.05),
          child: const Row(children: [
            Expanded(flex: 2, child: Text("Date", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 0.5))),
            Expanded(flex: 3, child: Text("Particulars", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 0.5))),
            Expanded(flex: 2, child: Text("Debit", textAlign: TextAlign.right, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kGoogleGreen))),
            Expanded(flex: 2, child: Text("Credit", textAlign: TextAlign.right, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kErrorColor))),
            Expanded(flex: 2, child: Text("Balance", textAlign: TextAlign.right, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kBlack54))),
          ]),
        ),
        Expanded(child: ListView.separated(
          itemCount: _entries.length,
          separatorBuilder: (_, __) => const Divider(height: 1, color: kGrey100),
          itemBuilder: (c, i) {
            final e = _entries[i];
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              child: Row(children: [
                Expanded(flex: 2, child: Text(DateFormat('dd/MM/yy').format(e.date), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kBlack87))),
                Expanded(flex: 3, child: Text(e.desc, style: const TextStyle(fontSize: 11, color: kBlack54, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis)),
                Expanded(flex: 2, child: Text(e.debit > 0 ? e.debit.toStringAsFixed(0) : "0", textAlign: TextAlign.right, style: const TextStyle(color: kGoogleGreen, fontSize: 11, fontWeight: FontWeight.w900))),
                Expanded(flex: 2, child: Text(e.credit > 0 ? e.credit.toStringAsFixed(0) : "-", textAlign: TextAlign.right, style: const TextStyle(color: kErrorColor, fontSize: 11, fontWeight: FontWeight.w900))),
                Expanded(flex: 2, child: Text(e.balance.toStringAsFixed(0), textAlign: TextAlign.right, style: const TextStyle(color: kBlack87, fontSize: 12, fontWeight: FontWeight.w900))),
              ]),
            );
          },
        )),
        _buildClosingBar(),
      ]),
    );
  }

  Widget _buildClosingBar() {
    final bal = _entries.isNotEmpty ? _entries.first.balance : 0.0;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        decoration: BoxDecoration(color: kWhite, border: const Border(top: BorderSide(color: kGrey200))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text("Current Closing Balance:", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: kBlack54)),
          Text("$_currencySymbol${bal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kErrorColor)),
        ]),
      ),
    );
  }
}

// =============================================================================
// SUB-PAGE: LIST VIEWS
// =============================================================================

class CustomerBillsPage extends StatelessWidget {
  final String phone; const CustomerBillsPage({super.key, required this.phone});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),title: const Text("Bill History", style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 16)), backgroundColor: kPrimaryColor, elevation: 0, centerTitle: true, iconTheme: const IconThemeData(color: kWhite)),
      body: FutureBuilder<CollectionReference>(
        future: FirestoreService().getStoreCollection('sales'),
        builder: (context, collectionSnap) {
          if (!collectionSnap.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
          return StreamBuilder<QuerySnapshot>(
            stream: collectionSnap.data!.where('customerPhone', isEqualTo: phone).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
              final docs = snapshot.data!.docs.toList();
              if (docs.isEmpty) {
                return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.receipt_long_rounded, size: 64, color: kGrey300),
            const SizedBox(height: 16),
            const Text("No bills found", style: TextStyle(color: kBlack54, fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 4),
            const Text("Bills will appear here once created", style: TextStyle(color: kGrey400, fontSize: 12)),
          ]));
              }
          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aDate = (aData['timestamp'] as Timestamp?)?.toDate() ?? DateTime(1970);
            final bDate = (bData['timestamp'] as Timestamp?)?.toDate() ?? DateTime(1970);
            return bDate.compareTo(aDate);
          });

          // Summary header
          double totalAmount = 0;
          int creditCount = 0;
          int validBillCount = 0;
          for (var doc in docs) {
            final d = doc.data() as Map<String, dynamic>;
            if (d['status'] != 'cancelled') {
              validBillCount++;
              totalAmount += (d['total'] ?? 0.0).toDouble();
              final mode = d['paymentMode'] ?? 'Cash';
              if (mode == 'Credit' || mode == 'Split') creditCount++;
            }
          }

          return Column(
            children: [
              // Summary bar
              Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kPrimaryColor.withOpacity(0.12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text("$validBillCount Bills", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: kPrimaryColor)),
                      if (creditCount > 0) Text("$creditCount on credit", style: const TextStyle(fontSize: 11, color: kErrorColor, fontWeight: FontWeight.w600)),
                    ]),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      const Text("Total", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kBlack54, letterSpacing: 0.5)),
                      Text(totalAmount.toStringAsFixed(2), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kBlack87)),
                    ]),
                  ],
                ),
              ),
              // Bill list
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final date = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
                    final paymentMode = data['paymentMode'] ?? 'Cash';
                    final total = (data['total'] ?? 0.0).toDouble();
                    final cashReceived = (data['cashReceived'] ?? 0.0).toDouble();
                    final onlineReceived = (data['onlineReceived'] ?? 0.0).toDouble();
                    final isCancelled = data['status'] == 'cancelled';

                    double creditAmount = 0;
                    if (paymentMode == 'Credit') {
                      creditAmount = total;
                    } else if (paymentMode == 'Split') {
                      creditAmount = total - cashReceived - onlineReceived;
                      if (creditAmount < 0) creditAmount = 0;
                    }

                    Color color = isCancelled ? Colors.grey : (paymentMode == 'Cash' ? kGoogleGreen : paymentMode == 'Online' ? kPrimaryColor : paymentMode == 'Credit' ? kOrange : (creditAmount > 0 ? kOrange : Colors.purple));
                    HeroIcons icon = paymentMode == 'Cash' ? HeroIcons.banknotes : paymentMode == 'Online' ? HeroIcons.qrCode : paymentMode == 'Credit' ? HeroIcons.bookOpen : HeroIcons.arrowsRightLeft;

                    String subtitle = "${DateFormat('dd MMM yyyy').format(date)} • $paymentMode";
                    if (isCancelled) {
                      subtitle += " • CANCELLED";
                    } else if (creditAmount > 0) {
                      subtitle += " • Credit: ${creditAmount.toStringAsFixed(2)}";
                    }

                    return Container(
                      decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: isCancelled ? Colors.transparent : kGrey200)),
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.1), radius: 18, child: HeroIcon(icon, color: color, size: 16)),
                        title: Text("Invoice #${data['invoiceNumber']}", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: kBlack87)),
                        subtitle: Text(subtitle, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isCancelled ? Colors.grey : (creditAmount > 0 ? kErrorColor : kBlack54))),
                        trailing: Text(total.toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: color, decoration: isCancelled ? TextDecoration.lineThrough : null)),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
            },
          );
        },
      ),
    );
  }
}

class CustomerCreditsPage extends StatelessWidget {
  final String customerId; const CustomerCreditsPage({super.key, required this.customerId});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),title: const Text("Payment History", style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 16)), backgroundColor: kPrimaryColor, elevation: 0, centerTitle: true, iconTheme: const IconThemeData(color: kWhite)),
      body: FutureBuilder<CollectionReference>(
        future: FirestoreService().getStoreCollection('credits'),
        builder: (context, collectionSnap) {
          if (!collectionSnap.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
          return StreamBuilder<QuerySnapshot>(
            stream: collectionSnap.data!.where('customerId', isEqualTo: customerId).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const HeroIcon(HeroIcons.clock, size: 64, color: kGrey300), const SizedBox(height: 16), const Text("No transaction history", style: TextStyle(color: kBlack54,fontWeight: FontWeight.bold))]));
              final docs = snapshot.data!.docs.toList();
              docs.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;
                final aDate = (aData['timestamp'] as Timestamp?)?.toDate() ?? DateTime(1970);
                final bDate = (bData['timestamp'] as Timestamp?)?.toDate() ?? DateTime(1970);
                return bDate.compareTo(aDate);
              });
          return ListView.separated(
            padding: const EdgeInsets.all(16), itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final type = data['type'] ?? '';
              final isCancelled = data['status'] == 'cancelled';
              bool isPaymentReceived = type == 'payment_received';
              bool isCreditSale = type == 'credit_sale';
              bool isSalePayment = type == 'sale_payment';
              bool isSettlement = type == 'settlement';
              bool isAddCredit = type == 'add_credit';
              final date = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
              final method = data['method'] ?? 'Manual';
              final amount = (data['amount'] ?? 0.0).toDouble();
              final note = data['note'] ?? '';
              final bool isSplit = note.toString().contains('Split');

              String title;
              Color color;
              HeroIcons icon;

              if (isCancelled) {
                title = "Cancelled Payment";
                color = Colors.grey;
                icon = HeroIcons.xCircle;
              } else if (isPaymentReceived) {
                title = "Payment Received";
                color = kGoogleGreen;
                icon = HeroIcons.arrowDown;
              } else if (isSettlement) {
                title = "Credit Received";
                color = kGoogleGreen;
                icon = HeroIcons.arrowDown;
              } else if (isSalePayment) {
                title = isSplit ? "Split Payment" : "Sale Payment";
                color = isSplit ? Colors.purple : kGoogleGreen;
                icon = isSplit ? HeroIcons.arrowsRightLeft : HeroIcons.shoppingBag;
              } else if (isCreditSale) {
                title = isSplit ? "Split Credit" : "Credit Sale";
                color = kOrange;
                icon = HeroIcons.banknotes;
              } else if (isAddCredit) {
                title = "Manual Credit";
                color = kOrange;
                icon = HeroIcons.arrowUp;
              } else {
                title = "Credit Added";
                color = kOrange;
                icon = HeroIcons.arrowUp;
              }

              final customerName = (data['customerName'] ?? customerId).toString();
              final invoiceNum = (data['invoiceNumber'] ?? '').toString();
              final receiptNum = (data['receiptNumber'] ?? '').toString();
              final dateStr = DateFormat('dd MMM yyyy').format(date);

              // Build share message
              final String shareMsg = _buildShareMessage(
                title: title,
                customerName: customerName,
                amount: amount,
                date: dateStr,
                method: method.toString(),
                invoiceNumber: invoiceNum,
                receiptNumber: receiptNum,
                note: note.toString(),
              );

              return Container(
                decoration: BoxDecoration(
                  color: kWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isCancelled ? Colors.transparent : kGrey200),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        backgroundColor: color.withValues(alpha: 0.1),
                        radius: 18,
                        child: HeroIcon(icon, color: color, size: 16),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: isCancelled ? Colors.grey : kBlack87,
                                    decoration: isCancelled ? TextDecoration.lineThrough : null)),
                            const SizedBox(height: 2),
                            Text(
                              "$dateStr • $method${invoiceNum.isNotEmpty ? ' • #$invoiceNum' : ''}",
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: kBlack54),
                            ),
                            if (receiptNum.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Receipt No: $receiptNum',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF4A5DF9)),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            amount.toStringAsFixed(2),
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: isCancelled ? Colors.grey : color,
                                decoration: isCancelled ? TextDecoration.lineThrough : null),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // WhatsApp direct share
                              Builder(builder: (ctx) {
                                final cleanPhone = customerId.replaceAll(RegExp(r'[\s\-+()]'), '');
                                final hasPhone = RegExp(r'^\d{7,15}$').hasMatch(cleanPhone);
                                if (!hasPhone) return const SizedBox.shrink();
                                return GestureDetector(
                                  onTap: () async {
                                    final waUrl = Uri.parse(
                                        'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(shareMsg)}');
                                    if (await canLaunchUrl(waUrl)) {
                                      await launchUrl(waUrl, mode: LaunchMode.externalApplication);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF25D366).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF25D366).withOpacity(0.3)),
                                    ),
                                    child: const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 15),
                                  ),
                                );
                              }),
                              const SizedBox(width: 5),
                              // General share
                              GestureDetector(
                                onTap: () => Share.share(shareMsg, subject: '$title – $customerName'),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: kPrimaryColor.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: kPrimaryColor.withOpacity(0.25)),
                                  ),
                                  child: const Icon(Icons.share_rounded, color: kPrimaryColor, size: 15),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
            },
          );
        },
      ),
    );
  }

  String _buildShareMessage({
    required String title,
    required String customerName,
    required double amount,
    required String date,
    required String method,
    required String invoiceNumber,
    required String receiptNumber,
    required String note,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('--- $title ---');
    buffer.writeln('Customer : $customerName');
    buffer.writeln('Date     : $date');
    buffer.writeln('Amount   : $amount');
    if (method.isNotEmpty) buffer.writeln('Method   : $method');
    if (invoiceNumber.isNotEmpty) buffer.writeln('Invoice  : #$invoiceNumber');
    if (receiptNumber.isNotEmpty) buffer.writeln('Receipt  : $receiptNumber');
    if (note.isNotEmpty && note != 'null') buffer.writeln('Note     : $note');
    return buffer.toString().trim();
  }
}
