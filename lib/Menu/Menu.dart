import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:maxbillup/Colors.dart';
import 'package:provider/provider.dart';
import 'package:maxbillup/Auth/SubscriptionPlanPage.dart';
import 'package:maxbillup/Sales/Bill.dart';
import 'package:maxbillup/Sales/Invoice.dart';
import 'package:maxbillup/Sales/QuotationsList.dart';
import 'package:maxbillup/Menu/CustomerManagement.dart';
import 'package:maxbillup/Menu/AddCustomer.dart';
import 'package:maxbillup/Menu/SettleManualCredit.dart';
import 'package:maxbillup/Menu/KnowledgePage.dart';
import 'package:maxbillup/components/common_bottom_nav.dart';
import 'package:maxbillup/models/cart_item.dart';
import 'package:maxbillup/services/cart_service.dart';
import 'package:maxbillup/services/currency_service.dart';
import 'package:maxbillup/services/number_generator_service.dart';
import 'package:maxbillup/services/payment_receipt_printer.dart';
import 'package:maxbillup/Receipts/PaymentReceiptPage.dart';
import 'package:maxbillup/Sales/Invoice.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:maxbillup/Stocks/StockPurchase.dart';
import 'package:maxbillup/Stocks/ExpenseCategories.dart';
import 'package:maxbillup/Stocks/Expenses.dart';
import 'package:maxbillup/Stocks/Vendors.dart';
import 'package:maxbillup/Settings/StaffManagement.dart' hide kPrimaryColor, kErrorColor;
import 'package:maxbillup/Reports/Reports.dart' hide kPrimaryColor;
import 'package:maxbillup/Stocks/Stock.dart';
import 'package:maxbillup/Settings/Profile.dart'; // For SettingsPage
import 'package:maxbillup/utils/permission_helper.dart';
import 'package:maxbillup/utils/plan_permission_helper.dart';
import 'package:maxbillup/utils/plan_provider.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/ledger_helper.dart';
import 'package:maxbillup/utils/amount_formatter.dart';
import 'package:maxbillup/Sales/NewSale.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/services/number_generator_service.dart';
import 'package:share_plus/share_plus.dart';
// ignore: uri_does_not_exist
import 'package:url_launcher/url_launcher.dart' as launcher;
import 'package:heroicons/heroicons.dart';

import '../Sales/components/common_widgets.dart';
import 'package:maxbillup/Sales/nq.dart';

/// A [MaterialPageRoute] with zero transition duration — prevents the black
/// flash that occurs when [PageRouteBuilder] has no background set.
class _NoAnimRoute<T> extends MaterialPageRoute<T> {
  _NoAnimRoute({required super.builder});
  @override
  Duration get transitionDuration => Duration.zero;
  @override
  Duration get reverseTransitionDuration => Duration.zero;
  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) => child;
}

// ==========================================
// VIDEO TUTORIAL PAGE
// ==========================================
class MenuPage extends StatefulWidget {
  final String uid;
  final String? userEmail;

  const MenuPage({super.key, required this.uid, this.userEmail});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  String? _currentView;
  String _businessName = "Loading...";
  String _email = "";
  String _role = "staff";
  String? _logoUrl;
  String _currencySymbol = 'Rs ';
  Map<String, dynamic> _permissions = {};
  Stream<int>? _overdueCounterStream;

  bool get _isOwner => _role.toLowerCase() == 'owner';

  /// Banner visibility rules:
  /// - #0 Upgrade: always visible
  /// - #1 Update Now (DayBook): requires DayBook access (owner OR daybook permission)
  /// - #2 Start Billing (Staff Access & Roles): owner only
  /// - #3 View Report (View Credit): owner only
  bool get _canAccessDayBook => _isOwner || _hasPermission('daybook');

  List<String> get _visibleBannerImages {
    // Security-first: do NOT show permission-gated banners until permissions are loaded.
    // This prevents staff briefly seeing banners they don't have access to.
    if (!_permissionsLoaded) return const <String>[];

    final images = <String>[_bannerImages[0]];
    if (_canAccessDayBook) images.add(_bannerImages[1]);
    if (_isOwner) {
      images.add(_bannerImages[2]);
      images.add(_bannerImages[3]);
    }

    return images;
  }

  bool _canSeeAnyExpensesGroup({required bool isAdmin, required bool isFullyLoaded}) {
    // Security-first: do not show until permissions + plan are loaded.
    if (!isFullyLoaded) return false;
    if (isAdmin) return true;
    return _hasPermission('expenses') ||
        _hasPermission('expenseCategories') ||
        _hasPermission('stockPurchase') ||
        _hasPermission('vendors');
  }

  // Slider State
  final PageController _headerController = PageController();
  int _currentHeaderIndex = 0;
  Timer? _sliderTimer;

  // Banner Images List
  final List<String> _bannerImages = [
    'assets/Upgrade_Now.png',
    'assets/Update_Now.png',
    'assets/Start_Billing.png',
    'assets/View_Report.png',
  ];

     StreamSubscription<DocumentSnapshot>? _userSubscription;
     StreamSubscription<DocumentSnapshot>? _storeSubscription;
     bool _permissionsLoaded = false; // track when permissions are loaded to avoid flicker of locks

  @override
  void initState() {
    super.initState();
    _email = widget.userEmail ?? "";
    _initFastFetch();
    _loadPermissions();
    _initStoreLogo();
    _startHeaderSlider();
    _initOverdueCounter();
  }

  void _initOverdueCounter() async {
    final storeId = await FirestoreService().getCurrentStoreId();
    if (storeId == null || !mounted) return;

    setState(() {
      _overdueCounterStream = FirebaseFirestore.instance
          .collection('store')
          .doc(storeId)
          .collection('credits')
          .where('type', isEqualTo: 'credit_sale')
          .where('isSettled', isEqualTo: false)
          .snapshots()
          .map((snapshot) {
            final now = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
            // Count unique customers with overdue credit bills
            final uniqueCustomers = <String>{};
            for (var doc in snapshot.docs) {
              final data = doc.data();
              final dueDateRaw = data['creditDueDate'];
              if (dueDateRaw == null) continue;
              try {
                final dueDate = DateTime.parse(dueDateRaw.toString());
                final dueDateOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);
                if (dueDateOnly.isBefore(now)) {
                  final customerId = (data['customerId'] ?? '').toString().trim();
                  if (customerId.isNotEmpty) uniqueCustomers.add(customerId);
                }
              } catch (_) {}
            }
            return uniqueCustomers.length;
          });
    });
  }

  void _startHeaderSlider() {
    _sliderTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_headerController.hasClients) {
        final visibleCount = _visibleBannerImages.length;
        if (visibleCount <= 1) return;
        int nextIndex = (_currentHeaderIndex + 1) % visibleCount;
        _headerController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _initFastFetch() {
    FirebaseFirestore.instance.collection('users').doc(widget.uid).get(
        const GetOptions(source: Source.cache)
    ).then((doc) {
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _businessName = data['businessName'] ?? data['name'] ?? 'My Business';
          _role = data['role'] ?? 'Staff';
        });
      }
    });

    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        setState(() {
          _businessName = data['businessName'] ?? data['name'] ?? 'My Business';
          if (data.containsKey('email')) _email = data['email'];
          _role = data['role'] ?? 'Staff';
        });
      }
    });
  }

  void _initStoreLogo() async {
    final storeId = await FirestoreService().getCurrentStoreId();
    if (storeId == null) return;

    _storeSubscription = FirebaseFirestore.instance
        .collection('store')
        .doc(storeId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data() as Map<String, dynamic>?;
        if (data != null) {
          setState(() {
            _logoUrl = (data?.containsKey('logoUrl') ?? false) ? data!['logoUrl'] as String? : null;
            _currencySymbol = CurrencyService.getSymbolWithSpace(data?['currency']);
          });
        }
      }
    });
  }

     void _loadPermissions() async {
     final userData = await PermissionHelper.getUserPermissions(widget.uid);
     if (mounted) {
       setState(() {
         _permissions = userData['permissions'] as Map<String, dynamic>? ?? {};
         _role = userData['role'] as String? ?? "staff";
         _permissionsLoaded = true;
       });
     }
     }

  @override
  void dispose() {
    _userSubscription?.cancel();
    _storeSubscription?.cancel();
    _sliderTimer?.cancel();
    _headerController.dispose();
    super.dispose();
  }

  bool _hasPermission(String permission) => _permissions[permission] == true;

  @override
  Widget build(BuildContext context) {
    return Consumer<PlanProvider>(
      builder: (context, planProvider, child) {
        bool isAdmin = _role.toLowerCase() == 'owner';
        final isProviderReady = planProvider.isInitialized;
        final currentPlan = planProvider.cachedPlan;
        // Wait until both provider and permissions are loaded before showing locks/upgrade prompts
        final isFullyLoaded = isProviderReady && _permissionsLoaded;

        int planRank = 0;
        if (isProviderReady) {
          final planLower = currentPlan.toLowerCase();
          if (planLower.contains('lite')) planRank = 1;
          else if (planLower.contains('plus')) planRank = 2;
          else if (planLower.contains('pro')) planRank = 3;
          else if (planLower.contains('starter') || planLower.contains('free')) planRank = 0;
        }

        bool isFeatureAvailable(String permission, {int requiredRank = 0}) {
          // Security-first: do NOT show gated features until both plan + permissions are loaded.
          if (!isFullyLoaded) return false;
          if (isAdmin) return true;

          // Daybook is a free feature (no plan rank requirement), but it should still respect staff permissions.
          // Note: Permission key is 'daybook' (lowercase) as used in PermissionEditor/PermissionHelper.
          if (permission.toLowerCase() == 'daybook') {
            return _hasPermission('daybook');
          }

          // If the current user explicitly has permission, grant access regardless of plan rank.
          if (_hasPermission(permission)) return true;

          // Otherwise enforce plan-based rank requirements (paid features)
          if (requiredRank > 0 && planRank < requiredRank) return false;

          // Default: deny access
          return false;
        }

        if (_currentView != null) {
          return _handleViewRouting(isAdmin, planProvider);
        }

        return Scaffold(
          backgroundColor: kGreyBg,
          body: Column(
            children: [
              SizedBox(
                height: MediaQuery.of(context).padding.top + 110,
                child: _buildProfileHeader(context, planProvider),
              ),

              _buildBannerHeader(context),

              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical:10),
                  children: [
                    // Compute section visibility
                    if (isFeatureAvailable('billHistory') || isFeatureAvailable('customerManagement', requiredRank: 1) || _canSeeAnyExpensesGroup(isAdmin: isAdmin, isFullyLoaded: isFullyLoaded))
                    _buildSectionLabel("Core Operations"),
                    if (isFeatureAvailable('billHistory') || isFeatureAvailable('customerManagement', requiredRank: 1))
                    Row(
                      children: [
                        if (_hasPermission('billHistory') || isAdmin)
                          Expanded(
                            child: _buildGridMenuTile(
                              'Manage Bills',
                              HeroIcons.documentText,
                              kGoogleGreen,
                              'BillHistory',
                            ),
                          ),
                        if ((_hasPermission('billHistory') || isAdmin) && isFeatureAvailable('customerManagement', requiredRank: 1))
                          const SizedBox(width: 12),
                        if (isFeatureAvailable('customerManagement', requiredRank: 1))
                          Expanded(
                            child: _buildGridMenuTile(
                              'Customer',
                              HeroIcons.users,
                              const Color(0xFF9C27B0),
                              'Customers',
                              requiredRank: 1,
                            ),
                          ),
                      ],
                    ),
                    if (isFeatureAvailable('billHistory') || isFeatureAvailable('customerManagement', requiredRank: 1) || _canSeeAnyExpensesGroup(isAdmin: isAdmin, isFullyLoaded: isFullyLoaded))
                    const SizedBox(height: 8),

                    if (_canSeeAnyExpensesGroup(isAdmin: isAdmin, isFullyLoaded: isFullyLoaded))
                      _buildExpenseExpansionTile(context, isAdmin: isAdmin),

                    if (isFeatureAvailable('creditDetails', requiredRank: 2) || (_hasPermission('creditNotes')) || isFeatureAvailable('quotation', requiredRank: 1))
                    const SizedBox(height: 12),
                    if (isFeatureAvailable('creditDetails', requiredRank: 2) || (_hasPermission('creditNotes')) || isFeatureAvailable('quotation', requiredRank: 1))
                    _buildSectionLabel("Sales Operations"),

                    if (isFeatureAvailable('creditDetails', requiredRank: 2))
                      StreamBuilder<int>(
                        stream: _overdueCounterStream,
                        builder: (context, snapshot) {
                          return _buildMenuTile(
                            'Credit & Dues',
                            HeroIcons.bookOpen,
                            const Color(0xFF00796B),
                            'CreditDetails',
                            requiredRank: 2,
                            badgeCount: snapshot.data ?? 0,
                          );
                        }
                      ),

                    if (_hasPermission('creditNotes'))
                      _buildMenuTile('Returns & Refunds', HeroIcons.ticket, kOrange, 'CreditNotes', requiredRank: 1),

                    if (isFeatureAvailable('quotation', requiredRank: 1))
                      _buildMenuTile('Estimation / Quotation', HeroIcons.document, kPrimaryColor, 'Quotation', requiredRank: 1),

                    const SizedBox(height: 12),
                    _buildSectionLabel("Help & Support"),
                    _buildMenuTile('How to - Videos', HeroIcons.playCircle, const Color(0xFF2F7CF6), 'VideoTutorial'),
                    _buildMenuTile('Knowledge Base', HeroIcons.academicCap, const Color(0xFFE6AE00), 'Knowledge'),
                    _buildMenuTile('Help & Support', HeroIcons.chatBubbleLeftRight, kPrimaryColor, 'Support', requiredRank: 1),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: CommonBottomNav(uid: widget.uid, userEmail: widget.userEmail, currentIndex: 0, screenWidth: MediaQuery.of(context).size.width),
        );
      },
    );
  }

  Widget _buildProfileHeader(BuildContext context, PlanProvider planProvider) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.only(top: (topPadding > 10 ? topPadding - 10 : 0), left: 20, right: 20, bottom: 0),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kPrimaryColor, kPrimaryColor],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          _buildStoreAvatar(),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_businessName, style: const TextStyle(color: kWhite, fontSize: 18, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildHeaderBadge(_role, kWhite.withOpacity(0.2)),
                    const SizedBox(width: 8),
                    _buildPlanBadge(planProvider),
                  ],
                ),
                const SizedBox(height: 6),
                Text(_email, style: TextStyle(color: kWhite.withOpacity(0.7), fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerHeader(BuildContext context) {
    final double bannerWidth = MediaQuery.of(context).size.width - 32;
    final double bannerHeight = bannerWidth * (400 / 1125);

    final banners = _visibleBannerImages;

    if (!_permissionsLoaded || banners.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        height: bannerHeight,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          children: [
            // 1. Clipped content (Image)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: PageView.builder(
                  controller: _headerController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentHeaderIndex = index;
                    });
                  },
                    itemCount: banners.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () => _handleBannerNavigation(index),
                      child: Image.asset(
                          banners[index],
                        fit: BoxFit.cover, // Changed from fill to cover for better quality
                      ),
                    );
                  },
                ),
              ),
            ),
            // 2. Border overlay (Ensures edges are always visible on top of image)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade300, width: 1.5),
                  ),
                ),
              ),
            ),
            // 3. Indicators
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  banners.length,
                      (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _currentHeaderIndex == index ? 18 : 6,
                    height: 5,
                    decoration: BoxDecoration(
                      color: _currentHeaderIndex == index
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleBannerNavigation(int index) {
    final planProvider = Provider.of<PlanProvider>(context, listen: false);

    // Map visible index -> original banner index.
    // NOTE: This must match _visibleBannerImages() order.
    int originalIndex = 0;
    if (!_permissionsLoaded) {
      originalIndex = index;
    } else {
      final mapping = <int>[0];
      if (_canAccessDayBook) mapping.add(1);
      if (_isOwner) {
        mapping.add(2);
        mapping.add(3);
      }
      if (index < 0 || index >= mapping.length) return;
      originalIndex = mapping[index];
    }

    switch (originalIndex) {
      case 0:
        // Upgrade Now → Subscription plan
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (_) => SubscriptionPlanPage(
              uid: widget.uid,
              currentPlan: planProvider.cachedPlan,
            ),
          ),
        );
        break;
      case 1:
        // Update Now → DayBook
        if (!_canAccessDayBook) {
          PermissionHelper.showPermissionDeniedDialog(context);
          return;
        }

        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (_) => DayBookPage(
              uid: widget.uid,
              onBack: () => Navigator.pop(context),
            ),
          ),
        );
        break;
      case 2:
        // Start Billing → Staff Access & Roles
        if (!_isOwner) {
          PermissionHelper.showPermissionDeniedDialog(context);
          return;
        }
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (_) => StaffManagementPage(
              uid: widget.uid,
              userEmail: widget.userEmail,
              onBack: () => Navigator.pop(context),
            ),
          ),
        );
        break;
      case 3:
        // View Report → View Credit
        if (!_isOwner) {
          PermissionHelper.showPermissionDeniedDialog(context);
          return;
        }
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (_) => CreditDetailsPage(
              uid: widget.uid,
              onBack: () => Navigator.pop(context),
            ),
          ),
        );
        break;
    }
  }

  Widget _buildStoreAvatar() {
    return GestureDetector(
      onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => SettingsPage(uid: widget.uid, userEmail: widget.userEmail))),
      child: Container(
        width: 60, height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: kWhite.withOpacity(0.1),
        ),
        child: Stack(
          children: [
            // Clipped Image
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _logoUrl != null && _logoUrl!.isNotEmpty
                    ? Image.network(_logoUrl!, fit: BoxFit.cover)
                    : Container(
                  alignment: Alignment.center,
                  child: const HeroIcon(HeroIcons.buildingStorefront, color: kWhite, size: 30),
                ),
              ),
            ),
            // Border Overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kWhite.withOpacity(0.5), width: 2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanBadge(PlanProvider planProvider) {
    final plan = planProvider.cachedPlan;
    final isPremium = !plan.toLowerCase().contains('free') && !plan.toLowerCase().contains('starter');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: isPremium ? kGoogleGreen : kOrange, borderRadius: BorderRadius.circular(6)),
      child: Row(
        children: [
          const HeroIcon(HeroIcons.star, style: HeroIconStyle.solid, color: kWhite, size: 10),
          const SizedBox(width: 4),
          Text(plan, style: const TextStyle(color: kWhite, fontSize: 9, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildHeaderBadge(String text, Color color) {
    final formattedText = text.isNotEmpty
        ? text[0].toUpperCase() + text.substring(1).toLowerCase()
        : text;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        formattedText,
        style: const TextStyle(
          color: kWhite,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12, left: 4),
    child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 1.5)),
  );

    Widget _buildMenuTile(String title, HeroIcons icon, Color color, String viewKey, {int requiredRank = 0, int badgeCount = 0}) {
    return Consumer<PlanProvider>(
      builder: (context, planProvider, child) {
        bool isAdmin = _role.toLowerCase() == 'owner';
        final currentPlan = planProvider.cachedPlan;
        final isProviderReady = planProvider.isInitialized; // only enforce rank checks when ready

        int planRank = 0;
        if (isProviderReady) {
          final planLower = currentPlan.toLowerCase();
          if (planLower.contains('lite')) planRank = 1;
          else if (planLower.contains('plus')) planRank = 2;
          else if (planLower.contains('pro') || planLower.contains('premium')) planRank = 3;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
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
                  // These info/help pages should always be accessible without any
                  // staff permission (role-based) or plan gating.
                  const noGateViews = <String>{'VideoTutorial', 'Knowledge', 'Support'};
                  if (noGateViews.contains(viewKey)) {
                    setState(() => _currentView = viewKey);
                    return;
                  }

                // If provider is not ready yet, allow navigation (avoid flicker/false blocks)
                if (!isProviderReady) {
                  setState(() => _currentView = viewKey);
                  return;
                }

                // Check paid plan synchronously — same as Reports.dart
                final isPaidPlan = planProvider.canAccessReports();

                // For admins on free/starter plan, show upgrade dialog
                if (isAdmin && !isPaidPlan && requiredRank > 0) {
                  PlanPermissionHelper.showUpgradeDialog(context, title, uid: widget.uid, currentPlan: currentPlan);
                  return;
                }

                // For staff, check user permissions + plan
                if (!isAdmin) {
                  final permKey = _getPermissionKeyFromView(viewKey);
                  final hasPermission = _hasPermission(permKey);
                  if (!hasPermission) {
                    PermissionHelper.showPermissionDeniedDialog(context);
                    return;
                  }
                  if (requiredRank > 0 && !isPaidPlan) {
                    PlanPermissionHelper.showUpgradeDialog(context, title, uid: widget.uid, currentPlan: currentPlan);
                    return;
                  }
                }

                // All checks passed, open the page
                setState(() => _currentView = viewKey);
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                      child: HeroIcon(icon, color: color, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: kBlack87)),
                    ),
                    if (badgeCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: kErrorColor,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(color: kErrorColor.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))
                          ],
                        ),
                        child: Text(
                          badgeCount > 99 ? '99+' : badgeCount.toString(),
                          style: const TextStyle(color: kWhite, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    const SizedBox(width: 8),
                    const HeroIcon(HeroIcons.chevronRight, color: kGrey400, size: 14),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

    Widget _buildGridMenuTile(String title, HeroIcons icon, Color color, String viewKey, {int requiredRank = 0}) {
    return Consumer<PlanProvider>(
      builder: (context, planProvider, child) {
        bool isAdmin = _role.toLowerCase() == 'owner';
        final currentPlan = planProvider.cachedPlan;
        final isProviderReady = planProvider.isInitialized; // only enforce rank checks when ready

        int planRank = 0;
        if (isProviderReady) {
          final planLower = currentPlan.toLowerCase();
          if (planLower.contains('lite')) planRank = 1;
          else if (planLower.contains('plus')) planRank = 2;
          else if (planLower.contains('pro') || planLower.contains('premium')) planRank = 3;
        }

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
                 // These info/help pages should always be accessible without any
                 // staff permission (role-based) or plan gating.
                 const noGateViews = <String>{'VideoTutorial', 'Knowledge', 'Support'};
                 if (noGateViews.contains(viewKey)) {
                   setState(() => _currentView = viewKey);
                   return;
                 }

                if (!isProviderReady) {
                  setState(() => _currentView = viewKey);
                  return;
                }

                // Check paid plan synchronously — same as Reports.dart
                final isPaidPlan = planProvider.canAccessReports();

                // For admins on free/starter plan, show upgrade dialog
                if (isAdmin && !isPaidPlan && requiredRank > 0) {
                  PlanPermissionHelper.showUpgradeDialog(context, title, uid: widget.uid, currentPlan: currentPlan);
                  return;
                }

                // For staff, check user permissions + plan
                if (!isAdmin) {
                  final permKey = _getPermissionKeyFromView(viewKey);
                  final hasPermission = _hasPermission(permKey);
                  if (!hasPermission) {
                    PermissionHelper.showPermissionDeniedDialog(context);
                    return;
                  }
                  if (requiredRank > 0 && !isPaidPlan) {
                    PlanPermissionHelper.showUpgradeDialog(context, title, uid: widget.uid, currentPlan: currentPlan);
                    return;
                  }
                }

                // All checks passed, open the page
                if (viewKey == 'BillHistory') {
                  Navigator.push(
                    context,
                    _NoAnimRoute(builder: (_) => SalesHistoryPage(uid: widget.uid, userEmail: widget.userEmail, onBack: () => Navigator.pop(context))),
                  );
                } else {
                  setState(() => _currentView = viewKey);
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                      child: HeroIcon(icon, color: color, size: 22),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title, 
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: kBlack87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildExpenseExpansionTile(BuildContext context, {required bool isAdmin}) {
    const Color color = Color(0xFFE91E63);

    // Show the Expenses tile if ANY expense-related permission is enabled.
    // This ensures the tile remains visible even if 'expenses' is disabled but
    // other sub-components are enabled (Expense Category / Product Purchase / Suppliers).
    final canSeeAny = isAdmin ||
        _hasPermission('expenses') ||
        _hasPermission('expenseCategories') ||
        _hasPermission('stockPurchase') ||
        _hasPermission('vendors');
    if (!canSeeAny) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kGrey200.withOpacity(0.5))
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
            child: const HeroIcon(HeroIcons.wallet, color: color, size: 22),
          ),
          title: Text(context.tr('expenses'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: kBlack87)),
          childrenPadding: const EdgeInsets.only(left: 58, right: 12, bottom: 12),
          children: [
            if (isAdmin || _hasPermission('expenses'))
              _buildSubMenuItem('Expenses', 'Expenses'),
            if (isAdmin || _hasPermission('expenseCategories'))
              _buildSubMenuItem('Expense Category', 'ExpenseCategories'),
            if (isAdmin || _hasPermission('stockPurchase'))
              _buildSubMenuItem('Product Purchase', 'StockPurchase'),
            if (isAdmin || _hasPermission('vendors'))
              _buildSubMenuItem('Suppliers', 'Vendors'),
          ],
        ),
      ),
    );
  }

  Widget _buildSubMenuItem(String text, String viewKey) {
    return ListTile(
      onTap: () => setState(() => _currentView = viewKey),
      title: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kBlack54)),
      trailing: const HeroIcon(HeroIcons.chevronRight, size: 18, color: kGrey300),
      dense: true, visualDensity: const VisualDensity(vertical: -2),
    );
  }

  String _getPermissionKeyFromView(String viewKey) {
    switch (viewKey) {
      case 'BillHistory': return 'billHistory';
      case 'Customers': return 'customerManagement';
      case 'CreditNotes': return 'creditNotes';
      case 'Expenses': return 'expenses';
      case 'ExpenseCategories': return 'expenseCategories';
      case 'StockPurchase': return 'stockPurchase';
      case 'Vendors': return 'vendors';
      case 'CreditDetails': return 'creditDetails';
      case 'Quotation': return 'quotation';
      case 'StaffManagement': return 'staffManagement';
      default: return viewKey.toLowerCase();
    }
  }

  Widget _handleViewRouting(bool isAdmin, PlanProvider planProvider) {
    void reset() => setState(() => _currentView = null);
    switch (_currentView) {
      case 'BillHistory': return SalesHistoryPage(uid: widget.uid, userEmail: widget.userEmail, onBack: reset);
      case 'Customers': return CustomersPage(uid: widget.uid, onBack: reset);
      case 'StockPurchase': return StockPurchasePage(uid: widget.uid, onBack: reset);
      case 'Expenses': return ExpensesPage(uid: widget.uid, onBack: reset);
      case 'ExpenseCategories': return ExpenseCategoriesPage(uid: widget.uid, onBack: reset);
      case 'Vendors': return VendorsPage(uid: widget.uid, onBack: reset);
      case 'Quotation': return QuotationsListPage(uid: widget.uid, userEmail: widget.userEmail, onBack: reset);
      case 'CreditNotes': return CreditNotesPage(uid: widget.uid, onBack: reset);
      case 'CreditDetails': return CreditDetailsPage(uid: widget.uid, onBack: reset);
      case 'StaffManagement': return StaffManagementPage(uid: widget.uid, userEmail: widget.userEmail, onBack: reset);
      case 'Knowledge': return KnowledgePage(onBack: reset);
      case 'VideoTutorial': return VideoTutorialPage(onBack: reset);
      case 'Support': return SupportPage(uid: widget.uid, userEmail: widget.userEmail, onBack: reset);
    }
    return Container();
  }
}


