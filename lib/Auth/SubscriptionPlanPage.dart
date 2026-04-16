import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:provider/provider.dart';
import 'package:heroicons/heroicons.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/utils/plan_provider.dart';
import 'package:maxbillup/Colors.dart';
import 'package:maxbillup/Auth/PlanComparisonPage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


class SubscriptionPlanPage extends StatefulWidget {
  final String uid;
  final String currentPlan;

  const SubscriptionPlanPage({
    super.key,
    required this.uid,
    required this.currentPlan,
  });

  @override
  State<SubscriptionPlanPage> createState() => _SubscriptionPlanPageState();
}

class _SubscriptionPlanPageState extends State<SubscriptionPlanPage> {
  Razorpay? _razorpay;
  String _selectedPlan = 'MAX Plus';
  int _selectedDuration = 1; // 1 or 12 months
  bool _isPaymentInProgress = false;

  // Subscription state (loaded from store document)
  DateTime? _currentStartDate;
  DateTime? _currentExpiryDate;
  bool _subscriptionLoaded = false;

  DateTime? _tryParseDate(dynamic v) {
    try {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString());
    } catch (_) {
      return null;
    }
  }

  int _daysBetween(DateTime a, DateTime b) {
    final start = DateTime.utc(a.year, a.month, a.day);
    final end = DateTime.utc(b.year, b.month, b.day);
    return end.difference(start).inDays;
  }

  int get _selectedPlanRank {
    return (plans.firstWhere(
          (p) => p['name'] == _selectedPlan,
          orElse: () => plans[1],
        )['rank'] as int?) ?? 0;
  }

  int get _currentPlanRank {
    final currentPlanLower = widget.currentPlan.toLowerCase();
    final matching = plans.firstWhere(
      (p) => p['name'].toString().toLowerCase() == currentPlanLower,
      orElse: () => plans[0],
    );
    return (matching['rank'] as int?) ?? 0;
  }

  bool get _isUpgrade => _selectedPlanRank > _currentPlanRank;
  bool get _isExtend => _selectedPlanRank == _currentPlanRank;

  final List<Map<String, dynamic>> plans = [
    {
      'name': 'Starter',
      'rank': 0,
      'price': {'1': 0, '12': 0},
      'icon': HeroIcons.rocketLaunch,
      'themeColor': kOrange,
      'staffText': '1 Admin Account',
      'included': [
        'POS Billing',
        'Purchases',
        'Expenses',
        'Credit Sales',
        'Cloud Backup',
        'Unlimited Products',
        'Bill History (upto 15 days)',
      ],
      'excluded': [
        'Edit Bill',
        'Reports',
        'Tax Reports',
        'Quotation / Estimation',
        'Import Customers',
        'Support',
        'Customer Dues',
        'Bulk Product Upload',
        'Logo on Bill',
        'Remove Watermark',
      ],
    },
    {
      'name': 'MAX One',
      'rank': 1,
      'price': {'1': 299, '12': 2499},
      'icon': HeroIcons.briefcase,
      'themeColor': kPrimaryColor,
      'staffText': '1 Admin Account',
      'included': [
        'POS Billing',
        'Purchases',
        'Expenses',
        'Credit Sales',
        'Cloud Backup',
        'Unlimited Products',
        'Bill History (Unlimited)',
        'Edit Bill',
        'Reports',
        'Tax Reports',
        'Quotation / Estimation',
        'Import Customers',
        'Support',
        'Customer Dues',
        'Bulk Product Upload',
        'Logo on Bill',
        'Remove Watermark',
      ],
      'excluded': [
        'Multiple Staff Accounts',
      ],
    },
    {
      'name': 'MAX Plus',
      'rank': 2,
      'price': {'1': 449, '12': 3999},
      'icon': HeroIcons.chartBar,
      'themeColor': Colors.purple,
      'popular': true,
      'staffText': 'Admin + 2 Users',
      'included': [
        'POS Billing',
        'Purchases',
        'Expenses',
        'Credit Sales',
        'Cloud Backup',
        'Unlimited Products',
        'Bill History (Unlimited)',
        'Edit Bill',
        'Reports',
        'Tax Reports',
        'Quotation / Estimation',
        'Import Customers',
        'Support',
        'Customer Dues',
        'Bulk Product Upload',
        'Logo on Bill',
        'Remove Watermark',
      ],
      'excluded': [
        // 'Up to 9 Staff Accounts',
      ],
    },
    {
      'name': 'MAX Pro',
      'rank': 3,
      'price': {'1': 599, '12': 5499},
      'icon': HeroIcons.academicCap,
      'themeColor': kGoogleGreen,
      'staffText': 'Admin + 9 Users',
      'included': [
        'POS Billing',
        'Purchases',
        'Expenses',
        'Credit Sales',
        'Cloud Backup',
        'Unlimited Products',
        'Bill History (Unlimited)',
        'Edit Bill',
        'Reports',
        'Tax Reports',
        'Quotation / Estimation',
        'Import Customers',
        'Support',
        'Customer Dues',
        'Bulk Product Upload',
        'Logo on Bill',
        'Remove Watermark',
      ],
      'excluded': [],
    },
  ];

  @override
  void initState() {
    super.initState();
    _setupRazorpay();
    _loadSubscriptionFromStore();
    // Default to 'MAX One' if current plan is Starter or Free or not found
    final currentPlanLower = widget.currentPlan.toLowerCase();
    if (currentPlanLower.contains('starter') || currentPlanLower.contains('free')) {
      _selectedPlan = 'MAX One';
    } else {
      // Try to find matching plan (case-insensitive)
      final matchingPlan = plans.firstWhere(
            (p) => p['name'].toString().toLowerCase() == currentPlanLower,
        orElse: () => plans[1], // Default to MAX One
      );
      _selectedPlan = matchingPlan['name'];
    }
  }

  Future<void> _loadSubscriptionFromStore() async {
    try {
      final storeDoc = await FirestoreService().getCurrentStoreDoc();
      if (storeDoc != null && storeDoc.exists) {
        final data = storeDoc.data() as Map<String, dynamic>;
        final start = _tryParseDate(data['subscriptionStartDate']);
        final exp = _tryParseDate(data['subscriptionExpiryDate']);
        if (mounted) {
          setState(() {
            _currentStartDate = start;
            _currentExpiryDate = exp;
            _subscriptionLoaded = true;
          });
        }
        return;
      }
    } catch (e) {
      debugPrint('Error loading subscription: $e');
    }
    if (mounted) {
      setState(() {
        _subscriptionLoaded = true;
      });
    }
  }

  void _setupRazorpay() {
    try {
      if (_razorpay != null) {
        _razorpay!.clear();
      }
      _razorpay = Razorpay();
      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
      _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    } catch (e) {
      debugPrint('Error setting up Razorpay: $e');
    }
  }

  @override
  void dispose() {
    try {
      _razorpay?.clear();
    } catch (e) {
      debugPrint('Error disposing Razorpay: $e');
    }
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    _showSuccessAndPop(response.paymentId ?? 'TXN_SUCCESS');
  }

  void _showSuccessAndPop(String paymentId) async {
    final now = DateTime.now();
    // Extend: add duration on top of current expiry (or now if expired/missing)
    // Upgrade: new cycle starts today.
    DateTime baseDate;
    if (_isExtend) {
      final exp = _currentExpiryDate;
      if (exp != null && exp.isAfter(now)) {
        baseDate = exp;
      } else {
        baseDate = now;
      }
    } else {
      baseDate = now;
    }
    DateTime expiryDate = DateTime(baseDate.year, baseDate.month + _selectedDuration, baseDate.day);

    final DateTime startDate = _isExtend
        ? (_currentStartDate ?? now)
        : now;

    final storeDoc = await FirestoreService().getCurrentStoreDoc();
    if (storeDoc == null) return;

    // Update Firestore with new subscription
    await FirestoreService().storeCollection.doc(storeDoc.id).update({
      'plan': _selectedPlan,
      'subscriptionStartDate': startDate.toIso8601String(),
      'subscriptionExpiryDate': expiryDate.toIso8601String(),
      'billingCycleMonths': _selectedDuration,
      'paymentId': paymentId,
      'lastPaymentDate': now.toIso8601String(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // IMPORTANT: Force refresh the PlanProvider to reflect changes instantly
    if (mounted) {
      // Get the PlanProvider and force immediate refresh
      final planProvider = Provider.of<PlanProvider>(context, listen: false);

      // This will immediately update the cached plan and notify ALL listeners
      await planProvider.forceRefresh();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("🎉 ${context.tr('Plan Upgrade Successful')}"),
          backgroundColor: kGoogleGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      // Return true to indicate subscription changed - parent screens can refresh if needed
      Navigator.of(context).pop(true);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (mounted) setState(() => _isPaymentInProgress = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.tr('payment_failed')}: ${response.message ?? "Unknown error"}'),
          backgroundColor: kErrorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {}

  void _startPayment() async {
    if (_isPaymentInProgress) return;
    
    setState(() => _isPaymentInProgress = true);
    
    // Show immediate feedback to the user
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Preparing payment interface...')),
          duration: const Duration(seconds: 2),
          backgroundColor: kPrimaryColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    
    // 1. FRESH SETUP: Essential to prevent background process hangs


    if (_razorpay == null) {
      setState(() => _isPaymentInProgress = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Payment service unavailable'))),
        );
      }
      return;
    }

    // Get current plan data
    final plan = plans.firstWhere(
      (p) => p['name'] == _selectedPlan,
      orElse: () => plans[1],
    );

    final int targetPrice = (plan['price'][_selectedDuration.toString()] ?? 0) as int;

    // Proration: if upgrading mid-cycle, apply credit for remaining days of current plan.
    int payablePrice = targetPrice;
    if (_isUpgrade) {
      final currentPlanLower = widget.currentPlan.toLowerCase();
      final currentPlanData = plans.firstWhere(
        (p) => p['name'].toString().toLowerCase() == currentPlanLower,
        orElse: () => plans[0],
      );
      final int currentPrice = (currentPlanData['price'][_selectedDuration.toString()] ?? 0) as int;

      final now = DateTime.now();
      final start = _currentStartDate;
      final exp = _currentExpiryDate;

      // If we don't have dates, skip credit (security-first and avoids wrong charges).
      if (start != null && exp != null && exp.isAfter(now) && exp.isAfter(start) && currentPrice > 0) {
        final cycleDays = _daysBetween(start, exp);
        final remainingDays = _daysBetween(now, exp);
        if (cycleDays > 0 && remainingDays > 0) {
          final credit = (currentPrice * (remainingDays / cycleDays));
          payablePrice = (targetPrice - credit).ceil();
          if (payablePrice < 0) payablePrice = 0;
        }
      }
    }

    final int amount = (payablePrice * 100).toInt();
    if (amount <= 0) {
      _showSuccessAndPop('FREE_ACTIVATION');
      setState(() => _isPaymentInProgress = false);
      return;
    }

    // Fetch store details
    String storeName = 'StockSphere';
    String contactEmail = 'stocksphere@gmail.com';
    String contactPhone = '';
    String? dynamicKey;

    try {
      final storeDoc = await FirestoreService().getCurrentStoreDoc();
      if (storeDoc != null && storeDoc.exists) {
        final data = storeDoc.data() as Map<String, dynamic>;
        storeName = data['businessName'] ?? storeName;
        contactEmail = data['ownerEmail'] ?? contactEmail;
        contactPhone = data['ownerPhone'] ?? '';
        dynamicKey = data['razorpayKey'];
      }
    } catch (e) {
      debugPrint('Error fetching store details: $e');
    }

    // ENSURE KEY FORMAT: Razorpay loader hangs if the key has spaces or invalid prefix
    // ✅ Replace with:
    final String fallbackKey = dotenv.env['RAZORPAY_KEY'] ?? '';
    final String baseKey = (dynamicKey?.isNotEmpty == true
        ? dynamicKey!
        : fallbackKey).trim();
    final String razorpayKey = baseKey.startsWith('rzp_') ? baseKey : 'rzp_live_$baseKey';
    // SUPER-LIGHTWEIGHT OPTIONS: 
    // Removing 'modal', 'timeout', and 'backdrop' to prevent the "Null anb" GPU errors
    var options = {
      'key': razorpayKey,
      'amount': amount,
      'currency': 'INR',
      'name': storeName.length > 20 ? storeName.substring(0, 20) : storeName,
      'description': 'Plan: $_selectedPlan',
      'prefill': {
        'contact': contactPhone.isNotEmpty ? contactPhone : '9999999999',
        'email': contactEmail.isNotEmpty ? contactEmail : 'customer@maxmybill.com',
      },
      'theme': {
        'color': '#2F7CF6'
      },
      'retry': {
        'enabled': true,
        'max_count': 1
      },
      'send_sms_hash': true
    };

    try {
      debugPrint('Launching Ultra-Light Razorpay Interface...');
      _razorpay!.open(options);
    } catch (e) {
      debugPrint('Razorpay Opening Error: $e');
    } finally {
      // Small delay before allowing another click to ensure UI is stable
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _isPaymentInProgress = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedPlanData = plans.firstWhere(
          (p) => p['name'] == _selectedPlan,
      orElse: () => plans[1], // Default to MAX One
    );
    final currentPrice = selectedPlanData['price'][_selectedDuration.toString()] ?? 0;
    final bool isCurrentPlanActive = _selectedPlan.toLowerCase() == widget.currentPlan.toLowerCase();

    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const HeroIcon(HeroIcons.arrowLeft, color: kWhite, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.tr('Subscription Plans'),
          style: const TextStyle(color: kWhite, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildHorizontalPlanSelector(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _buildComparePlansButton(),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  _buildSectionLabel("Choose Billing Cycle"),
                  const SizedBox(height: 8),
                  _buildDurationSelector(),
                  const SizedBox(height: 24),
                  // Not Included first
                  if (selectedPlanData['excluded'].isNotEmpty)
                    _buildFeatureContainer(
                      title: "Not Included",
                      features: selectedPlanData['excluded'],
                      color: kErrorColor,
                      icon: HeroIcons.xCircle,
                      isExcluded: true,
                    ),
                  if (selectedPlanData['excluded'].isNotEmpty)
                    const SizedBox(height: 16),
                  // What's Included second
                  _buildFeatureContainer(
                    title: "What's Included",
                    features: selectedPlanData['included'],
                    staffText: selectedPlanData['staffText'],
                    color: selectedPlanData['themeColor'] as Color? ?? kGoogleGreen,
                    icon: HeroIcons.checkCircle,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          _buildCheckoutBottom(currentPrice, isCurrentPlanActive),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 1.0)),
  );

  Widget _buildHorizontalPlanSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      color: kWhite,
      child: Row(
        children: plans.map((plan) {
          final isSelected = _selectedPlan == plan['name'];
          final isCurrent = widget.currentPlan.toLowerCase() == plan['name'].toString().toLowerCase();
          final themeColor = plan['themeColor'] as Color? ?? kPrimaryColor;
          
          final currentPrice = plan['price'][_selectedDuration.toString()] ?? 0;
          final String durationLabel = currentPrice == 0 ? "Forever" : "/${_selectedDuration == 12 ? 'year' : 'month'}";
          final String priceLabel = currentPrice == 0 ? "Free" : "$currentPrice";

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedPlan = plan['name']),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
                decoration: BoxDecoration(
                  color: isSelected ? themeColor.withOpacity(0.05) : kWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? themeColor : kGrey200,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected 
                      ? [BoxShadow(color: themeColor.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 4))]
                      : [],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Status Badge
                    Container(
                      height: 14,
                      alignment: Alignment.center,
                      child: isCurrent 
                        ? Text("Current", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: kGoogleGreen, letterSpacing: 0.5))
                        : (plan['popular'] == true 
                            ? Text("Popular", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: kOrange, letterSpacing: 0.5))
                            : null),
                    ),
                    const SizedBox(height: 6),
                    HeroIcon(
                      plan['icon'] as HeroIcons, 
                      color: isSelected ? themeColor : Colors.black,
                      size: 22
                    ),
                    const SizedBox(height: 8),
                    Text(
                      plan['name'],
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: isSelected ? themeColor : kBlack87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      priceLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? themeColor : kBlack87,
                      ),
                    ),
                    Text(
                      durationLabel,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: kBlack54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDurationSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7E6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.access_time_outlined, color: Colors.green, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                    children: [
                      TextSpan(text: "Limited Time Offer: "),
                      TextSpan(text: "Extra savings on yearly plans!", style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 56,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: kWhite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kGrey200),
          ),
          child: Row(
            children: [
              _durationToggleItem("Monthly", 1),
              _durationToggleItem("Yearly", 12, badge: "Save up to 30%"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _durationToggleItem(String label, int duration, {String? badge}) {
    bool isActive = _selectedDuration == duration;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedDuration = duration),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isActive ? kPrimaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isActive ? kWhite : kBlack54,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
              if (badge != null )
                Text(
                  badge,
                  style: const TextStyle(color: Color(0xFFE0B646), fontSize: 8, fontWeight: FontWeight.w900),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureContainer({
    required String title,
    required List<dynamic> features,
    String? staffText,
    required Color color,
    required HeroIcons icon,
    bool isExcluded = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HeroIcon(icon, color: color, size: 18),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!isExcluded && staffText != null)
            _buildFeatureRow(staffText, kPrimaryColor, HeroIcons.users),

          ...features.map((feature) => _buildFeatureRow(
              feature,
              kBlack87,
              isExcluded ? HeroIcons.minusCircle : HeroIcons.checkCircle
          )),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(String text, Color textColor, HeroIcons icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HeroIcon(icon, color: textColor.withOpacity(0.3), size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparePlansButton() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PlanComparisonPage(),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: kPrimaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kPrimaryColor.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const HeroIcon(HeroIcons.arrowsRightLeft, color: kPrimaryColor, size: 22),
            const SizedBox(width: 12),
            const Text(
              'Compare ALL Plans',
              style: TextStyle(
                color: kPrimaryColor,
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            const HeroIcon(HeroIcons.chevronRight, color: kPrimaryColor, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckoutBottom(int price, bool isCurrent) {
    final currentPlanData = plans.firstWhere(
            (p) => p['name'].toString().toLowerCase() == widget.currentPlan.toLowerCase(),
        orElse: () => plans[0]
    );
    final selectedPlanData = plans.firstWhere(
          (p) => p['name'] == _selectedPlan,
      orElse: () => plans[1], // Default to MAX Plus
    );
    final themeColor = selectedPlanData['themeColor'] as Color? ?? kPrimaryColor;
    final bool isUpgrade = selectedPlanData['rank'] > currentPlanData['rank'];
    final bool isExtend = selectedPlanData['rank'] == currentPlanData['rank'];

    int payablePrice = price;
    double appliedCredit = 0;
    int cycleDays = 0;
    int remainingDays = 0;
    if (isUpgrade) {
      // Apply remaining-day credit from current plan when possible.
      final now = DateTime.now();
      final start = _currentStartDate;
      final exp = _currentExpiryDate;
      final int currentPrice = (currentPlanData['price'][_selectedDuration.toString()] ?? 0) as int;
      if (start != null && exp != null && exp.isAfter(now) && exp.isAfter(start) && currentPrice > 0) {
        cycleDays = _daysBetween(start, exp);
        remainingDays = _daysBetween(now, exp);
        if (cycleDays > 0 && remainingDays > 0) {
          final credit = (currentPrice * (remainingDays / cycleDays));
          appliedCredit = credit;
          payablePrice = (price - credit).ceil();
          if (payablePrice < 0) payablePrice = 0;
        }
      }
    }

    String buttonText;
    bool isEnabled;

    if (isCurrent) {
      // Extend current plan (renew)
      buttonText = isExtend ? (_isPaymentInProgress ? "PROCESSING..." : "Extend Plan") : "Active Plan";
      isEnabled = isExtend && _subscriptionLoaded && !_isPaymentInProgress;
    } else if (isUpgrade) {
      // Block upgrades until we load subscription dates (to avoid wrong proration).
      final canProceed = _subscriptionLoaded;
      buttonText = !canProceed
          ? "LOADING..."
          : (_isPaymentInProgress ? "PROCESSING..." : "Upgrade Now");
      isEnabled = canProceed && !_isPaymentInProgress;
    } else {
      buttonText = "Locked";
      isEnabled = false;
    }

    final bool isYearly = _selectedDuration == 12;
    final double dailyPrice = payablePrice > 0 ? (isYearly ? payablePrice / 365.0 : payablePrice / 30.0) : 0;
    final String dailyPriceStr = dailyPrice < 10 ? dailyPrice.toStringAsFixed(1) : dailyPrice.toStringAsFixed(0);
    
    final int monthlyPrice = selectedPlanData['price']['1'] ?? 0;
    final int yearlyTotalIfMonthly = monthlyPrice * 12;
    final int savings = isYearly ? yearlyTotalIfMonthly - price : 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: const BoxDecoration(
        color: kWhite,
        border: Border(top: BorderSide(color: kGrey200, width: 1.5)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isYearly && price > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: kGoogleGreen, size: 16),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        "Serious business owners choose yearly",
                        style: TextStyle(fontSize: 12, color: kBlack87, fontWeight: FontWeight.w600),
                      )
                    ),
                    Text(
                      "Save $savings",
                      style: const TextStyle(fontSize: 12, color: kGoogleGreen, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            if (isUpgrade && appliedCredit > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    const Icon(Icons.discount_outlined, color: kGoogleGreen, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Credit for remaining $remainingDays/$cycleDays days", 
                        style: const TextStyle(fontSize: 12, color: kBlack87, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      "-₹${appliedCredit.toStringAsFixed(0)}",
                      style: const TextStyle(fontSize: 12, color: kGoogleGreen, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isYearly ? "TOTAL (YEARLY)" : "TOTAL (MONTHLY)", style: const TextStyle(color: kBlack54, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5)),
                      const SizedBox(height: 2),
                      Text("$payablePrice", style: TextStyle(color: themeColor, fontSize: 24, fontWeight: FontWeight.w900)),
                      if (payablePrice > 0) ...[
                        const SizedBox(height: 2),
                        Text("Only $dailyPriceStr per day", style: const TextStyle(color: kBlack54, fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: isEnabled ? _startPayment : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        disabledBackgroundColor: kGreyBg,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: isEnabled
                            ? BorderSide.none
                            : const BorderSide(color: kGrey200),
                      ),
                      child: Text(
                        buttonText,
                        style: TextStyle(
                            color: isEnabled ? kWhite : kBlack54,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