// ==========================================
// VIDEO TUTORIAL PAGE (STYLIZED)
// ==========================================
class VideoTutorialPage extends StatelessWidget {
  final VoidCallback onBack;
  const VideoTutorialPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) onBack();
      },
      child: Scaffold(
        backgroundColor: kWhite,
        appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
          title: const Text('Tutorials', style: TextStyle(color: kWhite,fontWeight: FontWeight.bold, fontSize: 16)),
          backgroundColor: kPrimaryColor, centerTitle: true, elevation: 0,
          leading: IconButton(icon: const HeroIcon(HeroIcons.arrowLeft, color: kWhite, size: 18), onPressed: onBack),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(color: kPrimaryColor.withOpacity(0.05), shape: BoxShape.circle),
                child: const HeroIcon(HeroIcons.playCircle, style: HeroIconStyle.solid, size: 80, color: kPrimaryColor),
              ),
              const SizedBox(height: 32),
              const Text('Master Your Business', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kBlack87)),
              const SizedBox(height: 12),
              const Text('Watch our comprehensive video guide to learn how to manage inventory, sales, and staff effectively.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: kBlack54, height: 1.5, fontWeight: FontWeight.w500)),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton.icon(
                  icon: const HeroIcon(HeroIcons.arrowTopRightOnSquare, size: 18),
                  label: const Text('Watch on YouTube', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.0)),
                  style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () async {
                    final url = Uri.parse('https://www.youtube.com');
                    if (await launcher.canLaunchUrl(url)) await launcher.launchUrl(url, mode: launcher.LaunchMode.externalApplication);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 2. HELPER WIDGETS (With onBack callback)
// ==========================================
class GenericListPage extends StatelessWidget {
  final String title;
  final String collectionPath;
  final String uid;
  final String? filterField;
  final bool filterNotEmpty;
  final num? numericFilterGreaterThan;
  final VoidCallback onBack; // Changed from Navigator
  final FirestoreService _firestoreService = FirestoreService();

  GenericListPage({
    super.key,
    required this.title,
    required this.collectionPath,
    required this.uid,
    required this.onBack,
    this.filterField,
    this.filterNotEmpty = false,
    this.numericFilterGreaterThan,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2F7CF6),
        leading: IconButton(icon: const HeroIcon(HeroIcons.arrowLeft, color: Colors.white), onPressed: onBack),
        centerTitle: true,
      ),
      body: FutureBuilder<CollectionReference>(
        future: _firestoreService.getStoreCollection(collectionPath),
        builder: (context, collectionSnapshot) {
          if (!collectionSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          Query collectionRef = collectionSnapshot.data!;
          if (filterNotEmpty && filterField != null) {
            collectionRef = collectionRef.where(filterField!, isNotEqualTo: null);
          }
          if (numericFilterGreaterThan != null && filterField != null) {
            collectionRef = collectionRef.where(filterField!, isGreaterThan: numericFilterGreaterThan);
          }
          collectionRef = collectionRef.orderBy('timestamp', descending: true);

          return StreamBuilder<QuerySnapshot>(
            stream: collectionRef.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Text(context.tr('nodata')));

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final subtitle = data.containsKey('total') ? 'Total:  ${data['total']}' : (data.containsKey('phone') ? data['phone'] : '');
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    child: ListTile(
                      title: Text(data['customerName'] ?? data['name'] ?? data['title'] ?? doc.id, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(subtitle.toString()),
                      trailing: Text(data['timestamp'] != null ? _formatTime(data['timestamp']) : '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
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

  String _formatTime(dynamic ts) {
    try {
      final dt = (ts as Timestamp).toDate();
      return DateFormat('dd MMM').format(dt);
    } catch (e) {
      return '';
    }
  }
}

// ==========================================
// UPDATED SALES HISTORY PAGE (UI MATCH)
// ==========================================

class SalesHistoryPage extends StatefulWidget {
  final String uid;
  final VoidCallback onBack;
  final String? userEmail;

  const SalesHistoryPage({
    super.key,
    required this.uid,
    required this.onBack,
    this.userEmail,
  });

  @override
  State<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

enum SortOption { dateNewest, dateOldest, amountHigh, amountLow }

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  // Streams
  Stream<List<QueryDocumentSnapshot>>? _combinedStream;
  StreamController<List<QueryDocumentSnapshot>>? _controller;
  StreamSubscription? _salesSub;
  StreamSubscription? _savedOrdersSub;

  // Search & Filter State
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  SortOption _currentSort = SortOption.dateNewest;

  // Filter options
  String _statusFilter = 'all'; // all, settled, unsettled, cancelled, edited, returned
  String _paymentFilter = 'all';
  String _selectedDateFilter = 'All Time';
  DateTimeRange? _customDateRange;

  // Currency
  String _currencySymbol = '';

  @override
  void initState() {
    super.initState();
    _initializeCombinedStream();
    _loadCurrency();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase().trim();
      });
    });
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
    _salesSub?.cancel();
    _savedOrdersSub?.cancel();
    _controller?.close();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeCombinedStream() async {
    // Create controller immediately and emit empty list — no more infinite spinner
    _controller = StreamController<List<QueryDocumentSnapshot>>.broadcast();
    if (mounted) setState(() => _combinedStream = _controller!.stream);
    // Emit empty list right away so StreamBuilder shows empty state instead of loading
    _controller!.add([]);

    try {
      final salesCollection = await FirestoreService().getStoreCollection('sales')
          .timeout(const Duration(seconds: 8), onTimeout: () => throw Exception('timeout'));
      final savedOrdersCollection = await FirestoreService().getStoreCollection('savedOrders')
          .timeout(const Duration(seconds: 8), onTimeout: () => throw Exception('timeout'));

      final salesStream = salesCollection.snapshots();
      final savedOrdersStream = savedOrdersCollection.snapshots();

      List<QueryDocumentSnapshot> salesDocs = [];
      List<QueryDocumentSnapshot> savedOrdersDocs = [];

      void updateController() {
        if (_controller == null || _controller!.isClosed) return;
        _controller!.add([...salesDocs, ...savedOrdersDocs]);
      }

      _salesSub = salesStream.listen((snapshot) { salesDocs = snapshot.docs; updateController(); });
      _savedOrdersSub = savedOrdersStream.listen((snapshot) { savedOrdersDocs = snapshot.docs; updateController(); });
    } catch (e) {
      // Already emitted empty list above, nothing more needed
      debugPrint('SalesHistoryPage stream init error: $e');
    }
  }

  List<QueryDocumentSnapshot> _processList(List<QueryDocumentSnapshot> docs, int historyLimit) {
    final now = DateTime.now();
    final historyLimitDate = now.subtract(Duration(days: historyLimit));

    // 1. Filter
    var filtered = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = data['timestamp'] as Timestamp?;
      if (timestamp != null && timestamp.toDate().isBefore(historyLimitDate)) return false;

      // Status logic
      final paymentStatus = data['paymentStatus'];
      final isSettled = paymentStatus != null ? paymentStatus != 'unsettled' : (data.containsKey('paymentMode'));
      final isCancelled = data['status'] == 'cancelled';
      final isEdited = data['status'] == 'edited' || data['hasBeenEdited'] == true || data['editedAt'] != null;
      final isReturned = data['status'] == 'returned' || data['hasBeenReturned'] == true || data['returnedAt'] != null;

      if (_statusFilter == 'settled' && (!isSettled || isCancelled || isEdited || isReturned)) return false;
      if (_statusFilter == 'unsettled' && (isSettled || isCancelled || isEdited || isReturned)) return false;
      if (_statusFilter == 'cancelled' && !isCancelled) return false;
      if (_statusFilter == 'edited' && !isEdited) return false;
      if (_statusFilter == 'returned' && !isReturned) return false;

      // Search
      if (_searchQuery.isNotEmpty) {
        final inv = (data['invoiceNumber'] ?? '').toString().toLowerCase();
        final customer = (data['customerName'] ?? '').toString().toLowerCase();
        if (!inv.contains(_searchQuery) && !customer.contains(_searchQuery)) return false;
      }

      return true;
    }).toList();

    // 2. Sort
    filtered.sort((a, b) {
      final dataA = a.data() as Map<String, dynamic>;
      final dataB = b.data() as Map<String, dynamic>;

      switch (_currentSort) {
        case SortOption.amountHigh:
          return (dataB['total'] ?? 0.0).compareTo(dataA['total'] ?? 0.0);
        case SortOption.amountLow:
          return (dataA['total'] ?? 0.0).compareTo(dataB['total'] ?? 0.0);
        case SortOption.dateOldest:
          return (dataA['timestamp'] as Timestamp? ?? Timestamp.now()).compareTo(dataB['timestamp'] as Timestamp? ?? Timestamp.now());
        case SortOption.dateNewest:
        default:
          return (dataB['timestamp'] as Timestamp? ?? Timestamp.now()).compareTo(dataA['timestamp'] as Timestamp? ?? Timestamp.now());
      }
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          widget.onBack();
        }
      },
      child: Scaffold(
        backgroundColor: kGreyBg,
        appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
          backgroundColor: kPrimaryColor,
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            icon: const HeroIcon(HeroIcons.arrowLeft, color: kWhite, size: 22),
            onPressed: widget.onBack,
          ),
          title: Text(context.tr("Manage Bills"),
              style: const TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
        ),
        body: Column(
          children: [
            _buildHeaderSection(),
            Expanded(
              child: FutureBuilder<int>(
                future: PlanPermissionHelper.getBillHistoryDaysLimit().timeout(
                  const Duration(seconds: 5),
                  onTimeout: () => 7,
                ),
                builder: (context, planSnap) {
                  final limit = planSnap.data ?? 7;
                  return StreamBuilder<List<QueryDocumentSnapshot>>(
                    stream: _combinedStream,
                    builder: (context, snapshot) {
                      if (_combinedStream == null || !snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                      }
                      final list = _processList(snapshot.data!, limit);
                      if (list.isEmpty) return _buildEmpty();

                      // Group bills by date
                      Map<String, List<QueryDocumentSnapshot>> groupedByDate = {};
                      for (var doc in list) {
                        final data = doc.data() as Map<String, dynamic>;
                        final timestamp = data['timestamp'] as Timestamp?;
                        if (timestamp != null) {
                          final dateKey = DateFormat('dd MMM yyyy').format(timestamp.toDate());
                          groupedByDate.putIfAbsent(dateKey, () => []).add(doc);
                        }
                      }

                      // Build list with date separators
                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: groupedByDate.length * 2 + groupedByDate.values.fold(0, (sum, list) => sum + list.length),
                        itemBuilder: (c, index) {
                          int currentIndex = 0;
                          for (var entry in groupedByDate.entries) {
                            // Date header
                            if (index == currentIndex) {
                              return Padding(
                                padding: EdgeInsets.only(bottom: 12, top: currentIndex == 0 ? 0 : 16),
                                child: Row(
                                  children: [
                                    Text(
                                      '${entry.value.length} ${entry.value.length == 1 ? 'Bill' : 'Bills'}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: kPrimaryColor,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'on ${entry.key}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            currentIndex++;

                            // Bills for this date
                            for (int i = 0; i < entry.value.length; i++) {
                              if (index == currentIndex) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _buildBillCard(entry.value[i]),
                                );
                              }
                              currentIndex++;
                            }
                          }
                          return const SizedBox.shrink();
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

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: const BoxDecoration(
        color: kWhite,
        border: Border(bottom: BorderSide(color: kGrey200)),
      ),
      child: Row(
        children: [
          Expanded(
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
                decoration: InputDecoration(
                  hintText: context.tr('search'),
                  hintStyle: TextStyle(color: kBlack54, fontSize: 14),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.all(12),
                    child: HeroIcon(HeroIcons.magnifyingGlass, color: kPrimaryColor, size: 20),
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
    ),
            ),
          ),
          const SizedBox(width: 10),
          _buildHeaderActionBtn(HeroIcons.bars3BottomLeft, _showSortMenu),
          const SizedBox(width: 8),
          _buildHeaderActionBtn(HeroIcons.adjustmentsHorizontal, _showFilterMenu),
        ],
      ),
    );
  }

  Widget _buildHeaderActionBtn(HeroIcons icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 46, width: 46,
        decoration: BoxDecoration(
          color: kPrimaryColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kGrey200),
        ),
        child: Center(child: HeroIcon(icon, color: kPrimaryColor, size: 22)),
      ),
    );
  }

  Widget _buildBillCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final inv = data['invoiceNumber'] ?? 'N/A';
    final total = (data['total'] ?? 0.0).toDouble();
    final customerName = data['customerName'] ?? 'Guest';
    final staffName = data['staffName'] ?? 'Staff';

    final timestamp = data['timestamp'] as Timestamp?;
    final formattedDateTime = timestamp != null
        ? DateFormat('dd MMM yyyy • hh:mm a').format(timestamp.toDate())
        : '--';

    final paymentStatus = data['paymentStatus'];
    final bool isSettled = paymentStatus != null ? paymentStatus != 'unsettled' : (data.containsKey('paymentMode'));
    final bool isCancelled = data['status'] == 'cancelled';
    // Check both current status and history flags for edited and returned
    final bool isEdited = data['status'] == 'edited' || data['hasBeenEdited'] == true || data['editedAt'] != null;
    final bool isReturned = data['status'] == 'returned' || data['hasBeenReturned'] == true || data['returnedAt'] != null;

    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGrey200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleOnTap(doc, data, isSettled, isCancelled, total),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: [
                    const HeroIcon(HeroIcons.documentText, size: 14, color: kPrimaryColor),
                    const SizedBox(width: 5),
                    Text("$inv", style: const TextStyle(fontWeight: FontWeight.w900, color: kPrimaryColor, fontSize: 13)),
                  ]),
                  Text(formattedDateTime, style: const TextStyle(fontSize: 10.5, color: Colors.black, fontWeight: FontWeight.w500))
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: Text(customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                  ),
                  Text("$_currencySymbol${total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: kSuccessGreen)),

                ]),
                const Divider(height: 20, color: kGreyBg),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text("Billed by", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: kBlack54, letterSpacing: 0.5)),
                    Text(staffName, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 10, color: kBlack87))
                  ]),
                  Row(children: [
                    _badge(isSettled, isCancelled, isEdited, isReturned),
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

  Widget _badge(bool settled, bool cancelled, bool edited, bool returned) {
    List<Widget> badges = [];

    // Show all applicable status badges
    if (cancelled) {
      badges.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: kBlack54.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: const Text("Cancelled", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kBlack54)),
      ));
    }
    if (returned) {
      badges.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.withOpacity(0.2))),
        child: const Text("Returned", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.orange)),
      ));
    }
    if (edited) {
      badges.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.withOpacity(0.2))),
        child: const Text("Edited", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.blue)),
      ));
    }

    // Only show Unsettled if no other status badges and bill is unsettled
    // Remove "Settled" indication - don't show it anymore
    if (badges.isEmpty && !settled) {
      badges.add(Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: kGoogleGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kGoogleGreen.withOpacity(0.2))),
          child: const Text("Unsettled",
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kGoogleGreen))));
    }

    // If no badges at all (settled with no special status), return empty container
    if (badges.isEmpty) {
      return const SizedBox.shrink();
    }

    // Return single badge or wrap multiple badges
    if (badges.length == 1) {
      return badges[0];
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: badges,
    );
  }

  void _handleOnTap(QueryDocumentSnapshot doc, Map<String, dynamic> data, bool isSettled, bool isCancelled, double total) {
    // Allow editing only if unsettled and not cancelled/edited/returned
    final bool isEdited = data['status'] == 'edited' || data['hasBeenEdited'] == true || data['editedAt'] != null;
    final bool isReturned = data['status'] == 'returned' || data['hasBeenReturned'] == true || data['returnedAt'] != null;

    if (!isSettled && !isCancelled && !isEdited && !isReturned) {
      final List<CartItem> cartItems = (data['items'] as List<dynamic>? ?? [])
          .map((item) {
        List<Map<String, dynamic>>? itemTaxes;
        if (item['taxes'] is List && (item['taxes'] as List).isNotEmpty) {
          itemTaxes = (item['taxes'] as List).map((t) => Map<String, dynamic>.from(t as Map)).toList();
        }
        return CartItem(
        productId: item['productId'] ?? '',
        name: item['name'] ?? '',
        price: (item['price'] ?? 0).toDouble(),
        quantity: item['quantity'] is int ? item['quantity'].toDouble() : (item['quantity'] is double ? item['quantity'] : double.tryParse(item['quantity'].toString()) ?? 1.0),
        taxes: itemTaxes,
        taxName: item['taxName'],
        taxPercentage: item['taxPercentage']?.toDouble(),
        taxType: item['taxType'],
      );
      })
          .toList();

      final isUnsettledSale = data.containsKey('paymentStatus') && data['paymentStatus'] == 'unsettled';

      // Load cart items into CartService before navigating to BillPage
      // This ensures the items are visible in the bill summary
      final cartService = Provider.of<CartService>(context, listen: false);
      cartService.updateCart(cartItems);

      Navigator.push(
        context,
        _NoAnimRoute(builder: (_) => BillPage(
          uid: widget.uid,
          cartItems: cartItems,
          totalAmount: total,
          userEmail: widget.userEmail,
          savedOrderId: isUnsettledSale ? null : doc.id,
          existingInvoiceNumber: data['invoiceNumber'],
          unsettledSaleId: isUnsettledSale ? doc.id : null,
          discountAmount: (data['discount'] ?? 0.0).toDouble(),
          customerPhone: data['customerPhone'],
          customerName: data['customerName'],
          customerGST: data['customerGST'],
          quotationId: data['quotationId'],
        )),
      );
    } else {
      Navigator.push(context, _NoAnimRoute(builder: (_) => SalesDetailPage(documentId: doc.id, initialData: data, uid: widget.uid, currencySymbol: _currencySymbol)));
    }
  }

  void _showSortMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const HeroIcon(HeroIcons.bars3BottomLeft, color: kPrimaryColor, size: 20),
                const SizedBox(width: 10),
                const Text('Sort History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kBlack87)),
              ]),
              const SizedBox(height: 16),
              _sortItem("Newest First", SortOption.dateNewest),
              _sortItem("Oldest First", SortOption.dateOldest),
              _sortItem("Amount: High to Low", SortOption.amountHigh),
              _sortItem("Amount: Low to High", SortOption.amountLow),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sortItem(String label, SortOption option) {
    bool isSelected = _currentSort == option;
    return ListTile(
      onTap: () { setState(() => _currentSort = option); Navigator.pop(context); },
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? kPrimaryColor : kBlack87)),
      trailing: isSelected ? const HeroIcon(HeroIcons.checkCircle, color: kPrimaryColor, size: 22) : null,
    );
  }

  void _showFilterMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kWhite,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const HeroIcon(HeroIcons.adjustmentsHorizontal, color: kPrimaryColor, size: 20),
                const SizedBox(width: 10),
                const Text('Filter Bills', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kBlack87)),
              ]),
              const SizedBox(height: 16),
              _filterItem("All Records", 'all'),
              _filterItem("Settled Only", 'settled'),
              _filterItem("Unsettled Only", 'unsettled'),
              _filterItem("Cancelled Only", 'cancelled'),
              _filterItem("Edited Only", 'edited'),
              _filterItem("Returned Only", 'returned'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterItem(String label, String value) {
    bool isSelected = _statusFilter == value;
    return ListTile(
      onTap: () { setState(() => _statusFilter = value); Navigator.pop(context); },
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? kPrimaryColor : kBlack87)),
      trailing: isSelected ? const HeroIcon(HeroIcons.checkCircle, color: kPrimaryColor, size: 22) : null,
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: kPrimaryColor.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: const Center(child: HeroIcon(HeroIcons.documentText, size: 38, color: kPrimaryColor)),
        ),
        const SizedBox(height: 20),
        const Text("No Bills Found", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kBlack87, fontFamily: 'NotoSans')),
        const SizedBox(height: 8),
        const Text("No billing records for the selected filter", textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: kBlack54, fontFamily: 'Lato')),
      ],
    ),
  );
}

// ==========================================
// 3. SALES DETAIL PAGE
// ==========================================
class SalesDetailPage extends StatelessWidget {
  final String documentId;
  final Map<String, dynamic> initialData;
  final String uid;
  final String currencySymbol;

  const SalesDetailPage({
    super.key,
    required this.documentId,
    required this.initialData,
    required this.uid,
    this.currencySymbol = '',
  });

  // ==========================================
  // LOGIC METHODS (PRESERVED BIT-BY-BIT)
  // ==========================================

  Map<String, dynamic> _calculateTaxTotals(List<Map<String, dynamic>> items) {
    double subtotalWithoutTax = 0.0;
    double totalTax = 0.0;
    Map<String, double> taxBreakdown = {};

    for (var item in items) {
      final price = (item['price'] ?? 0).toDouble();
      final quantity = (item['quantity'] ?? 1);
      final taxName = item['taxName'] as String?;
      final taxPercentage = (item['taxPercentage'] ?? 0).toDouble();
      final taxType = item['taxType'] as String?;

      double itemTotal = price * quantity;
      double itemTax = 0.0;
      double itemBaseAmount = itemTotal;

      if (taxPercentage > 0 && taxType != null) {
        if (taxType == 'Tax Included in Price' || taxType == 'Price includes Tax') {
          // Tax is included in price, extract it
          itemBaseAmount = itemTotal / (1 + taxPercentage / 100);
          itemTax = itemTotal - itemBaseAmount;
        } else if (taxType == 'Add Tax at Billing' || taxType == 'Price is without Tax') {
          // Tax needs to be added
          itemTax = itemTotal * (taxPercentage / 100);
        }
      }

      subtotalWithoutTax += itemBaseAmount;
      totalTax += itemTax;

      // Track tax breakdown by tax name
      if (itemTax > 0 && taxName != null && taxName.isNotEmpty) {
        taxBreakdown[taxName] = (taxBreakdown[taxName] ?? 0.0) + itemTax;
      }
    }

    return {
      'subtotalWithoutTax': subtotalWithoutTax,
      'totalTax': totalTax,
      'taxBreakdown': taxBreakdown,
    };
  }

  // Check user permissions for actions
  Future<Map<String, dynamic>> _getUserPermissions() async {
    try {
      // Use the same method that MenuPage uses to load permissions
      final userData = await PermissionHelper.getUserPermissions(uid);
      final role = userData['role'] as String;
      final permissions = userData['permissions'] as Map<String, dynamic>;

      debugPrint('Permission Check: role = $role');
      debugPrint('Staff permissions retrieved: $permissions');

      // Check if user is owner
      final isAdmin = role.toLowerCase() == 'owner';
      debugPrint('User is admin: $isAdmin');

      if (isAdmin) {
        debugPrint('User is admin - granting all permissions');
        return {
          'canSaleReturn': true,
          'canCancelBill': true,
          'canEditBill': true,
          'isAdmin': true,
        };
      }

      final result = {
        // Check both old and new permission keys for backward compatibility
        'canSaleReturn': permissions['returnInvoice'] == true || permissions['saleReturn'] == true,
        'canCancelBill': permissions['cancelInvoice'] == true || permissions['cancelBill'] == true,
        'canEditBill': permissions['editInvoice'] == true || permissions['editBill'] == true,
        'isAdmin': false,
      };

      debugPrint('Final permission result: $result');
      return result;
    } catch (e) {
      debugPrint('Error getting user permissions: $e');
      return {
        'canSaleReturn': false,
        'canCancelBill': false,
        'canEditBill': false,
        'isAdmin': false,
      };
    }
  }

  Future<void> _printInvoiceReceipt(BuildContext context, String documentId, Map<String, dynamic> data) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Get store details
      final storeId = await FirestoreService().getCurrentStoreId();
      String businessName = 'Business';
      String businessPhone = '';
      String businessLocation = '';
      String? businessGSTIN;

      if (storeId != null) {
        final storeDoc = await FirebaseFirestore.instance
            .collection('store')  // FIXED: Changed from 'stores' to 'store'
            .doc(storeId)
            .get();
        if (storeDoc.exists) {
          final storeData = storeDoc.data() as Map<String, dynamic>;
          businessName = storeData['businessName'] ?? 'Business';
          businessPhone = storeData['businessPhone'] ?? storeData['ownerPhone'] ?? '';
          businessLocation = storeData['address'] ?? storeData['location'] ?? '';
          businessGSTIN = storeData['gstin'];
        }
      }

      // Prepare items — preserve saved totals and multi-tax arrays
      final items = (data['items'] as List<dynamic>? ?? [])
          .map((item) => {
        'name': item['name'] ?? '',
        'quantity': item['quantity'] ?? 0,
        'price': (item['price'] ?? 0).toDouble(),
        // Use the saved total (correctly reflects included/added tax); fallback to price×qty
        'total': (item['total'] ?? ((item['price'] ?? 0) * (item['quantity'] ?? 1))).toDouble(),
        'productId': item['productId'] ?? '',
        'taxes': item['taxes'],          // multi-tax array (may be null for old records)
        'taxName': item['taxName'],
        'taxPercentage': (item['taxPercentage'] ?? 0).toDouble(),
        'taxAmount': (item['taxAmount'] ?? 0).toDouble(),
        'taxType': item['taxType'],
      }).toList();

      // Get timestamp
      DateTime dateTime = DateTime.now();
      if (data['timestamp'] != null) {
        dateTime = (data['timestamp'] as Timestamp).toDate();
      } else if (data['date'] != null) {
        dateTime = DateTime.tryParse(data['date'].toString()) ?? DateTime.now();
      }

      // ── Prefer saved document-level tax data (already correct from Bill.dart) ──
      List<Map<String, dynamic>>? taxList;
      double totalTax = (data['totalTax'] ?? 0).toDouble();
      double subtotal = (data['subtotal'] ?? 0).toDouble();

      final savedTaxes = data['taxes'];
      if (savedTaxes is List && savedTaxes.isNotEmpty) {
        // Saved taxes already have correct names (e.g. "CGST @9%") and amounts
        taxList = savedTaxes.map((t) => Map<String, dynamic>.from(t as Map)).toList();
        if (totalTax == 0) {
          totalTax = taxList.fold(0.0, (s, t) => s + ((t['amount'] ?? 0) as num).toDouble());
        }
      } else {
        // Fallback: recalculate from per-item fields (legacy records)
        final Map<String, double> taxMap = {};
        double recalcSubtotal = 0;
        double recalcTax = 0;
        for (final item in items) {
          final price = (item['price'] as double);
          final qty = (item['quantity'] is int)
              ? (item['quantity'] as int).toDouble()
              : double.tryParse(item['quantity'].toString()) ?? 1.0;
          final taxPct = (item['taxPercentage'] as double);
          final taxType = item['taxType'] as String?;
          double itemTax = (item['taxAmount'] as double);
          double itemBase = price * qty;

          if (itemTax == 0 && taxPct > 0 && taxType != null) {
            if (taxType == 'Tax Included in Price' || taxType == 'Price includes Tax') {
              itemBase = (price * qty) / (1 + taxPct / 100);
              itemTax = (price * qty) - itemBase;
            } else if (taxType == 'Add Tax at Billing' || taxType == 'Price is without Tax') {
              itemTax = price * qty * (taxPct / 100);
            }
          } else if (itemTax > 0 && (taxType == 'Tax Included in Price' || taxType == 'Price includes Tax')) {
            itemBase = (price * qty) - itemTax;
          }

          recalcSubtotal += itemBase;
          recalcTax += itemTax;

          if (itemTax > 0 && taxPct > 0) {
            final rawTaxes = item['taxes'];
            if (rawTaxes is List && rawTaxes.isNotEmpty) {
              for (final t in rawTaxes) {
                final tName = (t['name'] ?? 'Tax').toString();
                final tPct = ((t['percentage'] ?? 0.0) as num).toDouble();
                if (tPct > 0) {
                  final label = '$tName @${tPct % 1 == 0 ? tPct.toInt() : tPct}%';
                  taxMap[label] = (taxMap[label] ?? 0) + itemTax * (tPct / taxPct);
                }
              }
            } else {
              final tName = item['taxName'] as String?;
              if (tName != null && tName.isNotEmpty) {
                final label = '$tName @${taxPct % 1 == 0 ? taxPct.toInt() : taxPct}%';
                taxMap[label] = (taxMap[label] ?? 0) + itemTax;
              }
            }
          }
        }
        if (taxMap.isNotEmpty) taxList = taxMap.entries.map((e) => <String, dynamic>{'name': e.key, 'amount': e.value}).toList();
        if (totalTax == 0) totalTax = recalcTax;
        if (subtotal == 0) subtotal = recalcSubtotal;
      }

      // Last-resort subtotal: total − tax
      if (subtotal == 0) subtotal = (data['total'] ?? 0).toDouble() - totalTax;

      // Close loading
      if (context.mounted) {
        Navigator.pop(context);

        // Navigate to Invoice page
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => InvoicePage(
              uid: data['staffId'] ?? '',
              businessName: businessName,
              businessLocation: businessLocation,
              businessPhone: businessPhone,
              businessGSTIN: businessGSTIN,
              invoiceNumber: data['invoiceNumber']?.toString() ?? 'N/A',
              dateTime: dateTime,
              items: items.cast<Map<String, dynamic>>(),
              subtotal: subtotal,
              discount: (data['discount'] ?? 0).toDouble(),
              taxes: (taxList != null && taxList.isNotEmpty) ? taxList : null,
              total: (data['total'] ?? 0).toDouble(),
              paymentMode: data['paymentMode'] ?? 'Cash',
              cashReceived: (data['cashReceived'] ?? data['total'] ?? 0).toDouble(),
              cashReceived_split: data['paymentMode'] == 'Split' ? (data['cashReceived_split'] ?? 0).toDouble() : null,
              onlineReceived_split: data['paymentMode'] == 'Split' ? (data['onlineReceived_split'] ?? 0).toDouble() : null,
              creditIssued_split: data['paymentMode'] == 'Split' ? (data['creditIssued_split'] ?? 0).toDouble() : null,
              cashReceived_partial: data['paymentMode'] == 'Credit' ? (data['cashReceived_partial'] ?? 0).toDouble() : null,
              creditIssued_partial: data['paymentMode'] == 'Credit' ? (data['creditIssued_partial'] ?? 0).toDouble() : null,
              customerName: data['customerName'],
              customerPhone: data['customerPhone'],
              customerGSTIN: data['customerGST'],
              showCelebration: false,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.tr('error')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCancelBillDialog(BuildContext context, String documentId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Are you sure ?',
          style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Do you want to cancel Invoice No : ${data['invoiceNumber']} .',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            if (data['customerPhone'] != null && (data['total'] as num) > 0) ...[
              Text(
                'A Credit Note will be created for customer ${data['customerName'] ?? data['customerPhone']}',
                style: const TextStyle(fontSize: 14, color: Color(0xFF2F7CF6)),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('cancel'), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                // Show loading
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(child: CircularProgressIndicator()),
                );

                // 1. Restore stock for all items
                final items = (data['items'] as List<dynamic>? ?? []);
                final productsCollection = await FirestoreService().getStoreCollection('Products');
                for (var item in items) {
                  if (item['productId'] != null && item['productId'].toString().isNotEmpty) {
                    final productRef = productsCollection.doc(item['productId']);

                    await FirebaseFirestore.instance.runTransaction((transaction) async {
                      final productDoc = await transaction.get(productRef);
                      if (productDoc.exists) {
                        final productData = productDoc.data() as Map<String, dynamic>?;
                        final currentStock = productData?['currentStock'] ?? 0.0;
                        final quantity = (item['quantity'] ?? 0) is int
                            ? item['quantity']
                            : int.tryParse(item['quantity'].toString()) ?? 0;
                        final newStock = currentStock + quantity;
                        transaction.update(productRef, {'currentStock': newStock});
                      }
                    });
                  }
                }

                // 2. Create credit note if customer was involved (for any payment mode)
                if (data['customerPhone'] != null && (data['total'] as num) > 0) {
                  // Generate sequential credit note number
                  final creditNoteNumber = await NumberGeneratorService.generateCreditNoteNumber();

                  // Create credit note document - store-scoped
                  final creditNotesCollection = await FirestoreService().getStoreCollection('creditNotes');
                  await creditNotesCollection.add({
                    'creditNoteNumber': creditNoteNumber,
                    'invoiceNumber': data['invoiceNumber'],
                    'customerPhone': data['customerPhone'],
                    'customerName': data['customerName'] ?? 'Unknown',
                    'amount': (data['total'] as num).toDouble(),
                    'items': items.map((item) => {
                      'name': item['name'],
                      'quantity': item['quantity'],
                      'price': item['price'],
                      'total': (item['price'] ?? 0) * (item['quantity'] ?? 0),
                    }).toList(),
                    'timestamp': FieldValue.serverTimestamp(),
                    'status': 'Available',
                    'reason': 'Bill Cancelled',
                    'createdBy': 'owner',
                  });

                  // Reverse customer balance and total sales
                  if (data['customerPhone'] != null && data['customerPhone'].toString().trim().isNotEmpty) {
                    final customersCollection = await FirestoreService().getStoreCollection('customers');
                    final customerRef = customersCollection.doc(data['customerPhone']);

                    await FirebaseFirestore.instance.runTransaction((transaction) async {
                      final customerDoc = await transaction.get(customerRef);
                      if (customerDoc.exists) {
                        final customerData = customerDoc.data() as Map<String, dynamic>?;
                        final currentBalance = (customerData?['balance'] ?? 0.0).toDouble();
                        final currentTotalSales = (customerData?['totalSales'] ?? 0.0).toDouble();
                        final billTotal = (data['total'] as num).toDouble();

                        double balanceToDeduct = 0.0;
                        if (data['paymentMode'] == 'Credit') {
                          balanceToDeduct = billTotal;
                        } else if (data['paymentMode'] == 'Split') {
                          balanceToDeduct = (data['creditIssued_split'] ?? 0.0).toDouble();
                        }

                        final newBalance = currentBalance - balanceToDeduct;
                        final newTotalSales = currentTotalSales >= billTotal ? currentTotalSales - billTotal : 0.0;
                        transaction.update(customerRef, {
                          'balance': newBalance,
                          'totalSales': newTotalSales
                        });
                      }
                    });

                    // Also mark associated credits as cancelled
                    final creditsCollection = await FirestoreService().getStoreCollection('credits');
                    final creditsSnapshot = await creditsCollection.where('invoiceNumber', isEqualTo: data['invoiceNumber']).get();
                    for (var doc in creditsSnapshot.docs) {
                      await doc.reference.update({'status': 'cancelled'});
                    }
                  }
                }

                // 3. Mark the sales document as cancelled (don't delete)
                // Preserve history flags for edited/returned status
                final salesCollection = await FirestoreService().getStoreCollection('sales');
                final updateData = <String, dynamic>{
                  'status': 'cancelled',
                  'cancelledAt': FieldValue.serverTimestamp(),
                  'cancelledBy': data['staffName'] ?? 'owner',
                  'cancelReason': 'Bill Cancelled',
                };
                // Preserve edit history if bill was previously edited
                if (data['status'] == 'edited' || data['hasBeenEdited'] == true || data['editedAt'] != null) {
                  updateData['hasBeenEdited'] = true;
                }
                // Preserve return history if bill was previously returned
                if (data['status'] == 'returned' || data['hasBeenReturned'] == true || data['returnedAt'] != null) {
                  updateData['hasBeenReturned'] = true;
                }
                await salesCollection.doc(documentId).update(updateData);

                if (context.mounted) {
                  // Close loading dialog
                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          data['customerPhone'] != null
                              ? 'Bill cancelled. Credit note created for customer. Stock restored.'
                              : 'Bill cancelled successfully. Stock has been restored.'
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );

                  // Go back to bill history
                  Navigator.pop(context);
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context); // Close loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${context.tr('error')}: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(context.tr('cancel_bill'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // UI BUILD METHODS (QUOTATION PAGE STYLE)
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPrimaryColor, // Primary color background like QuotationPage entry
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        title: const Text('Invoice Details', style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: const HeroIcon(HeroIcons.arrowLeft, color: kWhite, size: 22), onPressed: () => Navigator.pop(context)),
      ),
      body: FutureBuilder<DocumentReference>(
        future: FirestoreService().getDocumentReference('sales', documentId),
        builder: (context, docRefSnapshot) {
          if (!docRefSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: kWhite));

          return StreamBuilder<DocumentSnapshot>(
            stream: docRefSnapshot.data!.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: kWhite));
              if (!snapshot.hasData || !snapshot.data!.exists) return Center(child: Text(context.tr('bill_not_found'), style: const TextStyle(color: kWhite)));

              final data = snapshot.data!.data() as Map<String, dynamic>;
              final ts = data['timestamp'] as Timestamp?;
              final dateStr = ts != null ? DateFormat('dd MMM yyyy • hh:mm a').format(ts.toDate()) : '--';
              final items = (data['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

              // ── Tax breakdown: prefer saved Firestore taxes (already @RATE% formatted) ──
              Map<String, double> taxBreakdown = {};
              double subtotalWithoutTax = (data['subtotal'] ?? 0).toDouble();

              final savedTaxes = data['taxes'];
              if (savedTaxes is List && savedTaxes.isNotEmpty) {
                // Use saved taxes directly — guaranteed correct
                for (var tax in savedTaxes) {
                  final taxName = tax['name'] as String?;
                  final taxAmount = (tax['amount'] ?? 0).toDouble();
                  if (taxName != null && taxAmount > 0) {
                    taxBreakdown[taxName] = (taxBreakdown[taxName] ?? 0) + taxAmount;
                  }
                }
                // If subtotal not stored, compute from total - totalTax
                if (subtotalWithoutTax == 0) {
                  final totalTax = (data['totalTax'] ?? taxBreakdown.values.fold(0.0, (a, b) => a + b)).toDouble();
                  subtotalWithoutTax = (data['total'] ?? 0).toDouble() - totalTax;
                }
              } else {
                // Fallback: recalculate from items (legacy records)
                final taxInfo = _calculateTaxTotals(items);
                subtotalWithoutTax = taxInfo['subtotalWithoutTax'] as double;
                taxBreakdown = taxInfo['taxBreakdown'] as Map<String, double>;

                // Still empty? try totalTax field
                if (taxBreakdown.isEmpty && (data['totalTax'] ?? 0) > 0) {
                  taxBreakdown['Tax'] = (data['totalTax'] as num).toDouble();
                }
                if (subtotalWithoutTax == 0 && data['subtotal'] != null) {
                  subtotalWithoutTax = (data['subtotal'] as num).toDouble();
                }
              }

              final status = data['paymentStatus'];
              final bool settled = status != null ? status != 'unsettled' : (data.containsKey('paymentMode'));
              final bool isCancelled = data['status'] == 'cancelled';
              final bool isEdited = data['status'] == 'edited' || data['hasBeenEdited'] == true || data['editedAt'] != null;
              final bool isReturned = data['status'] == 'returned' || data['hasBeenReturned'] == true || data['returnedAt'] != null;

              return Column(
                children: [
                  // Top Floating Card: Customer Info (Reduced vertical gap)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12,0, 12, 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: kWhite,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                              backgroundColor: kOrange.withOpacity(0.1),
                              radius: 18,
                              child: const HeroIcon(HeroIcons.user, color: kOrange, size: 18)
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['customerName'] ?? 'Guest',
                                  style: const TextStyle(color: kOrange, fontSize: 15, fontWeight: FontWeight.w700),
                                ),
                                if (data['customerPhone'] != null)
                                  Text(data['customerPhone'], style: const TextStyle(color: kBlack54, fontSize: 11)),
                              ],
                            ),
                          ),
                          _buildStatusTag(settled, isCancelled, isEdited, isReturned),
                        ],
                      ),
                    ),
                  ),

                  // Main Body: White Container extending to bottom
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: kWhite,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text('Billing overview', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: kBlack54, letterSpacing: 0.5)),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: kSuccessGreen.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: kSuccessGreen.withOpacity(0.3)),
                                        ),
                                        child: Text(
                                          '${items.length} ${items.length == 1 ? 'Item' : 'Items'}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: kSuccessGreen,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(HeroIcons.documentText, 'Invoice No', '${data['invoiceNumber']}'),
                                  _buildDetailRow(HeroIcons.identification, 'Billed By', data['staffName'] ?? 'owner'),
                                  _buildDetailRow(HeroIcons.calendar, 'Date Issued', dateStr),
                                  _buildDetailRow(HeroIcons.creditCard, 'Payment Mode', data['paymentMode'] ?? 'Not Set'),

                                  // Payment Split Details Section
                                  if (data['paymentMode'] == 'Split' || data['paymentMode'] == 'Credit')
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8, bottom: 4),
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: kPrimaryColor.withOpacity(0.05),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: kPrimaryColor.withOpacity(0.2)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Row(
                                              children: [
                                                HeroIcon(HeroIcons.wallet, size: 14, color: kPrimaryColor),
                                                SizedBox(width: 6),
                                                Text('Payment Split Details', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kPrimaryColor, letterSpacing: 0.5)),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            if (data['paymentMode'] == 'Split') ...[
                                              if ((data['cashReceived_split'] ?? 0).toDouble() > 0)
                                                _buildPaymentSplitRow(HeroIcons.banknotes, 'Cash', (data['cashReceived_split'] ?? 0).toDouble(), kGoogleGreen),
                                              if ((data['onlineReceived_split'] ?? 0).toDouble() > 0)
                                                _buildPaymentSplitRow(HeroIcons.buildingLibrary, 'Online', (data['onlineReceived_split'] ?? 0).toDouble(), kPrimaryColor),
                                              if ((data['creditIssued_split'] ?? 0).toDouble() > 0)
                                                _buildPaymentSplitRow(HeroIcons.creditCard, 'Credit', (data['creditIssued_split'] ?? 0).toDouble(), kOrange),
                                            ] else if (data['paymentMode'] == 'Credit') ...[
                                              // For Credit payment mode
                                              // Check if partial payment fields exist (when some amount was paid)
                                              if ((data['cashReceived_partial'] ?? 0).toDouble() > 0)
                                                _buildPaymentSplitRow(HeroIcons.banknotes, 'Cash Paid', (data['cashReceived_partial'] ?? 0).toDouble(), kGoogleGreen),
                                              if ((data['onlineReceived_partial'] ?? 0).toDouble() > 0)
                                                _buildPaymentSplitRow(HeroIcons.buildingLibrary, 'Online Paid', (data['onlineReceived_partial'] ?? 0).toDouble(), kPrimaryColor),
                                              // Show credit amount
                                              if ((data['creditIssued_partial'] ?? 0).toDouble() > 0)
                                                _buildPaymentSplitRow(HeroIcons.creditCard, 'Credit Issued', (data['creditIssued_partial'] ?? 0).toDouble(), kOrange)
                                              else if ((data['cashReceived_partial'] ?? 0).toDouble() == 0 && (data['onlineReceived_partial'] ?? 0).toDouble() == 0)
                                                // Fully credit - calculate from total and cashReceived
                                                _buildPaymentSplitRow(HeroIcons.creditCard, 'Credit Issued',
                                                  ((data['total'] ?? 0).toDouble() - (data['cashReceived'] ?? 0).toDouble()), kErrorColor),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),

                                  // Display custom note/description if available
                                  if (data['customNote'] != null && (data['customNote'] as String).trim().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8, bottom: 4),
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: kOrange.withOpacity(0.05),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: kOrange.withOpacity(0.2)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Row(
                                              children: [
                                                HeroIcon(HeroIcons.pencilSquare, size: 14, color: kOrange),
                                                SizedBox(width: 6),
                                                Text('Bill Notes', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kOrange, letterSpacing: 0.5)),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              data['customNote'] as String,
                                              style: const TextStyle(fontSize: 12, color: kBlack87, fontWeight: FontWeight.w500, height: 1.4),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                  // Display delivery address if available
                                  if (data['deliveryAddress'] != null && (data['deliveryAddress'] as String).trim().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8, bottom: 4),
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: kPrimaryColor.withOpacity(0.05),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: kPrimaryColor.withOpacity(0.2)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Row(
                                              children: [
                                                HeroIcon(HeroIcons.mapPin, size: 14, color: kPrimaryColor),
                                                SizedBox(width: 6),
                                                Text('Customer Notes', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kPrimaryColor, letterSpacing: 0.5)),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              data['deliveryAddress'] as String,
                                              style: const TextStyle(fontSize: 12, color: kBlack87, fontWeight: FontWeight.w500, height: 1.4),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                  const Padding(padding: EdgeInsets.symmetric(vertical: 0), child: Divider(color: kGreyBg, thickness: 1)),

                                  // Table-formatted Item List
                                  const Text('Items list', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: kBlack54, letterSpacing: 0.5)),
                                  const SizedBox(height: 8),
                                  _buildTableHeader(),
                                  ...items.map((item) => _buildItemTableRow(item)).toList(),

                                  const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Divider(color: kGreyBg, thickness: 1)),

                                  const Text('Valuation summary', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: kBlack54, letterSpacing: 0.5)),
                                  const SizedBox(height: 8),
                                  _buildPriceRow('Subtotal (Net)', subtotalWithoutTax),
                                  if ((data['discount'] ?? 0.0) > 0)
                                    _buildPriceRow(context.tr('discount'), -(data['discount'] ?? 0.0).toDouble(), valueColor: kErrorColor),

                                  // Tax Breakdown
                                  ...taxBreakdown.entries.map((e) => _buildPriceRow(e.key, e.value)).toList(),

                                  // Return Details Section (if any returns were made)
                                  if (isReturned && (data['returnAmount'] ?? 0.0) > 0) ...[
                                    const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Divider(color: kGreyBg, thickness: 1)),
                                    const Text('Return details', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: kBlack54, letterSpacing: 0.5)),
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: kErrorColor.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: kErrorColor.withOpacity(0.15)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const HeroIcon(HeroIcons.arrowUturnLeft, size: 14, color: kErrorColor),
                                              const SizedBox(width: 6),
                                              const Text('Items Returned', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kErrorColor, letterSpacing: 0.5)),
                                              const Spacer(),
                                              if (data['lastReturnAt'] != null)
                                                Text(
                                                  DateFormat('dd MMM yyyy').format((data['lastReturnAt'] as Timestamp).toDate()),
                                                  style: const TextStyle(fontSize: 9, color: kBlack54, fontWeight: FontWeight.w600),
                                                ),
                                            ],
                                          ),
                                          // Returned Items List
                                          if (data['returnedItems'] != null && (data['returnedItems'] as List).isNotEmpty) ...[
                                            const SizedBox(height: 10),
                                            const Divider(height: 1, color: kGrey200),
                                            const SizedBox(height: 8),
                                            ...(data['returnedItems'] as List).map((returnedItem) {
                                              final itemName = returnedItem['name'] ?? 'Item';
                                              final itemQty = returnedItem['quantity'] ?? 0;
                                              final itemPrice = (returnedItem['price'] ?? 0).toDouble();
                                              final itemTotal = (returnedItem['total'] ?? 0).toDouble(); // price * qty
                                              final itemTax = (returnedItem['taxAmount'] ?? 0).toDouble();
                                              final taxType = returnedItem['taxType'] as String?;
                                              final taxPercentage = (returnedItem['taxPercentage'] ?? 0).toDouble();

                                              // Determine tax type
                                              final bool isTaxIncluded = taxType == 'Tax Included in Price' || taxType == 'Price includes Tax';
                                              final bool isTaxAdded = taxType == 'Add Tax at Billing' || taxType == 'Price is without Tax';

                                              // Calculate display total:
                                              // - If tax is included in price: itemTotal already includes tax (price * qty where price has tax)
                                              // - If tax is added at billing: itemTotal is base, need to add tax
                                              // - If no tax or unknown: just use itemTotal
                                              double displayTotal;
                                              if (isTaxIncluded) {
                                                displayTotal = itemTotal; // Tax already in price
                                              } else if (isTaxAdded && itemTax > 0) {
                                                displayTotal = itemTotal + itemTax; // Add tax on top
                                              } else {
                                                displayTotal = itemTotal; // No tax or unknown
                                              }

                                              // Build tax info string
                                              String taxInfo = '';
                                              if (taxPercentage > 0 && itemTax > 0) {
                                                if (isTaxIncluded) {
                                                  taxInfo = ' (${taxPercentage.toStringAsFixed(0)}% Tax incl.)';
                                                } else {
                                                  taxInfo = ' (+${taxPercentage.toStringAsFixed(0)}% Tax: $currencySymbol${itemTax.toStringAsFixed(2)})';
                                                }
                                              }

                                              return Padding(
                                                padding: const EdgeInsets.only(bottom: 6),
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    const HeroIcon(HeroIcons.minusCircle, size: 12, color: kErrorColor),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(itemName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kBlack87)),
                                                          Text(
                                                            'Qty: $itemQty × $currencySymbol${itemPrice.toStringAsFixed(2)}$taxInfo',
                                                            style: const TextStyle(fontSize: 9, color: kBlack54),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Text(
                                                      '-$currencySymbol${displayTotal.toStringAsFixed(2)}',
                                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kErrorColor),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                            const SizedBox(height: 4),
                                            const Divider(height: 1, color: kGrey200),
                                          ],
                                          const SizedBox(height: 10),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text('Total Refund Amount', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kBlack54)),
                                              Text(
                                                '-$currencySymbol${(data['returnAmount'] ?? 0.0).toStringAsFixed(2)}',
                                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kErrorColor),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Original Total: $currencySymbol${((data['total'] ?? 0.0) + (data['returnAmount'] ?? 0.0)).toStringAsFixed(2)}',
                                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: kBlack54),
                                              ),
                                              Text(
                                                'After Return: $currencySymbol${(data['total'] ?? 0.0).toStringAsFixed(2)}',
                                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kPrimaryColor),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 32),
                                ],
                              ),
                            ),
                          ),
                          _buildFixedBottomArea(context, data, documentId: documentId),
                        ],
                      ),
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


  Widget _buildDetailRow(HeroIcons icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          HeroIcon(icon, size: 14, color: kGrey400),
          const SizedBox(width: 10),
          Text('$label: ', style: const TextStyle(color: kBlack54, fontSize: 11, fontWeight: FontWeight.w500)),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: kBlack87), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildPaymentSplitRow(HeroIcons icon, String label, double amount, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          HeroIcon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          Text(
            amount.toStringAsFixed(2),
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(8)),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('Product', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kBlack54))),
          Expanded(flex: 1, child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kBlack54))),
          Expanded(flex: 2, child: Text('Rate', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kBlack54))),
          Expanded(flex: 1, child: Text('Tax %', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kBlack54))),
          Expanded(flex: 2, child: Text('Tax amt', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kBlack54))),
          Expanded(flex: 2, child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kBlack54))),
        ],
      ),
    );
  }

  Widget _buildItemTableRow(Map<String, dynamic> item) {
    final price = (item['price'] ?? 0).toDouble();
    final quantity = (item['quantity'] ?? 1);
    final itemSubtotal = price * quantity;

    // Try to get tax info from item
    double taxVal = (item['taxAmount'] ?? 0.0).toDouble();
    int taxPerc = ((item['taxPercentage'] ?? 0) as num).toInt();
    String? taxName = item['taxName'] as String?;
    final taxType = item['taxType'] as String?;

    debugPrint('📊 Item: ${item['name']}, taxVal=$taxVal, taxPerc=$taxPerc, taxType=$taxType');

    // Determine if tax is included in price or added separately
    bool isTaxIncluded = taxType == 'Tax Included in Price' || taxType == 'Price includes Tax';

    // Calculate tax value based on taxType if we have percentage but no amount
    if (taxVal == 0 && taxPerc > 0 && taxType != null) {
      if (isTaxIncluded) {
        // Tax is included in price - extract it from the subtotal
        final baseAmount = itemSubtotal / (1 + taxPerc / 100);
        taxVal = itemSubtotal - baseAmount;
      } else if (taxType == 'Add Tax at Billing' || taxType == 'Price is without Tax') {
        // Tax needs to be added on top of subtotal
        taxVal = itemSubtotal * (taxPerc / 100);
      }
      debugPrint('   ✅ Calculated tax from type: $taxVal');
    }

    // Calculate final total based on tax type
    // If tax is included in price, total = itemSubtotal (tax is already in the price)
    // If tax is added at billing, total = itemSubtotal + taxVal
    final double itemTotalWithTax = isTaxIncluded ? itemSubtotal : (itemSubtotal + taxVal);

    debugPrint('   Final: taxPerc=$taxPerc, taxVal=$taxVal, total=$itemTotalWithTax, isTaxIncluded=$isTaxIncluded');

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kGreyBg))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
              flex: 3,
              child: Text(
                  item['name'] ?? 'Item',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: kBlack87),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis
              )
          ),
          Expanded(
              flex: 1,
              child: Text(
                  '${item['quantity']}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10, color: kBlack54, fontWeight: FontWeight.w700)
              )
          ),
          Expanded(
              flex: 2,
              child: Text(
                  price.toStringAsFixed(2),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10, color: kBlack54, fontWeight: FontWeight.w700)
              )
          ),
          Expanded(
              flex: 1,
              child: Text(
                  taxPerc > 0 ? '$taxPerc%' : '0%',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10, color: kBlack87, fontWeight: FontWeight.w700)
              )
          ),
          Expanded(
              flex: 2,
              child: Text(
                  taxVal > 0.01 ? taxVal.toStringAsFixed(2) : '0',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10,  color: kBlack87, fontWeight: FontWeight.w700)
              )
          ),
          Expanded(
              flex: 2,
              child: Text(
                  itemTotalWithTax.toStringAsFixed(2),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800,  color: kPrimaryColor)
              )
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, double val, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: kBlack54)),
          Text('${val.toStringAsFixed(2)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: valueColor ?? kBlack87)),
        ],
      ),
    );
  }

    Widget _buildFixedBottomArea(BuildContext context, Map<String, dynamic> data, {required String documentId}) {
    final bool hasReturns = (data['returnAmount'] ?? 0.0) > 0;
    final double returnAmount = (data['returnAmount'] ?? 0.0).toDouble();
    final double currentTotal = (data['total'] ?? 0.0).toDouble();
    final double originalTotal = currentTotal + returnAmount;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
            color: kWhite,
            border: const Border(top: BorderSide(color: kGrey200)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))]
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Show original total and return deduction if there were returns
            if (hasReturns) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Original Total', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: kBlack54)),
                  Text('$currencySymbol${originalTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kBlack54, decoration: TextDecoration.lineThrough)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const HeroIcon(HeroIcons.arrowUturnLeft, size: 12, color: kErrorColor),
                      const SizedBox(width: 4),
                      const Text('Return Deduction', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: kErrorColor)),
                    ],
                  ),
                  Text('-$currencySymbol${returnAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kErrorColor)),
                ],
              ),
              const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Divider(height: 1, color: kGrey200)),
            ],
            // Row 1: Net Amount Fixed at Bottom
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(hasReturns ? 'Net Payable (After Return)' : 'Final Total Payable', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: kBlack54)),
                Text('$currencySymbol${currentTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kPrimaryColor)),
              ],
            ),
            const SizedBox(height: 12),
            // Row 2: Square Action Buttons (Reordered)
              _buildActionGrid(context, data, documentId: documentId, uid: uid),
           ],
         ),
       ),
     );
     }

    Widget _buildActionGrid(BuildContext context, Map<String, dynamic> data, {required String documentId, required String uid}) {
     return FutureBuilder<Map<String, dynamic>>(
       future: _getUserPermissions(),
       builder: (context, permSnap) {
         if (!permSnap.hasData) return const SizedBox.shrink();
         final perms = permSnap.data!;
         final bool isCancelled = data['status'] == 'cancelled';

        // Check if items list has items
        final items = data['items'] as List<dynamic>? ?? [];
        final bool hasItems = items.isNotEmpty;

        List<Widget> actions = [];

        // 1. Receipt - only show if there are items
        if (hasItems) {
          actions.add(_squareActionButton(HeroIcons.documentText, 'Receipt', kPrimaryColor, () => _printInvoiceReceipt(context, documentId, data)));
        }

        // 2. Edit
        if (!isCancelled && (perms['canEditBill'] || perms['isAdmin'])) {
          actions.add(_squareActionButton(HeroIcons.pencilSquare, 'Edit', kPrimaryColor, () async {
            if ((data['editCount'] ?? 0) >= 2) {
              showDialog(context: context, builder: (_) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), title: const Text('Limit Reached'), content: const Text('This bill has been edited 2 times. Please cancel and create a new bill for further changes.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))]));
              return;
            }
            if (await PlanPermissionHelper.canEditBill()) {
              // Always open the edit page; the user can switch to Split within EditBillPage.
              if (context.mounted) Navigator.push(context, _NoAnimRoute(builder: (_) => EditBillPage(documentId: documentId, invoiceData: data)));
            } else {
              if (context.mounted) PlanPermissionHelper.showUpgradeDialog(context, 'Edit Bill', uid: uid);
            }
          }));
        }

        // 3. Return - only show if there are items and not cancelled
          if (hasItems && !isCancelled && (perms['canSaleReturn'] || perms['isAdmin'])) {
          actions.add(_squareActionButton(HeroIcons.arrowUturnLeft, 'Return', kPrimaryColor, () => Navigator.push(context, CupertinoPageRoute(builder: (_) => SaleReturnPage(documentId: documentId, invoiceData: data)))));
        }

        // 4. Cancel
        if (!isCancelled && (perms['canCancelBill'] || perms['isAdmin'])) {
          actions.add(_squareActionButton(HeroIcons.xCircle, 'Cancel', kErrorColor, () => _showCancelBillDialog(context, documentId, data)));
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: actions,
        );
      },
    );
  }

  Widget _squareActionButton(HeroIcons icon, String lbl, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 68, height: 68,
        decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2))
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HeroIcon(icon, size: 20, color: color),
            const SizedBox(height: 6),
            Text(lbl, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 9)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTag(bool settled, bool cancelled, bool edited, bool returned) {
    List<Widget> badges = [];

    // Priority order: cancelled > returned > edited
    if (cancelled) {
      badges.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: kBlack54.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBlack54.withOpacity(0.2)),
        ),
        child: const Text("Cancelled", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kBlack54)),
      ));
    }
    if (returned) {
      badges.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(0.2)),
        ),
        child: const Text("Returned", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.orange)),
      ));
    }
    if (edited) {
      badges.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.withOpacity(0.2)),
        ),
        child: const Text("Edited", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.blue)),
      ));
    }

    // Only show Unsettled if no other status badges and bill is unsettled
    // Remove "Settled" indication - don't show it anymore
    if (badges.isEmpty && !settled) {
      badges.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: kGoogleGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kGoogleGreen.withOpacity(0.2)),
        ),
        child: const Text(
          "Unsettled",
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kGoogleGreen),
        ),
      ));
    }

    // If no badges at all (settled with no special status), return empty container
    if (badges.isEmpty) {
      return const SizedBox.shrink();
    }

    // Return single badge or wrap multiple badges
    if (badges.length == 1) {
      return badges[0];
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: badges,
    );
  }
}// Close BillHistoryPage class

// ==========================================
// 4. CUSTOMER RELATED PAGES


// --- Global Theme Constants (Pure White BG, Standard Blue AppBar) ---
const Color kPrimaryColor = Color(0xFF4A5DF9);
const Color kDeepNavy = Color(0xFF1E293B);
const Color kMediumBlue = Color(0xFF475569);
const Color kWhite = Colors.white;
const Color kSoftAzure = Color(0xFFF1F5F9);
const Color kBorderColor = Color(0xFFE2E8F0);

// Semantic Colors
const Color kSuccessGreen = Color(0xFF4CAF50);
const Color kWarningOrange = Color(0xFFFF9800);
const Color kErrorRed = Color(0xFFFF5252);

// ==========================================
// 1. CREDIT NOTES LIST PAGE
// ==========================================
class CreditNotesPage extends StatefulWidget {
  final String uid;
  final VoidCallback onBack;

  const CreditNotesPage({super.key, required this.uid, required this.onBack});

  @override
  State<CreditNotesPage> createState() => _CreditNotesPageState();
}

class _CreditNotesPageState extends State<CreditNotesPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterStatus = 'All';
  String _currencySymbol = 'Rs ';
  // Stream that provides overdue credit bills for the notification bell (state-scoped)
  Stream<List<QueryDocumentSnapshot>>? _overdueBillsStream;

      @override
      void initState() {
        super.initState();
        _loadCurrency();
        _searchController.addListener(() {
          setState(() {
            _searchQuery = _searchController.text.toLowerCase();
          });
        });
        // Initialize stream that provides overdue credit bills for the notification bell
        _initOverdueBillsStream();
      }

      // Initialize a state-scoped stream of overdue (unsettled and past due) credit bills
      void _initOverdueBillsStream() async {
        final storeId = await FirestoreService().getCurrentStoreId();
        if (storeId == null || !mounted) return;

        setState(() {
          _overdueBillsStream = FirebaseFirestore.instance
              .collection('store')
              .doc(storeId)
              .collection('credits')
              .where('type', isEqualTo: 'credit_sale')
              .where('isSettled', isEqualTo: false)
              .snapshots()
              .map((snapshot) {
            final now = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
            final overdue = snapshot.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final dueDateRaw = data['creditDueDate'];
              if (dueDateRaw == null) return false;
              try {
                final dueDate = DateTime.parse(dueDateRaw.toString());
                final dueDateOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);
                return dueDateOnly.isBefore(now);
              } catch (_) {
                return false;
              }
            }).toList();

            // Sort by due date ascending
            overdue.sort((a, b) {
              try {
                final da = DateTime.parse((a.data() as Map<String, dynamic>)['creditDueDate'].toString());
                final db = DateTime.parse((b.data() as Map<String, dynamic>)['creditDueDate'].toString());
                return da.compareTo(db);
              } catch (_) {
                return 0;
              }
            });
            return overdue;
          });
        });
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
          title: Text(context.tr('credit_notes'),
              style: const TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
          backgroundColor: kPrimaryColor,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const HeroIcon(HeroIcons.arrowLeft, color: kWhite, size: 22),
            onPressed: widget.onBack,
          ),
        ),
        body: Column(
        children: [
          // ENTERPRISE SEARCH & FILTER HEADER
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            decoration: const BoxDecoration(
              color: kWhite,
              border: Border(bottom: BorderSide(color: kGrey200)),
            ),
            child: Row(
              children: [
                Expanded(
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
                      style: const TextStyle(color: kBlack87, fontWeight: FontWeight.w600, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: context.tr('search'),
                        hintStyle: const TextStyle(color: kBlack54, fontSize: 14),
                        prefixIcon: const HeroIcon(HeroIcons.magnifyingGlass, color: kPrimaryColor, size: 20),
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
                const SizedBox(width: 12),
                _buildStatusFilter(),
              ],
            ),
          ),

          Expanded(
            child: FutureBuilder<CollectionReference>(
              future: FirestoreService().getStoreCollection('creditNotes'),
              builder: (context, collectionSnapshot) {
                if (!collectionSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));

                return StreamBuilder<QuerySnapshot>(
                  stream: collectionSnapshot.data!.orderBy('timestamp', descending: true).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return _buildEmptyState();
                    }

                    var docs = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      if (_filterStatus != 'All' && (data['status'] ?? 'Available') != _filterStatus) return false;
                      if (_searchQuery.isNotEmpty) {
                        final cn = (data['creditNoteNumber'] ?? '').toString().toLowerCase();
                        final cust = (data['customerName'] ?? '').toString().toLowerCase();
                        return cn.contains(_searchQuery) || cust.contains(_searchQuery);
                      }
                      return true;
                    }).toList();

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      separatorBuilder: (c, i) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _buildCreditNoteCard(docs[index]),
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

  Widget _buildStatusFilter() {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: kPrimaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGrey200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _filterStatus,
          dropdownColor: kWhite,
          icon: const HeroIcon(HeroIcons.adjustmentsHorizontal, color: kPrimaryColor, size: 20),
          items: ['All', 'Available', 'Used'].map((s) => DropdownMenuItem(
              value: s,
              child: Text(s, style: const TextStyle(color: kBlack87,fontWeight: FontWeight.bold, fontSize: 13))
          )).toList(),
          onChanged: (v) => setState(() => _filterStatus = v!),
        ),
      ),
    );
  }

  Widget _buildCreditNoteCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final status = data['status'] ?? 'Available';
    final amount = (data['amount'] ?? 0.0) as num;
    final timestamp = data['timestamp'] as Timestamp?;
    final dateStr = timestamp != null ? DateFormat('dd MMM yyyy • hh:mm a').format(timestamp.toDate()) : '--';
    final isAvailable = status.toLowerCase() == 'available';

    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGrey200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(context, _NoAnimRoute(builder: (_) => _CreditNoteDetailPage(documentId: doc.id, creditNoteData: data, currencySymbol: _currencySymbol))),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: [
                    const HeroIcon(HeroIcons.documentText, size: 14, color: kPrimaryColor),
                    const SizedBox(width: 5),
                    Text(data['creditNoteNumber'] ?? 'CN-N/A', style: const TextStyle(fontWeight: FontWeight.w900, color: kPrimaryColor, fontSize: 13)),
                  ]),
                  Text(dateStr, style: const TextStyle(fontSize: 10.5, color: Colors.black, fontWeight: FontWeight.w500)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: Text(data['customerName'] ?? 'Guest',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                  ),
                  Text("$_currencySymbol${amount.toStringAsFixed(2)}",
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: kSuccessGreen)),
                ]),
                const Divider(height: 20, color: kGreyBg),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text("For invoice", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: kBlack54, letterSpacing: 0.5)),
                    Text(data['invoiceNumber'] ?? 'Manual Entry', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 10, color: kBlack87)),
                  ]),
                  Row(children: [
                    _statusBadge(isAvailable),
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

  Widget _statusBadge(bool available) {
    final Color c = available ? kGoogleGreen : kErrorColor;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: c.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.withOpacity(0.2))),
        child: Text(available ? "Available" : "Used",
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: c)));
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HeroIcon(HeroIcons.archiveBox, size: 64, color: kGrey300),
          const SizedBox(height: 16),
          Text(context.tr('no_records_found'), style: const TextStyle(color: kBlack54, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ==========================================
// INTERNAL SUB-PAGE: CREDIT NOTE DETAIL
// ==========================================
class _CreditNoteDetailPage extends StatelessWidget {
  final String documentId;
  final Map<String, dynamic> creditNoteData;
  final String currencySymbol;

  const _CreditNoteDetailPage({required this.documentId, required this.creditNoteData, required this.currencySymbol});

  @override
  Widget build(BuildContext context) {
    final amount = (creditNoteData['amount'] ?? 0.0) as num;
    final status = creditNoteData['status'] ?? 'Available';
    final items = (creditNoteData['items'] as List<dynamic>? ?? []);
    final ts = creditNoteData['timestamp'] as Timestamp?;
    final dateStr = ts != null ? DateFormat('dd MMM yyyy • hh:mm a').format(ts.toDate()) : 'N/A';
    final bool isAvailable = status.toLowerCase() == 'available';

    return Scaffold(
      backgroundColor: kPrimaryColor,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        title: const Text('Credit Note Info', style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: const HeroIcon(HeroIcons.arrowLeft, color: kWhite, size: 22), onPressed: () => Navigator.pop(context)),
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
                  CircleAvatar(backgroundColor: kOrange.withOpacity(0.1), radius: 18, child: const HeroIcon(HeroIcons.user, color: kOrange, size: 18)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(creditNoteData['customerName'] ?? 'Guest', style: const TextStyle(color: kOrange, fontSize: 15, fontWeight: FontWeight.w700)),
                      Text(creditNoteData['customerPhone'] ?? '--', style: const TextStyle(color: kBlack54, fontSize: 11)),
                    ]),
                  ),
                  _buildStatusTag(isAvailable),
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
                    const Text('Note information', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: kBlack54, letterSpacing: 0.5)),
                    const SizedBox(height: 12),
                    _buildDetailRow(HeroIcons.documentText, 'Reference ID', creditNoteData['creditNoteNumber'] ?? 'N/A'),
                    _buildDetailRow(HeroIcons.clock, 'Against Invoice', creditNoteData['invoiceNumber'] ?? 'Manual'),
                    _buildDetailRow(HeroIcons.calendarDays, 'Date Issued', dateStr),
                    _buildDetailRow(HeroIcons.informationCircle, 'Reason', creditNoteData['reason'] ?? 'Not Specified'),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: kGrey100, thickness: 1)),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Total credit value', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: kBlack54)),
                      Text('$currencySymbol${amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kPrimaryColor)),
                    ]),
                    const SizedBox(height: 24),
                    const Text('Returned items', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: kBlack54, letterSpacing: 0.5)),
                    const SizedBox(height: 12),
                    ...items.map((i) => _buildItemTile(i)).toList(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildStatusTag(bool available) {
    final Color c = available ? kGoogleGreen : kErrorColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(available ? "Available" : "Used", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: c)),
    );
  }

  Widget _buildDetailRow(HeroIcons icon, String label, String value) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [HeroIcon(icon, size: 14, color: kGrey400), const SizedBox(width: 10), Text('$label: ', style: const TextStyle(color: kBlack54, fontSize: 11, fontWeight: FontWeight.w500)), Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: kBlack87), overflow: TextOverflow.ellipsis))]));

  Widget _buildItemTile(Map<String, dynamic> i) => Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kGrey100))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(i['name'] ?? 'Item', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kBlack87)), Text("${i['quantity']} ×${(i['price'] ?? 0).toStringAsFixed(0)}", style: const TextStyle(color: kBlack54, fontSize: 11))])), Text("${((i['price'] ?? 0) * (i['quantity'] ?? 1)).toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: kBlack87))]));
}

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
  void initState() { super.initState(); _loadLedger(); _loadCurrency(); }

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
        entries.add(LedgerEntry(date: date, type: 'Inv', desc: "Invoice #${d['invoiceNumber']} ($mode)", debit: total, credit: 0, balanceImpact: 0));
      } else if (mode == 'Credit') {
        entries.add(LedgerEntry(date: date, type: 'Inv', desc: "Invoice #${d['invoiceNumber']} (Credit)", debit: total, credit: total, balanceImpact: total));
      } else if (mode == 'Split') {
        final cashPaid = (d['cashReceived'] ?? 0.0).toDouble();
        final onlinePaid = (d['onlineReceived'] ?? 0.0).toDouble();
        final creditAmt = total - cashPaid - onlinePaid;
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
        entries.add(LedgerEntry(date: date, type: 'Pay', desc: "Payment Received (${method.isNotEmpty ? method : 'Cash'})", debit: amt, credit: 0, balanceImpact: -amt));
      } else if (type == 'settlement') {
        entries.add(LedgerEntry(date: date, type: 'Pay', desc: "Credit Received (${method.isNotEmpty ? method : 'Cash'})", debit: amt, credit: 0, balanceImpact: -amt));
      } else if (type == 'add_credit') {
        entries.add(LedgerEntry(date: date, type: 'CR', desc: "Manual Credit Added", debit: 0, credit: amt, balanceImpact: amt));
      }
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
          color: kPrimaryColor.withOpacity(0.05),
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
                Expanded(flex: 3, child: Text(e.desc, style: const TextStyle(fontSize: 11, color: kBlack54, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                Expanded(flex: 2, child: Text(e.debit > 0 ? e.debit.toStringAsFixed(0) : "-", textAlign: TextAlign.right, style: const TextStyle(color: kGoogleGreen, fontSize: 11, fontWeight: FontWeight.w900))),
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
class CustomerBillsPage extends StatelessWidget {
  final String phone; const CustomerBillsPage({super.key, required this.phone});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),title: const Text("Billing History", style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 16)), backgroundColor: kPrimaryColor, elevation: 0, centerTitle: true, iconTheme: const IconThemeData(color: kWhite)),
      body: FutureBuilder<QuerySnapshot>(
        future: FirestoreService().getStoreCollection('sales').then((c) => c.where('customerPhone', isEqualTo: phone).get()),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return _billsEmptyState();
          }
          final docs = snapshot.data!.docs.toList();
          if (docs.isEmpty) return _billsEmptyState();
          // Sort by timestamp descending (latest first)
          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aDate = (aData['timestamp'] as Timestamp?)?.toDate() ?? DateTime(1970);
            final bDate = (bData['timestamp'] as Timestamp?)?.toDate() ?? DateTime(1970);
            return bDate.compareTo(aDate); // Descending order
          });
          return ListView.separated(
            padding: const EdgeInsets.all(16), itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final date = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
              final isCancelled = data['status'] == 'cancelled';
              final total = (data['total'] ?? 0.0).toDouble();
              final inv = data['invoiceNumber'] ?? 'N/A';
              return Container(
                decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {},
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Column(children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Row(children: [
                            const HeroIcon(HeroIcons.documentText, size: 14, color: kPrimaryColor),
                            const SizedBox(width: 5),
                            Text("#$inv", style: TextStyle(fontWeight: FontWeight.w900, color: isCancelled ? kBlack54 : kPrimaryColor, fontSize: 13)),
                          ]),
                          Text(DateFormat('dd MMM yyyy • hh:mm a').format(date), style: const TextStyle(fontSize: 10.5, color: Colors.black, fontWeight: FontWeight.w500)),
                        ]),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(child: Text(data['customerName'] ?? 'Guest', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87))),
                          Text(total.toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: isCancelled ? kBlack54 : kSuccessGreen, decoration: isCancelled ? TextDecoration.lineThrough : null)),
                        ]),
                        const Divider(height: 20, color: kGreyBg),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text("Status", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: kBlack54, letterSpacing: 0.5)),
                          ]),
                          Row(children: [
                            if (isCancelled) Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: kBlack54.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                              child: const Text("Cancelled", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kBlack54)),
                            ),
                            const SizedBox(width: 8),
                            const HeroIcon(HeroIcons.chevronRight, color: kPrimaryColor, size: 16),
                          ]),
                        ]),
                      ]),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _billsEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: kPrimaryColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const HeroIcon(HeroIcons.documentText, size: 38, color: kPrimaryColor),
            ),
            const SizedBox(height: 20),
            const Text(
              "No Bills Found",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kBlack87, fontFamily: 'NotoSans'),
            ),
            const SizedBox(height: 8),
            const Text(
              "This customer has no billing history yet",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: kBlack54, fontFamily: 'Lato'),
            ),
          ],
        ),
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
        ),title: const Text("Payment Log", style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 16)), backgroundColor: kPrimaryColor, elevation: 0, centerTitle: true, iconTheme: const IconThemeData(color: kWhite)),
      body: FutureBuilder<QuerySnapshot>(
        future: _fetchCredits(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [HeroIcon(HeroIcons.clock, size: 64, color: kGrey300), const SizedBox(height: 16), const Text("No transaction history", style: TextStyle(color: kBlack54,fontWeight: FontWeight.bold))]));
          final docs = snapshot.data!.docs.toList();
          // Sort by timestamp descending (latest first)
          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aDate = (aData['timestamp'] as Timestamp?)?.toDate() ?? DateTime(1970);
            final bDate = (bData['timestamp'] as Timestamp?)?.toDate() ?? DateTime(1970);
            return bDate.compareTo(aDate); // Descending order
          });
          return ListView.separated(
            padding: const EdgeInsets.all(16), itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              bool isPayment = data['type'] == 'payment_received';
              final isCancelled = data['status'] == 'cancelled';
              final date = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
              final amount = (data['amount'] ?? 0.0).toDouble();
              final Color amtColor = isCancelled ? kBlack54 : (isPayment ? kSuccessGreen : kErrorColor);
              return Container(
                decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {},
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Column(children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Row(children: [
                            HeroIcon(isPayment ? HeroIcons.arrowDown : HeroIcons.arrowUp, size: 14, color: amtColor),
                            const SizedBox(width: 5),
                            Text(isPayment ? "Payment" : "Credit", style: TextStyle(fontWeight: FontWeight.w900, color: amtColor, fontSize: 13)),
                          ]),
                          Text(DateFormat('dd MMM yyyy • hh:mm a').format(date), style: const TextStyle(fontSize: 10.5, color: Colors.black, fontWeight: FontWeight.w500)),
                        ]),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(child: Text(isPayment ? "Payment Received" : "Credit Added", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87))),
                          Text(amount.toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: amtColor, decoration: isCancelled ? TextDecoration.lineThrough : null)),
                        ]),
                        const Divider(height: 20, color: kGreyBg),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text("Method", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: kBlack54, letterSpacing: 0.5)),
                            Text(data['method'] ?? 'Manual', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 10, color: kBlack87)),
                          ]),
                          Row(children: [
                            if (isCancelled) Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: kBlack54.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                              child: const Text("Cancelled", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kBlack54)),
                            ),
                            const SizedBox(width: 8),
                            const HeroIcon(HeroIcons.chevronRight, color: kPrimaryColor, size: 16),
                          ]),
                        ]),
                      ]),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<QuerySnapshot> _fetchCredits() async {
    try {
      final collection = await FirestoreService().getStoreCollection('credits');
      return await collection.where('customerId', isEqualTo: customerId).orderBy('timestamp', descending: true).get();
    } catch (e) {
      final collection = await FirestoreService().getStoreCollection('credits');
      return await collection.where('customerId', isEqualTo: customerId).get();
    }
  }
}
class _ReceiveCreditPage extends StatefulWidget {
  final String customerId; final Map<String, dynamic> customerData; final double currentBalance;
  const _ReceiveCreditPage({required this.customerId, required this.customerData, required this.currentBalance});
  @override State<_ReceiveCreditPage> createState() => _ReceiveCreditPageState();
}

class _ReceiveCreditPageState extends State<_ReceiveCreditPage> {
  final TextEditingController _amountController = TextEditingController();
  double _amt = 0.0;
  String _currencySymbol = '';
  bool _isSaving = false; // Prevents double-click

  @override
  void initState() {
    super.initState();
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
            const Spacer(),
            SafeArea(
              top: false,
              child: SizedBox(width: double.infinity, height: 60, child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), disabledBackgroundColor: kPrimaryColor.withOpacity(0.6)),
                onPressed: (_amt <= 0 || _isSaving) ? null : () async {
                  setState(() => _isSaving = true);
                  try {
                    final cCol = await FirestoreService().getStoreCollection('customers');
                    final crCol = await FirestoreService().getStoreCollection('credits');
                    await cCol.doc(widget.customerId).update({'balance': widget.currentBalance - _amt});
                    await crCol.add({'customerId': widget.customerId, 'customerName': widget.customerData['name'], 'amount': _amt, 'type': 'payment_received', 'method': 'Cash', 'timestamp': FieldValue.serverTimestamp()});
                    if (mounted) Navigator.pop(context);
                  } catch (e) {
                    if (mounted) setState(() => _isSaving = false);
                  }
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _isSaving
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: kWhite, strokeWidth: 2.5))
                      : const Text("Save payment", style: TextStyle(color: kWhite, fontSize: 16, fontWeight: FontWeight.w900)),
                ),
              )),
            ),
          ],
          ),
        )
    );
  }
}

// ==========================================
// 2. CREDIT NOTE DETAIL PAGE
// ==========================================
class CreditNoteDetailPage extends StatelessWidget {
  final String documentId;
  final Map<String, dynamic> creditNoteData;
  final String currencySymbol;

  const CreditNoteDetailPage({
    super.key,
    required this.documentId,
    required this.creditNoteData,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    final amount = (creditNoteData['amount'] ?? 0.0) as num;
    final status = creditNoteData['status'] ?? 'Available';
    final items = (creditNoteData['items'] as List<dynamic>? ?? []);
    final timestamp = creditNoteData['timestamp'] as Timestamp?;
    final dateString = timestamp != null ? DateFormat('dd MMM yyyy • h:mm a').format(timestamp.toDate()) : 'N/A';

    return Scaffold(
      backgroundColor: kWhite,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),

        title: const Text('Detail Overview',
            style: TextStyle(color: kWhite,fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const HeroIcon(HeroIcons.arrowLeft, color: kWhite),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Prominent Amount Card
            _buildHeroCard(creditNoteData['creditNoteNumber'] ?? 'N/A', amount, status),

            const SizedBox(height: 24),
            _buildSectionTitle("Information"),
            _buildSectionCard(
              child: Column(
                children: [
                  _buildIconRow(HeroIcons.documentText, "Invoice ID", "#${creditNoteData['invoiceNumber']}", kPrimaryColor),
                  const Divider(height: 32),
                  _buildIconRow(HeroIcons.user, "Customer", creditNoteData['customerName'] ?? 'Guest', kSuccessGreen),
                  const Divider(height: 32),
                  _buildIconRow(HeroIcons.calendarDays, "Issued", dateString, kWarningOrange),
                ],
              ),
            ),

            const SizedBox(height: 24),
            _buildSectionTitle("Items List"),
            _buildSectionCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  if (items.isEmpty)
                    const Padding(padding: EdgeInsets.all(32), child: Text("No items listed", style: TextStyle(color: kMediumBlue))),
                  ...items.map((item) => _buildItemRow(item)).toList(),
                  _buildDetailTotalRow(amount, items.length),
                ],
              ),
            ),

            const SizedBox(height: 32),
            if (status == 'Available')
              _buildLargeButton(
                context,
                label: "Process Refund",
                icon: HeroIcons.checkCircle,
                color: kSuccessGreen,
                onPressed: () => _showRefundDialog(context),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(String id, num amount, String status) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kPrimaryColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: kPrimaryColor.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(id, style: const TextStyle(color: Colors.white,fontWeight: FontWeight.bold)),
              _buildStatusPill(status, isInverse: true),
            ],
          ),
          const SizedBox(height: 20),
          const Text("Refund amount", style: TextStyle(color: Colors.white70,fontWeight: FontWeight.bold, fontSize: 11)),
          const SizedBox(height: 4),
          Text("$currencySymbol${amount.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 32)),
        ],
      ),
    );
  }

  void _showRefundDialog(BuildContext context) {
    String mode = 'Cash';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Confirm Refund', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select refund method:', style: TextStyle(color: kMediumBlue)),
              const SizedBox(height: 24),
              _buildDialogOption(onSelect: () => setState(() => mode = "Cash"), mode: "Cash", current: mode, icon: HeroIcons.banknotes, color: kSuccessGreen),
              const SizedBox(height: 12),
              _buildDialogOption(onSelect: () => setState(() => mode = "Online"), mode: "Online", current: mode, icon: HeroIcons.buildingLibrary, color: kPrimaryColor),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: kErrorRed))),
            ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final scaffoldMessenger = ScaffoldMessenger.of(context);

                Navigator.pop(ctx); // Close dialog

                // Show loading
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const Center(child: CircularProgressIndicator()),
                );

                try {
                  debugPrint('🔵 [Refund] Starting refund process...');
                  debugPrint('🔵 [Refund] Document ID: $documentId');
                  debugPrint('🔵 [Refund] Amount: ${creditNoteData['amount']}');
                  debugPrint('🔵 [Refund] Customer Phone: ${creditNoteData['customerPhone']}');

                  // Process refund - Update backend
                  await _processRefund(mode);

                  debugPrint('🔵 [Refund] Refund completed successfully');

                  // Always close loading first
                  navigator.pop(); // Close loading

                  // Then close detail page
                  navigator.pop(); // Close detail page

                  // Show success message
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Refund processed successfully'),
                      backgroundColor: kSuccessGreen,
                      duration: Duration(seconds: 2),
                    ),
                  );
                } catch (e) {
                  debugPrint('🔴 [Refund] Error: $e');

                  // Always close loading
                  navigator.pop(); // Close loading

                  // Show error message
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: kErrorRed,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: kSuccessGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  /// Process refund - Update credit note status and customer balance in backend
  Future<void> _processRefund(String paymentMode) async {
    try {
      debugPrint('🔵 [Refund] Step 1: Getting credit note data...');
      final amount = (creditNoteData['amount'] ?? 0.0) as num;
      final customerPhone = creditNoteData['customerPhone'] as String?;
      debugPrint('🔵 [Refund] Amount: $amount, Customer Phone: $customerPhone');

      // Update credit note status to 'Used' in backend
      debugPrint('🔵 [Refund] Step 2: Updating credit note status...');
      await FirestoreService().updateDocument('creditNotes', documentId, {
        'status': 'Used',
        'refundMethod': paymentMode,
        'refundedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('🔵 [Refund] Credit note status updated');

      // Update customer balance - reduce by refund amount
      if (customerPhone != null && customerPhone.isNotEmpty) {
        debugPrint('🔵 [Refund] Step 3: Getting customer reference...');
        final customerRef = await FirestoreService().getDocumentReference('customers', customerPhone);

        debugPrint('🔵 [Refund] Step 4: Starting transaction to update balance...');
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final customerDoc = await transaction.get(customerRef);
          if (customerDoc.exists) {
            final currentBalance = (customerDoc.data() as Map<String, dynamic>?)?['balance'] as double? ?? 0.0;
            final newBalance = (currentBalance - amount.toDouble()).clamp(0.0, double.infinity);

            debugPrint('🔵 [Refund] Current balance: $currentBalance, New balance: $newBalance');

            transaction.update(customerRef, {
              'balance': newBalance,
              'lastUpdated': FieldValue.serverTimestamp()
            });
          }
        });
        debugPrint('🔵 [Refund] Customer balance updated');

        // Add refund record to credits collection
        debugPrint('🔵 [Refund] Step 5: Adding refund record to credits...');
        await FirestoreService().addDocument('credits', {
          'customerId': customerPhone,
          'customerName': creditNoteData['customerName'] ?? 'Unknown',
          'amount': -amount.toDouble(),  // Negative for refund
          'type': 'refund',
          'method': paymentMode,
          'creditNoteNumber': creditNoteData['creditNoteNumber'],
          'invoiceNumber': creditNoteData['invoiceNumber'],
          'timestamp': FieldValue.serverTimestamp(),
          'date': DateTime.now().toIso8601String(),
          'note': 'Refund for Credit Note #${creditNoteData['creditNoteNumber']}',
        });
        debugPrint('🔵 [Refund] Refund record added to credits');
      }

      debugPrint('🔵 [Refund] Process completed successfully');
    } catch (e, stackTrace) {
      debugPrint('🔴 [Refund] Error processing refund: $e');
      debugPrint('🔴 [Refund] Stack trace: $stackTrace');
      rethrow;
    }
  }
}

// ==========================================
// 3. CREDIT DETAILS PAGE
// ==========================================


// --- UI CONSTANTS (Matching Quotations Style) ---
const Color _primaryColor = Color(0xFF2F7CF6);
const Color _successColor = Color(0xFF4CAF50);
const Color _errorColor = Color(0xFFEF4444);
const Color _cardBorder = Color(0xFFE3F2FD);
const Color _bgColor = Colors.white;

class CreditDetailsPage extends StatefulWidget {
  final String uid;
  final VoidCallback onBack;

  const CreditDetailsPage({super.key, required this.uid, required this.onBack});

  @override
  State<CreditDetailsPage> createState() => _CreditDetailsPageState();
}

class _CreditDetailsPageState extends State<CreditDetailsPage> {
  final TextEditingController _searchController = TextEditingController();
  final Map<String, double> _salesCreditCache = {};
  String _searchQuery = '';
  bool _isSearching = false;
  String _currencySymbol = '';
  Stream<List<QueryDocumentSnapshot>>? _overdueBillsStream;

    @override
    void initState() {
    super.initState();
    _loadCurrency();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    // Initialize overdue bills stream for notification bell
    _initOverdueBillsStream();
    }

    // Prepare a stream that emits list of overdue credit entries (unsettled and past due)
    void _initOverdueBillsStream() async {
    final storeId = await FirestoreService().getCurrentStoreId();
    if (storeId == null || !mounted) return;

    setState(() {
      _overdueBillsStream = FirebaseFirestore.instance
          .collection('store')
          .doc(storeId)
          .collection('credits')
          .where('type', isEqualTo: 'credit_sale')
          .where('isSettled', isEqualTo: false)
          .snapshots()
          .map((snapshot) {
        final now = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
        final overdue = snapshot.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final dueDateRaw = data['creditDueDate'];
          if (dueDateRaw == null) return false;
          try {
            final dueDate = DateTime.parse(dueDateRaw.toString());
            final dueDateOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);
            return dueDateOnly.isBefore(now);
          } catch (_) {
            return false;
          }
        }).toList();

        overdue.sort((a, b) {
          try {
            final da = DateTime.parse((a.data() as Map<String, dynamic>)['creditDueDate'].toString());
            final db = DateTime.parse((b.data() as Map<String, dynamic>)['creditDueDate'].toString());
            return da.compareTo(db);
          } catch (_) {
            return 0;
          }
        });
        return overdue;
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) widget.onBack();
      },
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: kGreyBg,
          appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
            elevation: 0,
            backgroundColor: kPrimaryColor,
            iconTheme: const IconThemeData(color: kWhite),
            leading: IconButton(
              icon: const HeroIcon(HeroIcons.arrowLeft, size: 22),
              onPressed: widget.onBack,
            ),
            title: _isSearching
                ? ValueListenableBuilder<TextEditingValue>(
      valueListenable: _searchController,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: kBlack87, fontSize: 16),
              decoration: InputDecoration(
                hintText: "Search name or contact...",
                hintStyle: const TextStyle(color: kBlack54),
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
    )
                : const Text(
              'Credit Tracker',
              style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18),
            ),
            centerTitle: true,
            actions: [
              StreamBuilder<List<QueryDocumentSnapshot>>(
                stream: _overdueBillsStream,
                builder: (context, snapshot) {
                  final list = snapshot.data ?? [];
                  if (list.isEmpty) return const SizedBox.shrink();

                  // compute unique customer phones
                  final Set<String> uniquePhones = <String>{};
                  for (var doc in list) {
                    final data = doc.data() as Map<String, dynamic>;
                    final phone = (data['customerPhone'] ?? data['customerId'] ?? '').toString().trim();
                    if (phone.isNotEmpty) uniquePhones.add(phone);
                  }
                  final int badgeCount = uniquePhones.length;

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: const HeroIcon(HeroIcons.bell, size: 22, color: kWhite),
                        onPressed: () => _showOverdueBillsSheet(context, list),
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: kErrorColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: kPrimaryColor, width: 1.5),
                          ),
                          constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                          child: Text(
                            badgeCount.toString(),
                            style: const TextStyle(color: kWhite, fontSize: 8, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    ],
                  );
                }
              ),
              IconButton(
                icon: HeroIcon(_isSearching ? HeroIcons.xMark : HeroIcons.magnifyingGlass, size: 22),
                onPressed: () => setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) _searchController.clear();
                }),
              ),
            ],
            bottom: const TabBar(
              indicatorColor: kWhite,
              indicatorWeight: 4,
              labelStyle: TextStyle(fontWeight: FontWeight.w800, color: kWhite, fontSize: 12, letterSpacing: 0.5),
              unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, color: Colors.white70, fontSize: 12),
              tabs: [
                Tab(text: "Sales credit"),
                Tab(text: "Purchase credit"),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _buildSalesList(),
              _buildPurchaseList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSalesList() {
    return FutureBuilder<CollectionReference>(
      future: FirestoreService().getStoreCollection('customers'),
      builder: (context, collectionSnapshot) {
        if (!collectionSnapshot.hasData) return _buildLoading();
        return StreamBuilder<QuerySnapshot>(
          stream: collectionSnapshot.data!.where('balance', isGreaterThan: 0).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return _buildLoading();

            final docs = snapshot.data?.docs ?? [];
            final filtered = docs.where((d) {
              final data = d.data() as Map<String, dynamic>;
              final name = (data['name'] ?? '').toString().toLowerCase();
              final phone = (data['phone'] ?? '').toString().toLowerCase();
              return name.contains(_searchQuery) || phone.contains(_searchQuery);
            }).toList();

            double totalSalesCredit = 0.0;
            for (var doc in filtered) {
              totalSalesCredit += ((doc.data() as Map<String, dynamic>)['balance'] ?? 0.0) as num;
            }

            if (filtered.isEmpty && _searchQuery.isEmpty) return _buildEmptyState("No outstanding customer dues.");
            if (filtered.isEmpty) return _buildEmptyState("No results found for '$_searchQuery'");

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length + 1,
              separatorBuilder: (c, i) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) return _buildTotalSummary(totalSalesCredit, kGoogleGreen, "Total receivable");
                return _buildSalesCard(filtered[index - 1]);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPurchaseList() {
    return FutureBuilder<CollectionReference>(
      future: FirestoreService().getStoreCollection('purchaseCreditNotes'),
      builder: (context, collectionSnapshot) {
        if (!collectionSnapshot.hasData) return _buildLoading();
        return StreamBuilder<QuerySnapshot>(
          stream: collectionSnapshot.data!.orderBy('timestamp', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return _buildLoading();

            final docs = snapshot.data?.docs ?? [];
            final filtered = docs.where((d) {
              final data = d.data() as Map<String, dynamic>;

              // ── Hide fully settled credit notes ──────────────────────
              final status = (data['status'] ?? '').toString();
              if (status == 'Used' || status == 'Settled') return false;
              final remaining = ((data['amount'] ?? 0.0) as num) - ((data['paidAmount'] ?? 0.0) as num);
              if (remaining <= 0) return false;

              final supplier = (data['supplierName'] ?? '').toString().toLowerCase();
              final noteNo = (data['creditNoteNumber'] ?? '').toString().toLowerCase();
              return supplier.contains(_searchQuery) || noteNo.contains(_searchQuery);
            }).toList();

            double totalPurchaseCredit = 0.0;
            for (var doc in filtered) {
              final data = doc.data() as Map<String, dynamic>;
              final amt = (data['amount'] ?? 0.0 as num).toDouble();
              final paid = (data['paidAmount'] ?? 0.0 as num).toDouble();
              totalPurchaseCredit += (amt - paid).clamp(0.0, double.infinity);
            }

            if (filtered.isEmpty && _searchQuery.isEmpty) return _buildEmptyState("No pending purchase credits.");
            if (filtered.isEmpty) return _buildEmptyState("No results found for '$_searchQuery'");

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length + 1,
              separatorBuilder: (c, i) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) return _buildTotalSummary(totalPurchaseCredit, kErrorColor, "Total payable");
                return _buildPurchaseCard(filtered[index - 1]);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTotalSummary(double amount, Color color, String title) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Text('$_currencySymbol${amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kPrimaryColor)),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: HeroIcon(HeroIcons.wallet, color: color, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final customerName = (data['name'] ?? 'Guest').toString();
    final phone = (data['phone'] ?? 'N/A').toString();
    final rating = (data['rating'] ?? 0) as num;
    final balance = (data['balance'] ?? 0.0).toDouble();

    return _buildSalesCardInner(doc.id, data, customerName, phone, rating, balance);
  }

  Widget _buildSalesCardInner(String docId, Map<String, dynamic> data, String customerName, String phone, num rating, double balance) {
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
          onTap: () => Navigator.push(
            context,
            _NoAnimRoute(builder: (_) => CustomerCreditDetailsPage(
              customerId: docId,
              customerData: data,
              currentBalance: balance,
            )),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                      if (rating > 0) ...[
                        const SizedBox(width: 8),
                        ...List.generate(5, (i) => HeroIcon(
                          HeroIcons.star,
                          style: i < rating ? HeroIconStyle.solid : HeroIconStyle.outline,
                          size: 12,
                          color: i < rating ? kOrange : kGrey300,
                        )),
                      ],
                    ]),
                    Text(phone, style: const TextStyle(color: kBlack54, fontSize: 12, fontWeight: FontWeight.w500)),
                  ]),
                ),
                const HeroIcon(HeroIcons.chevronRight, color: kPrimaryColor, size: 16),
              ]),
              const Divider(height: 20, color: kGreyBg),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Balance due', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: kBlack54, letterSpacing: 0.5)),
                  Text('$_currencySymbol${balance.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: kPrimaryColor)),
                ]),
                _statusBadge("Settle", kGoogleGreen),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildPurchaseCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final total = (data['amount'] ?? 0.0) as num;
    final paid = (data['paidAmount'] ?? 0.0) as num;
    final remaining = (total - paid).toDouble();
    final supplierName = (data['supplierName'] ?? 'Supplier').toString();
    final noteNumber = (data['creditNoteNumber'] ?? 'N/A').toString();
    final timestamp = data['timestamp'] as Timestamp?;
    final dateStr = timestamp != null ? DateFormat('dd MMM yyyy • hh:mm a').format(timestamp.toDate()) : '--';

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
          onTap: () => _showSettleDialog(doc.id, data, remaining),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [
                  const HeroIcon(HeroIcons.buildingStorefront, size: 14, color: kPrimaryColor),
                  const SizedBox(width: 5),
                  Text(noteNumber, style: const TextStyle(fontWeight: FontWeight.w900, color: kPrimaryColor, fontSize: 13)),
                ]),
                Text(dateStr, style: const TextStyle(fontSize: 10.5, color: Colors.black, fontWeight: FontWeight.w500)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: Text(supplierName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87), overflow: TextOverflow.ellipsis)),
                Text('$_currencySymbol${remaining.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: kSuccessGreen)),
              ]),
              const Divider(height: 20, color: kGreyBg),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Pending amount', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: kBlack54, letterSpacing: 0.5)),
                ]),
                Row(children: [
                  _statusBadge("Record", kGoogleGreen),
                  const SizedBox(width: 8),
                  const HeroIcon(HeroIcons.chevronRight, color: kPrimaryColor, size: 16),
                ]),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  void _showOverdueBillsSheet(BuildContext context, List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) return;

    // Group by customerId
    final Map<String, Map<String, dynamic>> overdueCustomers = {};
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final customerId = (data['customerId'] ?? '').toString().trim();
      if (customerId.isEmpty) continue;

      if (!overdueCustomers.containsKey(customerId)) {
        overdueCustomers[customerId] = {
          'name': data['customerName'] ?? 'Unknown',
          'phone': customerId,
          'totalDue': 0.0,
          'billCount': 0,
          'earliestDue': data['creditDueDate']?.toString() ?? '',
        };
      }

      final amount = ((data['amount'] ?? 0.0) as num).toDouble();
      overdueCustomers[customerId]!['totalDue'] += amount;
      overdueCustomers[customerId]!['billCount'] =
          (overdueCustomers[customerId]!['billCount'] as int) + 1;

      // Track the earliest due date for this customer
      final existingDue = overdueCustomers[customerId]!['earliestDue'] as String;
      final newDue = data['creditDueDate']?.toString() ?? '';
      if (existingDue.isEmpty || (newDue.isNotEmpty && newDue.compareTo(existingDue) < 0)) {
        overdueCustomers[customerId]!['earliestDue'] = newDue;
      }
    }

    // Sort by earliest due date
    final customers = overdueCustomers.values.toList()
      ..sort((a, b) {
        final da = a['earliestDue'] as String;
        final db = b['earliestDue'] as String;
        return da.compareTo(db);
      });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: kWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: kGrey200, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    const HeroIcon(HeroIcons.exclamationTriangle, color: kErrorColor, size: 24),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Overdue Customers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kErrorColor)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: kErrorColor, borderRadius: BorderRadius.circular(10)),
                      child: Text('${customers.length}', style: const TextStyle(color: kWhite, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: customers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final c = customers[index];
                    final dueStr = c['earliestDue'] as String;
                    String dueLabel = '';
                    try {
                      final dueDate = DateTime.parse(dueStr);
                      dueLabel = DateFormat('dd MMM yyyy').format(dueDate);
                    } catch (_) {}

                    final customerName = c['name'] as String;
                    final customerPhone = c['phone'] as String;
                    final totalDue = c['totalDue'] as double;
                    final billCount = c['billCount'] as int;

                    // Compose the overdue reminder message
                    String shareMessage =
                        'Dear $customerName,\n\n'
                        'This is a gentle reminder that you have an overdue balance of $_currencySymbol${totalDue.toStringAsFixed(2)} '
                        'across $billCount unpaid bill(s).'
                        '${dueLabel.isNotEmpty ? '\nDue since: $dueLabel' : ''}\n\n'
                        'Please clear your dues at the earliest to avoid any inconvenience.\n\n'
                        'Thank you!';

                    return Container(
                      decoration: BoxDecoration(
                        color: kWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kErrorColor.withValues(alpha: 0.4)),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            Navigator.pop(context);
                            try {
                              final customersCol = await FirestoreService().getStoreCollection('customers');
                              final custDoc = await customersCol.doc(customerPhone).get();
                              final custData = custDoc.exists
                                  ? (custDoc.data() as Map<String, dynamic>)
                                  : {'name': customerName, 'phone': customerPhone};
                              final balance = (custData['balance'] ?? totalDue).toDouble();
                              if (mounted) {
                                Navigator.push(this.context, _NoAnimRoute(builder: (_) => CustomerCreditDetailsPage(customerId: customerPhone, customerData: custData, currentBalance: balance)));
                              }
                            } catch (_) {
                              if (mounted) {
                                Navigator.push(this.context, _NoAnimRoute(builder: (_) => CustomerCreditDetailsPage(customerId: customerPhone, customerData: {'name': customerName, 'phone': customerPhone}, currentBalance: totalDue)));
                              }
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Column(children: [
                              // Row 1: name | date
                              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                Row(children: [
                                  const HeroIcon(HeroIcons.user, size: 14, color: kErrorColor),
                                  const SizedBox(width: 5),
                                  Text(customerName, style: const TextStyle(fontWeight: FontWeight.w900, color: kErrorColor, fontSize: 13)),
                                ]),
                                if (dueLabel.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: kErrorColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                    child: Text('Due $dueLabel', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kErrorColor)),
                                  ),
                              ]),
                              const SizedBox(height: 10),
                              // Row 2: phone | amount
                              Row(children: [
                                Expanded(child: Text(customerPhone, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87))),
                                Text('$_currencySymbol${totalDue.toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: kSuccessGreen)),
                              ]),
                              const Divider(height: 20, color: kGreyBg),
                              // Row 3: bills count | share buttons + chevron
                              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  const Text('Overdue bills', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: kBlack54, letterSpacing: 0.5)),
                                  Text('$billCount bill(s)', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 10, color: kBlack87)),
                                ]),
                                Row(mainAxisSize: MainAxisSize.min, children: [
                                  if (RegExp(r'^\d{7,15}$').hasMatch(customerPhone.replaceAll(RegExp(r'[\s\-+()]'), '')))
                                    GestureDetector(
                                      onTap: () async {
                                        final cleanPhone = customerPhone.replaceAll(RegExp(r'[\s\-+()]'), '');
                                        final waUrl = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(shareMessage)}');
                                        if (await launcher.canLaunchUrl(waUrl)) await launcher.launchUrl(waUrl, mode: launcher.LaunchMode.externalApplication);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(color: const Color(0xFF25D366).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.3))),
                                        child: const HeroIcon(HeroIcons.chatBubbleLeft, color: Color(0xFF25D366), size: 14),
                                      ),
                                    ),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () => Share.share(shareMessage, subject: 'Overdue Payment Reminder – $customerName'),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(color: kPrimaryColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: kPrimaryColor.withValues(alpha: 0.25))),
                                      child: const HeroIcon(HeroIcons.share, color: kPrimaryColor, size: 14),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const HeroIcon(HeroIcons.chevronRight, color: kPrimaryColor, size: 16),
                                ]),
                              ]),
                            ]),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5)),
    );
  }

  // --- REFINED DIALOGS ---

  void _showSettleDialog(String docId, Map<String, dynamic> data, double remaining) {
    final TextEditingController amountController = TextEditingController();
    String paymentMode = 'Cash';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: kWhite,
          title: const Text('Settle Purchase', style: TextStyle(fontWeight: FontWeight.w800, color: kBlack87, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: kErrorColor.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: kErrorColor.withOpacity(0.15))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Due amount', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kErrorColor, letterSpacing: 0.5)),
                    Text('$_currencySymbol${remaining.toStringAsFixed(2)}', style: const TextStyle(color: kErrorColor, fontWeight: FontWeight.w900, fontSize: 16)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildDialogField(amountController, 'Amount to Pay', HeroIcons.currencyDollar),
              const SizedBox(height: 20),
              _buildPayOption(setDialogState, paymentMode, 'Cash', HeroIcons.banknotes, kGoogleGreen, (v) => paymentMode = v),
              const SizedBox(height: 8),
              _buildPayOption(setDialogState, paymentMode, 'Online', HeroIcons.buildingLibrary, kPrimaryColor, (v) => paymentMode = v),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: kBlack54,fontWeight: FontWeight.bold))),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0 || amount > remaining) return;
                Navigator.pop(ctx);
                _performAsyncAction(() => _settlePurchaseCredit(docId, data, amount, paymentMode), "Purchase settled successfully");
              },
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Confirm', style: TextStyle(color: kWhite,fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomerSettlementDialog(String customerId, Map<String, dynamic> customerData, double currentBalance) {
    final TextEditingController amountController = TextEditingController(text: currentBalance.toStringAsFixed(2));
    String paymentMode = 'Cash';
    final customerRating = (customerData['rating'] ?? 0) as num;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: kWhite,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Customer Payment', style: TextStyle(fontWeight: FontWeight.w800, color: kBlack87, fontSize: 18)),
              const SizedBox(height: 8),
              // Customer Rating Display with Edit Option
              Row(
                children: [
                  ...List.generate(5, (i) => GestureDetector(
                    onTap: () {
                      // Show rating edit dialog
                      _showEditRatingDialog(customerId, customerData, i + 1);
                    },
                    child: HeroIcon(
                      i < customerRating ? HeroIcons.star : HeroIcons.star,
                      style: i < customerRating ? HeroIconStyle.solid : HeroIconStyle.outline,
                      size: 20,
                      color: i < customerRating ? kOrange : kGrey300,
                    ),
                  )),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _showEditRatingDialog(customerId, customerData, customerRating.toInt()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: kPrimaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          HeroIcon(HeroIcons.pencil, size: 12, color: kPrimaryColor),
                          SizedBox(width: 4),
                          Text('Edit', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kPrimaryColor)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: kGoogleGreen.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: kGoogleGreen.withOpacity(0.15))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total due', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kGoogleGreen, letterSpacing: 0.5)),
                      Text('${currentBalance.toStringAsFixed(2)}', style: const TextStyle(color: kGoogleGreen, fontWeight: FontWeight.w900, fontSize: 16)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildDialogField(amountController, 'Settlement Amount', HeroIcons.currencyDollar),
                const SizedBox(height: 20),
                _buildPayOption(setDialogState, paymentMode, 'Cash', HeroIcons.banknotes, kGoogleGreen, (v) => paymentMode = v),
                const SizedBox(height: 8),
                _buildPayOption(setDialogState, paymentMode, 'Online', HeroIcons.buildingLibrary, kPrimaryColor, (v) => paymentMode = v),
                const SizedBox(height: 8),
                _buildPayOption(setDialogState, paymentMode, 'Waive Off', HeroIcons.noSymbol, kOrange, (v) => paymentMode = v),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: kBlack54,fontWeight: FontWeight.bold))),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0 || amount > currentBalance) return;
                Navigator.pop(ctx);
                _performAsyncAction(() => _settleCustomerCredit(customerId, customerData, amount, paymentMode, currentBalance), "Payment recorded successfully");
              },
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Settle', style: TextStyle(color: kWhite,fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogField(TextEditingController ctrl, String label, HeroIcons icon) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: ctrl,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          decoration: InputDecoration(
            labelText: label, prefixIcon: HeroIcon(icon, color: kPrimaryColor, size: 18),
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

  void _showEditRatingDialog(String customerId, Map<String, dynamic> customerData, int currentRating) {
    int selectedRating = currentRating;

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
                        backgroundColor: kPrimaryColor.withOpacity(0.1),
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
                            index < selectedRating ? HeroIcons.star : HeroIcons.star,
                            style: index < selectedRating ? HeroIconStyle.solid : HeroIconStyle.outline,
                            size: 40,
                            color: index < selectedRating ? kOrange : kGrey300,
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
              if (currentRating > 0)
                TextButton(
                  onPressed: () {
                    _updateCustomerRating(customerId, 0);
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
                  _updateCustomerRating(customerId, selectedRating);
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

  Future<void> _updateCustomerRating(String customerId, int rating) async {
    try {
      final customersCollection = await FirestoreService().getStoreCollection('customers');

      if (rating > 0) {
        await customersCollection.doc(customerId).update({
          'rating': rating,
          'ratedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const HeroIcon(HeroIcons.star, style: HeroIconStyle.solid, color: kOrange, size: 20),
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
        await customersCollection.doc(customerId).update({
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

  Widget _buildPayOption(StateSetter setDialogState, String current, String val, HeroIcons icon, Color color, Function(String) onSel) {
    final sel = current == val;
    return InkWell(
      onTap: () => setDialogState(() => onSel(val)),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: sel ? color.withOpacity(0.08) : Colors.transparent, borderRadius: BorderRadius.circular(12), border: Border.all(color: sel ? color : kGrey200)),
        child: Row(
          children: [
            HeroIcon(icon, color: sel ? color : kBlack54, size: 18),
            const SizedBox(width: 12),
            Text(val, style: TextStyle(color: sel ? color : kBlack87, fontWeight: sel ? FontWeight.w900 : FontWeight.w600, fontSize: 13)),
            const Spacer(),
            if (sel) HeroIcon(HeroIcons.checkCircle, color: color, size: 18),
          ],
        ),
      ),
    );
  }

  // --- ASYNC HELPERS ---

  Future<void> _performAsyncAction(Future<void> Function() action, String successMsg) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: kPrimaryColor)));
    try {
      await action();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMsg), backgroundColor: kGoogleGreen, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: kErrorColor, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
    }
  }

  Future<void> _settlePurchaseCredit(String docId, Map<String, dynamic> data, double amount, String mode) async {
    final paid = (data['paidAmount'] ?? 0.0) as num;
    await FirestoreService().updateDocument('purchaseCreditNotes', docId, {
      'paidAmount': paid + amount,
      'lastPaymentDate': FieldValue.serverTimestamp(),
      'lastPaymentMethod': mode,
    });
    await FirestoreService().addDocument('purchasePayments', {
      'creditNoteId': docId, 'creditNoteNumber': data['creditNoteNumber'], 'supplierName': data['supplierName'],
      'amount': amount, 'paymentMode': mode, 'timestamp': FieldValue.serverTimestamp(), 'date': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _settleCustomerCredit(String id, Map<String, dynamic> data, double amt, String mode, double old) async {
    final custs = await FirestoreService().getStoreCollection('customers');
    final creds = await FirestoreService().getStoreCollection('credits');
    await FirebaseFirestore.instance.runTransaction((tx) async {
      tx.update(custs.doc(id), {'balance': old - amt, 'lastUpdated': FieldValue.serverTimestamp()});
    });
    await creds.add({
      'customerId': id, 'customerName': data['name'], 'amount': amt, 'type': 'settlement', 'method': mode, 'timestamp': FieldValue.serverTimestamp(), 'date': DateTime.now().toIso8601String(),
    });
  }

  Widget _buildEmptyState(String msg) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      HeroIcon(HeroIcons.documentText, size: 60, color: kPrimaryColor.withOpacity(0.1)),
      const SizedBox(height: 16),
      Text(msg, style: const TextStyle(fontWeight: FontWeight.w700, color: kBlack54)),
    ]));
  }

    Widget _buildLoading() => const Center(child: CircularProgressIndicator(color: kPrimaryColor));

    // Duplicate _initOverdueBillsStream removed — single implementation retained elsewhere in this file

}

// ==========================================
// CUSTOMER CREDIT DETAILS PAGE (NEW PAGE)
// ==========================================
class CustomerCreditDetailsPage extends StatefulWidget {
  final String customerId;
  final Map<String, dynamic> customerData;
  final double currentBalance;

  const CustomerCreditDetailsPage({
    super.key,
    required this.customerId,
    required this.customerData,
    required this.currentBalance,
  });

  @override
  State<CustomerCreditDetailsPage> createState() => _CustomerCreditDetailsPageState();
}

class _CustomerCreditDetailsPageState extends State<CustomerCreditDetailsPage> {
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


  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: FirestoreService().getCurrentStoreId(),
      builder: (context, storeIdSnap) {
        if (storeIdSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: kPrimaryColor)));
        }
        final storeId = storeIdSnap.data;
        if (storeId == null) return const Scaffold(body: Center(child: Text("Store not found")));

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('store')
              .doc(storeId)
              .collection('customers')
              .doc(widget.customerId)
              .snapshots(),
      builder: (context, custSnap) {
        final custData = custSnap.data?.data() as Map<String, dynamic>? ?? widget.customerData;
        final currentBalance = (custData['balance'] ?? 0.0).toDouble();
        final customerName = (custData['name'] ?? 'Customer').toString();

        return Scaffold(
          backgroundColor: kGreyBg,
          appBar: AppBar(
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            elevation: 0,
            backgroundColor: kPrimaryColor,
            iconTheme: const IconThemeData(color: kWhite),
            title: Text(customerName, style: const TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
            centerTitle: true,
          ),
          body: Column(
            children: [
              // Credit Breakdown Summary
              FutureBuilder<CollectionReference>(
                future: FirestoreService().getStoreCollection('credits'),
                builder: (context, collSnap) {
                  if (!collSnap.hasData) return const SizedBox.shrink();
                  return StreamBuilder<QuerySnapshot>(
                    stream: collSnap.data!.where('customerId', isEqualTo: widget.customerId).snapshots(),
                    builder: (context, snap) {
                      double billCredit = 0;
                      double manualCredit = 0;
                      if (snap.hasData) {
                        for (var doc in snap.data!.docs) {
                          final d = doc.data() as Map<String, dynamic>;
                          final isCancelled = d['status'] == 'cancelled';
                          if (isCancelled) continue;

                          final type = d['type'] ?? '';
                          final amt = (d['amount'] ?? 0.0).toDouble();
                          final isSettled = d['isSettled'] == true;
                          if (type == 'credit_sale' && !isSettled) {
                            billCredit += amt;
                          } else if (type == 'add_credit') {
                            manualCredit += amt;
                          }
                        }
                      }
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Row(
                          children: [
                            _buildCreditSummaryCard('Total Credit', currentBalance, kErrorColor),
                            const SizedBox(width: 8),
                            _buildCreditSummaryCard('Bill Credit', billCredit, kOrange),
                            const SizedBox(width: 8),
                            _buildCreditSummaryCard('Manual Credit', manualCredit, Colors.purple),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),

              // Credit Bills List Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Credit Bills', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: kBlack87)),
                  ],
                ),
              ),

              // Credit Bills List
              Expanded(
                child: FutureBuilder<CollectionReference>(
                  future: FirestoreService().getStoreCollection('credits'),
                  builder: (context, collectionSnapshot) {
                    if (!collectionSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                    }
                    return StreamBuilder<QuerySnapshot>(
                      stream: collectionSnapshot.data!
                          .where('customerId', isEqualTo: widget.customerId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                        }

                        final docs = snapshot.data?.docs ?? [];
                        final unsettledDocs = docs.where((d) {
                          final data = d.data() as Map<String, dynamic>;
                          final type = data['type'] as String?;
                          final isSettled = data['isSettled'] == true;
                          final isCancelled = data['status'] == 'cancelled';
                          final amount = (data['amount'] ?? 0.0).toDouble();

                          if (isCancelled) return false;
                          if (type == 'credit_sale' && !isSettled) return true;
                          if (type == 'add_credit' && !isSettled) return true; // hide once settled
                          if (type == null && amount > 0 && data['invoiceNumber'] != null && !isSettled) return true;
                          return false;
                        }).toList();

                        unsettledDocs.sort((a, b) {
                          final aData = a.data() as Map<String, dynamic>;
                          final bData = b.data() as Map<String, dynamic>;
                          final aTime = aData['timestamp'] as Timestamp?;
                          final bTime = bData['timestamp'] as Timestamp?;
                          if (aTime == null && bTime == null) return 0;
                          if (aTime == null) return 1;
                          if (bTime == null) return -1;
                          return bTime.compareTo(aTime);
                        });

                        if (unsettledDocs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                HeroIcon(HeroIcons.checkCircle, size: 60, color: kGoogleGreen.withOpacity(0.3)),
                                const SizedBox(height: 16),
                                const Text('No pending credit bills', style: TextStyle(fontWeight: FontWeight.w700, color: kBlack54)),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: unsettledDocs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final doc = unsettledDocs[index];
                            final docData = doc.data() as Map<String, dynamic>;
                            final docType = (docData['type'] ?? '').toString();
                            if (docType == 'add_credit') {
                              return _buildManualCreditCard(doc);
                            }
                            return _buildCreditBillCard(doc, currentBalance);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          bottomNavigationBar: null,
        );
      },
    );
  },
);
  }

  Widget _buildCreditSummaryCard(String label, double amount, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            const SizedBox(height: 6),
            Text('$_currencySymbol${amount.toStringAsFixed(0)}', style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditBillCard(QueryDocumentSnapshot doc, double currentBalance) {
    final data = doc.data() as Map<String, dynamic>;
    final amount = (data['amount'] ?? 0.0).toDouble();
    final invoiceNumber = (data['invoiceNumber'] ?? 'N/A').toString();
    final creditDueDateStr = data['creditDueDate'] as String?;
    final dateStr = data['date'] as String?;

    DateTime? billDate = dateStr != null ? DateTime.tryParse(dateStr) : null;
    DateTime? dueDate = creditDueDateStr != null ? DateTime.tryParse(creditDueDateStr) : null;

    bool isOverdue = false;
    bool isNearDue = false;
    int daysRemaining = 0;
    if (dueDate != null) {
      final now = DateTime.now();
      final diff = dueDate.difference(now).inDays;
      daysRemaining = diff;
      isOverdue = diff < 0;
      isNearDue = diff >= 0 && diff <= 7;
    }

    Color dueDateColor = kBlack54;
    String dueDateLabel = '';
    if (isOverdue) { dueDateColor = kErrorColor; dueDateLabel = 'Overdue'; }
    else if (isNearDue) { dueDateColor = kOrange; dueDateLabel = daysRemaining == 0 ? 'Due Today' : 'DUE IN $daysRemaining DAYS'; }

    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isOverdue ? kErrorColor.withValues(alpha: 0.5) : (isNearDue ? kOrange.withValues(alpha: 0.5) : kGrey200)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.push(
            context,
            _NoAnimRoute(builder: (_) => SettleManualCreditPage(
              customerId: widget.customerId,
              customerData: widget.customerData,
              currentBalance: currentBalance,
              invoiceNumber: invoiceNumber,
              billAmount: amount,
              creditDocId: doc.id,
            )),
          ).then((settled) { if (settled == true && mounted) setState(() {}); }),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [
                  const HeroIcon(HeroIcons.documentText, size: 14, color: kPrimaryColor),
                  const SizedBox(width: 5),
                  Text(invoiceNumber, style: const TextStyle(fontWeight: FontWeight.w900, color: kPrimaryColor, fontSize: 13)),
                ]),
                Text(
                  billDate != null ? '${billDate.day.toString().padLeft(2,'0')} ${DateFormat('MMM').format(billDate)} ${billDate.year}' : '--',
                  style: const TextStyle(fontSize: 10.5, color: Colors.black, fontWeight: FontWeight.w500),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: Text(widget.customerData['name'] ?? 'Customer',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87))),
                Text('$_currencySymbol${amount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: kSuccessGreen)),
              ]),
              const Divider(height: 20, color: kGreyBg),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(dueDate != null ? (isOverdue || isNearDue ? dueDateLabel : 'Due date') : 'Credit bill',
                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: dueDateColor.withValues(alpha: isOverdue || isNearDue ? 1 : 0.7), letterSpacing: 0.5)),
                  if (dueDate != null)
                    Text('${dueDate.day.toString().padLeft(2,'0')}-${dueDate.month.toString().padLeft(2,'0')}-${dueDate.year}',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 10, color: dueDateColor)),
                ]),
                Row(children: [
                  // share buttons
                  Builder(builder: (ctx) {
                    final customerName = (widget.customerData['name'] ?? '').toString();
                    final msg = 'Dear $customerName,\n\nPending credit: Invoice #$invoiceNumber\nAmount: $_currencySymbol${amount.toStringAsFixed(2)}\n\nPlease settle. Thank you!';
                    final cleanPhone = widget.customerId.replaceAll(RegExp(r'[\s\-+()]'), '');
                    final hasPhone = RegExp(r'^\d{7,15}$').hasMatch(cleanPhone);
                    return Row(mainAxisSize: MainAxisSize.min, children: [
                      if (hasPhone) GestureDetector(
                        onTap: () async {
                          final url = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(msg)}');
                          if (await launcher.canLaunchUrl(url)) await launcher.launchUrl(url, mode: launcher.LaunchMode.externalApplication);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: const Color(0xFF25D366).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.3))),
                          child: const HeroIcon(HeroIcons.chatBubbleLeft, color: Color(0xFF25D366), size: 14),
                        ),
                      ),
                      if (hasPhone) const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: kGoogleGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: kGoogleGreen.withValues(alpha: 0.2))),
                        child: const Text('Settle', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kGoogleGreen)),
                      ),
                      const SizedBox(width: 8),
                      const HeroIcon(HeroIcons.chevronRight, color: kPrimaryColor, size: 16),
                    ]);
                  }),
                ]),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  /// Card for manually added credits (type == 'add_credit')
  Widget _buildManualCreditCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final amount = (data['amount'] ?? 0.0).toDouble();
    final note = (data['note'] ?? 'Manual Credit Added').toString();
    final dateStr = data['date'] as String?;
    final method = (data['method'] ?? 'Cash').toString();

    DateTime? addedDate;
    if (dateStr != null) addedDate = DateTime.tryParse(dateStr);

    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.push(
            context,
            _NoAnimRoute(builder: (_) => SettleManualCreditPage(
              customerId: widget.customerId,
              customerData: widget.customerData,
              currentBalance: widget.currentBalance,
              billAmount: amount,
              creditDocId: doc.id,
            )),
          ).then((settled) { if (settled == true && mounted) setState(() {}); }),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                    child: const HeroIcon(HeroIcons.plusCircle, size: 12, color: Colors.purple),
                  ),
                  const SizedBox(width: 6),
                  const Text('Manual Credit', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.purple, fontSize: 13)),
                ]),
                Text(
                  addedDate != null ? '${addedDate.day.toString().padLeft(2,'0')} ${DateFormat('MMM').format(addedDate)} ${addedDate.year}' : '--',
                  style: const TextStyle(fontSize: 10.5, color: Colors.black, fontWeight: FontWeight.w500),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: Text(note, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis)),
                Text('$_currencySymbol${amount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: kSuccessGreen)),
              ]),
              const Divider(height: 20, color: kGreyBg),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Method', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: kBlack54, letterSpacing: 0.5)),
                  Text(method, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 10, color: kBlack87)),
                ]),
                Row(children: [
                  Builder(builder: (ctx) {
                    final customerName = (widget.customerData['name'] ?? '').toString();
                    final msg = 'Dear $customerName,\n\nManual credit pending: $_currencySymbol${amount.toStringAsFixed(2)}\nMethod: $method\n\nPlease settle. Thank you!';
                    final cleanPhone = widget.customerId.replaceAll(RegExp(r'[\s\-+()]'), '');
                    final hasPhone = RegExp(r'^\d{7,15}$').hasMatch(cleanPhone);
                    return Row(mainAxisSize: MainAxisSize.min, children: [
                      if (hasPhone) GestureDetector(
                        onTap: () async {
                          final url = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(msg)}');
                          if (await launcher.canLaunchUrl(url)) await launcher.launchUrl(url, mode: launcher.LaunchMode.externalApplication);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: const Color(0xFF25D366).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.3))),
                          child: const HeroIcon(HeroIcons.chatBubbleLeft, color: Color(0xFF25D366), size: 14),
                        ),
                      ),
                      if (hasPhone) const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: kGoogleGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: kGoogleGreen.withValues(alpha: 0.2))),
                        child: const Text('Settle', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kGoogleGreen)),
                      ),
                      const SizedBox(width: 8),
                      const HeroIcon(HeroIcons.chevronRight, color: kPrimaryColor, size: 16),
                    ]);
                  }),
                ]),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

}

// 4. PURCHASE CREDIT NOTE DETAIL PAGE
// ==========================================
class PurchaseCreditNoteDetailPage extends StatefulWidget {
  final String documentId;
  final Map<String, dynamic> creditNoteData;

  const PurchaseCreditNoteDetailPage({super.key, required this.documentId, required this.creditNoteData});

  @override
  State<PurchaseCreditNoteDetailPage> createState() => _PurchaseCreditNoteDetailPageState();
}

class _PurchaseCreditNoteDetailPageState extends State<PurchaseCreditNoteDetailPage> {
  @override
  Widget build(BuildContext context) {
    final data = widget.creditNoteData;
    final total = (data['amount'] ?? 0.0) as num;
    final paid = (data['paidAmount'] ?? 0.0) as num;
    final remaining = total - paid;

    return Scaffold(
      backgroundColor: kWhite,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        title: const Text('Purchase Overview',
            style: TextStyle(color: kWhite,fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const HeroIcon(HeroIcons.arrowLeft, color: kWhite),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSectionCard(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(data['creditNoteNumber'] ?? 'N/A', style: const TextStyle(fontSize: 18,fontWeight: FontWeight.bold, color: kPrimaryColor)),
                      _buildStatusPill(data['status'] ?? 'Available'),
                    ],
                  ),
                  const Divider(height: 32),
                  _buildLabelValue("Supplier", data['supplierName'] ?? 'Unknown'),
                  const SizedBox(height: 16),
                  _buildLabelValue("BUSINESS CONTACT", data['supplierPhone'] ?? '--'),
                ],
              ),
            ),

            const SizedBox(height: 24),
            _buildSectionTitle("Financial Summary"),
            _buildSectionCard(
              child: Column(
                children: [
                  _buildSummaryRow("Purchase Liability", "${total.toStringAsFixed(2)}"),
                  _buildSummaryRow("Settled Amount", "${paid.toStringAsFixed(2)}", color: kSuccessGreen),
                  const Divider(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Unpaid Due", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: kMediumBlue)),
                      Text("${remaining.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: kErrorRed)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            if (remaining > 0)
              _buildLargeButton(context, label: "Record payment", icon: HeroIcons.documentText, color: kPrimaryColor, onPressed: () {}),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: kMediumBlue,fontWeight: FontWeight.bold, fontSize: 14)),
          Text(value, style: TextStyle(color: color ?? kDeepNavy,fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      ),
    );
  }
}

// --- Top Level Helper Widgets (SaleAllPage Aesthetics) ---

Widget _buildSectionCard({required Widget child, EdgeInsets? padding}) {
  return Container(
    width: double.infinity,
    padding: padding ?? const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: kWhite,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))
      ],
    ),
    child: child,
  );
}

Widget _buildSectionTitle(String title) {
  return Padding(padding: const EdgeInsets.only(left: 6, bottom: 12), child: Text(title, style: const TextStyle(fontSize: 12,fontWeight: FontWeight.bold, color: kMediumBlue, letterSpacing: 1)));
}

Widget _buildLabelValue(String label, String value, {CrossAxisAlignment crossAlign = CrossAxisAlignment.start, Color? color}) {
  return Column(crossAxisAlignment: crossAlign, children: [
    Text(label, style: const TextStyle(fontSize: 10,fontWeight: FontWeight.bold, color: kMediumBlue)),
    const SizedBox(height: 4),
    Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color ?? kDeepNavy)),
  ]);
}

Widget _buildStatusPill(String status, {bool isInverse = false}) {
  Color c;
  switch (status.toLowerCase()) {
    case 'available': c = kSuccessGreen; break;
    case 'used': c = kErrorRed; break;
    default: c = kWarningOrange;
  }
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: isInverse ? kWhite.withOpacity(0.2) : c.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      border: isInverse ? Border.all(color: kWhite.withOpacity(0.4)) : Border.all(color: c.withOpacity(0.2)),
    ),
    child: Text(status[0].toUpperCase() + status.substring(1).toLowerCase(), style: TextStyle(color: isInverse ? kWhite : c,fontWeight: FontWeight.bold, fontSize: 10)),
  );
}

Widget _buildItemRow(Map<String, dynamic> item) {
  final name = item['name'] ?? 'Item';
  final qty = (item['quantity'] ?? 0).toDouble();
  final price = (item['price'] ?? 0).toDouble();
  final total = (item['total'] ?? (price * qty)).toDouble();
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kDeepNavy)),
        const SizedBox(height: 2),
        Text("${price.toStringAsFixed(0)} × ${qty.toInt()}", style: const TextStyle(fontSize: 12, color: kMediumBlue)),
      ])),
      Text("${total.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kDeepNavy)),
    ]),
  );
}

Widget _buildDetailTotalRow(num amount, int itemCount) {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16))),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text("Total return ($itemCount)", style: const TextStyle(fontSize: 11,fontWeight: FontWeight.bold, color: kMediumBlue)),
      Text("${amount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 22,fontWeight: FontWeight.bold, color: kPrimaryColor)),
    ]),
  );
}

Widget _buildIconRow(HeroIcons icon, String label, String value, Color iconColor) {
  return Row(children: [
    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: HeroIcon(icon, color: iconColor, size: 20)),
    const SizedBox(width: 16),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 10,fontWeight: FontWeight.bold, color: kMediumBlue)),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kDeepNavy)),
    ])),
  ]);
}

Widget _buildLargeButton(BuildContext context, {required String label, required HeroIcons icon, required Color color, required VoidCallback onPressed}) {
  return SizedBox(
    width: double.infinity, height: 56,
    child: ElevatedButton.icon(
      onPressed: onPressed, icon: HeroIcon(icon, color: kWhite, size: 20),
      label: Text(label, style: const TextStyle(color: kWhite,fontWeight: FontWeight.bold, fontSize: 16)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}

Widget _buildDialogOption({required VoidCallback onSelect, required String mode, required String current, required HeroIcons icon, required Color color}) {
  final isSelected = current == mode;
  return InkWell(
    onTap: onSelect, borderRadius: BorderRadius.circular(12),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSelected ? color.withOpacity(0.05) : kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isSelected ? color : Colors.grey.shade200, width: 2),
      ),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: HeroIcon(icon, size: 22, color: color)),
        const SizedBox(width: 16),
        Text(mode, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isSelected ? color : kDeepNavy)),
        const Spacer(),
        if (isSelected) HeroIcon(HeroIcons.checkCircle, color: color, size: 20),
      ]),
    ),
  );
}


// ==========================================
// 1. CUSTOMEMANAGEMENT PAGE
// ==========================================
class CustomersPage extends StatefulWidget {
  final String uid;
  final VoidCallback onBack;

  const CustomersPage({super.key, required this.uid, required this.onBack});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  static bool _hasSyncedBalancesThisSession = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'sales'; // 'sales' or 'credit'
  String _currencySymbol = '';

  @override
  void initState() {
    super.initState();
    _loadCurrency();
    _searchController.addListener(() => setState(() => _searchQuery = _searchController.text.toLowerCase()));
    _syncAllBalancesInBackground();
  }

  void _loadCurrency() async {
    final store = await FirestoreService().getCurrentStoreDoc();
    if (store != null && store.exists && mounted) {
      final data = store.data() as Map<String, dynamic>;
      setState(() => _currencySymbol = CurrencyService.getSymbolWithSpace(data['currency']));
    }
  }

  Future<void> _syncAllBalancesInBackground() async {
    if (_hasSyncedBalancesThisSession) return;
    _hasSyncedBalancesThisSession = true;

    try {
      final customersCollection = await FirestoreService().getStoreCollection('customers');
      final snap = await customersCollection.get();
      for (var doc in snap.docs) {
        // Run ledger helper in background for each customer, this silently updates 
        // the Firestore document with the true balance, which then triggers the 
        // StreamBuilder in the UI to update organically.
        LedgerHelper.computeClosingBalance(doc.id, syncToFirestore: true);
      }
    } catch (e) {
      debugPrint('Error syncing balances: $e');
    }
  }

  Future<void> _downloadCustomersList() async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: kPrimaryColor),
        ),
      );

      // Fetch all data in parallel for better performance
      final customersStream = await FirestoreService().getCollectionStream('customers');
      final salesCollection = await FirestoreService().getStoreCollection('sales');
      final creditNotesCollection = await FirestoreService().getStoreCollection('creditNotes');

      // Get all data at once
      final results = await Future.wait([
        customersStream.first,
        salesCollection.get(),
        creditNotesCollection.where('status', isEqualTo: 'Available').get(),
      ]);

      final customersSnapshot = results[0] as QuerySnapshot;
      final allSales = results[1] as QuerySnapshot;
      final allCredits = results[2] as QuerySnapshot;

      if (customersSnapshot.docs.isEmpty) {
        if (mounted) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No customers found'), backgroundColor: Colors.orange),
        );
        return;
      }

      // Create lookup maps for fast access
      Map<String, double> salesByPhone = {};
      Map<String, double> creditByPhone = {};

      // Process all sales at once
      for (var sale in allSales.docs) {
        final data = sale.data() as Map<String, dynamic>;
        final phone = data['customerPhone']?.toString() ?? '';
        final total = (data['total'] ?? 0.0).toDouble();
        if (phone.isNotEmpty) {
          salesByPhone[phone] = (salesByPhone[phone] ?? 0.0) + total;
        }
      }

      // Process all credits at once
      for (var credit in allCredits.docs) {
        final data = credit.data() as Map<String, dynamic>;
        final phone = data['customerPhone']?.toString() ?? '';
        final amount = (data['amount'] ?? 0.0).toDouble();
        final paid = (data['paidAmount'] ?? 0.0).toDouble();
        if (phone.isNotEmpty) {
          creditByPhone[phone] = (creditByPhone[phone] ?? 0.0) + (amount - paid);
        }
      }

      // Prepare data for PDF
      List<List<String>> rows = [];
      double totalSales = 0.0;
      double totalCredit = 0.0;

      // Build rows quickly using lookup maps
      for (var doc in customersSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final name = data['name']?.toString() ?? 'N/A';
        final phone = data['phone']?.toString() ?? 'N/A';
        final email = data['email']?.toString() ?? '';

        final customerSales = salesByPhone[phone] ?? 0.0;
        final customerCredit = creditByPhone[phone] ?? 0.0;

        totalSales += customerSales;
        totalCredit += customerCredit;

        rows.add([
          name,
          phone,
          '${customerSales.toStringAsFixed(2)}',
          '${customerCredit.toStringAsFixed(2)}',
        ]);
      }

      if (mounted) Navigator.pop(context); // Close loading dialog

      // Generate PDF using ReportPdfGenerator
      await ReportPdfGenerator.generateAndDownloadPdf(
        context: context,
        reportTitle: 'Customers List',
        headers: ['Name', 'Phone', 'Total Sales', 'Credit Due'],
        rows: rows,
        additionalSummary: {
          'Total Customers': customersSnapshot.docs.length.toString(),
          'Total Sales': '$_currencySymbol${totalSales.toStringAsFixed(2)}',
          'Total Credit Due': '$_currencySymbol${totalCredit.toStringAsFixed(2)}',
        },
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: kErrorColor),
      );
    }
  }


  void _showSortMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sort Customers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kBlack87)),
              const SizedBox(height: 20),
              _buildSortOption('Sort by Sales', 'sales', HeroIcons.arrowTrendingUp),
              _buildSortOption('Sort by Credit', 'credit', HeroIcons.wallet),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortOption(String label, String value, HeroIcons icon) {
    bool isSelected = _sortBy == value;
    return ListTile(
      onTap: () {
        setState(() => _sortBy = value);
        Navigator.pop(context);
      },
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? kPrimaryColor.withOpacity(0.1) : kGreyBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: HeroIcon(icon, color: isSelected ? kPrimaryColor : kBlack54, size: 22),
      ),
      title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? kPrimaryColor : kBlack87)),
      trailing: isSelected ? const HeroIcon(HeroIcons.checkCircle, color: kPrimaryColor, size: 20) : null,
    );
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
          title: Text(context.tr('customer_management'),
              style: const TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
          backgroundColor: kPrimaryColor,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const HeroIcon(HeroIcons.arrowLeft, color: kWhite, size: 22),
            onPressed: widget.onBack,
          ),
          actions: [
            IconButton(
              icon: const HeroIcon(HeroIcons.arrowDownTray, color: kWhite, size: 22),
              onPressed: _downloadCustomersList,
              tooltip: 'Download Customers List',
            ),
            const SizedBox(width: 8),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (context) => AddCustomerPage(
                  uid: widget.uid,
                  onBack: null,
                ),
              ),
            ).then((value) {
              if (value == true) {
                setState(() {}); // Refresh the list
              }
            });
          },
          backgroundColor: kPrimaryColor,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          icon: const HeroIcon(HeroIcons.plus, color: kWhite, size: 20),
          label: Text(
            context.tr('add_customer'),
            style: const TextStyle(color: kWhite, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5),
          ),
        ),
        body: Column(
        children: [
          // Updated Search Header Area with Sort Button
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            decoration: const BoxDecoration(
              color: kWhite,
              border: Border(bottom: BorderSide(color: kGrey200)),
            ),
            child: Row(
              children: [
                Expanded(
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
                      style: const TextStyle(color: kBlack87, fontWeight: FontWeight.w600, fontSize: 14),
                      decoration: InputDecoration(
                        prefixIcon: const HeroIcon(HeroIcons.magnifyingGlass, color: kPrimaryColor, size: 20),
                        hintText: context.tr('search'),
                        hintStyle: const TextStyle(color: kBlack54, fontSize: 14),
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
                const SizedBox(width: 8),
                // New Sort Button UI
                InkWell(
                  onTap: _showSortMenu,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 46,
                    width: 46,
                    decoration: BoxDecoration(
                      color: kPrimaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kGrey200),
                    ),
                    child: const HeroIcon(HeroIcons.bars3BottomLeft, color: kPrimaryColor, size: 22),
                  ),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: FutureBuilder<Stream<QuerySnapshot>>(
              future: FirestoreService().getCollectionStream('customers'),
              builder: (context, streamSnapshot) {
                if (!streamSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                return StreamBuilder<QuerySnapshot>(
                  stream: streamSnapshot.data,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildManagerNoDataState(context.tr('no_customers_found'));

                    final docs = snapshot.data!.docs.where((d) {
                      final data = d.data() as Map<String, dynamic>;
                      final name = (data['name'] ?? '').toString().toLowerCase();
                      final phone = (data['phone'] ?? '').toString().toLowerCase();
                      return name.contains(_searchQuery) || phone.contains(_searchQuery);
                    }).toList();

                    // Sort docs based on selected sort option
                    docs.sort((a, b) {
                      final dataA = a.data() as Map<String, dynamic>;
                      final dataB = b.data() as Map<String, dynamic>;
                      if (_sortBy == 'sales') {
                        final salesA = (dataA['totalSales'] ?? 0).toDouble();
                        final salesB = (dataB['totalSales'] ?? 0).toDouble();
                        return salesB.compareTo(salesA); // Descending
                      } else {
                        final creditA = (dataA['balance'] ?? 0).toDouble();
                        final creditB = (dataB['balance'] ?? 0).toDouble();
                        return creditB.compareTo(creditA); // Descending
                      }
                    });

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final docId = docs[index].id;
                        final data = docs[index].data() as Map<String, dynamic>;
                        return _buildCustomerCard(docId, data);
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

  Widget _buildCustomerCard(String docId, Map<String, dynamic> data) {
    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGrey200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Use push with MaterialPageRoute instead of CupertinoPageRoute for better performance
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CustomerDetailsPage(
                  customerId: docId,
                  customerData: data,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(data['name'] ?? 'Unknown',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black)),
                              if ((data['rating'] ?? 0) > 0) ...[
                                const SizedBox(width: 8),
                                ...List.generate(5, (i) {
                                  final rating = (data['rating'] ?? 0) as num;
                                  return HeroIcon(
                                    HeroIcons.star,
                                    size: 12,
                                    color: i < rating ? kOrange : kGrey300,
                                    style: i < rating ? HeroIconStyle.solid : HeroIconStyle.outline,
                                  );
                                }),
                              ],
                            ],
                          ),
                          Text(data['phone'] ?? '--',
                              style: const TextStyle(color: kBlack54, fontSize: 12, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    const HeroIcon(HeroIcons.chevronRight, color: kPrimaryColor, size: 20),
                  ],
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: kGrey100)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildManagerStatItem("Total sales", "${(data['totalSales'] ?? 0).toStringAsFixed(0)}", kSuccessGreen),
                    _buildManagerStatItem("Credit due", "${(data['balance'] ?? 0).toStringAsFixed(0)}", kErrorRed, align: CrossAxisAlignment.end),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildManagerStatItem(String label, String value, Color color, {CrossAxisAlignment align = CrossAxisAlignment.start}) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kBlack54, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text("$value", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: color)),
      ],
    );
  }

  Widget _buildManagerNoDataState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HeroIcon(HeroIcons.userGroup, size: 64, color: kGrey300),
          const SizedBox(height: 16),
          Text(msg, style: const TextStyle(color: kBlack54, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ==========================================
// 2. STAFF MANAGEMENT LIST
// ==========================================
class StaffManagementList extends StatelessWidget {
  final String adminUid;
  final VoidCallback onBack;
  final VoidCallback onAddStaff;

  const StaffManagementList({super.key, required this.adminUid, required this.onBack, required this.onAddStaff});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWhite,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        title: Text(context.tr('staffmanagement'),
            style: const TextStyle(color: kWhite, fontWeight: FontWeight.w900, fontSize: 18)),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: const HeroIcon(HeroIcons.arrowLeft, color: kWhite), onPressed: onBack),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Staff Overview", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: kMediumBlue, letterSpacing: 0.5)),
                TextButton.icon(
                  onPressed: onAddStaff,
                  icon: const HeroIcon(HeroIcons.plusCircle, size: 20, color: kWhite),
                  label: const Text("Add New", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: kWhite)),
                  style: TextButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: kSoftAzure, thickness: 2),
          Expanded(
            child: FutureBuilder<String?>(
              future: FirestoreService().getCurrentStoreId(),
              builder: (context, storeIdSnapshot) {
                if (!storeIdSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').where('storeId', isEqualTo: storeIdSnapshot.data).snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                    if (snapshot.data!.docs.isEmpty) return _buildManagerNoDataState("No staff memberegistered");

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                        bool isActive = (data['status'] ?? '') == 'Active';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: kWhite,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: kSoftAzure, width: 1.5),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: kPrimaryColor.withOpacity(0.1),
                              child: Text((data['name'] ?? 'S')[0].toUpperCase(),
                                  style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w900)),
                            ),
                            title: Text(data['name'] ?? 'Unknown',
                                style: const TextStyle(fontWeight: FontWeight.w900, color: kDeepNavy, fontSize: 15)),
                            subtitle: Text("${data['role'] ?? 'Staff'} • ${data['email'] ?? ''}",
                                style: const TextStyle(fontSize: 12, color: kMediumBlue, fontWeight: FontWeight.w600)),
                            trailing: _buildManagerStatusPill(isActive ? "Active" : "Inactive", isActive ? kSuccessGreen : kErrorRed),
                          ),
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
    );
  }
}

// ==========================================
// 3. ADD STAFF PAGE
// ==========================================
class AddStaffPage extends StatefulWidget {
  final String adminUid;
  final VoidCallback onBack;

  const AddStaffPage({super.key, required this.adminUid, required this.onBack});

  @override
  State<AddStaffPage> createState() => _AddStaffPageState();
}

class _AddStaffPageState extends State<AddStaffPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String _selectedRole = "Administrator";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWhite,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        title: Text(context.tr('addnewstaff'),
            style: const TextStyle(color: kWhite, fontWeight: FontWeight.w900, fontSize: 18)),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: const HeroIcon(HeroIcons.arrowLeft, color: kWhite), onPressed: widget.onBack),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildManagerSectionTitle("Login Information"),
              _buildManagerFormTextField(_nameCtrl, "Staff Full Name", HeroIcons.identification),
              const SizedBox(height: 16),
              _buildManagerFormTextField(_emailCtrl, "Email Address / User ID", HeroIcons.atSymbol),
              const SizedBox(height: 16),
              _buildManagerFormTextField(_passCtrl, "Password", HeroIcons.key, isObscure: true),
              const SizedBox(height: 32),
              _buildManagerSectionTitle("Access Permissions"),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kSoftAzure),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedRole,
                    isExpanded: true,
                    dropdownColor: kWhite,
                    icon: const HeroIcon(HeroIcons.chevronDown, color: kPrimaryColor),
                    items: ["Administrator", "Cashier", "Sales"].map((r) => DropdownMenuItem(
                        value: r,
                        child: Text(r, style: const TextStyle(fontWeight: FontWeight.w700, color: kDeepNavy))
                    )).toList(),
                    onChanged: (val) => setState(() => _selectedRole = val!),
                  ),
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) return;
                    final storeId = await FirestoreService().getCurrentStoreId();
                    await FirebaseFirestore.instance.collection('users').add({
                      'name': _nameCtrl.text,
                      'email': _emailCtrl.text,
                      'role': _selectedRole,
                      'status': 'Active',
                      'storeId': storeId,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                    widget.onBack();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text("Create Staff Account",
                      style: TextStyle(color: kWhite, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1.2)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManagerFormTextField(TextEditingController ctrl, String hint, HeroIcons icon, {bool isObscure = false}) {
    return Container(
      decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kSoftAzure)
      ),
      child: ValueListenableBuilder<TextEditingValue>(
      valueListenable: ctrl,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextFormField(
        controller: ctrl,
        obscureText: isObscure,
        style: const TextStyle(fontWeight: FontWeight.w700, color: kDeepNavy),
        decoration: InputDecoration(
          prefixIcon: HeroIcon(icon, color: kPrimaryColor, size: 22),
          hintText: hint,
          hintStyle: const TextStyle(color: kMediumBlue, fontWeight: FontWeight.w500),
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
    );
  }
}

// --- Common UI Helper Widgets ---

Widget _buildCustomerDialogField(TextEditingController ctrl, String label, HeroIcons icon, {TextInputType type = TextInputType.text}) {
  return Container(
    height: 54,
    decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kSoftAzure)
    ),
    child: ValueListenableBuilder<TextEditingValue>(
      valueListenable: ctrl,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextField(
      controller: ctrl,
      keyboardType: type,
      style: const TextStyle(fontWeight: FontWeight.w700, color: kDeepNavy),
      decoration: InputDecoration(
        prefixIcon: HeroIcon(icon, color: kPrimaryColor, size: 20),
        hintText: label,
        hintStyle: const TextStyle(color: kMediumBlue, fontSize: 13),
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
  );
}

Widget _buildManagerStatItem(String label, String value, Color color, {CrossAxisAlignment align = CrossAxisAlignment.start}) {
  return Column(
    crossAxisAlignment: align,
    children: [
      Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kMediumBlue, letterSpacing: 1)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: color)),
    ],
  );
}

Widget _buildManagerStatusPill(String text, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.2), width: 1),
    ),
    child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5)),
  );
}

Widget _buildManagerNoDataState(String msg) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        HeroIcon(HeroIcons.folderOpen, size: 60, color: kSoftAzure),
        const SizedBox(height: 12),
        Text(msg, style: TextStyle(color: kMediumBlue.withOpacity(0.6), fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

Widget _buildManagerSectionTitle(String title) {
  return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: kMediumBlue, letterSpacing: 2))
  );
}


// ==========================================
// SALE RETURN PAGE
// ==========================================

class SaleReturnPage extends StatefulWidget {
  final String documentId;
  final Map<String, dynamic> invoiceData;

  const SaleReturnPage({
    super.key,
    required this.documentId,
    required this.invoiceData,
  });

  @override
  State<SaleReturnPage> createState() => _SaleReturnPageState();
}

class _SaleReturnPageState extends State<SaleReturnPage> {
  Map<int, int> returnQuantities = {};
  String returnMode = 'CreditNote';
  String _currencySymbol = '';

  // Customer info - can be updated if user adds customer
  String? _customerPhone;
  String? _customerName;

  @override
  void initState() {
    super.initState();
    _loadCurrency();
    // Initialize customer info from invoice
    _customerPhone = widget.invoiceData['customerPhone'];
    _customerName = widget.invoiceData['customerName'];
  }

  void _loadCurrency() async {
    final store = await FirestoreService().getCurrentStoreDoc();
    if (store != null && store.exists && mounted) {
      final data = store.data() as Map<String, dynamic>;
      setState(() => _currencySymbol = CurrencyService.getSymbolWithSpace(data['currency']));
    }
  }

  // Check if customer exists
  bool get hasCustomer => _customerPhone != null && _customerPhone!.isNotEmpty;

  // Show customer selection/add dialog
  void _showCustomerDialog() {
    CommonWidgets.showCustomerSelectionDialog(
      context: context,
      selectedCustomerPhone: _customerPhone,
      onCustomerSelected: (phone, name, gst) async {
        setState(() {
          _customerPhone = phone;
          _customerName = name;
        });
        // Also update the sale document with the customer
        try {
          final salesCollection = await FirestoreService().getStoreCollection('sales');
          await salesCollection.doc(widget.documentId).update({
            'customerPhone': phone,
            'customerName': name,
            if (gst != null && gst.isNotEmpty) 'customerGst': gst,
          });
        } catch (e) {
          debugPrint('Error updating customer: $e');
        }
      },
    );
  }

  // Helper to parse quantity properly
  int _parseQuantity(dynamic qty) {
    if (qty == null) return 0;
    if (qty is int) return qty;
    if (qty is double) return qty.toInt();
    if (qty is String) return int.tryParse(qty) ?? 0;
    return 0;
  }

  // Helper to get filtered items (with quantity > 0)
  List<dynamic> get _filteredItems {
    final allItems = widget.invoiceData['items'] as List<dynamic>? ?? [];
    return allItems.where((item) => _parseQuantity(item['quantity']) > 0).toList();
  }

  // Calculate subtotal without tax (base amount)
  double get totalReturnSubtotal {
    double subtotal = 0;
    final items = _filteredItems;
    returnQuantities.forEach((index, qty) {
      if (index < items.length) {
        final item = items[index];
        final price = (item['price'] ?? 0).toDouble();
        final taxPercentage = (item['taxPercentage'] ?? 0).toDouble();
        final taxType = item['taxType'] as String?;
        final itemTotal = price * qty;

        // For tax included, extract the base amount; for tax added, use itemTotal as base
        if (taxPercentage > 0 && (taxType == 'Tax Included in Price' || taxType == 'Price includes Tax')) {
          // Tax is included - calculate base amount
          subtotal += itemTotal / (1 + taxPercentage / 100);
        } else {
          // Tax is added or no tax - price is the base amount
          subtotal += itemTotal;
        }
      }
    });
    return subtotal;
  }

  double get totalReturnTax {
    double totalTax = 0;
    final items = _filteredItems;
    returnQuantities.forEach((index, qty) {
      if (index < items.length) {
        final item = items[index];
        final price = (item['price'] ?? 0).toDouble();
        final taxPercentage = (item['taxPercentage'] ?? 0).toDouble();
        final taxType = item['taxType'] as String?;
        if (taxPercentage > 0 && taxType != null) {
          final itemTotal = price * qty;
          if (taxType == 'Tax Included in Price' || taxType == 'Price includes Tax') {
            // Tax is included in price - extract it
            final taxRate = taxPercentage / 100;
            totalTax += itemTotal - (itemTotal / (1 + taxRate));
          } else if (taxType == 'Add Tax at Billing' || taxType == 'Price is without Tax') {
            // Tax is added on top
            totalTax += itemTotal * (taxPercentage / 100);
          }
        }
      }
    });
    return totalTax;
  }

  // Total refund amount (what customer gets back)
  // For tax included: total = subtotal + tax = price * qty (because tax is already in price)
  // For tax added: total = subtotal + tax = (price * qty) + tax
  double get totalReturnWithTax {
    double total = 0;
    final items = _filteredItems;
    returnQuantities.forEach((index, qty) {
      if (index < items.length) {
        final item = items[index];
        final price = (item['price'] ?? 0).toDouble();
        final taxPercentage = (item['taxPercentage'] ?? 0).toDouble();
        final taxType = item['taxType'] as String?;
        final itemTotal = price * qty;

        if (taxPercentage > 0 && taxType != null) {
          if (taxType == 'Tax Included in Price' || taxType == 'Price includes Tax') {
            // Tax is already included in price, so total is just itemTotal
            total += itemTotal;
          } else if (taxType == 'Add Tax at Billing' || taxType == 'Price is without Tax') {
            // Tax needs to be added
            total += itemTotal + (itemTotal * taxPercentage / 100);
          } else {
            // Unknown tax type, just use itemTotal
            total += itemTotal;
          }
        } else {
          // No tax
          total += itemTotal;
        }
      }
    });
    return total;
  }

  // For backward compatibility - returns the item price total (may or may not include tax)
  double get totalReturnAmount => totalReturnSubtotal;

  @override
  Widget build(BuildContext context) {
    final items = _filteredItems; // Use filtered items with quantity > 0
    final timestamp = widget.invoiceData['timestamp'] != null ? (widget.invoiceData['timestamp'] as Timestamp).toDate() : DateTime.now();

    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        title: Text(context.tr('sale_return'), style: const TextStyle(color: kWhite, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1.0)),
        backgroundColor: kPrimaryColor, centerTitle: true, elevation: 0,
        leading: IconButton(icon: const HeroIcon(HeroIcons.arrowLeft, color: kWhite, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: items.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                HeroIcon(HeroIcons.checkCircle, size: 64, color: kGoogleGreen.withOpacity(0.5)),
                const SizedBox(height: 16),
                const Text('All items have been returned', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kBlack54)),
                const SizedBox(height: 8),
                const Text('No items available for return', style: TextStyle(fontSize: 12, color: kBlack54)),
              ],
            ),
          )
        : Column(
        children: [
          // Header Card with Customer Info
          Container(
            width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(color: kWhite, border: Border(bottom: BorderSide(color: kGrey200))),
            child: Row(
              children: [
                CircleAvatar(backgroundColor: kOrange.withOpacity(0.1), radius: 18, child: const HeroIcon(HeroIcons.user, color: kOrange, size: 18)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_customerName ?? 'Walk-in Customer', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: kBlack87)),
                    Text("${widget.invoiceData['invoiceNumber']} • ${DateFormat('dd MMM yyyy').format(timestamp)}", style: const TextStyle(color: kBlack54, fontSize: 10, fontWeight: FontWeight.w600)),
                  ]),
                ),
                // Add Customer Button (if no customer)
                if (!hasCustomer)
                  InkWell(
                    onTap: _showCustomerDialog,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: kOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kOrange.withOpacity(0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          HeroIcon(HeroIcons.userPlus, size: 14, color: kOrange),
                          SizedBox(width: 4),
                          Text('Add Customer', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kOrange)),
                        ],
                      ),
                    ),
                  )
                else
                  InkWell(
                    onTap: _showCustomerDialog,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: kPrimaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const HeroIcon(HeroIcons.pencil, size: 14, color: kPrimaryColor),
                    ),
                  ),
              ],
            ),
          ),

          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 10),
              itemBuilder: (ctx, index) {
                final item = items[index];
                final name = item['name'] ?? 'Item';
                final maxQty = _parseQuantity(item['quantity']);
                final price = (item['price'] ?? 0).toDouble();
                final taxPercentage = (item['taxPercentage'] ?? 0).toDouble();
                final currentReturnQty = returnQuantities[index] ?? 0;

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))]),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kBlack87)),
                            const SizedBox(height: 4),
                            Row(children: [
                              Text('Rate: $_currencySymbol${price.toStringAsFixed(0)}', style: const TextStyle(color: kBlack54, fontSize: 11, fontWeight: FontWeight.w600)),
                              if (taxPercentage > 0) ...[
                                const SizedBox(width: 6),
                                Text('($taxPercentage% TAX)', style: const TextStyle(color: kOrange, fontSize: 10, fontWeight: FontWeight.w800)),
                              ]
                            ]),
                          ])),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: kPrimaryColor.withOpacity(0.08), borderRadius: BorderRadius.circular(8)), child: Text("Available: $maxQty", style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w900, fontSize: 10))),
                        ],
                      ),
                      const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: kGrey100)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Quantity to return", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: kBlack54)),
                          Row(
                            children: [
                              _qtyBtn(HeroIcons.minus, currentReturnQty > 0 ? () => setState(() {
                                returnQuantities[index] = currentReturnQty - 1;
                                if (returnQuantities[index]! <= 0) returnQuantities.remove(index);
                              }) : null),
                              Container(width: 50, alignment: Alignment.center, child: Text("$currentReturnQty", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: kBlack87))),
                              _qtyBtn(HeroIcons.plus, currentReturnQty < maxQty ? () => setState(() => returnQuantities[index] = currentReturnQty + 1) : null),
                            ],
                          ),
                        ],
                      )
                    ],
                  ),
                );
              },
            ),
          ),

          _buildReturnSummaryPanel(),
        ],
      ),
    );
  }

  Widget _qtyBtn(HeroIcons icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: onTap == null ? kGrey100 : kPrimaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: HeroIcon(icon, size: 18, color: onTap == null ? kGrey400 : kPrimaryColor)),
    );
  }

  Widget _buildReturnSummaryPanel() {
    final bool creditNoteNeedsCustomer = returnMode == 'CreditNote' && !hasCustomer;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(color: kWhite, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -5))], border: const Border(top: BorderSide(color: kGrey200))),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _rowItem('Subtotal (Net)', totalReturnSubtotal.toStringAsFixed(2)),
            if (totalReturnTax > 0) _rowItem('Tax Refund', totalReturnTax.toStringAsFixed(2), color: kOrange),
            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, color: kGrey100)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total refund', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: kBlack54, letterSpacing: 0.5)),
                Text('$_currencySymbol${totalReturnWithTax.toStringAsFixed(2)}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: kPrimaryColor)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _modeBtn('CreditNote', 'Credit note')),
                const SizedBox(width: 12),
                Expanded(child: _modeBtn('Cash', 'Cash Refund')),
              ],
            ),
            // Warning if credit note needs customer
            if (creditNoteNeedsCustomer) ...[
              const SizedBox(height: 12),
              InkWell(
                onTap: _showCustomerDialog,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kOrange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kOrange.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      HeroIcon(HeroIcons.exclamationTriangle, size: 16, color: kOrange),
                      SizedBox(width: 8),
                      Text('Add customer to create credit note', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kOrange)),
                      SizedBox(width: 4),
                      HeroIcon(HeroIcons.chevronRight, size: 10, color: kOrange),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                onPressed: returnQuantities.isEmpty ? null : _processSaleReturn,
                style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                child: const Text('Process return', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, color: kWhite, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowItem(String l, String v, {Color? color}) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(color: kBlack54, fontSize: 13, fontWeight: FontWeight.w600)), Text('$_currencySymbol$v', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color ?? kBlack87))]));

  Widget _modeBtn(String val, String lbl) {
    bool sel = returnMode == val;
    return GestureDetector(
      onTap: () => setState(() => returnMode = val),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: sel ? kPrimaryColor : kWhite, borderRadius: BorderRadius.circular(10), border: Border.all(color: sel ? kPrimaryColor : kGrey200, width: 1.5)),
        child: Center(child: Text(lbl, style: TextStyle(color: sel ? kWhite : kBlack54, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5))),
      ),
    );
  }

  Future<void> _processSaleReturn() async {
    // Check if credit note requires customer
    if (returnMode == 'CreditNote' && !hasCustomer) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please add a customer to create credit note'),
          backgroundColor: kOrange,
          action: SnackBarAction(
            label: 'Add',
            textColor: kWhite,
            onPressed: _showCustomerDialog,
          ),
        ),
      );
      return;
    }

    try {
      showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));

      final allItems = widget.invoiceData['items'] as List<dynamic>? ?? [];
      final filteredItems = _filteredItems; // Items with quantity > 0 (same as displayed in UI)
      final productsCollection = await FirestoreService().getStoreCollection('Products');

      // Map filtered item indices to original item indices
      Map<int, int> filteredToOriginalIndex = {};
      int filteredIdx = 0;
      for (int i = 0; i < allItems.length; i++) {
        if (_parseQuantity(allItems[i]['quantity']) > 0) {
          filteredToOriginalIndex[filteredIdx] = i;
          filteredIdx++;
        }
      }

      // Update product stock for returned items
      for (var entry in returnQuantities.entries) {
        final filteredIndex = entry.key;
        final returnQty = entry.value;
        if (filteredIndex < filteredItems.length) {
          final item = filteredItems[filteredIndex];
          if (item['productId'] != null && item['productId'].toString().isNotEmpty) {
            final productRef = productsCollection.doc(item['productId']);
            await FirebaseFirestore.instance.runTransaction((transaction) async {
              final productDoc = await transaction.get(productRef);
              if (productDoc.exists) {
                final currentStock = (productDoc.data() as Map<String, dynamic>?)?['currentStock'] ?? 0.0;
                transaction.update(productRef, {'currentStock': currentStock.toDouble() + returnQty});
              }
            });
          }
        }
      }

      // Create credit note if mode is CreditNote and customer exists
      if (returnMode == 'CreditNote' && hasCustomer) {
        final creditNoteNumber = await NumberGeneratorService.generateCreditNoteNumber();
        final creditNotesCollection = await FirestoreService().getStoreCollection('creditNotes');
        await creditNotesCollection.add({
          'creditNoteNumber': creditNoteNumber,
          'invoiceNumber': widget.invoiceData['invoiceNumber'],
          'customerPhone': _customerPhone,
          'customerName': _customerName ?? 'Unknown',
          'amount': totalReturnWithTax,
          'subtotal': totalReturnAmount,
          'totalTax': totalReturnTax,
          'items': returnQuantities.entries.map((entry) {
            final item = filteredItems[entry.key];
            return {
              'name': item['name'], 'quantity': entry.value, 'price': item['price'],
              'total': (item['price'] ?? 0) * entry.value, 'taxAmount': (totalReturnTax / totalReturnAmount) * ((item['price'] ?? 0) * entry.value),
            };
          }).toList(),
          'timestamp': FieldValue.serverTimestamp(), 'status': 'Available', 'reason': 'Sale Return',
        });
      }

      final salesCollection = await FirestoreService().getStoreCollection('sales');
      List<Map<String, dynamic>> updatedItems = [];

      // Process all original items, updating quantities for returned items
      for (int i = 0; i < allItems.length; i++) {
        final item = Map<String, dynamic>.from(allItems[i]);
        final originalQty = _parseQuantity(item['quantity']);

        // Check if this original index corresponds to a filtered index with returns
        int? filteredIndex;
        for (var entry in filteredToOriginalIndex.entries) {
          if (entry.value == i) {
            filteredIndex = entry.key;
            break;
          }
        }

        final returnedQty = filteredIndex != null ? (returnQuantities[filteredIndex] ?? 0) : 0;
        final newQty = originalQty - returnedQty;
        if (newQty > 0) { item['quantity'] = newQty; updatedItems.add(item); }
      }

      // Build the list of returned items for this return
      List<Map<String, dynamic>> newReturnedItems = [];
      for (var entry in returnQuantities.entries) {
        final filteredIndex = entry.key;
        final returnQty = entry.value;
        if (filteredIndex < filteredItems.length && returnQty > 0) {
          final item = filteredItems[filteredIndex];
          final price = (item['price'] ?? 0).toDouble();
          final taxPercentage = (item['taxPercentage'] ?? 0).toDouble();
          final taxType = item['taxType'] as String?;
          final taxName = item['taxName'] as String?;

          // Calculate tax for this returned item based on tax type
          double itemTax = 0;
          final itemTotal = price * returnQty;
          if (taxPercentage > 0 && taxType != null) {
            if (taxType == 'Tax Included in Price' || taxType == 'Price includes Tax') {
              final taxRate = taxPercentage / 100;
              itemTax = itemTotal - (itemTotal / (1 + taxRate));
            } else if (taxType == 'Add Tax at Billing' || taxType == 'Price is without Tax') {
              itemTax = itemTotal * (taxPercentage / 100);
            }
          }

          newReturnedItems.add({
            'name': item['name'] ?? 'Item',
            'quantity': returnQty,
            'price': price,
            'total': itemTotal,
            'taxAmount': itemTax,
            'taxPercentage': taxPercentage,
            'taxType': taxType,
            'taxName': taxName,
            'productId': item['productId'],
            'returnedAt': DateTime.now().toIso8601String(),
          });
        }
      }

      // Get existing returned items and append new ones
      List<dynamic> existingReturnedItems = widget.invoiceData['returnedItems'] as List<dynamic>? ?? [];
      List<Map<String, dynamic>> allReturnedItems = [
        ...existingReturnedItems.map((e) => Map<String, dynamic>.from(e)),
        ...newReturnedItems,
      ];

      // Check if bill was previously edited to preserve the flag
      final wasEdited = widget.invoiceData['status'] == 'edited' || widget.invoiceData['hasBeenEdited'] == true || widget.invoiceData['editedAt'] != null;

      final updateData = <String, dynamic>{
        'items': updatedItems,
        'total': (widget.invoiceData['total'] ?? 0.0) - totalReturnWithTax,
        'hasReturns': true,
        'returnAmount': (widget.invoiceData['returnAmount'] ?? 0.0) + totalReturnWithTax,
        'returnedItems': allReturnedItems, // Store all returned items with details
        'lastReturnAt': FieldValue.serverTimestamp(),
        'status': 'returned', // Mark as returned
        'hasBeenReturned': true, // Preserve return history
        'returnedAt': FieldValue.serverTimestamp(),
      };
      // Preserve edit history if bill was previously edited
      if (wasEdited) {
        updateData['hasBeenEdited'] = true;
      }

      await salesCollection.doc(widget.documentId).update(updateData);

      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(returnMode == 'CreditNote' ? 'Credit note created successfully' : 'Return processed successfully'), backgroundColor: kGoogleGreen));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: kErrorColor)); }
    }
  }
}

class EditBillPage extends StatefulWidget {
  final String documentId;
  final Map<String, dynamic> invoiceData;

  const EditBillPage({
    super.key,
    required this.documentId,
    required this.invoiceData,
  });

  @override
  State<EditBillPage> createState() => _EditBillPageState();
}

class _EditBillPageState extends State<EditBillPage> {
  // --- Standardized Color Palette ---
  static const Color kHeaderColor = kPrimaryColor;
  static const Color kCardBg = kWhite;
  static const Color kAccentOrange = kOrange;

  late TextEditingController _discountController;
  late String _selectedPaymentMode;
  late String? _selectedCustomerPhone;
  late String? _selectedCustomerName;
    late List<Map<String, dynamic>> _items;
    late List<Map<String, dynamic>> _originalItems; // snapshot of items when page opened
    List<Map<String, dynamic>> _selectedCreditNotes = [];
    double _creditNotesAmount = 0.0;
    bool _isSaving = false;
    /// Split payment edit tracking
    bool _isSplitEdited = false;
    double _splitCash = 0.0;
    double _splitOnline = 0.0;
    double _splitCredit = 0.0;
    String _currencySymbol = 'Rs ';

    @override
    void initState() {
    super.initState();
    _loadCurrency();
    _discountController = TextEditingController(
      text: (widget.invoiceData['discount'] ?? 0).toString(),
    );
    _selectedPaymentMode = widget.invoiceData['paymentMode'] ?? 'Cash';
    _selectedCustomerPhone = widget.invoiceData['customerPhone'];
    _selectedCustomerName = widget.invoiceData['customerName'];

    // Copy items to editable list
    final originalItems = widget.invoiceData['items'] as List<dynamic>? ?? [];
    _items = originalItems.map((item) => Map<String, dynamic>.from(item)).toList();
    _originalItems = originalItems.map((item) => Map<String, dynamic>.from(item)).toList();

    // Load previously selected credit notes
    final selectedNotes = widget.invoiceData['selectedCreditNotes'] as List<dynamic>?;
    if (selectedNotes != null) {
      _selectedCreditNotes = selectedNotes.map((n) => Map<String, dynamic>.from(n)).toList();
      _creditNotesAmount = _selectedCreditNotes.fold(0.0, (sum, cn) => sum + ((cn['amount'] ?? 0) as num).toDouble());
    }

    // Prefill split payment amounts if present on invoice (edit mode)
    try {
      _splitCash = ((widget.invoiceData['cashReceived_split'] ?? 0) as num).toDouble();
      _splitOnline = ((widget.invoiceData['onlineReceived_split'] ?? 0) as num).toDouble();
      _splitCredit = ((widget.invoiceData['creditIssued_split'] ?? 0) as num).toDouble();
    } catch (_) {
      _splitCash = 0.0; _splitOnline = 0.0; _splitCredit = 0.0;
    }
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
    _discountController.dispose();
    super.dispose();
  }

  // --- Calculations ---
  // Calculate subtotal (net amount without tax)
  double get subtotal => _items.fold(0.0, (sum, item) {
    final price = (item['price'] ?? 0).toDouble();
    final qty = (item['quantity'] ?? 0) is int
        ? (item['quantity'] as int).toDouble()
        : double.tryParse(item['quantity'].toString()) ?? 0.0;
    final taxPercentage = (item['taxPercentage'] ?? 0).toDouble();
    final taxType = item['taxType'] as String?;

    final itemTotal = price * qty;

    // For tax included, extract the base amount; for tax added, use itemTotal as base
    if (taxPercentage > 0 && (taxType == 'Tax Included in Price' || taxType == 'Price includes Tax')) {
      // Tax is included - calculate base amount
      return sum + (itemTotal / (1 + taxPercentage / 100));
    } else {
      // Tax is added or no tax - price is the base amount
      return sum + itemTotal;
    }
  });

  // Calculate total tax from all items
  double get totalTax => _items.fold(0.0, (sum, item) {
    final price = (item['price'] ?? 0).toDouble();
    final qty = (item['quantity'] ?? 0) is int
        ? (item['quantity'] as int).toDouble()
        : double.tryParse(item['quantity'].toString()) ?? 0.0;
    final taxPercentage = (item['taxPercentage'] ?? 0).toDouble();
    final taxType = item['taxType'] as String?;

    if (taxPercentage == 0) return sum;

    final itemTotal = price * qty;
    if (taxType == 'Tax Included in Price' || taxType == 'Price includes Tax') {
      // Tax is already included in price, extract it
      final taxRate = taxPercentage / 100;
      return sum + (itemTotal - (itemTotal / (1 + taxRate)));
    } else if (taxType == 'Add Tax at Billing' || taxType == 'Price is without Tax') {
      // Tax needs to be added to price
      return sum + (itemTotal * (taxPercentage / 100));
    } else {
      // No Tax Applied or Exempt from Tax
      return sum;
    }
  });

  // Calculate the grand total (what customer pays)
  double get grandTotal => _items.fold(0.0, (sum, item) {
    final price = (item['price'] ?? 0).toDouble();
    final qty = (item['quantity'] ?? 0) is int
        ? (item['quantity'] as int).toDouble()
        : double.tryParse(item['quantity'].toString()) ?? 0.0;
    final taxPercentage = (item['taxPercentage'] ?? 0).toDouble();
    final taxType = item['taxType'] as String?;

    final itemTotal = price * qty;

    // For tax included: total is just itemTotal (tax already in price)
    // For tax added: total is itemTotal + tax
    if (taxPercentage > 0 && (taxType == 'Add Tax at Billing' || taxType == 'Price is without Tax')) {
      return sum + itemTotal + (itemTotal * taxPercentage / 100);
    } else {
      // Tax included or no tax - just use itemTotal
      return sum + itemTotal;
    }
  });

  // Get taxes grouped by name for display — multi-tax support
  Map<String, double> get taxBreakdown {
    final Map<String, double> taxMap = {};
    for (var item in _items) {
      final price = (item['price'] ?? 0).toDouble();
      final qty = (item['quantity'] ?? 0) is int
          ? (item['quantity'] as int).toDouble()
          : double.tryParse(item['quantity'].toString()) ?? 0.0;
      final taxPercentage = (item['taxPercentage'] ?? 0).toDouble();
      final taxType = item['taxType'] as String?;
      final itemTotal = price * qty;

      if (taxPercentage == 0) continue;

      double totalTaxAmount = 0;
      if (taxType == 'Tax Included in Price' || taxType == 'Price includes Tax') {
        final taxRate = taxPercentage / 100;
        totalTaxAmount = itemTotal - (itemTotal / (1 + taxRate));
      } else if (taxType == 'Add Tax at Billing' || taxType == 'Price is without Tax') {
        totalTaxAmount = itemTotal * (taxPercentage / 100);
      }

      if (totalTaxAmount <= 0) continue;

      // Check for multi-tax array
      final rawTaxes = item['taxes'];
      if (rawTaxes is List && rawTaxes.isNotEmpty) {
        for (var tax in rawTaxes) {
          final name = (tax['name'] ?? 'Tax').toString();
          final pct = ((tax['percentage'] ?? 0.0) as num).toDouble();
          if (pct > 0 && taxPercentage > 0) {
            final label = '$name @${pct % 1 == 0 ? pct.toInt() : pct}%';
            final share = totalTaxAmount * (pct / taxPercentage);
            taxMap[label] = (taxMap[label] ?? 0) + share;
          }
        }
      } else {
        final taxName = item['taxName'] as String?;
        if (taxName != null) {
          final label = taxPercentage > 0 ? '$taxName @${taxPercentage % 1 == 0 ? taxPercentage.toInt() : taxPercentage}%' : taxName;
          taxMap[label] = (taxMap[label] ?? 0) + totalTaxAmount;
        }
      }
    }
    return taxMap;
  }

  double get discount => double.tryParse(_discountController.text) ?? 0;
  double get totalBeforeCreditNotes => grandTotal - discount;
  double get finalTotal => (totalBeforeCreditNotes - _creditNotesAmount).clamp(0, double.infinity);

  @override
  Widget build(BuildContext context) {
    final DateTime time = widget.invoiceData['timestamp'] != null
        ? (widget.invoiceData['timestamp'] as Timestamp).toDate()
        : DateTime.now();

    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        title: Text(
          context.tr('edit_bill'),
          style: const TextStyle(fontWeight: FontWeight.w900, color: kWhite, fontSize: 15, letterSpacing: 1.0),
        ),
        backgroundColor: kHeaderColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const HeroIcon(HeroIcons.arrowLeft, color: kWhite, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Fixed Header Bar (Invoice Num & Date)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: kWhite,
              border: Border(bottom: BorderSide(color: kGrey200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Reference invoice", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 0.5)),
                    Text("${widget.invoiceData['invoiceNumber'] ?? 'N/A'}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: kHeaderColor)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("Date issued", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 0.5)),
                    Text(DateFormat('dd MMM yyyy').format(time), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: kBlack87)),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionLabel('Assigned customer'),
                  _buildCustomerCard(),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionLabel('Billing Items'),
                      GestureDetector(
                        onTap: () async {
                          // Build current cart items to pre-populate nq.dart
                          final currentCartItems = _items.map((item) {
                            final qty = (item['quantity'] is int)
                                ? (item['quantity'] as int).toDouble()
                                : double.tryParse(item['quantity'].toString()) ?? 1.0;
                            List<Map<String, dynamic>>? itemTaxes;
                            if (item['taxes'] is List && (item['taxes'] as List).isNotEmpty) {
                              itemTaxes = (item['taxes'] as List).map((t) => Map<String, dynamic>.from(t as Map)).toList();
                            }
                            return CartItem(
                              productId: item['productId'] ?? '',
                              name: item['name'] ?? '',
                              price: (item['price'] ?? 0).toDouble(),
                              quantity: qty,
                              taxes: itemTaxes,
                              taxName: item['taxName'],
                              taxPercentage: item['taxPercentage'] != null ? (item['taxPercentage'] as num).toDouble() : null,
                              taxType: item['taxType'],
                            );
                          }).toList();

                          final result = await Navigator.push<List<CartItem>>(
                            context,
                            CupertinoPageRoute(
                              builder: (_) => NewQuotationPage(
                                uid: (widget.invoiceData['staffId'] ?? '').toString(),
                                userEmail: widget.invoiceData['userEmail']?.toString(),
                                isEditMode: true,
                                initialQuotationData: {
                                  'customerName': _selectedCustomerName,
                                  'customerPhone': _selectedCustomerPhone,
                                  'items': currentCartItems.map((c) => {
                                    'productId': c.productId,
                                    'name': c.name,
                                    'price': c.price,
                                    'quantity': c.quantity,
                                    'taxName': c.taxName,
                                    'taxPercentage': c.taxPercentage,
                                    'taxType': c.taxType,
                                  }).toList(),
                                },
                              ),
                            ),
                          );

                          if (result != null && result.isNotEmpty && mounted) {
                            setState(() {
                              _items = result.map((c) => {
                                'productId': c.productId,
                                'name': c.name,
                                'price': c.price,
                                'quantity': c.quantity,
                                'taxName': c.taxName,
                                'taxPercentage': c.taxPercentage,
                                'taxType': c.taxType,
                              }).toList();
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: kHeaderColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Row(
                            children: [
                              HeroIcon(HeroIcons.plusCircle, size: 14, color: kHeaderColor),
                              SizedBox(width: 6),
                              Text('Add Item', style: TextStyle(color: kHeaderColor, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  _buildItemsList(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          _buildSummaryPanel(),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildCustomerCard() {
    final hasCustomer = _selectedCustomerPhone != null;
    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hasCustomer ? kHeaderColor.withOpacity(0.3) : kOrange),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            CommonWidgets.showCustomerSelectionDialog(
              context: context,
              selectedCustomerPhone: _selectedCustomerPhone,
              onCustomerSelected: (phone, name, gst) {
                setState(() {
                  _selectedCustomerPhone = phone.isEmpty ? null : phone;
                  _selectedCustomerName = name.isEmpty ? null : name;
                  // If customer changes, credit notes may no longer be applicable
                  _selectedCreditNotes = [];
                  _creditNotesAmount = 0;
                });
              },
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: hasCustomer ? kHeaderColor : kGreyBg,
                  radius: 20,
                  child: HeroIcon(HeroIcons.user, color: hasCustomer ? kWhite : kOrange, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedCustomerName ?? 'Guest',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: kBlack87),
                      ),
                      Text(
                        hasCustomer ? _selectedCustomerPhone! : 'Tap to add customer',
                        style: TextStyle(
                          color: hasCustomer ? Colors.black : kHeaderColor,
                          fontSize: 11,
                          fontWeight: hasCustomer ? FontWeight.w600 : FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasCustomer)
                  IconButton(
                    onPressed: () => setState(() {
                      _selectedCustomerPhone = null;
                      _selectedCustomerName = null;
                      _selectedCreditNotes = [];
                      _creditNotesAmount = 0;
                    }),
                    icon: const HeroIcon(HeroIcons.xCircle, color: kErrorColor, size: 22),
                  )
                else
                  const HeroIcon(HeroIcons.chevronRight, color: kOrange, size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemsList() {
    if (_items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
        child: const Column(
          children: [
            HeroIcon(HeroIcons.shoppingCart, color: kGrey300, size: 40),
            SizedBox(height: 12),
            Text('No items in this invoice', style: TextStyle(color: kBlack54, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _items[index];
        final double rate = (item['price'] ?? 0).toDouble();
        final double qty = (item['quantity'] ?? 0) is int ? (item['quantity'] as int).toDouble() : double.parse(item['quantity'].toString());

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kGrey200),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(8)),
                child: Text('${qty.toInt()}x', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: kHeaderColor)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['name'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kBlack87), maxLines: 2, overflow: TextOverflow.ellipsis),
                    Row(
                      children: [
                        Text('@ ${rate.toStringAsFixed(0)}', style: const TextStyle(color: kOrange, fontSize: 11, fontWeight: FontWeight.w600)),
                        if (item['taxName'] != null && (item['taxPercentage'] ?? 0) > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: kPrimaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${item['taxName']} ${(item['taxPercentage'] as num).toInt()}%',
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kPrimaryColor),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${(rate * qty).toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: kHeaderColor),
                  ),
                  if (item['taxName'] != null && (item['taxPercentage'] ?? 0) > 0) ...[
                    Builder(builder: (context) {
                      final taxPercentage = (item['taxPercentage'] ?? 0).toDouble();
                      final taxType = item['taxType'] as String?;
                      final itemTotal = rate * qty;
                      double taxAmount = 0;
                      if (taxType == 'Tax Included in Price' || taxType == 'Price includes Tax') {
                        final taxRate = taxPercentage / 100;
                        taxAmount = itemTotal - (itemTotal / (1 + taxRate));
                      } else if (taxType == 'Add Tax at Billing' || taxType == 'Price is without Tax') {
                        taxAmount = itemTotal * (taxPercentage / 100);
                      }
                      return Text(
                        '+${taxAmount.toStringAsFixed(1)} tax',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: kBlack54),
                      );
                    }),
                  ],
                ],
              ),
              const SizedBox(width: 12),
              // Changed Delete button to Edit button that opens the same popup as Bill Summary
              GestureDetector(
                onTap: () => _showEditItemDialog(index),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: kHeaderColor.withOpacity(0.1), shape: BoxShape.circle),
                  child: const HeroIcon(HeroIcons.pencil, color: kHeaderColor, size: 22),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: kWhite,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -5))],
        border: const Border(top: BorderSide(color: kGrey200)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSummaryRow('Subtotal (Gross)', subtotal.toStringAsFixed(2)),
            // Display tax breakdown
            ...taxBreakdown.entries.map((entry) => _buildSummaryRow(
              '${entry.key}',
              '+ ${entry.value.toStringAsFixed(2)}',
              color: kBlack54,
            )).toList(),
            if (totalTax > 0)
              _buildSummaryRow('Total Tax', '+ ${totalTax.toStringAsFixed(2)}', color: kOrange),
            _buildSummaryRow(
                'Applied Discount',
                '- ${discount.toStringAsFixed(2)}',
                color: kGoogleGreen,
                isClickable: true,
                onTap: _showDiscountDialog
            ),
            if (_selectedCustomerPhone != null)
              _buildSummaryRow(
                  _selectedCreditNotes.isEmpty ? 'Apply Credit Note' : 'Applied Credit',
                  '- ${_creditNotesAmount.toStringAsFixed(2)}',
                  color: kAccentOrange,
                  isClickable: true,
                  onTap: _showCreditNotesDialog
              ),

            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, color: kGrey100)),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Amount payable', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: kBlack54, letterSpacing: 0.5)),
                Text('${finalTotal.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: kHeaderColor)),
              ],
            ),
            const SizedBox(height: 16),
            _buildPaymentModeSelector(),
            const SizedBox(height: 16),
             SizedBox(
               width: double.infinity,
               height: 56,
               child: ElevatedButton(
                 onPressed: _isSaving ? null : _onConfirmPressed,
                 style: ElevatedButton.styleFrom(
                   backgroundColor: kHeaderColor,
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                   elevation: 0,
                 ),
                 child: _isSaving
                     ? const CircularProgressIndicator(color: kWhite)
                     : const Text('Confirm updates', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, color: kWhite, fontSize: 14)),
               ),
             ),
           ],
         ),
       ),
     );
     }

    Future<void> _onConfirmPressed() async {
    // If Split payment selected, navigate to SplitPaymentPage with prefilled values
    if (_selectedPaymentMode == 'Split') {
      // Convert current editable items to CartItem list
      final List<CartItem> cartItems = _items.map((item) {
        final qty = (item['quantity'] is int)
            ? (item['quantity'] as int).toDouble()
            : (item['quantity'] is double ? item['quantity'] as double : double.tryParse(item['quantity'].toString()) ?? 1.0);
        List<Map<String, dynamic>>? itemTaxes;
        if (item['taxes'] is List && (item['taxes'] as List).isNotEmpty) {
          itemTaxes = (item['taxes'] as List).map((t) => Map<String, dynamic>.from(t as Map)).toList();
        }
        return CartItem(
          productId: item['productId'] ?? '',
          name: item['name'] ?? '',
          price: (item['price'] ?? 0).toDouble(),
          quantity: qty,
          taxes: itemTaxes,
          taxName: item['taxName'],
          taxPercentage: item['taxPercentage'] != null ? (item['taxPercentage'] as num).toDouble() : null,
          taxType: item['taxType'],
        );
      }).toList();

      // Extract fields from invoiceData as available (fallbacks to sensible defaults)
      final String uid = (widget.invoiceData['staffId'] ?? widget.invoiceData['staff'] ?? '')?.toString() ?? '';
      final String? userEmail = widget.invoiceData['userEmail']?.toString();
      final String? customerPhone = _selectedCustomerPhone ?? widget.invoiceData['customerPhone']?.toString();
      final String? customerName = _selectedCustomerName ?? widget.invoiceData['customerName']?.toString();
      final String customerGST = widget.invoiceData['customerGST']?.toString() ?? '';
      final double discountAmount = discount;
      final String creditNote = widget.invoiceData['creditNote']?.toString() ?? '';
      final String customNote = widget.invoiceData['customNote']?.toString() ?? '';
      final String businessName = widget.invoiceData['businessName']?.toString() ?? '';
      final String businessLocation = widget.invoiceData['businessLocation']?.toString() ?? '';
      final String businessPhone = widget.invoiceData['businessPhone']?.toString() ?? '';
      final String staffName = widget.invoiceData['staffName']?.toString() ?? widget.invoiceData['staff']?.toString() ?? '';
      final String? existingInvoiceNumber = widget.invoiceData['invoiceNumber']?.toString();
      final String? unsettledSaleId = widget.invoiceData['unsettledSaleId']?.toString() ?? widget.invoiceData['unsettledId']?.toString();
      final double deliveryCharge = (widget.invoiceData['deliveryCharge'] ?? 0).toDouble();

      // Prefill previously recorded split amounts if present
      final double? cashPrefill = widget.invoiceData['cashReceived_split'] != null ? (widget.invoiceData['cashReceived_split'] as num).toDouble() : null;
      final double? onlinePrefill = widget.invoiceData['onlineReceived_split'] != null ? (widget.invoiceData['onlineReceived_split'] as num).toDouble() : null;
      final double? creditPrefill = widget.invoiceData['creditIssued_split'] != null ? (widget.invoiceData['creditIssued_split'] as num).toDouble() : null;

      // Navigate to SplitPaymentPage and await result
      final result = await Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => SplitPaymentPage(
            uid: uid,
            userEmail: userEmail,
            cartItems: cartItems,
            totalAmount: finalTotal,
            customerPhone: customerPhone,
            customerName: customerName,
            customerGST: customerGST,
            discountAmount: discountAmount,
            creditNote: creditNote,
            customNote: customNote,
            deliveryAddress: widget.invoiceData['deliveryAddress']?.toString(),
            savedOrderId: widget.invoiceData['savedOrderId']?.toString(),
            selectedCreditNotes: _selectedCreditNotes,
            quotationId: widget.invoiceData['quotationId']?.toString(),
            existingInvoiceNumber: existingInvoiceNumber,
            unsettledSaleId: unsettledSaleId,
            businessName: businessName,
            businessLocation: businessLocation,
            businessPhone: businessPhone,
            staffName: staffName,
            actualCreditUsed: _creditNotesAmount,
            deliveryCharge: deliveryCharge,
            cashReceived_split: cashPrefill,
            onlineReceived_split: onlinePrefill,
            creditIssued_split: creditPrefill,
          ),
        ),
      );

      // If split page returned success, pop this edit page with success to refresh history
      if (result != null && result is Map && result['success'] == true) {
        if (mounted) Navigator.pop(context, true);
      }
      return;
    }

    // Otherwise fall back to normal update flow
    await _updateBill();
    }

    Widget _buildSummaryRow(String label, String value, {Color? color, bool isClickable = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Text(label, style: const TextStyle(color: kBlack54, fontSize: 13, fontWeight: FontWeight.w600)),
              if (isClickable) Padding(padding: const EdgeInsets.only(left: 6), child: HeroIcon(HeroIcons.pencilSquare, size: 16, color: color ?? kHeaderColor)),
            ]),
            Text('$value', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color ?? kBlack87)),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentModeSelector() {
    final modes = ['Cash', 'Online', 'Credit', 'Split'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: modes.map((mode) {
        final isSelected = _selectedPaymentMode == mode;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedPaymentMode = mode),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? kHeaderColor : kWhite,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isSelected ? kHeaderColor : kGrey200, width: 1.5),
              ),
              child: Center(
                child: Text(mode[0].toUpperCase() + mode.substring(1).toLowerCase(), style: TextStyle(
                    color: isSelected ? kWhite : kBlack54,
                    fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5
                )),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // --- Dialogs (Functionality Optimized) ---

  // Restoration of Edit Item Dialog logic matching Bill Summary page
  void _showEditItemDialog(int idx) async {
    final item = _items[idx];
    final nameController = TextEditingController(text: item['name']);
    final priceController = TextEditingController(text: item['price'].toString());
    final qtyController = TextEditingController(text: item['quantity'].toString());

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
    } catch (e) {
      debugPrint('Error fetching taxes: $e');
    }

    // Current tax selection - find matching tax by name and percentage
    String? selectedTaxId;
    if (item['taxName'] != null && item['taxPercentage'] != null) {
      try {
        final matchingTax = availableTaxes.firstWhere(
              (tax) {
            final nameMatch = tax['name'] == item['taxName'];
            final taxPercentage = (tax['percentage'] as num).toDouble();
            final itemPercentage = (item['taxPercentage'] as num).toDouble();
            final percentageMatch = (taxPercentage - itemPercentage).abs() < 0.01;
            return nameMatch && percentageMatch;
          },
        );
        selectedTaxId = matchingTax['id'] as String?;
      } catch (e) {
        selectedTaxId = null;
      }
    }

    // Tax type
    String selectedTaxType = item['taxType'] ?? 'Add Tax at Billing';
    final taxTypes = ['Tax Included in Price', 'Add Tax at Billing', 'No Tax Applied', 'Exempt from Tax'];

    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: kWhite,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Edit Billing Item', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: kBlack87)),
                        GestureDetector(onTap: () => Navigator.pop(context), child: const HeroIcon(HeroIcons.xMark, color: kBlack54, size: 24)),
                      ],
                    ),
                    const SizedBox(height: 24),
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
                                height: 48,
                                decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
                                child: Row(
                                  children: [
                                    IconButton(
                                      onPressed: () {
                                        int current = int.tryParse(qtyController.text) ?? 1;
                                        if (current > 1) {
                                          setDialogState(() => qtyController.text = (current - 1).toString());
                                        } else {
                                          Navigator.of(context).pop();
                                          setState(() => _items.removeAt(idx));
                                        }
                                      },
                                      icon: HeroIcon(
                                        (int.tryParse(qtyController.text) ?? 1) <= 1 ? HeroIcons.trash : HeroIcons.minus,
                                        color: (int.tryParse(qtyController.text) ?? 1) <= 1 ? kErrorColor : kHeaderColor,
                                        size: 20,
                                      ),
                                    ),
                                    Expanded(
                                      child: ValueListenableBuilder<TextEditingValue>(
      valueListenable: qtyController,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextField(
                                        controller: qtyController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        textAlign: TextAlign.center,
                                        onChanged: (v) => setDialogState(() {}),
                                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: kBlack87),
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          filled: false,
                                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                                        ),
                                      
);
      },
    ),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        int current = int.tryParse(qtyController.text) ?? 0;
                                        setDialogState(() => qtyController.text = (current + 1).toString());
                                      },
                                      icon: const HeroIcon(HeroIcons.plus, color: kHeaderColor, size: 20),
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
                                              selectedTaxType = 'Price is without Tax';
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

                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              setState(() => _items.removeAt(idx));
                            },
                            icon: const HeroIcon(HeroIcons.trash, size: 18),
                            label: const Text('Remove'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: kErrorColor,
                              side: const BorderSide(color: kErrorColor),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final newName = nameController.text.trim();
                              final newPrice = double.tryParse(priceController.text.trim()) ?? item['price'];
                              final newQty = int.tryParse(qtyController.text.trim()) ?? 1;

                              // Get tax details
                              String? taxName;
                              double? taxPercentage;
                              String? taxType;
                              double taxAmount = 0.0;

                              if (selectedTaxId != null) {
                                final selectedTax = availableTaxes.firstWhere(
                                      (tax) => tax['id'] == selectedTaxId,
                                  orElse: () => {},
                                );
                                taxName = selectedTax['name'];
                                taxPercentage = selectedTax['percentage'];
                                taxType = selectedTaxType;

                                // Recalculate tax amount based on new price and quantity
                                if (taxPercentage != null && taxPercentage > 0) {
                                  final itemTotal = newPrice * newQty;
                                  if (taxType == 'Tax Included in Price' || taxType == 'Price includes Tax') {
                                    final taxRate = taxPercentage / 100;
                                    taxAmount = itemTotal - (itemTotal / (1 + taxRate));
                                  } else if (taxType == 'Add Tax at Billing' || taxType == 'Price is without Tax') {
                                    taxAmount = itemTotal * (taxPercentage / 100);
                                  }
                                }
                              }

                              setState(() {
                                _items[idx]['name'] = newName;
                                _items[idx]['price'] = newPrice;
                                _items[idx]['quantity'] = newQty;
                                _items[idx]['taxName'] = taxName;
                                _items[idx]['taxPercentage'] = taxPercentage ?? 0;
                                _items[idx]['taxType'] = taxType;
                                _items[idx]['taxAmount'] = taxAmount;
                              });
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: kHeaderColor, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                            child: const Text('Save', style: TextStyle(color: kWhite, fontWeight: FontWeight.w900, fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  Widget _buildDialogLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: kBlack54, letterSpacing: 0.5)),
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
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kBlack87),
          decoration: InputDecoration(
            hintText: hint,
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

  void _showDiscountDialog() {
    final TextEditingController controller = TextEditingController(text: _discountController.text);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Apply discount', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
        content: ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            style: const TextStyle(fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              prefixText: _currencySymbol,
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
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold, color: kBlack54))),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kHeaderColor),
              onPressed: () {
                setState(() => _discountController.text = controller.text);
                Navigator.pop(context);
              },
              child: const Text('Apply', style: TextStyle(color: kWhite, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }

  void _showCreditNotesDialog() async {
    if (_selectedCustomerPhone == null) return;

    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      final creditNotesCollection = await FirestoreService().getStoreCollection('creditNotes');
      final snapshot = await creditNotesCollection
          .where('customerPhone', isEqualTo: _selectedCustomerPhone)
          .where('status', isEqualTo: 'Available')
          .get();

      Navigator.pop(context); // Close loading

      final availableCreditNotes = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, ...data};
      }).toList();

      if (!mounted) return;
      if (availableCreditNotes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No available credit notes for this customer')));
        return;
      }

      showDialog(
        context: context,
        builder: (ctx) {
          List<Map<String, dynamic>> tempSelected = List.from(_selectedCreditNotes);
          return StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              backgroundColor: kWhite,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text('Select credit notes', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: availableCreditNotes.length,
                  itemBuilder: (context, index) {
                    final cn = availableCreditNotes[index];
                    final isSelected = tempSelected.any((s) => s['id'] == cn['id']);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? kHeaderColor : kGrey200)),
                      child: CheckboxListTile(
                        activeColor: kHeaderColor,
                        value: isSelected,
                        title: Text(cn['creditNoteNumber'] ?? 'CN-N/A', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        subtitle: Text('Balance: ${((cn['amount'] ?? 0) as num).toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        onChanged: (val) => setDialogState(() {
                          if (val == true) tempSelected.add(cn);
                          else tempSelected.removeWhere((s) => s['id'] == cn['id']);
                        }),
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold, color: kBlack54))),
                ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: kHeaderColor),
                    onPressed: () {
                      setState(() {
                        _selectedCreditNotes = tempSelected;
                        _creditNotesAmount = _selectedCreditNotes.fold(0.0, (sum, cn) => sum + ((cn['amount'] ?? 0) as num).toDouble());
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text('Apply', style: TextStyle(color: kWhite, fontWeight: FontWeight.bold))
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      Navigator.pop(context);
      debugPrint(e.toString());
    }
  }

  void _showAddProductDialog() async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      final productsCollection = await FirestoreService().getStoreCollection('Products');
      final snapshot = await productsCollection.orderBy('itemName').get();
      Navigator.pop(context); // Close loading

      final productsList = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['itemName'] ?? 'Unknown',
          'price': (data['price'] ?? 0).toDouble(),
          'stock': (data['currentStock'] ?? 0).toDouble(),
          'code': data['productCode'] ?? '',
          'taxPercentage': (data['taxPercentage'] ?? 0).toDouble(),
          'taxName': data['taxName'],
          'taxType': data['taxType'],
          'stockEnabled': data['stockEnabled'] ?? false,
          'lowStockAlert': (data['lowStockAlert'] ?? 0.0).toDouble(),
          'expiryDate': data['expiryDate'] ?? '',
          'stockUnit': data['stockUnit'] ?? '',
        };
      }).toList();

      if (!mounted) return;

      final searchCtrl = TextEditingController();

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setSheetState) {
            final query = searchCtrl.text.toLowerCase();
            final filteredProducts = productsList.where((p) {
              final name = p['name'].toString().toLowerCase();
              final code = p['code'].toString().toLowerCase();
              return name.contains(query) || code.contains(query);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: const BoxDecoration(color: kWhite, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              child: Column(
                children: [
                  Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 40, height: 4, decoration: BoxDecoration(color: kGrey300, borderRadius: BorderRadius.circular(2))),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text('Add product', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  ),
                  // Search Bar inside Item Popup
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: searchCtrl,
                      builder: (context, value, _) {
                        final bool hasText = value.text.isNotEmpty;
                        return TextField(
                          controller: searchCtrl,
                          onChanged: (v) => setSheetState(() {}),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: "Search name or product code...",
                            prefixIcon: HeroIcon(HeroIcons.magnifyingGlass, color: kPrimaryColor, size: 20),
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
                  const Divider(height: 1, color: kGrey200),
                  Expanded(
                    child: filteredProducts.isEmpty
                        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const HeroIcon(HeroIcons.magnifyingGlass, size: 40, color: kGrey300), const SizedBox(height: 12), const Text("No matches found", style: TextStyle(color: kBlack54, fontWeight: FontWeight.w600))]))
                        : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: filteredProducts.length,
                        itemBuilder: (context, index) {
                          final p = filteredProducts[index];
                          final price = (p['price'] as double?) ?? 0.0;
                          final taxPercentage = (p['taxPercentage'] as double?) ?? 0.0;
                          final taxType = p['taxType'] as String?;
                          final stockEnabled = p['stockEnabled'] as bool? ?? false;
                          final firestoreStock = (p['stock'] as double?) ?? 0.0;
                          final lowStockAlert = (p['lowStockAlert'] as double?) ?? 0.0;
                          final unit = (p['stockUnit'] as String?) ?? '';
                          final expiryDateStr = (p['expiryDate'] as String?) ?? '';

                          // Compute how many units of this product are already in _items
                          final alreadyInCart = _items.fold<double>(0.0, (sum, item) {
                            if ((item['productId'] ?? '').toString() == p['id'].toString()) {
                              final q = (item['quantity'] is num)
                                  ? (item['quantity'] as num).toDouble()
                                  : double.tryParse(item['quantity'].toString()) ?? 0.0;
                              return sum + q;
                            }
                            return sum;
                          });

                          // Effective stock = Firestore stock minus already-in-cart qty
                          final effectiveStock = stockEnabled ? (firestoreStock - alreadyInCart).clamp(0.0, double.infinity) : firestoreStock;

                          // Status checks
                          bool isExpired = false;
                          if (expiryDateStr.isNotEmpty) {
                            try {
                              final expiry = DateTime.parse(expiryDateStr);
                              isExpired = expiry.isBefore(DateTime.now());
                            } catch (_) {}
                          }
                          final isOutOfStock = stockEnabled && effectiveStock <= 0;
                          final isLowStock = stockEnabled && lowStockAlert > 0 && effectiveStock > 0 && effectiveStock <= lowStockAlert;

                          // Border & background colours
                          final borderColor = isExpired
                              ? Colors.black.withOpacity(0.5)
                              : isOutOfStock
                                  ? kErrorColor.withOpacity(0.4)
                                  : isLowStock
                                      ? kOrange.withOpacity(0.4)
                                      : kGrey200;
                          final bgColor = isExpired
                              ? Colors.black.withOpacity(0.04)
                              : isOutOfStock
                                  ? kErrorColor.withOpacity(0.04)
                                  : isLowStock
                                      ? kOrange.withOpacity(0.04)
                                      : kWhite;

                          double taxAmount = 0.0;
                          if (taxPercentage > 0) {
                            if (taxType == 'Tax Included in Price' || taxType == 'Price includes Tax') {
                              final taxRate = taxPercentage / 100;
                              taxAmount = price - (price / (1 + taxRate));
                            } else if (taxType == 'Add Tax at Billing' || taxType == 'Price is without Tax') {
                              taxAmount = price * (taxPercentage / 100);
                            }
                          }

                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borderColor),
                            ),
                            child: Stack(
                              children: [
                                ListTile(
                                  contentPadding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
                                  title: Text(
                                    p['name'],
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: isExpired ? Colors.black : isOutOfStock ? kErrorColor : kBlack87,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Rate: $price${taxPercentage > 0 ? ' • Tax: ${taxPercentage.toStringAsFixed(0)}%' : ''}',
                                        style: const TextStyle(fontSize: 11, color: kBlack54, fontWeight: FontWeight.w600),
                                      ),
                                      if (stockEnabled) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          '${effectiveStock.toStringAsFixed(effectiveStock.truncateToDouble() == effectiveStock ? 0 : 1)} $unit available',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: isOutOfStock
                                                ? kErrorColor
                                                : isLowStock
                                                    ? kOrange
                                                    : kGoogleGreen,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  trailing: HeroIcon(
                                    HeroIcons.plusCircle,
                                    style: HeroIconStyle.solid,
                                    color: isExpired || isOutOfStock ? kGrey300 : kHeaderColor,
                                    size: 28,
                                  ),
                                  onTap: () {
                                    if (isExpired || isOutOfStock) return; // block adding
                                    setState(() {
                                      // Check if this product already exists in _items
                                      final existingIndex = _items.indexWhere(
                                        (item) => (item['productId'] ?? '').toString() == p['id'].toString(),
                                      );
                                      if (existingIndex != -1) {
                                        // Increment quantity of the existing item
                                        final currentQty = (_items[existingIndex]['quantity'] is num)
                                            ? (_items[existingIndex]['quantity'] as num).toDouble()
                                            : double.tryParse(_items[existingIndex]['quantity'].toString()) ?? 1.0;
                                        _items[existingIndex]['quantity'] = currentQty + 1;
                                      } else {
                                        // Add as new item
                                        _items.add({
                                          'productId': p['id'],
                                          'name': p['name'],
                                          'price': p['price'],
                                          'quantity': 1,
                                          'taxPercentage': taxPercentage,
                                          'taxName': p['taxName'],
                                          'taxType': taxType,
                                          'taxAmount': taxAmount,
                                        });
                                      }
                                    });
                                    // Refresh sheet so effectiveStock recalculates
                                    setSheetState(() {});
                                  },
                                ),
                                // Status badge
                                if (isExpired)
                                  Positioned(
                                    top: 8, right: 42,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(4)),
                                      child: const Text('Expired', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: kWhite)),
                                    ),
                                  )
                                else if (isOutOfStock)
                                  Positioned(
                                    top: 8, right: 42,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: kErrorColor, borderRadius: BorderRadius.circular(4)),
                                      child: const Text('Out Of Stock', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: kWhite)),
                                    ),
                                  )
                                else if (isLowStock)
                                  Positioned(
                                    top: 8, right: 42,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: kOrange, borderRadius: BorderRadius.circular(4)),
                                      child: const Text('Low Stock', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: kWhite)),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      debugPrint(e.toString());
    }
  }

  Future<void> _updateBill() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one item to update')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final oldPaymentMode = widget.invoiceData['paymentMode'];
      final oldTotal = (widget.invoiceData['total'] ?? 0).toDouble();
      final currentEditCount = (widget.invoiceData['editCount'] ?? 0) as int;

      final salesCollection = await FirestoreService().getStoreCollection('sales');
      final productsCollection = await FirestoreService().getStoreCollection('Products');

      // ── Stock diff: compare _originalItems vs _items ──────────────────────
      // Build a map of productId → total quantity for original and new items
      Map<String, double> originalQtyMap = {};
      for (final item in _originalItems) {
        final id = (item['productId'] ?? '').toString();
        if (id.isEmpty) continue;
        final qty = (item['quantity'] is num) ? (item['quantity'] as num).toDouble() : double.tryParse(item['quantity'].toString()) ?? 0.0;
        originalQtyMap[id] = (originalQtyMap[id] ?? 0) + qty;
      }

      Map<String, double> newQtyMap = {};
      for (final item in _items) {
        final id = (item['productId'] ?? '').toString();
        if (id.isEmpty) continue;
        final qty = (item['quantity'] is num) ? (item['quantity'] as num).toDouble() : double.tryParse(item['quantity'].toString()) ?? 0.0;
        newQtyMap[id] = (newQtyMap[id] ?? 0) + qty;
      }

      // Collect all unique product IDs across both maps
      final allProductIds = {...originalQtyMap.keys, ...newQtyMap.keys};

      for (final productId in allProductIds) {
        final originalQty = originalQtyMap[productId] ?? 0.0;
        final newQty = newQtyMap[productId] ?? 0.0;
        final diff = newQty - originalQty; // positive = more stock used, negative = stock restored

        if (diff == 0) continue;

        try {
          final productDoc = await productsCollection.doc(productId).get();
          if (!productDoc.exists) continue;
          final productData = productDoc.data() as Map<String, dynamic>?;
          if (productData == null) continue;
          final stockEnabled = productData['stockEnabled'] ?? false;
          if (!stockEnabled) continue;

          final currentStock = (productData['currentStock'] ?? 0.0).toDouble();
          final updatedStock = currentStock - diff; // deduct if diff > 0, restore if diff < 0
          await productsCollection.doc(productId).update({
            'currentStock': updatedStock < 0 ? 0.0 : updatedStock,
          });
        } catch (e) {
          debugPrint('Stock update error for $productId: $e');
        }
      }
      // ──────────────────────────────────────────────────────────────────────

      // Prepare taxes list for storage
      final taxList = taxBreakdown.entries.map((e) => {'name': e.key, 'amount': e.value}).toList();

      await salesCollection.doc(widget.documentId).update({
        'items': _items,
        'subtotal': subtotal,
        'discount': discount,
        'total': finalTotal,
        'totalTax': totalTax,
        'taxes': taxList,
        'paymentMode': _selectedPaymentMode,
        'customerPhone': _selectedCustomerPhone,
        'customerName': _selectedCustomerName,
        'selectedCreditNotes': _selectedCreditNotes,
        'creditNotesAmount': _creditNotesAmount,
        'updatedAt': FieldValue.serverTimestamp(),
        'editCount': currentEditCount + 1,
        'status': 'edited',
        'hasBeenEdited': true,
        'editedAt': FieldValue.serverTimestamp(),
      });

      // Handle Partial Credit Note Logic
      if (_selectedCreditNotes.isNotEmpty) {
        double remainingToDeduct = _creditNotesAmount;
        final creditNotesCollection = await FirestoreService().getStoreCollection('creditNotes');

        for (var cn in _selectedCreditNotes) {
          if (remainingToDeduct <= 0) break;
          final double noteAmount = (cn['amount'] as num).toDouble();

          if (noteAmount <= remainingToDeduct) {
            await creditNotesCollection.doc(cn['id']).update({
              'status': 'Used',
              'usedInInvoice': widget.invoiceData['invoiceNumber'],
              'usedAt': FieldValue.serverTimestamp(),
              'amount': 0.0
            });
            remainingToDeduct -= noteAmount;
          } else {
            await creditNotesCollection.doc(cn['id']).update({
              'amount': noteAmount - remainingToDeduct,
              'lastPartialUseAt': FieldValue.serverTimestamp(),
              'lastPartialInvoice': widget.invoiceData['invoiceNumber']
            });
            remainingToDeduct = 0;
          }
        }
      }

      // Customer Balance Sync
      if (_selectedCustomerPhone != null) {
        final customersCollection = await FirestoreService().getStoreCollection('customers');
        final customerRef = customersCollection.doc(_selectedCustomerPhone);

        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final customerDoc = await transaction.get(customerRef);
          if (customerDoc.exists) {
            final customerData = customerDoc.data() as Map<String, dynamic>?;
            double currentBalance = ((customerData?['balance'] ?? 0.0) as num).toDouble();
            if (oldPaymentMode == 'Credit') currentBalance -= oldTotal;
            if (_selectedPaymentMode == 'Credit') currentBalance += finalTotal;
            transaction.update(customerRef, {'balance': currentBalance});
          }
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('bill_updated_success')), backgroundColor: kGoogleGreen));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${context.tr('error_updating_bill')}: $e'), backgroundColor: kErrorColor));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

// ==========================================
// SUPPORT PAGE
// ==========================================
class SupportPage extends StatefulWidget {
  final String uid;
  final String? userEmail;
  final VoidCallback onBack;

  const SupportPage({
    super.key,
    required this.uid,
    this.userEmail,
    required this.onBack,
  });

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  String _selectedCategory = 'Technical Issue';
  bool _isSubmitting = false;

  // Store details
  String? _businessName;
  String? _businessLocation;
  String? _businessPhone;
  String? _storePlan;

  final List<String> _categories = [
    'Technical Issue',
    'Billing Question',
    'Feature Request',
    'Bug Report',
    'Account Help',
    'General Inquiry',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      // Load user's email if available
      if (widget.userEmail != null && widget.userEmail!.isNotEmpty) {
        _emailController.text = widget.userEmail!;
      }

      // Try to load business/user details from store settings
      final storeDoc = await FirestoreService().getDocument('users', widget.uid);
      if (storeDoc.exists) {
        final data = storeDoc.data() as Map<String, dynamic>?;
        if (data != null) {
          // Store details for internal tracking
          _businessName = data['businessName'] as String?;
          _businessLocation = data['businessLocation'] as String?;
          _businessPhone = data['phone'] as String?;
          _storePlan = data['plan'] as String?;

          // Pre-fill form fields
          if (data['businessName'] != null) {
            _nameController.text = data['businessName'];
          }
          if (data['phone'] != null) {
            _phoneController.text = data['phone'];
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submitSupport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      await FirebaseFirestore.instance.collection('support').add({
        // User/Contact Information
        'uid': widget.uid,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),

        // Store/Business Details
        'businessName': _businessName ?? _nameController.text.trim(),
        'businessLocation': _businessLocation ?? '',
        'businessPhone': _businessPhone ?? _phoneController.text.trim(),
        'storePlan': _storePlan ?? 'Unknown',

        // Issue Details
        'category': _selectedCategory,
        'subject': _subjectController.text.trim(),
        'description': _descriptionController.text.trim(),

        // Status & Timestamps
        'status': 'Open',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Support request submitted successfully! We\'ll get back to you soon.'),
            backgroundColor: kGoogleGreen,
            duration: Duration(seconds: 3),
          ),
        );

        // Clear form
        _subjectController.clear();
        _descriptionController.clear();
        setState(() => _selectedCategory = 'Technical Issue');

        // Go back after a short delay
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) widget.onBack();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting support request: $e'),
            backgroundColor: kErrorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
        backgroundColor: kWhite,
        appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
          title: const Text('Support', style: TextStyle(color: kWhite, fontWeight: FontWeight.bold, fontSize: 16)),
          backgroundColor: kPrimaryColor,
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            icon: const HeroIcon(HeroIcons.arrowLeft, color: kWhite, size: 18),
            onPressed: widget.onBack,
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: kPrimaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const HeroIcon(HeroIcons.lifebuoy, size: 32, color: Color(0xFF1976D2)),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Need Help?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kBlack87)),
                            SizedBox(height: 4),
                            Text('We\'re here to assist you with any questions or issues.', style: TextStyle(fontSize: 13, color: kBlack54, height: 1.4)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Contact Information Section
                const Text('Contact Information', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kBlack87)),
                const SizedBox(height: 12),

                // Name Field
                ValueListenableBuilder<TextEditingValue>(
      valueListenable: _nameController,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Your Name *',
                    hintText: 'Enter your name *',
                    prefixIcon: HeroIcon(HeroIcons.user, color: kPrimaryColor),
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
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                
);
      },
    ),

                const SizedBox(height: 16),

                // Email Field
                ValueListenableBuilder<TextEditingValue>(
      valueListenable: _emailController,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email Address *',
                    hintText: 'Enter your email *',
                    prefixIcon: HeroIcon(HeroIcons.envelope, color: kPrimaryColor),
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
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                
);
      },
    ),

                const SizedBox(height: 16),

                // Phone Field
                ValueListenableBuilder<TextEditingValue>(
      valueListenable: _phoneController,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Phone Number (Optional) *',
                    hintText: 'Enter your phone number *',
                    prefixIcon: HeroIcon(HeroIcons.phone, color: kPrimaryColor),
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

                // Issue Details Section
                const Text('Issue Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kBlack87)),
                const SizedBox(height: 12),

                // Category Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Category *',
                    prefixIcon: HeroIcon(HeroIcons.tag, color: kPrimaryColor),
                    filled: true,
                    fillColor: const Color(0xFFF8F9FA),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: kGrey200, width: 1.0),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: kGrey200, width: 1.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: kPrimaryColor, width: 2.0),
                    ),
                    labelStyle: const TextStyle(color: kBlack54, fontSize: 13, fontWeight: FontWeight.w600),
                    floatingLabelStyle: const TextStyle(color: kPrimaryColor, fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                  items: _categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedCategory = value);
                    }
                  },
                ),

                const SizedBox(height: 16),

                // Subject Field
                ValueListenableBuilder<TextEditingValue>(
      valueListenable: _subjectController,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextFormField(
                  controller: _subjectController,
                  decoration: InputDecoration(
                    labelText: 'Subject *',
                    hintText: 'Brief summary of your issue *',
                    prefixIcon: HeroIcon(HeroIcons.pencil, color: kPrimaryColor),
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
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a subject';
                    }
                    return null;
                  },
                
);
      },
    ),

                const SizedBox(height: 16),

                // Description Field
                ValueListenableBuilder<TextEditingValue>(
      valueListenable: _descriptionController,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextFormField(
                  controller: _descriptionController,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: 'Description *',
                    hintText: 'Please describe your issue in detail *',
                    alignLabelWithHint: true,
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(bottom: 80),
                      child: HeroIcon(HeroIcons.documentText, color: kPrimaryColor),
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
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please describe your issue';
                    }
                    if (value.trim().length < 10) {
                      return 'Please provide more details (at least 10 characters)';
                    }
                    return null;
                  },
                
);
      },
    ),

                const SizedBox(height: 32),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitSupport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      disabledBackgroundColor: kGrey300,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(color: kWhite, strokeWidth: 2),
                          )
                        : const Text(
                            'Submit Support Request',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.5, color: kWhite),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // Help Text
                Center(
                  child: Text(
                    'We typically respond within 24 hours',
                    style: TextStyle(fontSize: 13, color: kBlack54.withOpacity(0.7)),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

