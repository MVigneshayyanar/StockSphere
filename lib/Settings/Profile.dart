import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:maxbillup/Colors.dart';
import 'package:maxbillup/components/app_mini_switch.dart';
import 'package:maxbillup/utils/plan_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:async';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:heroicons/heroicons.dart';

// Imports from your project structure
import 'package:maxbillup/components/common_bottom_nav.dart';
import 'package:maxbillup/Auth/LoginPage.dart';
import 'package:maxbillup/Auth/SubscriptionPlanPage.dart';
import 'package:maxbillup/services/number_generator_service.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/Sales/components/common_widgets.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/utils/plan_permission_helper.dart';
import 'package:maxbillup/Settings/TaxSettings.dart' as TaxSettingsNew;
import 'package:maxbillup/Settings/StaffManagement.dart';
import 'package:maxbillup/services/referral_service.dart';

// ==========================================DF
// 1. MAIN SETTINGS PAGE
// ==========================================
class SettingsPage extends StatefulWidget {
  final String uid;
  final String? userEmail;
  const SettingsPage({super.key, required this.uid, this.userEmail});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? _currentView;
  final List<String> _viewHistory = [];
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _storeData;
  bool _loading = true;
  StreamSubscription? _storeDataSub;

  // Permission tracking
  Map<String, dynamic> _permissions = {};
  String _role = '';
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _initFastFetch();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
      if (userDoc.exists && mounted) {
        final data = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _permissions = data['permissions'] as Map<String, dynamic>? ?? {};
          _role = data['role'] as String? ?? '';
          _isAdmin = _role.toLowerCase() == 'owner';
        });
      } else {
        // If no user doc found, check if this is the store owner
        final storeDoc = await FirestoreService().getCurrentStoreDoc();
        if (storeDoc != null && mounted) {
          final storeData = storeDoc.data() as Map<String, dynamic>?;
          if (storeData?['ownerId'] == widget.uid) {
            setState(() {
              _isAdmin = true;
              _role = 'Owner';
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading permissions: $e');
    }
  }

  bool _hasPermission(String permission) {
    if (_isAdmin) return true;
    return _permissions[permission] == true;
  }

  /// FAST FETCH: Using memory cache and reactive streams for 0ms load
  Future<void> _initFastFetch() async {
    final fs = FirestoreService();

    final storeDoc = await fs.getCurrentStoreDoc();
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.uid).get(
        const GetOptions(source: Source.cache)
    );

    if (mounted) {
      setState(() {
        _storeData = storeDoc?.data() as Map<String, dynamic>?;
        _userData = userDoc.data();
        _loading = false;
      });
      _handleImageCaching();
    }

    _storeDataSub = fs.storeDataStream.listen((data) {
      if (mounted) {
        setState(() {
          _storeData = data;
        });
        _handleImageCaching();
      }
    });

    fs.notifyStoreDataChanged();
  }

  void _handleImageCaching() {
    final logoUrl = _storeData?['logoUrl'] as String?;
    if (logoUrl != null && logoUrl.isNotEmpty) {
      precacheImage(NetworkImage(logoUrl), context);
    }
  }

  @override
  void dispose() {
    _storeDataSub?.cancel();
    super.dispose();
  }

  void _navigateTo(String view) {
    setState(() {
      if (_currentView != null) _viewHistory.add(_currentView!);
      _currentView = view;
    });
  }

  void _goBack() {
    setState(() {
      if (_viewHistory.isNotEmpty) {
        _currentView = _viewHistory.removeLast();
      } else {
        _currentView = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (_currentView != null) {
      // Wrap sub-pages with PopScope to handle Android back button
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            _goBack();
          }
        },
        child: _buildSubPage(),
      );
    }

    return _buildMainSettingsPage(context, screenWidth);
  }

  Widget _buildSubPage() {
    switch (_currentView) {
      case 'BusinessDetails':
        return BusinessDetailsPage(
          uid: widget.uid,
          onBack: _goBack,
          initialStoreData: _storeData,
          initialUserData: _userData,
        );
      case 'UserManagement':
        return StaffManagementPage(uid: widget.uid, userEmail: widget.userEmail, onBack: _goBack);
      case 'ReceiptSettings':
        return ReceiptSettingsPage(onBack: _goBack, onNavigate: _navigateTo, uid: widget.uid, userEmail: widget.userEmail);
      case 'BillPrintSettings':
        return BillPrintSettingsPage(onBack: _goBack);
      case 'ReceiptCustomization':
        return ReceiptCustomizationPage(onBack: _goBack);
      case 'TaxSettings':
        return TaxSettingsNew.TaxSettingsPage(uid: widget.uid, onBack: _goBack);
      case 'PrinterSetup':
        return PrinterSetupPage(onBack: _goBack);
      case 'GeneralSettings':
        return GeneralSettingsPage(onBack: _goBack, onNavigate: _navigateTo);
      case 'FeatureSettings':
        return FeatureSettingsPage(onBack: _goBack);
      case 'Language':
        return LanguagePage(onBack: _goBack);
      case 'Theme':
        return ThemePage(onBack: _goBack);
      case 'Help':
        return HelpPage(onBack: _goBack, onNavigate: _navigateTo);
      case 'FAQs':
        return FAQsPage(onBack: _goBack);
      case 'UpcomingFeatures':
        return UpcomingFeaturesPage(onBack: _goBack);
      case 'VideoTutorials':
        return VideoTutorialsPage(onBack: _goBack);
      default:
        return _buildMainSettingsPage(context, MediaQuery.of(context).size.width);
    }
  }

  Widget _buildMainSettingsPage(BuildContext context, double screenWidth) {
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        title: Text(context.tr('settings'), style: const TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18, fontFamily: 'NotoSans')),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        children: [
          _buildProfileCard(),
          const SizedBox(height: 24),
          _buildSectionTitle("App config"),
          // 1. Business Profile - only visible if admin or has editBusinessProfile permission
            if (_isAdmin || _hasPermission('editBusinessProfile'))
            _buildModernTile(
              title: "Business Profile",
              icon: HeroIcons.buildingStorefront,
              color: kGoogleGreen,
              onTap: () => _navigateTo('BusinessDetails'),
              subtitle: "Manage business profile & details",
            ),
          // 2. User Management (Staff Management - only visible if admin or has staffManagement permission)
          if (_isAdmin)
            _buildModernTile(
              title: "Staff Access & Roles",
              icon: HeroIcons.users,
              color: const Color(0xFF9C27B0),
              onTap: () async {
                final canAccess = await PlanPermissionHelper.canAccessStaffManagement();
                if (!mounted) return;
                if (canAccess) {
                  _navigateTo('UserManagement');
                } else {
                  PlanPermissionHelper.showUpgradeDialog(
                    context,
                    'Staff Access & Roles',
                    uid: widget.uid,
                  );
                }
              },
              subtitle: "Manage staff & permissions",
            ),
          // 3. Tax Settings - only visible if admin or has taxSettings permission
          if (_isAdmin || _hasPermission('taxSettings'))
            _buildModernTile(
              title: "Tax Settings",
              icon: HeroIcons.receiptPercent,
              color: const Color(0xFF00796B),
              onTap: () => _navigateTo('TaxSettings'),
              subtitle: "GST, VAT & local tax compliance",
            ),
          // 4. Bill & Print Settings - only visible if admin or has receiptCustomization permission
          if (_isAdmin || _hasPermission('receiptCustomization'))
            _buildModernTile(
              title: "Bill Receipt Settings",
              icon: HeroIcons.documentText,
              color: kOrange,
              onTap: () => _navigateTo('BillPrintSettings'),
              subtitle: "Invoice templates & format",
            ),
          // 5. Printer Setup
          _buildModernTile(
            title: "Printer Setup",
            icon: HeroIcons.printer,
            color: const Color(0xFFE91E63),
            onTap: () => _navigateTo('PrinterSetup'),
            subtitle: "Setup Bluetooth thermal printers",
          ),
          // 6. General Settings (Language included)
          _buildModernTile(
            title: "General Settings",
            icon: HeroIcons.cog6Tooth,
            color: kPrimaryColor,
            onTap: () => _navigateTo('GeneralSettings'),
            subtitle: "Language",//, theme & preferences
          ),

          // Invite a Friend
          _buildModernTile(
            title: "Invite a Friend",
            icon: HeroIcons.share,
            color: const Color(0xFF2F7CF6),
            onTap: () => ReferralService.showReferralDialog(context),
            subtitle: "Share MAXmybill with friends",
          ),
          const SizedBox(height: 32),
          const Center(child: Text('Version 1.0.0', style: TextStyle(color: kBlack54, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1, fontFamily: 'Lato'))),
          const SizedBox(height: 16),
          _buildLogoutButton(),
          const SizedBox(height: 40),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Subscription info bar
          // Main bottom navigation
          CommonBottomNav(
            uid: widget.uid,
            userEmail: widget.userEmail,
            currentIndex: 4,
            screenWidth: screenWidth,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    final name = _storeData?['businessName'] ?? _userData?['businessName'] ?? _userData?['name'] ?? 'Business Owner';
    final email = _userData?['email'] ?? widget.userEmail ?? '';
    final logoUrl = (_storeData?['logoUrl'] as String?) ?? '';

    // Use Consumer to automatically rebuild when plan changes
    return Consumer<PlanProvider>(
      builder: (context, planProvider, child) {
        // Use cached plan for instant access - updates automatically when subscription changes
        final plan = planProvider.cachedPlan;
        final originalPlan = planProvider.originalPlan;
        final isPremium = plan.toLowerCase() != 'free' && plan.toLowerCase() != 'starter';
        final expiryDate = planProvider.cachedExpiryDate;
        final isExpiringSoon = planProvider.isExpiringSoon;
        final daysUntilExpiry = planProvider.daysUntilExpiry;

        // Check if plan is expired (originalPlan was premium but current plan is free due to expiry)
        final isExpired = originalPlan.toLowerCase() != 'free' &&
                         originalPlan.toLowerCase() != 'starter' &&
                         plan.toLowerCase() == 'free' &&
                         expiryDate != null &&
                         DateTime.now().isAfter(expiryDate);

        // Format expiry date
        String? expiryText;
        if (expiryDate != null) {
          final day = expiryDate.day.toString().padLeft(2, '0');
          final month = _getMonthName(expiryDate.month);
          final year = expiryDate.year;
          expiryText = '$day $month $year';
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: kWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kGrey200),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (logoUrl.isNotEmpty) {
                    showDialog(
                      context: context,
                      builder: (context) => Dialog(
                        backgroundColor: Colors.transparent,
                        insetPadding: const EdgeInsets.all(16),
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: InteractiveViewer(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(logoUrl, fit: BoxFit.contain),
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: kGreyBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: logoUrl.isNotEmpty
                              ? Image.network(logoUrl, fit: BoxFit.cover, key: ValueKey(logoUrl))
                              : Container(
                                  alignment: Alignment.center,
                                  child: const HeroIcon(HeroIcons.buildingStorefront, size: 28, color: kGrey400),
                                ),
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: kGrey200, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: kBlack87, fontFamily: 'NotoSans'), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(email, style: const TextStyle(fontSize: 12, color: kBlack54, fontWeight: FontWeight.w600, fontFamily: 'Lato')),
                    const SizedBox(height: 10),
                    // Plan badge - clickable to go to subscription page
                    GestureDetector(
                      onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (context) => SubscriptionPlanPage(uid: widget.uid, currentPlan: plan))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (isExpired ? kErrorColor : (isPremium ? kGoogleGreen : kOrange)).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: (isExpired ? kErrorColor : (isPremium ? kGoogleGreen : kOrange)).withOpacity(0.2)),
                                ),
                                child: Text(
                                  isExpired ? 'Expired' : plan,
                                  style: TextStyle(fontSize: 9, color: isExpired ? kErrorColor : (isPremium ? kGoogleGreen : kOrange), fontWeight: FontWeight.w900, letterSpacing: 0.5, fontFamily: 'Lato')
                                ),
                              ),
                              if (isExpired) ...[
                                const SizedBox(width: 8),
                                Text('(was ${originalPlan})', style: const TextStyle(fontSize: 9, color: kBlack54, fontStyle: FontStyle.italic, fontFamily: 'Lato')),
                              ],
                              if (!isPremium || isExpired) ...[
                                const SizedBox(width: 12),
                                Text(isExpired ? 'Renew Now' : 'Upgrade Now', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kPrimaryColor, letterSpacing: 0.5, fontFamily: 'Lato')),
                              ]
                            ],
                          ),
                          // Expiry info
                          if (isExpired && expiryText != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const HeroIcon(HeroIcons.exclamationTriangle, size: 12, color: kErrorColor),
                                const SizedBox(width: 4),
                                Text(
                                  'Expired on $expiryText',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: kErrorColor,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Lato',
                                  ),
                                ),
                              ],
                            ),
                          ] else if (isPremium && expiryText != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                HeroIcon(HeroIcons.calendar, size: 12, color: isExpiringSoon ? kErrorColor : kBlack54),
                                const SizedBox(width: 4),
                                Text(
                                  isExpiringSoon
                                    ? 'Expires in $daysUntilExpiry day${daysUntilExpiry == 1 ? '' : 's'} ($expiryText)'
                                    : 'Valid till $expiryText',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isExpiringSoon ? kErrorColor : kBlack54,
                                    fontWeight: isExpiringSoon ? FontWeight.w700 : FontWeight.w500,
                                    fontFamily: 'Lato',
                                  ),
                                ),
                                if (isExpiringSoon) ...[
                                  const SizedBox(width: 6),
                                  const Text('Renew', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kPrimaryColor, fontFamily: 'Lato')),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  Widget _buildModernTile({required String title, required HeroIcons icon, required Color color, required VoidCallback onTap, String? subtitle}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
          child: HeroIcon(icon, color: color, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: kBlack87)),
        subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(color: kBlack54, fontSize: 11, fontWeight: FontWeight.w500, fontFamily: 'Lato')) : null,
        trailing: const HeroIcon(HeroIcons.chevronRight, color: kGrey400, size: 14),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () async {
          FirestoreService().clearCache();
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(CupertinoPageRoute(builder: (_) => const LoginPage()), (r) => false);
        },
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: kErrorColor, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text("Sign Out", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: kErrorColor, letterSpacing: 1.0, fontFamily: 'Lato')),
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12, left: 4),
    child: Text(title, style: const TextStyle(color: kBlack54, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontFamily: 'NotoSans')),
  );
}

// ==========================================
// 2. BUSINESS DETAILS PAGE
// ==========================================
class BusinessDetailsPage extends StatefulWidget {
  final String uid;
  final VoidCallback onBack;
  final Map<String, dynamic>? initialStoreData;
  final Map<String, dynamic>? initialUserData;

  const BusinessDetailsPage({
    super.key,
    required this.uid,
    required this.onBack,
    this.initialStoreData,
    this.initialUserData,
  });

  @override
  State<BusinessDetailsPage> createState() => _BusinessDetailsPageState();
}

class _BusinessDetailsPageState extends State<BusinessDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController(), _phoneCtrl = TextEditingController(), _personalPhoneCtrl = TextEditingController(), _locCtrl = TextEditingController(), _emailCtrl = TextEditingController(), _ownerCtrl = TextEditingController();
  final _taxTypeCtrl = TextEditingController(), _taxNumberCtrl = TextEditingController();
  final _licenseTypeCtrl = TextEditingController(), _licenseNumberCtrl = TextEditingController();
  bool _loading = false, _fetching = true, _uploadingImage = false;
  bool _hasChanges = false;
  bool _isPremium = false;

  // Original values to track changes
  Map<String, String> _originalValues = {};

  String? _logoUrl;
  File? _selectedImage;
  String _selectedCurrency = 'INR';

  // Country code
  String _selectedCountryCode = '+91';
  String _selectedCountryFlag = '🇮🇳';

  final List<Map<String, String>> _countryCodes = [
    {'code': '+91', 'flag': '🇮🇳', 'name': 'India'},
    {'code': '+1', 'flag': '🇺🇸', 'name': 'United States'},
    {'code': '+44', 'flag': '🇬🇧', 'name': 'United Kingdom'},
    {'code': '+971', 'flag': '🇦🇪', 'name': 'Uae'},
    {'code': '+966', 'flag': '🇸🇦', 'name': 'Saudi Arabia'},
    {'code': '+974', 'flag': '🇶🇦', 'name': 'Qatar'},
    {'code': '+965', 'flag': '🇰🇼', 'name': 'Kuwait'},
    {'code': '+973', 'flag': '🇧🇭', 'name': 'Bahrain'},
    {'code': '+968', 'flag': '🇴🇲', 'name': 'Oman'},
    {'code': '+60', 'flag': '🇲🇾', 'name': 'Malaysia'},
    {'code': '+65', 'flag': '🇸🇬', 'name': 'Singapore'},
    {'code': '+92', 'flag': '🇵🇰', 'name': 'Pakistan'},
    {'code': '+880', 'flag': '🇧🇩', 'name': 'Bangladesh'},
    {'code': '+94', 'flag': '🇱🇰', 'name': 'Sri Lanka'},
    {'code': '+977', 'flag': '🇳🇵', 'name': 'Nepal'},
    {'code': '+61', 'flag': '🇦🇺', 'name': 'Australia'},
    {'code': '+64', 'flag': '🇳🇿', 'name': 'New Zealand'},
    {'code': '+49', 'flag': '🇩🇪', 'name': 'Germany'},
    {'code': '+33', 'flag': '🇫🇷', 'name': 'France'},
    {'code': '+39', 'flag': '🇮🇹', 'name': 'Italy'},
    {'code': '+34', 'flag': '🇪🇸', 'name': 'Spain'},
    {'code': '+7', 'flag': '🇷🇺', 'name': 'Russia'},
    {'code': '+81', 'flag': '🇯🇵', 'name': 'Japan'},
    {'code': '+82', 'flag': '🇰🇷', 'name': 'South Korea'},
    {'code': '+86', 'flag': '🇨🇳', 'name': 'China'},
    {'code': '+55', 'flag': '🇧🇷', 'name': 'Brazil'},
    {'code': '+52', 'flag': '🇲🇽', 'name': 'Mexico'},
    {'code': '+27', 'flag': '🇿🇦', 'name': 'South Africa'},
    {'code': '+234', 'flag': '🇳🇬', 'name': 'Nigeria'},
    {'code': '+254', 'flag': '🇰🇪', 'name': 'Kenya'},
    {'code': '+20', 'flag': '🇪🇬', 'name': 'Egypt'},
  ];

  final List<Map<String, String>> _currencies = [
    // Popular currencies first
    {'code': 'INR', 'symbol': '₹', 'name': 'Indian Rupee'},
    {'code': 'USD', 'symbol': '\$', 'name': 'US Dollar'},
    {'code': 'EUR', 'symbol': '€', 'name': 'Euro'},
    {'code': 'GBP', 'symbol': '£', 'name': 'British Pound'},
    {'code': 'CNY', 'symbol': '¥', 'name': 'Chinese Yuan'},
    {'code': 'JPY', 'symbol': '¥', 'name': 'Japanese Yen'},
    {'code': 'AUD', 'symbol': 'A\$', 'name': 'Australian Dollar'},
    {'code': 'CAD', 'symbol': 'C\$', 'name': 'Canadian Dollar'},
    {'code': 'CHF', 'symbol': 'CHF', 'name': 'Swiss Franc'},
    {'code': 'SGD', 'symbol': 'S\$', 'name': 'Singapore Dollar'},
    {'code': 'AED', 'symbol': 'د.إ', 'name': 'UAE Dirham'},
    {'code': 'SAR', 'symbol': '﷼', 'name': 'Saudi Riyal'},

    // Asia-Pacific
    {'code': 'AFN', 'symbol': '؋', 'name': 'Afghan Afghani'},
    {'code': 'AMD', 'symbol': '֏', 'name': 'Armenian Dram'},
    {'code': 'AZN', 'symbol': '₼', 'name': 'Azerbaijani Manat'},
    {'code': 'BDT', 'symbol': '৳', 'name': 'Bangladeshi Taka'},
    {'code': 'BHD', 'symbol': '.د.ب', 'name': 'Bahraini Dinar'},
    {'code': 'BND', 'symbol': 'B\$', 'name': 'Brunei Dollar'},
    {'code': 'BTN', 'symbol': 'Nu.', 'name': 'Bhutanese Ngultrum'},
    {'code': 'FJD', 'symbol': 'FJ\$', 'name': 'Fijian Dollar'},
    {'code': 'GEL', 'symbol': '₾', 'name': 'Georgian Lari'},
    {'code': 'HKD', 'symbol': 'HK\$', 'name': 'Hong Kong Dollar'},
    {'code': 'IDR', 'symbol': 'Rp', 'name': 'Indonesian Rupiah'},
    {'code': 'ILS', 'symbol': '₪', 'name': 'Israeli New Shekel'},
    {'code': 'IQD', 'symbol': 'ع.د', 'name': 'Iraqi Dinar'},
    {'code': 'IRR', 'symbol': '﷼', 'name': 'Iranian Rial'},
    {'code': 'JOD', 'symbol': 'د.ا', 'name': 'Jordanian Dinar'},
    {'code': 'KHR', 'symbol': '៛', 'name': 'Cambodian Riel'},
    {'code': 'KRW', 'symbol': '₩', 'name': 'South Korean Won'},
    {'code': 'KWD', 'symbol': 'د.ك', 'name': 'Kuwaiti Dinar'},
    {'code': 'KZT', 'symbol': '₸', 'name': 'Kazakhstani Tenge'},
    {'code': 'KGS', 'symbol': 'с', 'name': 'Kyrgyzstani Som'},
    {'code': 'LAK', 'symbol': '₭', 'name': 'Lao Kip'},
    {'code': 'LBP', 'symbol': 'ل.ل', 'name': 'Lebanese Pound'},
    {'code': 'LKR', 'symbol': 'Rs', 'name': 'Sri Lankan Rupee'},
    {'code': 'MMK', 'symbol': 'K', 'name': 'Myanmar Kyat'},
    {'code': 'MNT', 'symbol': '₮', 'name': 'Mongolian Tugrik'},
    {'code': 'MOP', 'symbol': 'MOP\$', 'name': 'Macanese Pataca'},
    {'code': 'MVR', 'symbol': 'Rf', 'name': 'Maldivian Rufiyaa'},
    {'code': 'MYR', 'symbol': 'RM', 'name': 'Malaysian Ringgit'},
    {'code': 'NPR', 'symbol': 'Rs', 'name': 'Nepalese Rupee'},
    {'code': 'NZD', 'symbol': 'NZ\$', 'name': 'New Zealand Dollar'},
    {'code': 'OMR', 'symbol': 'ر.ع.', 'name': 'Omani Rial'},
    {'code': 'PGK', 'symbol': 'K', 'name': 'Papua New Guinean Kina'},
    {'code': 'PHP', 'symbol': '₱', 'name': 'Philippine Peso'},
    {'code': 'PKR', 'symbol': 'Rs', 'name': 'Pakistani Rupee'},
    {'code': 'QAR', 'symbol': 'ر.ق', 'name': 'Qatari Riyal'},
    {'code': 'SBD', 'symbol': 'SI\$', 'name': 'Solomon Islands Dollar'},
    {'code': 'SYP', 'symbol': '£S', 'name': 'Syrian Pound'},
    {'code': 'THB', 'symbol': '฿', 'name': 'Thai Baht'},
    {'code': 'TJS', 'symbol': 'SM', 'name': 'Tajikistani Somoni'},
    {'code': 'TMT', 'symbol': 'T', 'name': 'Turkmenistani Manat'},
    {'code': 'TOP', 'symbol': 'T\$', 'name': 'Tongan Paʻanga'},
    {'code': 'TRY', 'symbol': '₺', 'name': 'Turkish Lira'},
    {'code': 'TWD', 'symbol': 'NT\$', 'name': 'New Taiwan Dollar'},
    {'code': 'UZS', 'symbol': 'so\'m', 'name': 'Uzbekistani Som'},
    {'code': 'VND', 'symbol': '₫', 'name': 'Vietnamese Dong'},
    {'code': 'VUV', 'symbol': 'VT', 'name': 'Vanuatu Vatu'},
    {'code': 'WST', 'symbol': 'WS\$', 'name': 'Samoan Tālā'},
    {'code': 'YER', 'symbol': '﷼', 'name': 'Yemeni Rial'},

    // Americas
    {'code': 'ARS', 'symbol': '\$', 'name': 'Argentine Peso'},
    {'code': 'AWG', 'symbol': 'ƒ', 'name': 'Aruban Florin'},
    {'code': 'BBD', 'symbol': 'Bds\$', 'name': 'Barbadian Dollar'},
    {'code': 'BMD', 'symbol': 'BD\$', 'name': 'Bermudian Dollar'},
    {'code': 'BOB', 'symbol': 'Bs.', 'name': 'Bolivian Boliviano'},
    {'code': 'BRL', 'symbol': 'R\$', 'name': 'Brazilian Real'},
    {'code': 'BSD', 'symbol': 'B\$', 'name': 'Bahamian Dollar'},
    {'code': 'BZD', 'symbol': 'BZ\$', 'name': 'Belize Dollar'},
    {'code': 'CLP', 'symbol': '\$', 'name': 'Chilean Peso'},
    {'code': 'COP', 'symbol': '\$', 'name': 'Colombian Peso'},
    {'code': 'CRC', 'symbol': '₡', 'name': 'Costa Rican Colón'},
    {'code': 'CUP', 'symbol': '\$', 'name': 'Cuban Peso'},
    {'code': 'DOP', 'symbol': 'RD\$', 'name': 'Dominican Peso'},
    {'code': 'GTQ', 'symbol': 'Q', 'name': 'Guatemalan Quetzal'},
    {'code': 'GYD', 'symbol': 'G\$', 'name': 'Guyanese Dollar'},
    {'code': 'HNL', 'symbol': 'L', 'name': 'Honduran Lempira'},
    {'code': 'HTG', 'symbol': 'G', 'name': 'Haitian Gourde'},
    {'code': 'JMD', 'symbol': 'J\$', 'name': 'Jamaican Dollar'},
    {'code': 'KYD', 'symbol': 'CI\$', 'name': 'Cayman Islands Dollar'},
    {'code': 'MXN', 'symbol': '\$', 'name': 'Mexican Peso'},
    {'code': 'NIO', 'symbol': 'C\$', 'name': 'Nicaraguan Córdoba'},
    {'code': 'PAB', 'symbol': 'B/.', 'name': 'Panamanian Balboa'},
    {'code': 'PEN', 'symbol': 'S/.', 'name': 'Peruvian Sol'},
    {'code': 'PYG', 'symbol': '₲', 'name': 'Paraguayan Guaraní'},
    {'code': 'SRD', 'symbol': '\$', 'name': 'Surinamese Dollar'},
    {'code': 'TTD', 'symbol': 'TT\$', 'name': 'Trinidad and Tobago Dollar'},
    {'code': 'UYU', 'symbol': '\$U', 'name': 'Uruguayan Peso'},
    {'code': 'VES', 'symbol': 'Bs.S', 'name': 'Venezuelan Bolívar'},
    {'code': 'XCD', 'symbol': 'EC\$', 'name': 'East Caribbean Dollar'},

    // Europe
    {'code': 'ALL', 'symbol': 'L', 'name': 'Albanian Lek'},
    {'code': 'BAM', 'symbol': 'KM', 'name': 'Bosnia and Herzegovina Mark'},
    {'code': 'BGN', 'symbol': 'лв', 'name': 'Bulgarian Lev'},
    {'code': 'BYN', 'symbol': 'Br', 'name': 'Belarusian Ruble'},
    {'code': 'CZK', 'symbol': 'Kč', 'name': 'Czech Koruna'},
    {'code': 'DKK', 'symbol': 'kr', 'name': 'Danish Krone'},
    {'code': 'GEL', 'symbol': '₾', 'name': 'Georgian Lari'},
    {'code': 'GIP', 'symbol': '£', 'name': 'Gibraltar Pound'},
    {'code': 'HRK', 'symbol': 'kn', 'name': 'Croatian Kuna'},
    {'code': 'HUF', 'symbol': 'Ft', 'name': 'Hungarian Forint'},
    {'code': 'ISK', 'symbol': 'kr', 'name': 'Icelandic Króna'},
    {'code': 'MDL', 'symbol': 'L', 'name': 'Moldovan Leu'},
    {'code': 'MKD', 'symbol': 'ден', 'name': 'Macedonian Denar'},
    {'code': 'NOK', 'symbol': 'kr', 'name': 'Norwegian Krone'},
    {'code': 'PLN', 'symbol': 'zł', 'name': 'Polish Złoty'},
    {'code': 'RON', 'symbol': 'lei', 'name': 'Romanian Leu'},
    {'code': 'RSD', 'symbol': 'дин', 'name': 'Serbian Dinar'},
    {'code': 'RUB', 'symbol': '₽', 'name': 'Russian Ruble'},
    {'code': 'SEK', 'symbol': 'kr', 'name': 'Swedish Krona'},
    {'code': 'UAH', 'symbol': '₴', 'name': 'Ukrainian Hryvnia'},

    // Africa
    {'code': 'AOA', 'symbol': 'Kz', 'name': 'Angolan Kwanza'},
    {'code': 'BIF', 'symbol': 'Fr', 'name': 'Burundian Franc'},
    {'code': 'BWP', 'symbol': 'P', 'name': 'Botswana Pula'},
    {'code': 'CDF', 'symbol': 'FC', 'name': 'Congolese Franc'},
    {'code': 'CVE', 'symbol': '\$', 'name': 'Cape Verdean Escudo'},
    {'code': 'DJF', 'symbol': 'Fdj', 'name': 'Djiboutian Franc'},
    {'code': 'DZD', 'symbol': 'د.ج', 'name': 'Algerian Dinar'},
    {'code': 'EGP', 'symbol': '£', 'name': 'Egyptian Pound'},
    {'code': 'ERN', 'symbol': 'Nfk', 'name': 'Eritrean Nakfa'},
    {'code': 'ETB', 'symbol': 'Br', 'name': 'Ethiopian Birr'},
    {'code': 'GHS', 'symbol': '₵', 'name': 'Ghanaian Cedi'},
    {'code': 'GMD', 'symbol': 'D', 'name': 'Gambian Dalasi'},
    {'code': 'GNF', 'symbol': 'FG', 'name': 'Guinean Franc'},
    {'code': 'KES', 'symbol': 'KSh', 'name': 'Kenyan Shilling'},
    {'code': 'KMF', 'symbol': 'CF', 'name': 'Comorian Franc'},
    {'code': 'LRD', 'symbol': 'L\$', 'name': 'Liberian Dollar'},
    {'code': 'LSL', 'symbol': 'L', 'name': 'Lesotho Loti'},
    {'code': 'LYD', 'symbol': 'ل.د', 'name': 'Libyan Dinar'},
    {'code': 'MAD', 'symbol': 'د.م.', 'name': 'Moroccan Dirham'},
    {'code': 'MGA', 'symbol': 'Ar', 'name': 'Malagasy Ariary'},
    {'code': 'MRU', 'symbol': 'UM', 'name': 'Mauritanian Ouguiya'},
    {'code': 'MUR', 'symbol': '₨', 'name': 'Mauritian Rupee'},
    {'code': 'MWK', 'symbol': 'MK', 'name': 'Malawian Kwacha'},
    {'code': 'MZN', 'symbol': 'MT', 'name': 'Mozambican Metical'},
    {'code': 'NAD', 'symbol': 'N\$', 'name': 'Namibian Dollar'},
    {'code': 'NGN', 'symbol': '₦', 'name': 'Nigerian Naira'},
    {'code': 'RWF', 'symbol': 'FRw', 'name': 'Rwandan Franc'},
    {'code': 'SCR', 'symbol': '₨', 'name': 'Seychellois Rupee'},
    {'code': 'SDG', 'symbol': 'ج.س.', 'name': 'Sudanese Pound'},
    {'code': 'SLL', 'symbol': 'Le', 'name': 'Sierra Leonean Leone'},
    {'code': 'SOS', 'symbol': 'Sh', 'name': 'Somali Shilling'},
    {'code': 'SSP', 'symbol': '£', 'name': 'South Sudanese Pound'},
    {'code': 'STN', 'symbol': 'Db', 'name': 'São Tomé and Príncipe Dobra'},
    {'code': 'SZL', 'symbol': 'L', 'name': 'Swazi Lilangeni'},
    {'code': 'TND', 'symbol': 'د.ت', 'name': 'Tunisian Dinar'},
    {'code': 'TZS', 'symbol': 'TSh', 'name': 'Tanzanian Shilling'},
    {'code': 'UGX', 'symbol': 'USh', 'name': 'Ugandan Shilling'},
    {'code': 'XAF', 'symbol': 'Fcfa', 'name': 'Central African CFA Franc'},
    {'code': 'XOF', 'symbol': 'Cfa', 'name': 'West African CFA Franc'},
    {'code': 'ZAR', 'symbol': 'R', 'name': 'South African Rand'},
    {'code': 'ZMW', 'symbol': 'ZK', 'name': 'Zambian Kwacha'},
    {'code': 'ZWL', 'symbol': 'Z\$', 'name': 'Zimbabwean Dollar'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialStoreData != null) {
      final data = widget.initialStoreData!;
      _nameCtrl.text = data['businessName'] ?? '';
      _phoneCtrl.text = data['businessPhone'] ?? '';
      _personalPhoneCtrl.text = data['personalPhone'] ?? '';

      // Split taxType into type and number (format: "Type Number")
      final taxType = data['taxType'] ?? data['gstin'] ?? '';
      if (taxType.isNotEmpty) {
        final taxParts = taxType.toString().split(' ');
        if (taxParts.length > 1) {
          _taxTypeCtrl.text = taxParts[0];
          _taxNumberCtrl.text = taxParts.sublist(1).join(' ');
        } else {
          _taxTypeCtrl.text = '';
          _taxNumberCtrl.text = taxType;
        }
      }

      // Split licenseNumber into type and number (format: "Type Number")
      final licenseNumber = data['licenseNumber'] ?? '';
      if (licenseNumber.isNotEmpty) {
        final licenseParts = licenseNumber.toString().split(' ');
        if (licenseParts.length > 1) {
          _licenseTypeCtrl.text = licenseParts[0];
          _licenseNumberCtrl.text = licenseParts.sublist(1).join(' ');
        } else {
          _licenseTypeCtrl.text = '';
          _licenseNumberCtrl.text = licenseNumber;
        }
      }

      _selectedCurrency = data['currency'] ?? 'INR';
      _locCtrl.text = data['businessLocation'] ?? '';
      _ownerCtrl.text = data['ownerName'] ?? '';
      _logoUrl = data['logoUrl'];
      _fetching = false;
    }
    if (widget.initialUserData != null) {
      _emailCtrl.text = widget.initialUserData!['email'] ?? '';
      if (_ownerCtrl.text.isEmpty) _ownerCtrl.text = widget.initialUserData!['name'] ?? '';
    }

    _loadData();
  }

  @override
  void dispose() { _nameCtrl.dispose(); _phoneCtrl.dispose(); _personalPhoneCtrl.dispose(); _taxTypeCtrl.dispose(); _taxNumberCtrl.dispose(); _licenseTypeCtrl.dispose(); _licenseNumberCtrl.dispose(); _locCtrl.dispose(); _emailCtrl.dispose(); _ownerCtrl.dispose(); super.dispose(); }

  void _storeOriginalValues() {
    _originalValues = {
      'businessName': _nameCtrl.text,
      'businessPhone': _phoneCtrl.text,
      'personalPhone': _personalPhoneCtrl.text,
      'businessLocation': _locCtrl.text,
      'ownerName': _ownerCtrl.text,
      'taxType': _taxTypeCtrl.text,
      'taxNumber': _taxNumberCtrl.text,
      'licenseType': _licenseTypeCtrl.text,
      'licenseNumber': _licenseNumberCtrl.text,
      'currency': _selectedCurrency,
      'countryCode': _selectedCountryCode,
    };
  }

  void _checkForChanges() {
    final currentValues = {
      'businessName': _nameCtrl.text,
      'businessPhone': _phoneCtrl.text,
      'personalPhone': _personalPhoneCtrl.text,
      'businessLocation': _locCtrl.text,
      'ownerName': _ownerCtrl.text,
      'taxType': _taxTypeCtrl.text,
      'taxNumber': _taxNumberCtrl.text,
      'licenseType': _licenseTypeCtrl.text,
      'licenseNumber': _licenseNumberCtrl.text,
      'currency': _selectedCurrency,
      'countryCode': _selectedCountryCode,
    };

    bool changed = false;
    for (final key in currentValues.keys) {
      if (currentValues[key] != _originalValues[key]) {
        changed = true;
        break;
      }
    }

    if (changed != _hasChanges) {
      setState(() => _hasChanges = changed);
    }
  }

  void _setupChangeListeners() {
    _nameCtrl.addListener(_checkForChanges);
    _phoneCtrl.addListener(_checkForChanges);
    _personalPhoneCtrl.addListener(_checkForChanges);
    _locCtrl.addListener(_checkForChanges);
    _ownerCtrl.addListener(_checkForChanges);
    _taxTypeCtrl.addListener(_checkForChanges);
    _taxNumberCtrl.addListener(_checkForChanges);
    _licenseTypeCtrl.addListener(_checkForChanges);
    _licenseNumberCtrl.addListener(_checkForChanges);
  }

  Future<void> _saveAllFields() async {
    // Basic form validation (if you use _formKey around fields)
    if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
      CommonWidgets.showSnackBar(context, 'Please fix validation errors', bgColor: const Color(0xFFFF5252));
      return;
    }

    setState(() => _loading = true);

    try {
      final storeId = await FirestoreService().getCurrentStoreId();
      if (storeId == null) throw Exception('Store ID not found');

      // Build update payload (trimmed values)
      final rawPhone = _phoneCtrl.text.trim();
      // Store full phone (country code + number) if the number doesn't already start with +
      final fullPhone = rawPhone.startsWith('+') ? rawPhone : '$_selectedCountryCode$rawPhone';
      final updateData = <String, dynamic>{
        'businessName': _nameCtrl.text.trim(),
        'businessPhone': fullPhone,
        'businessPhoneCountryCode': _selectedCountryCode,
        'personalPhone': _personalPhoneCtrl.text.trim(),
        'businessLocation': _locCtrl.text.trim(),
        'ownerName': _ownerCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'currency': _selectedCurrency,
        // Combine tax/license fields if present
        'taxType': (_taxTypeCtrl.text.trim().isNotEmpty && _taxNumberCtrl.text.trim().isNotEmpty)
            ? '${_taxTypeCtrl.text.trim()} ${_taxNumberCtrl.text.trim()}'
            : (_taxNumberCtrl.text.trim().isNotEmpty ? _taxNumberCtrl.text.trim() : _taxTypeCtrl.text.trim()),
        'licenseNumber': (_licenseTypeCtrl.text.trim().isNotEmpty && _licenseNumberCtrl.text.trim().isNotEmpty)
            ? '${_licenseTypeCtrl.text.trim()} ${_licenseNumberCtrl.text.trim()}'
            : (_licenseNumberCtrl.text.trim().isNotEmpty ? _licenseNumberCtrl.text.trim() : _licenseTypeCtrl.text.trim()),
      };

      await FirebaseFirestore.instance.collection('store').doc(storeId).set(updateData, SetOptions(merge: true));
      await FirestoreService().notifyStoreDataChanged();

      // Reset change tracking on success
      if (mounted) {
        _storeOriginalValues();
        setState(() {
          _hasChanges = false;
        });
      }

      CommonWidgets.showSnackBar(context, 'All changes saved successfully!', bgColor: const Color(0xFF4CAF50));
    } catch (e) {
      CommonWidgets.showSnackBar(context, 'Error saving: ${e.toString()}', bgColor: const Color(0xFFFF5252));
      debugPrint('BusinessDetailsPage save error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  Future<void> _loadData() async {
    try {
      final store = await FirestoreService().getCurrentStoreDoc();
      final user = await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
      if (store != null && store.exists) {
        final data = store.data() as Map<String, dynamic>;
        setState(() {
          _nameCtrl.text = data['businessName'] ?? '';
          _phoneCtrl.text = data['businessPhone'] ?? '';
          _personalPhoneCtrl.text = data['personalPhone'] ?? '';

          // Split taxType into type and number (format: "Type Number")
          final taxType = data['taxType'] ?? data['gstin'] ?? '';
          if (taxType.isNotEmpty) {
            final taxParts = taxType.toString().split(' ');
            if (taxParts.length > 1) {
              _taxTypeCtrl.text = taxParts[0];
              _taxNumberCtrl.text = taxParts.sublist(1).join(' ');
            } else {
              _taxTypeCtrl.text = '';
              _taxNumberCtrl.text = taxType;
            }
          }

          // Split licenseNumber into type and number (format: "Type Number")
          final licenseNumber = data['licenseNumber'] ?? '';
          if (licenseNumber.isNotEmpty) {
            final licenseParts = licenseNumber.toString().split(' ');
            if (licenseParts.length > 1) {
              _licenseTypeCtrl.text = licenseParts[0];
              _licenseNumberCtrl.text = licenseParts.sublist(1).join(' ');
            } else {
              _licenseTypeCtrl.text = '';
              _licenseNumberCtrl.text = licenseNumber;
            }
          }

          _selectedCurrency = data['currency'] ?? 'INR';
          _locCtrl.text = data['businessLocation'] ?? '';
          _ownerCtrl.text = data['ownerName'] ?? '';
          _logoUrl = data['logoUrl'];
          // Load country code
          final savedCode = data['businessPhoneCountryCode'] as String?;
          if (savedCode != null && savedCode.isNotEmpty) {
            final match = _countryCodes.where((c) => c['code'] == savedCode).toList();
            if (match.isNotEmpty) {
              _selectedCountryCode = match.first['code']!;
              _selectedCountryFlag = match.first['flag']!;
            } else {
              _selectedCountryCode = savedCode;
            }
          }
          // Check premium status
          final plan = data['plan'] ?? 'free';
          _isPremium = plan.toString().toLowerCase() != 'free' && plan.toString().toLowerCase() != 'starter';
          // Load email from store, fallback to user email
          if (data['email'] != null && data['email'].toString().isNotEmpty) {
            _emailCtrl.text = data['email'];
          }
          _fetching = false;
        });
      }
      if (user.exists) {
        final uData = user.data() as Map<String, dynamic>;
        // Only set email from user if not already set from store
        if (_emailCtrl.text.isEmpty) {
          setState(() => _emailCtrl.text = uData['email'] ?? '');
        }
      }
      // Store original values after loading and setup change listeners
      _storeOriginalValues();
      _setupChangeListeners();
    } catch (e) { debugPrint(e.toString()); }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
    if (pickedFile != null) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Logo',
            toolbarColor: kPrimaryColor,
            toolbarWidgetColor: kWhite,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            aspectRatioPresets: [
              CropAspectRatioPreset.square, // Only square option
            ],
          ),
          IOSUiSettings(
            title: 'Crop Logo',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
            aspectRatioPresets: [
              CropAspectRatioPreset.square, // Only square option
            ],
          ),
        ],
      );
      if (croppedFile != null) {
        setState(() => _selectedImage = File(croppedFile.path));
        await _uploadImage();
      }
    }
  }

  Future<void> _uploadImage() async {
    if (_selectedImage == null) return;
    setState(() => _uploadingImage = true);
    try {
      final storeId = await FirestoreService().getCurrentStoreId();
      if (storeId == null) throw Exception('Identity Error');
      final storageRef = FirebaseStorage.instance.ref().child('store_logos').child('$storeId.jpg');
      final uploadTask = await storageRef.putFile(_selectedImage!);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      await FirebaseFirestore.instance.collection('store').doc(storeId).set({'logoUrl': downloadUrl}, SetOptions(merge: true));
      await FirestoreService().notifyStoreDataChanged();
      if (mounted) setState(() => _logoUrl = downloadUrl);
    } catch (e) { debugPrint(e.toString()); }
    finally { if (mounted) setState(() => _uploadingImage = false); }
  }

  void _showPremiumRequiredDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: kOrange.withAlpha(25), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.workspace_premium_rounded, color: kOrange, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Premium Feature', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, fontFamily: 'NotoSans')),
          ],
        ),
        content: const Text('Upgrade to Premium to customize your business logo.', style: TextStyle(color: kBlack54, fontFamily: 'Lato')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Later', style: TextStyle(color: kBlack54, fontWeight: FontWeight.w600))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (_) => SubscriptionPlanPage(uid: widget.uid, currentPlan: 'free'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Upgrade', style: TextStyle(color: kWhite, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showRemoveLogoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Remove Logo?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, fontFamily: 'NotoSans')),
        content: const Text('Are you sure you want to remove your business logo?', style: TextStyle(color: kBlack54, fontFamily: 'Lato')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: kBlack54, fontWeight: FontWeight.w600))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _removeLogo();
            },
            style: ElevatedButton.styleFrom(backgroundColor: kErrorColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Remove', style: TextStyle(color: kWhite, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _removeLogo() async {
    setState(() => _uploadingImage = true);
    try {
      final storeId = await FirestoreService().getCurrentStoreId();
      if (storeId == null) throw Exception('Identity Error');
      // Remove from Firestore
      await FirebaseFirestore.instance.collection('store').doc(storeId).update({'logoUrl': FieldValue.delete()});
      // Try to delete from Storage
      try {
        final storageRef = FirebaseStorage.instance.ref().child('store_logos').child('$storeId.jpg');
        await storageRef.delete();
      } catch (_) {}
      await FirestoreService().notifyStoreDataChanged();
      if (mounted) setState(() { _logoUrl = null; _selectedImage = null; });
      CommonWidgets.showSnackBar(context, 'Logo removed successfully', bgColor: kGoogleGreen);
    } catch (e) {
      debugPrint(e.toString());
      CommonWidgets.showSnackBar(context, 'Error removing logo', bgColor: kErrorColor);
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) { if (!didPop) { widget.onBack(); } },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
          title: const Text("Business Profile", style: TextStyle(color: kWhite, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'NotoSans')),
          backgroundColor: kPrimaryColor,
          centerTitle: true,
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: kWhite, size: 18), onPressed: () => widget.onBack()),
        ),
        body: _fetching ? const Center(child: CircularProgressIndicator()) : Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Center(child: Stack(children: [
                        Container(
                          width: 110, height: 110,
                          decoration: BoxDecoration(
                            color: kWhite,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: kGrey200, width: 2),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: _selectedImage != null
                                ? Image.file(_selectedImage!, fit: BoxFit.cover)
                                : _logoUrl != null && _logoUrl!.isNotEmpty
                                ? Image.network(_logoUrl!, fit: BoxFit.cover, key: ValueKey(_logoUrl))
                                : const Center(child: HeroIcon(HeroIcons.buildingStorefront, size: 40, color: kGrey400)),
                          ),
                        ),
                        // Edit/Add button with premium restriction
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _uploadingImage ? null : () {
                              if (!_isPremium) {
                                _showPremiumRequiredDialog();
                              } else {
                                _pickImage();
                              }
                            },
                            child: Container(
                              width: 34, height: 34,
                              decoration: BoxDecoration(
                                color: _isPremium ? kPrimaryColor : kGrey400,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: kWhite, width: 2),
                              ),
                              child: _uploadingImage
                                  ? const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(color: kWhite, strokeWidth: 2))
                                  : Stack(
                                      children: [
                                        const Center(child: Icon(Icons.camera_alt_rounded, color: kWhite, size: 16)),
                                        if (!_isPremium)
                                          Positioned(
                                            top: 0,
                                            right: 0,
                                            child: Container(
                                              width: 14, height: 14,
                                              decoration: BoxDecoration(
                                                color: kOrange,
                                                borderRadius: BorderRadius.circular(7),
                                              ),
                                              child: const Icon(Icons.workspace_premium_rounded, color: kWhite, size: 10),
                                            ),
                                          ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                        // Remove button - only show if there's a logo and user is premium
                        if ((_logoUrl != null && _logoUrl!.isNotEmpty) || _selectedImage != null)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _uploadingImage ? null : () {
                                if (!_isPremium) {
                                  _showPremiumRequiredDialog();
                                } else {
                                  _showRemoveLogoDialog();
                                }
                              },
                              child: Container(
                                width: 24, height: 24,
                                decoration: BoxDecoration(
                                  color: kErrorColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: kWhite, width: 2),
                                ),
                                child: const Icon(Icons.close_rounded, color: kWhite, size: 12),
                              ),
                            ),
                          ),
                      ])),
                      const SizedBox(height: 24),
                      _buildSectionLabel("Identity & Tax"),
                      _buildModernField("Business Name", _nameCtrl, Icons.store_rounded, isMandatory: true),
                      _buildBusinessPhoneWithCountryCode(),
                      _buildLocationField(),
                      _buildModernFieldWithHint("Tax Type", _taxTypeCtrl, Icons.receipt_long_rounded, hint: "VAT, GST, Sales Tax"),
                      _buildModernFieldWithHint("Tax Number", _taxNumberCtrl, Icons.numbers_rounded, hint: "Enter your tax identification number"),
                      _buildModernFieldWithHint("License Type", _licenseTypeCtrl, Icons.badge_rounded, hint: "Business License, Trade License"),
                      _buildModernFieldWithHint("License Number", _licenseNumberCtrl, Icons.numbers_rounded, hint: "Enter your license number"),
                      _buildCurrencyField(),
                      const SizedBox(height: 24),
                      _buildSectionLabel("Contact & Ownership"),
                      _buildModernField("Owner Name", _ownerCtrl, Icons.person_rounded),
                      _buildModernField("Personal Phone", _personalPhoneCtrl, Icons.phone_rounded, type: TextInputType.phone),
                      _buildModernField("Email Address", _emailCtrl, Icons.email_rounded, enabled: false),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
            // Bottom Update Button - only show when there are changes
            if (_hasChanges)
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: 16 + MediaQuery.of(context).padding.bottom,
                ),
                decoration: BoxDecoration(
                  color: kWhite,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(25),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _loading ? null : _saveAllFields,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: kWhite, strokeWidth: 2),
                        )
                      : const Text(
                          'Update',
                          style: TextStyle(
                            color: kWhite,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'NotoSans',
                          ),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12, left: 4),
    child: Text(title, style: const TextStyle(color: kBlack54, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontFamily: 'NotoSans')),
  );

  Widget _buildModernField(String label, TextEditingController ctrl, IconData icon, {bool enabled = true, TextInputType type = TextInputType.text, bool isMandatory = false}) {
    return _FocusAwareField(
      ctrl: ctrl,
      builder: (isFocused) {
        return ValueListenableBuilder<TextEditingValue>(
          valueListenable: ctrl,
          builder: (context, value, _) {
            final bool isFilled = value.text.isNotEmpty;
            // Colors: primary only when focused, neutral when unfocused
            final Color borderColor = isFocused ? kPrimaryColor : kGrey200;
            final double borderWidth = isFocused ? 2.0 : 1.0;
            final Color labelColor = isFocused ? kPrimaryColor : kBlack54;
            final Color iconColor = isFocused ? kPrimaryColor : kBlack54;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: TextFormField(
                controller: ctrl,
                enabled: enabled,
                keyboardType: type,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kBlack87, fontFamily: 'Lato'),
                decoration: InputDecoration(
                  labelText: isMandatory ? '$label *' : label,
                  labelStyle: TextStyle(color: labelColor, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'NotoSans'),
                  prefixIcon: Icon(icon, color: iconColor, size: 20),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FA),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderColor, width: borderWidth),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderColor, width: borderWidth),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kPrimaryColor, width: 2.0),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isFilled ? kGrey300 : kGrey200, width: 1.0),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kErrorColor),
                  ),
                  floatingLabelStyle: TextStyle(color: isFocused ? kPrimaryColor : kBlack54, fontWeight: FontWeight.w900),
                ),
                validator: isMandatory ? (v) => v == null || v.isEmpty ? '$label is required' : null : null,
                onChanged: (_) => _checkForChanges(),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModernFieldWithHint(String label, TextEditingController ctrl, IconData icon, {bool enabled = true, TextInputType type = TextInputType.text, bool isMandatory = false, String? hint}) {
    return _FocusAwareField(
      ctrl: ctrl,
      builder: (isFocused) {
        return ValueListenableBuilder<TextEditingValue>(
          valueListenable: ctrl,
          builder: (context, value, _) {
            final bool isFilled = value.text.isNotEmpty;
            // Colors: primary only when focused, neutral when unfocused
            final Color borderColor = isFocused ? kPrimaryColor : kGrey200;
            final double borderWidth = isFocused ? 2.0 : 1.0;
            final Color labelColor = isFocused ? kPrimaryColor : kBlack54;
            final Color iconColor = isFocused ? kPrimaryColor : kBlack54;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: TextFormField(
                controller: ctrl,
                enabled: enabled,
                keyboardType: type,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kBlack87, fontFamily: 'Lato'),
                decoration: InputDecoration(
                  labelText: isMandatory ? '$label *' : label,
                  hintText: hint,
                  hintStyle: const TextStyle(color: kGrey400, fontSize: 12, fontWeight: FontWeight.w400),
                  labelStyle: TextStyle(color: labelColor, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'NotoSans'),
                  prefixIcon: Icon(icon, color: iconColor, size: 20),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FA),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderColor, width: borderWidth),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderColor, width: borderWidth),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kPrimaryColor, width: 2.0),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isFilled ? kGrey300 : kGrey200, width: 1.0),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kErrorColor),
                  ),
                  floatingLabelStyle: TextStyle(color: isFocused ? kPrimaryColor : kBlack54, fontWeight: FontWeight.w900),
                ),
                validator: isMandatory ? (v) => v == null || v.isEmpty ? '$label is required' : null : null,
                onChanged: (_) => _checkForChanges(),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBusinessPhoneWithCountryCode() {
    return _FocusAwareField(
      ctrl: _phoneCtrl,
      builder: (isFocused) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9]'))],
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kBlack87, fontFamily: 'Lato'),
            decoration: InputDecoration(
              labelText: 'Business Contact Number *',
              labelStyle: TextStyle(color: isFocused ? kPrimaryColor : kBlack54, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'NotoSans'),
              prefixIcon: GestureDetector(
                onTap: _showCountryCodePickerProfile,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_selectedCountryFlag, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 3),
                      Text(
                        _selectedCountryCode,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isFocused ? kPrimaryColor : kBlack54,
                          fontFamily: 'NotoSans',
                        ),
                      ),
                      Icon(Icons.arrow_drop_down, size: 16, color: isFocused ? kPrimaryColor : kBlack54),
                    ],
                  ),
                ),
              ),
              filled: true,
              fillColor: const Color(0xFFF8F9FA),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isFocused ? kPrimaryColor : kGrey200, width: isFocused ? 2.0 : 1.0),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isFocused ? kPrimaryColor : kGrey200, width: isFocused ? 2.0 : 1.0),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kPrimaryColor, width: 2.0),
              ),
              floatingLabelStyle: TextStyle(color: isFocused ? kPrimaryColor : kBlack54, fontWeight: FontWeight.w900),
            ),
            validator: (v) => v == null || v.isEmpty ? 'Business Contact Number is required' : null,
            onChanged: (_) => _checkForChanges(),
          ),
        );
      },
    );
  }

  void _showCountryCodePickerProfile() {
    String searchQuery = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = _countryCodes.where((c) {
              if (searchQuery.isEmpty) return true;
              final q = searchQuery.toLowerCase();
              return c['name']!.toLowerCase().contains(q) || c['code']!.contains(q);
            }).toList();

            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Column(
                      children: [
                        const Text("Select Country Code",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: kBlack87, fontFamily: 'NotoSans')),
                        const SizedBox(height: 14),
                        TextField(
                          autofocus: false,
                          decoration: InputDecoration(
                            hintText: 'Search country...',
                            hintStyle: const TextStyle(fontSize: 13, color: kGrey400),
                            prefixIcon: const Icon(Icons.search_rounded, color: kPrimaryColor, size: 20),
                            filled: true,
                            fillColor: kGreyBg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onChanged: (v) => setModalState(() => searchQuery = v),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: kGrey100),
                      itemBuilder: (context, i) {
                        final c = filtered[i];
                        final isSelected = c['code'] == _selectedCountryCode;
                        return ListTile(
                          onTap: () {
                            setState(() {
                              _selectedCountryCode = c['code']!;
                              _selectedCountryFlag = c['flag']!;
                            });
                            _checkForChanges();
                            Navigator.pop(ctx);
                          },
                          leading: Text(c['flag']!, style: const TextStyle(fontSize: 24)),
                          title: Text(c['name']!,
                              style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  fontSize: 14,
                                  color: isSelected ? kPrimaryColor : kBlack87,
                                  fontFamily: 'Lato')),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(c['code']!,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected ? kPrimaryColor : kBlack54,
                                      fontFamily: 'NotoSans')),
                              if (isSelected)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Icon(Icons.check_circle_rounded, color: kPrimaryColor, size: 20),
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
        );
      },
    );
  }

  Widget _buildLocationField() {
    return _FocusAwareField(
      ctrl: _locCtrl,
      builder: (isFocused) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            controller: _locCtrl,
            keyboardType: TextInputType.streetAddress,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kBlack87, fontFamily: 'Lato'),
            maxLines: 2,
            minLines: 1,
            decoration: InputDecoration(
              labelText: "Address",
              labelStyle: TextStyle(color: isFocused ? kPrimaryColor : kBlack54, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'NotoSans'),
              prefixIcon: Icon(Icons.location_on_rounded, color: isFocused ? kPrimaryColor : kBlack54, size: 20),
              filled: true,
              fillColor: const Color(0xFFF8F9FA),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isFocused ? kPrimaryColor : kGrey200, width: isFocused ? 2.0 : 1.0),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isFocused ? kPrimaryColor : kGrey200, width: isFocused ? 2.0 : 1.0),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kPrimaryColor, width: 2.0),
              ),
              floatingLabelStyle: TextStyle(color: isFocused ? kPrimaryColor : kBlack54, fontWeight: FontWeight.w900),
            ),
            onChanged: (_) => _checkForChanges(),
          ),
        );
      },
    );
  }

  Widget _buildCurrencyField() {
    final sel = _currencies.firstWhere((c) => c['code'] == _selectedCurrency, orElse: () => _currencies[3]);
    final hasValue = _selectedCurrency.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: _showCurrencyPicker,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: hasValue ? kPrimaryColor : kGrey200, width: hasValue ? 1.5 : 1.0),
          ),
          child: Row(
            children: [
              Icon(Icons.currency_exchange_rounded, color: kPrimaryColor, size: 20),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Business Currency",
                      style: TextStyle(fontSize: 9, color: kBlack54, fontWeight: FontWeight.w900, letterSpacing: 0.5, fontFamily: 'NotoSans'),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${sel['symbol']} ${sel['code']} - ${sel['name']}",
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kBlack87, fontFamily: 'Lato'),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded, color: kBlack54, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  void _showCurrencyPicker() {
    String searchQuery = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredCurrencies = _currencies.where((currency) {
              if (searchQuery.isEmpty) return true;
              final query = searchQuery.toLowerCase();
              return currency['code']!.toLowerCase().contains(query) ||
                  currency['name']!.toLowerCase().contains(query) ||
                  currency['symbol']!.toLowerCase().contains(query);
            }).toList();

            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.75,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text("Select Currency",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: kBlack87, letterSpacing: 0.5, fontFamily: 'NotoSans')),
                    const SizedBox(height: 20),
                    TextField(
                      autofocus: false,
                      decoration: InputDecoration(
                        hintText: 'Search currency...',
                        hintStyle: const TextStyle(fontSize: 13, color: kGrey400),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: HeroIcon(HeroIcons.magnifyingGlass, color: kPrimaryColor, size: 20),
                        ),
                        filled: true,
                        fillColor: kGreyBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (value) => setModalState(() => searchQuery = value),
                    ),
                    const SizedBox(height: 16),
                    if (searchQuery.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${filteredCurrencies.length} ${filteredCurrencies.length == 1 ? 'currency' : 'currencies'} found',
                            style: const TextStyle(fontSize: 11, color: kBlack54, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    Expanded(
                      child: filteredCurrencies.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  HeroIcon(HeroIcons.magnifyingGlass, size: 48, color: kGrey400),
                                  SizedBox(height: 12),
                                  Text('No currencies found', style: TextStyle(color: kGrey400, fontSize: 14)),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: filteredCurrencies.length,
                              separatorBuilder: (_, __) => const Divider(height: 1, color: kGrey100),
                              itemBuilder: (context, i) {
                                final c = filteredCurrencies[i];
                                final isSelected = c['code'] == _selectedCurrency;
                                return ListTile(
                                  onTap: () {
                                    setState(() => _selectedCurrency = c['code']!);
                                    _checkForChanges();
                                    Navigator.pop(ctx);
                                  },
                                  contentPadding: EdgeInsets.zero,
                                  leading: Container(
                                    width: 40, height: 40,
                                    decoration: BoxDecoration(
                                      color: isSelected ? kPrimaryColor.withAlpha(25) : kGreyBg,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: Text(c['symbol']!,
                                          style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: isSelected ? kPrimaryColor : kBlack54)),
                                    ),
                                  ),
                                  title: Text(c['name']!,
                                      style: TextStyle(
                                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                          fontSize: 14,
                                          color: isSelected ? kPrimaryColor : kBlack87,
                                          fontFamily: 'Lato')),
                                  subtitle: Text(c['code']!,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: isSelected ? kPrimaryColor : kBlack54,
                                          fontWeight: FontWeight.w500)),
                                  trailing: isSelected
                                      ? const Icon(Icons.check_circle_rounded, color: kPrimaryColor, size: 24)
                                      : null,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ==========================================
// BILL & PRINT SETTINGS PAGE
// ==========================================
class BillPrintSettingsPage extends StatefulWidget {
  final VoidCallback onBack;
  const BillPrintSettingsPage({super.key, required this.onBack});
  @override
  State<BillPrintSettingsPage> createState() => _BillPrintSettingsPageState();
}

class _BillPrintSettingsPageState extends State<BillPrintSettingsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Thermal Printer Settings
  String _thermalPageSize = '58mm';
  bool _thermalShowHeader = true;
  bool _thermalShowLogo = true;
  bool _thermalShowCustomerInfo = true;
  bool _thermalShowItemTable = true;
  bool _thermalShowTotalItemQuantity = true;
  bool _thermalShowTaxDetails = true;
  bool _thermalShowYouSaved = true;
  bool _thermalShowDescription = false;
  bool _thermalShowDelivery = false;
  bool _thermalShowLicense = true;
  String _thermalSaleInvoiceText = 'Thank you for your purchase!';
  bool _thermalShowTaxColumnInTable = false; // Tax column removed by default for thermal

  // A4 Printer Settings
  bool _a4ShowHeader = true;
  bool _a4ShowLogo = true;
  bool _a4ShowCustomerInfo = true;
  bool _a4ShowItemTable = true;
  bool _a4ShowTotalItemQuantity = true;
  bool _a4ShowTaxDetails = true;
  bool _a4ShowYouSaved = true;
  bool _a4ShowDescription = false;
  bool _a4ShowDelivery = false;
  bool _a4ShowLicense = true;
  String _a4SaleInvoiceText = 'Thank you for your purchase!';
  bool _a4ShowSignature = false;
  String _a4EstimationText = '';
  String _a4DeliveryChallanText = '';
  bool _a4ShowTaxColumnInTable = true;
  String _a4ColorTheme = 'blue'; // Color theme for A4

  // Document Numbering Settings
  String _selectedDocType = 'Invoice';
  final List<String> _docTypes = ['Invoice', 'Quotation/Estimation', 'Purchase', 'Expense', 'Payment Receipt'];

  // Prefix and number controllers for each document type
  final _invoicePrefixCtrl = TextEditingController();
  final _invoiceNumberCtrl = TextEditingController();
  final _quotationPrefixCtrl = TextEditingController();
  final _quotationNumberCtrl = TextEditingController();
  final _purchasePrefixCtrl = TextEditingController();
  final _purchaseNumberCtrl = TextEditingController();
  final _expensePrefixCtrl = TextEditingController();
  final _expenseNumberCtrl = TextEditingController();
  final _paymentReceiptPrefixCtrl = TextEditingController();
  final _paymentReceiptNumberCtrl = TextEditingController();

  // Old series lists
  List<Map<String, dynamic>> _oldInvoiceSeries = [];
  List<Map<String, dynamic>> _oldQuotationSeries = [];
  List<Map<String, dynamic>> _oldPurchaseSeries = [];
  List<Map<String, dynamic>> _oldExpenseSeries = [];
  List<Map<String, dynamic>> _oldPaymentReceiptSeries = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSettings();
    _loadDocumentNumberSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _invoicePrefixCtrl.dispose();
    _invoiceNumberCtrl.dispose();
    _quotationPrefixCtrl.dispose();
    _quotationNumberCtrl.dispose();
    _purchasePrefixCtrl.dispose();
    _purchaseNumberCtrl.dispose();
    _expensePrefixCtrl.dispose();
    _expenseNumberCtrl.dispose();
    _paymentReceiptPrefixCtrl.dispose();
    _paymentReceiptNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // Thermal settings
      _thermalPageSize = prefs.getString('thermal_page_size') ?? '58mm';
      _thermalShowHeader = prefs.getBool('thermal_show_header') ?? true;
      _thermalShowLogo = prefs.getBool('thermal_show_logo') ?? true;
      _thermalShowCustomerInfo = prefs.getBool('thermal_show_customer_info') ?? true;
      _thermalShowItemTable = prefs.getBool('thermal_show_item_table') ?? true;
      _thermalShowTotalItemQuantity = prefs.getBool('thermal_show_total_item_quantity') ?? true;
      _thermalShowTaxDetails = prefs.getBool('thermal_show_tax_details') ?? true;
      _thermalShowYouSaved = prefs.getBool('thermal_show_you_saved') ?? true;
      _thermalShowDescription = prefs.getBool('thermal_show_description') ?? false;
      _thermalShowDelivery = prefs.getBool('thermal_show_delivery') ?? false;
      _thermalShowLicense = prefs.getBool('thermal_show_license') ?? true;
      _thermalSaleInvoiceText = prefs.getString('thermal_sale_invoice_text') ?? 'Thank you for your purchase!';
      _thermalShowTaxColumnInTable = prefs.getBool('thermal_show_tax_column') ?? false;

      // A4 settings
      _a4ShowHeader = prefs.getBool('a4_show_header') ?? true;
      _a4ShowLogo = prefs.getBool('a4_show_logo') ?? true;
      _a4ShowCustomerInfo = prefs.getBool('a4_show_customer_info') ?? true;
      _a4ShowItemTable = prefs.getBool('a4_show_item_table') ?? true;
      _a4ShowTotalItemQuantity = prefs.getBool('a4_show_total_item_quantity') ?? true;
      _a4ShowTaxDetails = prefs.getBool('a4_show_tax_details') ?? true;
      _a4ShowYouSaved = prefs.getBool('a4_show_you_saved') ?? true;
      _a4ShowDescription = prefs.getBool('a4_show_description') ?? false;
      _a4ShowDelivery = prefs.getBool('a4_show_delivery') ?? false;
      _a4ShowLicense = prefs.getBool('a4_show_license') ?? true;
      _a4SaleInvoiceText = prefs.getString('a4_sale_invoice_text') ?? 'Thank you for your purchase!';
      _a4ShowSignature = prefs.getBool('a4_show_signature') ?? false;
      _a4EstimationText = prefs.getString('a4_estimation_text') ?? '';
      _a4DeliveryChallanText = prefs.getString('a4_delivery_challan_text') ?? '';
      _a4ShowTaxColumnInTable = prefs.getBool('a4_show_tax_column') ?? true;
      _a4ColorTheme = prefs.getString('a4_color_theme') ?? 'blue';
    });
  }

  Future<void> _loadDocumentNumberSettings() async {
    try {
      final storeDoc = await FirestoreService().getCurrentStoreDoc();
      if (storeDoc != null && storeDoc.exists) {
        final data = storeDoc.data() as Map<String, dynamic>?;
        if (data != null) {
          setState(() {
            // Invoice
            _invoicePrefixCtrl.text = data['invoicePrefix']?.toString() ?? '';
            _invoiceNumberCtrl.text = (data['nextInvoiceNumber'] ?? 100001).toString();
            _oldInvoiceSeries = List<Map<String, dynamic>>.from(data['oldInvoiceSeries'] ?? []);

            // Quotation / Estimation (combined)
            _quotationPrefixCtrl.text = data['quotationPrefix']?.toString() ?? '';
            _quotationNumberCtrl.text = (data['nextQuotationNumber'] ?? 100001).toString();
            _oldQuotationSeries = List<Map<String, dynamic>>.from(data['oldQuotationSeries'] ?? []);


            // Purchase
            _purchasePrefixCtrl.text = data['purchasePrefix']?.toString() ?? '';
            _purchaseNumberCtrl.text = (data['nextPurchaseNumber'] ?? 100001).toString();
            _oldPurchaseSeries = List<Map<String, dynamic>>.from(data['oldPurchaseSeries'] ?? []);

            // Expense
            _expensePrefixCtrl.text = data['expensePrefix']?.toString() ?? '';
            _expenseNumberCtrl.text = (data['nextExpenseNumber'] ?? 100001).toString();
            _oldExpenseSeries = List<Map<String, dynamic>>.from(data['oldExpenseSeries'] ?? []);

            // Payment Receipt
            _paymentReceiptPrefixCtrl.text = data['paymentReceiptPrefix']?.toString() ?? 'PR';
            _paymentReceiptNumberCtrl.text = (data['nextPaymentReceiptNumber'] ?? 100001).toString();
            _oldPaymentReceiptSeries = List<Map<String, dynamic>>.from(data['oldPaymentReceiptSeries'] ?? []);
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading document number settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    // Thermal settings
    await prefs.setString('thermal_page_size', _thermalPageSize);
    await prefs.setBool('thermal_show_header', _thermalShowHeader);
    await prefs.setBool('thermal_show_logo', _thermalShowLogo);
    await prefs.setBool('thermal_show_customer_info', _thermalShowCustomerInfo);
    await prefs.setBool('thermal_show_item_table', _thermalShowItemTable);
    await prefs.setBool('thermal_show_total_item_quantity', _thermalShowTotalItemQuantity);
    await prefs.setBool('thermal_show_tax_details', _thermalShowTaxDetails);
    await prefs.setBool('thermal_show_you_saved', _thermalShowYouSaved);
    await prefs.setBool('thermal_show_description', _thermalShowDescription);
    await prefs.setBool('thermal_show_delivery', _thermalShowDelivery);
    await prefs.setBool('thermal_show_license', _thermalShowLicense);
    await prefs.setString('thermal_sale_invoice_text', _thermalSaleInvoiceText);
    await prefs.setBool('thermal_show_tax_column', _thermalShowTaxColumnInTable);

    // A4 settings
    await prefs.setBool('a4_show_header', _a4ShowHeader);
    await prefs.setBool('a4_show_logo', _a4ShowLogo);
    await prefs.setBool('a4_show_customer_info', _a4ShowCustomerInfo);
    await prefs.setBool('a4_show_item_table', _a4ShowItemTable);
    await prefs.setBool('a4_show_total_item_quantity', _a4ShowTotalItemQuantity);
    await prefs.setBool('a4_show_tax_details', _a4ShowTaxDetails);
    await prefs.setBool('a4_show_you_saved', _a4ShowYouSaved);
    await prefs.setBool('a4_show_description', _a4ShowDescription);
    await prefs.setBool('a4_show_delivery', _a4ShowDelivery);
    await prefs.setBool('a4_show_license', _a4ShowLicense);
    await prefs.setString('a4_sale_invoice_text', _a4SaleInvoiceText);
    await prefs.setBool('a4_show_signature', _a4ShowSignature);
    await prefs.setString('a4_estimation_text', _a4EstimationText);
    await prefs.setString('a4_delivery_challan_text', _a4DeliveryChallanText);
    await prefs.setBool('a4_show_tax_column', _a4ShowTaxColumnInTable);
    await prefs.setString('a4_color_theme', _a4ColorTheme);

    // Also save for invoice page compatibility
    await prefs.setBool('receipt_show_logo', _tabController.index == 0 ? _thermalShowLogo : _a4ShowLogo);
    await prefs.setBool('receipt_show_customer_details', _tabController.index == 0 ? _thermalShowCustomerInfo : _a4ShowCustomerInfo);
    await prefs.setBool('receipt_show_total_items', _tabController.index == 0 ? _thermalShowTotalItemQuantity : _a4ShowTotalItemQuantity);
    await prefs.setBool('receipt_show_save_amount', _tabController.index == 0 ? _thermalShowYouSaved : _a4ShowYouSaved);
    await prefs.setString('receipt_footer_description', _tabController.index == 0 ? _thermalSaleInvoiceText : _a4SaleInvoiceText);
  }

  Future<void> _saveDocumentNumberSettings() async {
    try {
      final storeId = await FirestoreService().getCurrentStoreId();
      if (storeId == null) return;

      // Get current data to check for existing series
      final storeDoc = await FirestoreService().getCurrentStoreDoc();
      final currentData = storeDoc?.data() as Map<String, dynamic>? ?? {};

      final updateData = <String, dynamic>{};
      final newPrefix = _getActivePrefix().trim();
      final newNumber = _getActiveNumber();

      switch (_selectedDocType) {
        case 'Invoice':
          final currentPrefix = currentData['invoicePrefix']?.toString() ?? '';
          final currentNumber = currentData['nextInvoiceNumber'] ?? 100001;

          // Always save to history if the values are different from new values
          if (currentPrefix != newPrefix || currentNumber != newNumber) {
            final oldSeries = List<Map<String, dynamic>>.from(currentData['oldInvoiceSeries'] ?? []);
            // Check if this series already exists in history
            final existsInHistory = oldSeries.any((s) =>
              (s['prefix']?.toString() ?? '') == (currentPrefix.isEmpty ? '--' : currentPrefix) &&
              s['number'] == currentNumber);
            if (!existsInHistory && (currentPrefix.isNotEmpty || currentNumber != 100001)) {
              oldSeries.add({'prefix': currentPrefix.isEmpty ? '--' : currentPrefix, 'number': currentNumber});
              updateData['oldInvoiceSeries'] = oldSeries;
              // Update local state immediately
              setState(() => _oldInvoiceSeries = oldSeries);
            }
          }
          updateData['invoicePrefix'] = newPrefix;
          updateData['nextInvoiceNumber'] = newNumber;
          break;

        case 'Quotation/Estimation':
          final currentPrefix = currentData['quotationPrefix']?.toString() ?? '';
          final currentNumber = currentData['nextQuotationNumber'] ?? 100001;

          if (currentPrefix != newPrefix || currentNumber != newNumber) {
            final oldSeries = List<Map<String, dynamic>>.from(currentData['oldQuotationSeries'] ?? []);
            final existsInHistory = oldSeries.any((s) =>
              (s['prefix']?.toString() ?? '') == (currentPrefix.isEmpty ? '--' : currentPrefix) &&
              s['number'] == currentNumber);
            if (!existsInHistory && (currentPrefix.isNotEmpty || currentNumber != 100001)) {
              oldSeries.add({'prefix': currentPrefix.isEmpty ? '--' : currentPrefix, 'number': currentNumber});
              updateData['oldQuotationSeries'] = oldSeries;
              setState(() => _oldQuotationSeries = oldSeries);
            }
          }
          updateData['quotationPrefix'] = newPrefix;
          updateData['nextQuotationNumber'] = newNumber;
          break;

        case 'Purchase':
          final currentPrefix = currentData['purchasePrefix']?.toString() ?? '';
          final currentNumber = currentData['nextPurchaseNumber'] ?? 100001;

          if (currentPrefix != newPrefix || currentNumber != newNumber) {
            final oldSeries = List<Map<String, dynamic>>.from(currentData['oldPurchaseSeries'] ?? []);
            final existsInHistory = oldSeries.any((s) =>
              (s['prefix']?.toString() ?? '') == (currentPrefix.isEmpty ? '--' : currentPrefix) &&
              s['number'] == currentNumber);
            if (!existsInHistory && (currentPrefix.isNotEmpty || currentNumber != 100001)) {
              oldSeries.add({'prefix': currentPrefix.isEmpty ? '--' : currentPrefix, 'number': currentNumber});
              updateData['oldPurchaseSeries'] = oldSeries;
              setState(() => _oldPurchaseSeries = oldSeries);
            }
          }
          updateData['purchasePrefix'] = newPrefix;
          updateData['nextPurchaseNumber'] = newNumber;
          break;

        case 'Expense':
          final currentPrefix = currentData['expensePrefix']?.toString() ?? '';
          final currentNumber = currentData['nextExpenseNumber'] ?? 100001;

          if (currentPrefix != newPrefix || currentNumber != newNumber) {
            final oldSeries = List<Map<String, dynamic>>.from(currentData['oldExpenseSeries'] ?? []);
            final existsInHistory = oldSeries.any((s) =>
              (s['prefix']?.toString() ?? '') == (currentPrefix.isEmpty ? '--' : currentPrefix) &&
              s['number'] == currentNumber);
            if (!existsInHistory && (currentPrefix.isNotEmpty || currentNumber != 100001)) {
              oldSeries.add({'prefix': currentPrefix.isEmpty ? '--' : currentPrefix, 'number': currentNumber});
              updateData['oldExpenseSeries'] = oldSeries;
              setState(() => _oldExpenseSeries = oldSeries);
            }
          }
          updateData['expensePrefix'] = newPrefix;
          updateData['nextExpenseNumber'] = newNumber;
          break;

        case 'Payment Receipt':
          final currentPrefix = currentData['paymentReceiptPrefix']?.toString() ?? 'PR';
          final currentNumber = currentData['nextPaymentReceiptNumber'] ?? 100001;

          if (currentPrefix != newPrefix || currentNumber != newNumber) {
            final oldSeries = List<Map<String, dynamic>>.from(currentData['oldPaymentReceiptSeries'] ?? []);
            final existsInHistory = oldSeries.any((s) =>
              (s['prefix']?.toString() ?? '') == (currentPrefix.isEmpty ? '--' : currentPrefix) &&
              s['number'] == currentNumber);
            if (!existsInHistory && (currentPrefix.isNotEmpty || currentNumber != 100001)) {
              oldSeries.add({'prefix': currentPrefix.isEmpty ? '--' : currentPrefix, 'number': currentNumber});
              updateData['oldPaymentReceiptSeries'] = oldSeries;
              setState(() => _oldPaymentReceiptSeries = oldSeries);
            }
          }
          updateData['paymentReceiptPrefix'] = newPrefix;
          updateData['nextPaymentReceiptNumber'] = newNumber;
          break;
      }

      await FirebaseFirestore.instance.collection('store').doc(storeId).update(updateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document numbering updated!'), backgroundColor: kGoogleGreen, behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      debugPrint('Error saving document number settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: kErrorColor, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  String _getActivePrefix() {
    switch (_selectedDocType) {
      case 'Invoice': return _invoicePrefixCtrl.text;
      case 'Quotation/Estimation': return _quotationPrefixCtrl.text;
      case 'Purchase': return _purchasePrefixCtrl.text;
      case 'Expense': return _expensePrefixCtrl.text;
      case 'Payment Receipt': return _paymentReceiptPrefixCtrl.text;
      default: return '';
    }
  }

  int _getActiveNumber() {
    switch (_selectedDocType) {
      case 'Invoice': return int.tryParse(_invoiceNumberCtrl.text) ?? 100001;
      case 'Quotation/Estimation': return int.tryParse(_quotationNumberCtrl.text) ?? 100001;
      case 'Purchase': return int.tryParse(_purchaseNumberCtrl.text) ?? 100001;
      case 'Expense': return int.tryParse(_expenseNumberCtrl.text) ?? 100001;
      case 'Payment Receipt': return int.tryParse(_paymentReceiptNumberCtrl.text) ?? 100001;
      default: return 100001;
    }
  }

  Future<void> _reuseSeries(String docType, Map<String, dynamic> series) async {
    try {
      final prefix = series['prefix']?.toString() ?? '';
      final number = series['number'] ?? 100001;

      switch (docType) {
        case 'Invoice':
          setState(() {
            _invoicePrefixCtrl.text = prefix == '--' ? '' : prefix;
            _invoiceNumberCtrl.text = number.toString();
          });
          break;
        case 'Quotation/Estimation':
          setState(() {
            _quotationPrefixCtrl.text = prefix == '--' ? '' : prefix;
            _quotationNumberCtrl.text = number.toString();
          });
          break;
        case 'Purchase':
          setState(() {
            _purchasePrefixCtrl.text = prefix == '--' ? '' : prefix;
            _purchaseNumberCtrl.text = number.toString();
          });
          break;
        case 'Expense':
          setState(() {
            _expensePrefixCtrl.text = prefix == '--' ? '' : prefix;
            _expenseNumberCtrl.text = number.toString();
          });
          break;

        case 'Payment Receipt':
          setState(() {
            _paymentReceiptPrefixCtrl.text = prefix == '--' ? '' : prefix;
            _paymentReceiptNumberCtrl.text = number.toString();
          });
          break;
      }
    } catch (e) {
      debugPrint('Error reusing series: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) { if (!didPop) widget.onBack(); },
      child: Scaffold(
        backgroundColor: kGreyBg,
        appBar: AppBar(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))),
          title: const Text('Bill Receipt Settings', style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 16, fontFamily: 'NotoSans')),
          backgroundColor: kPrimaryColor,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: kWhite, size: 18), onPressed: widget.onBack),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: Container(
              color: kWhite,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.3),
                  tabs: const [
                    Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.print_rounded, size: 14), SizedBox(width: 4), Text('Thermal')])),
                    Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.picture_as_pdf_rounded, size: 14), SizedBox(width: 4), Text('A4/PDF')])),
                    Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.tag_rounded, size: 14), SizedBox(width: 4), Text('DOC NO.')])),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabController,

          children: [
            _buildThermalTab(),
            _buildA4Tab(),
            _buildDocumentNumberingTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildThermalTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildInfoCard('Thermal Receipt', 'Small paper print for POS printers', Icons.print_rounded),
        const SizedBox(height: 16),
        _buildSectionLabel('Identity & Branding'),
        _SettingsGroup(children: [
          _SwitchTile('Show Header', _thermalShowHeader, (v) { setState(() => _thermalShowHeader = v); _saveSettings(); }),
          _SwitchTile('Show Logo', _thermalShowLogo, (v) { setState(() => _thermalShowLogo = v); _saveSettings(); }),
          _SwitchTile('Show Customer Information', _thermalShowCustomerInfo, (v) { setState(() => _thermalShowCustomerInfo = v); _saveSettings(); }),
          _SwitchTile('Show Item Table', _thermalShowItemTable, (v) { setState(() => _thermalShowItemTable = v); _saveSettings(); }),
          _SwitchTile('Show License Number', _thermalShowLicense, (v) { setState(() => _thermalShowLicense = v); _saveSettings(); }, showDivider: false),
        ]),
        const SizedBox(height: 16),
        _buildSectionLabel('Totals & Taxes'),
        _SettingsGroup(children: [
          _SwitchTile('Total Item Quantity', _thermalShowTotalItemQuantity, (v) { setState(() => _thermalShowTotalItemQuantity = v); _saveSettings(); }),
          _SwitchTile('Tax Details', _thermalShowTaxDetails, (v) { setState(() => _thermalShowTaxDetails = v); _saveSettings(); }),
          _SwitchTile('You Saved', _thermalShowYouSaved, (v) { setState(() => _thermalShowYouSaved = v); _saveSettings(); }, showDivider: false),
        ]),
        const SizedBox(height: 16),
        _buildSectionLabel('Footer'),
        _buildTextFieldSection('Sale Invoice Text', _thermalSaleInvoiceText, (v) { _thermalSaleInvoiceText = v; _saveSettings(); }),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildA4Tab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildInfoCard('A4 / Pdf Invoice', 'Full-page invoice for print or sharing', Icons.picture_as_pdf_rounded),
        const SizedBox(height: 16),
        // Color Theme Selector
        _buildSectionLabel('Color Theme'),
        Container(
          decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Invoice Color', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, fontFamily: 'NotoSans')),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildColorOption('gold', const Color(0xFFC9A441)),
                  _buildColorOption('lavender', const Color(0xFF9A96D8)),
                  _buildColorOption('green', const Color(0xFF1CB466)),
                  _buildColorOption('brown', const Color(0xFFAF4700)),
                  _buildColorOption('blue', const Color(0xFF6488E0)),
                  _buildColorOption('peach', const Color(0xFFFAA774)),
                  _buildColorOption('red', const Color(0xFFDB4747)),
                  _buildColorOption('purple', const Color(0xFF7A1FA2)),
                  _buildColorOption('orange', const Color(0xFFF45715)),
                  _buildColorOption('pink', const Color(0xFFE2A9F1)),
                  _buildColorOption('copper', const Color(0xFFB36A22)),
                  _buildColorOption('black', const Color(0xFF000000)),
                  _buildColorOption('navy', const Color(0xFF2F6798)),
                  _buildColorOption('forest', const Color(0xFF4F6F1F)),
                ],
              ),
              const SizedBox(height: 16),
              // A4 Preview
              _buildA4Preview(_getThemeColor(_a4ColorTheme)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionLabel('Identity & Branding'),
        _SettingsGroup(children: [
          _SwitchTile('Show Header', _a4ShowHeader, (v) { setState(() => _a4ShowHeader = v); _saveSettings(); }),
          _SwitchTile('Show Logo', _a4ShowLogo, (v) { setState(() => _a4ShowLogo = v); _saveSettings(); }),
          _SwitchTile('Show Customer Information', _a4ShowCustomerInfo, (v) { setState(() => _a4ShowCustomerInfo = v); _saveSettings(); }),
          _SwitchTile('Show Item Table', _a4ShowItemTable, (v) { setState(() => _a4ShowItemTable = v); _saveSettings(); }),
          _SwitchTile('Show Tax Column in Table', _a4ShowTaxColumnInTable, (v) { setState(() => _a4ShowTaxColumnInTable = v); _saveSettings(); }),
          _SwitchTile('Show License Number', _a4ShowLicense, (v) { setState(() => _a4ShowLicense = v); _saveSettings(); }, showDivider: false),
        ]),
        const SizedBox(height: 16),
        _buildSectionLabel('Totals & Taxes'),
        _SettingsGroup(children: [
          _SwitchTile('Total Item Quantity', _a4ShowTotalItemQuantity, (v) { setState(() => _a4ShowTotalItemQuantity = v); _saveSettings(); }),
          _SwitchTile('Tax Details', _a4ShowTaxDetails, (v) { setState(() => _a4ShowTaxDetails = v); _saveSettings(); }),
          _SwitchTile('You Saved', _a4ShowYouSaved, (v) { setState(() => _a4ShowYouSaved = v); _saveSettings(); }, showDivider: false),
        ]),
        const SizedBox(height: 16),
        _buildSectionLabel('Footer'),
        _SettingsGroup(children: [_SwitchTile('Print Signature', _a4ShowSignature, (v) { setState(() => _a4ShowSignature = v); _saveSettings(); }, showDivider: false)]),
        const SizedBox(height: 16),
        _buildTextFieldSection('Sale Invoice Text', _a4SaleInvoiceText, (v) { _a4SaleInvoiceText = v; _saveSettings(); }),
        const SizedBox(height: 12),
        _buildTextFieldSection('Estimation / Quotation Text', _a4EstimationText, (v) { _a4EstimationText = v; _saveSettings(); }),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildDocumentNumberingTab() {
    // Get current prefix and number based on selected doc type
    TextEditingController prefixCtrl;
    TextEditingController numberCtrl;
    List<Map<String, dynamic>> oldSeries;
    String docLabel;
    Color docColor;

    switch (_selectedDocType) {
      case 'Invoice':
        prefixCtrl = _invoicePrefixCtrl;
        numberCtrl = _invoiceNumberCtrl;
        oldSeries = _oldInvoiceSeries;
        docLabel = 'Invoice';
        docColor = kPrimaryColor;
        break;
      case 'Quotation/Estimation':
        prefixCtrl = _quotationPrefixCtrl;
        numberCtrl = _quotationNumberCtrl;
        oldSeries = _oldQuotationSeries;
        docLabel = 'Quotation';
        docColor = Colors.orange;
        break;
      case 'Purchase':
        prefixCtrl = _purchasePrefixCtrl;
        numberCtrl = _purchaseNumberCtrl;
        oldSeries = _oldPurchaseSeries;
        docLabel = 'Purchase';
        docColor = Colors.purple;
        break;
      case 'Expense':
        prefixCtrl = _expensePrefixCtrl;
        numberCtrl = _expenseNumberCtrl;
        oldSeries = _oldExpenseSeries;
        docLabel = 'Expense';
        docColor = Colors.teal;
        break;
      case 'Payment Receipt':
        prefixCtrl = _paymentReceiptPrefixCtrl;
        numberCtrl = _paymentReceiptNumberCtrl;
        oldSeries = _oldPaymentReceiptSeries;
        docLabel = 'Payment Receipt';
        docColor = Colors.green;
        break;
      default:
        prefixCtrl = _invoicePrefixCtrl;
        numberCtrl = _invoiceNumberCtrl;
        oldSeries = _oldInvoiceSeries;
        docLabel = 'Invoice';
        docColor = kPrimaryColor;
    }

    final previewPrefix = prefixCtrl.text.isEmpty ? '' : prefixCtrl.text;
    final previewNumber = numberCtrl.text.isEmpty ? '100001' : numberCtrl.text;
    final previewFull = previewPrefix.isEmpty ? previewNumber : '$previewPrefix$previewNumber';

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Document Type Chips (compact)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _docTypes.map((type) {
              final isSelected = _selectedDocType == type;
              Color chipColor = type == 'Invoice' ? kPrimaryColor : type == 'Quotation/Estimation' ? Colors.orange : type == 'Purchase' ? Colors.purple : type == 'Expense' ? Colors.teal : Colors.green;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDocType = type),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? chipColor : kWhite,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? chipColor : kGrey200, width: isSelected ? 1.5 : 1),
                      boxShadow: isSelected ? [BoxShadow(color: chipColor.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))] : [],
                    ),
                    child: Text(type == 'Quotation/Estimation' ? 'Quotation' : type, style: TextStyle(fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600, fontSize: 12, fontFamily: 'NotoSans', color: isSelected ? kWhite : chipColor)),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        // Preview Card (compact)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: docColor, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Next $docLabel', style: TextStyle(fontSize: 11, color: kWhite.withAlpha(200))),
                    const SizedBox(height: 2),
                    Text(previewFull, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: kWhite, letterSpacing: 0.5)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: kWhite.withAlpha(40), borderRadius: BorderRadius.circular(8)),
                child: Text('Preview', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kWhite.withAlpha(220))),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Input Fields (compact)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Prefix', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kBlack54)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: prefixCtrl,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                          ],
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          decoration: InputDecoration(
                            hintText: 'DD',
                            hintStyle: const TextStyle(color: kGrey400, fontSize: 13),
                            
                            
                            isDense: true,
                            
                            
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Starting Number', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kBlack54)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: numberCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          decoration: InputDecoration(
                            hintText: '505',
                            hintStyle: const TextStyle(color: kGrey400, fontSize: 13),
                            
                            
                            isDense: true,
                            
                            
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveDocumentNumberSettings,
                  style: ElevatedButton.styleFrom(backgroundColor: docColor, foregroundColor: kWhite, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
                  child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),

        // Old Series (compact)
        if (oldSeries.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('History', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: docColor)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: docColor.withAlpha(20), borderRadius: BorderRadius.circular(10)),
                      child: Text('${oldSeries.length}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: docColor)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...oldSeries.map((series) {
                  final prefix = series['prefix']?.toString() ?? '--';
                  final number = series['number']?.toString() ?? '--';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        Text(prefix == '--' ? 'No Prefix' : prefix, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        const SizedBox(width: 8),
                        Text('• $number', style: const TextStyle(fontSize: 12, color: kBlack54)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => _reuseSeries(_selectedDocType, series),
                          child: Text('Reuse', style: TextStyle(color: docColor, fontWeight: FontWeight.w700, fontSize: 12)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildInfoCard(String title, String subtitle, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kPrimaryColor.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kPrimaryColor.withAlpha(40)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: kPrimaryColor.withAlpha(25), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: kPrimaryColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, fontFamily: 'NotoSans', color: kBlack87)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: kBlack54, fontWeight: FontWeight.w500, fontFamily: 'Lato')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageSizeOption(String label, String value, bool isSelected, bool isThermal) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (isThermal) _thermalPageSize = value;
          });
          _saveSettings();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(color: isSelected ? kPrimaryColor.withAlpha(25) : kGreyBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: isSelected ? kPrimaryColor : kGrey300)),
          child: Column(
            children: [
              Icon(Icons.receipt_long_rounded, color: isSelected ? kWhite : kBlack54, size: 24),
              const SizedBox(height: 6),
              Text("58mm", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: isSelected ? kWhite : kBlack87)),
              Text("2 inch", style: TextStyle(fontSize: 10, color: isSelected ? kWhite.withOpacity(0.8) : kBlack54)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextFieldSection(String label, String value, Function(String) onChanged) {
    final controller = TextEditingController(text: value);
    return Container(
      decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, fontFamily: 'NotoSans')),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: onChanged,
          maxLines: 2,
          style: const TextStyle(fontSize: 14, fontFamily: 'Lato'),
          decoration: InputDecoration(
            hintText: 'Enter $label',
            hintStyle: const TextStyle(color: kGrey400, fontSize: 12, fontWeight: FontWeight.w400),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: kGreyBg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ]),
    );
  }

  Widget _buildColorOption(String theme, Color color) {
    final isSelected = _a4ColorTheme == theme;
    return GestureDetector(
      onTap: () {
        setState(() => _a4ColorTheme = theme);
        _saveSettings();
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: isSelected ? kWhite : Colors.transparent, width: 3),
          boxShadow: isSelected ? [BoxShadow(color: color.withAlpha(100), blurRadius: 8, spreadRadius: 2)] : null,
        ),
        child: isSelected ? const Icon(Icons.check, color: kWhite, size: 18) : null,
      ),
    );
  }

  Color _getThemeColor(String theme) {
    switch (theme) {
      case 'gold': return const Color(0xFFC9A441);
      case 'lavender': return const Color(0xFF9A96D8);
      case 'green': return const Color(0xFF1CB466);
      case 'brown': return const Color(0xFFAF4700);
      case 'blue': return const Color(0xFF6488E0);
      case 'peach': return const Color(0xFFFAA774);
      case 'red': return const Color(0xFFDB4747);
      case 'purple': return const Color(0xFF7A1FA2);
      case 'orange': return const Color(0xFFF45715);
      case 'pink': return const Color(0xFFE2A9F1);
      case 'copper': return const Color(0xFFB36A22);
      case 'black': return const Color(0xFF000000);
      case 'olive': return const Color(0xFF9B9B6E);
      case 'navy': return const Color(0xFF2F6798);
      case 'grey': return const Color(0xFF737373);
      case 'forest': return const Color(0xFF4F6F1F);
      default: return const Color(0xFF6488E0);
    }
  }

  Widget _buildA4Preview(Color themeColor) {
    return Container(
      decoration: BoxDecoration(
        color: kGreyBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGrey200),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Preview', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: kBlack54, fontFamily: 'NotoSans')),
          const SizedBox(height: 8),
          // A4 Preview Card
          AspectRatio(
            aspectRatio: 210 / 297, // A4 ratio
            child: Container(
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                children: [
                  // Header with theme color
                  Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: themeColor,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: kWhite.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(height: 6, width: 50, decoration: BoxDecoration(color: kWhite.withOpacity(0.9), borderRadius: BorderRadius.circular(2))),
                              const SizedBox(height: 3),
                              Container(height: 4, width: 35, decoration: BoxDecoration(color: kWhite.withOpacity(0.6), borderRadius: BorderRadius.circular(2))),
                            ],
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(height: 5, width: 28, decoration: BoxDecoration(color: kWhite.withOpacity(0.8), borderRadius: BorderRadius.circular(2))),
                            const SizedBox(height: 3),
                            Container(height: 4, width: 22, decoration: BoxDecoration(color: kWhite.withOpacity(0.5), borderRadius: BorderRadius.circular(2))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Content area
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Customer info
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(height: 4, width: 35, decoration: BoxDecoration(color: kGrey300, borderRadius: BorderRadius.circular(2))),
                                    const SizedBox(height: 3),
                                    Container(height: 3, width: 50, decoration: BoxDecoration(color: kGrey200, borderRadius: BorderRadius.circular(2))),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(height: 4, width: 25, decoration: BoxDecoration(color: kGrey300, borderRadius: BorderRadius.circular(2))),
                                  const SizedBox(height: 3),
                                  Container(height: 3, width: 30, decoration: BoxDecoration(color: kGrey200, borderRadius: BorderRadius.circular(2))),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Table header
                          Container(
                            height: 10,
                            decoration: BoxDecoration(
                              color: themeColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              children: [
                                Expanded(flex: 3, child: Container(height: 3, decoration: BoxDecoration(color: themeColor.withOpacity(0.5), borderRadius: BorderRadius.circular(1)))),
                                const SizedBox(width: 4),
                                Expanded(child: Container(height: 3, decoration: BoxDecoration(color: themeColor.withOpacity(0.5), borderRadius: BorderRadius.circular(1)))),
                                const SizedBox(width: 4),
                                Expanded(child: Container(height: 3, decoration: BoxDecoration(color: themeColor.withOpacity(0.5), borderRadius: BorderRadius.circular(1)))),
                                const SizedBox(width: 4),
                                Expanded(child: Container(height: 3, decoration: BoxDecoration(color: themeColor.withOpacity(0.5), borderRadius: BorderRadius.circular(1)))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Table rows
                          ...List.generate(3, (index) => Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Row(
                              children: [
                                Expanded(flex: 3, child: Container(height: 3, decoration: BoxDecoration(color: kGrey200, borderRadius: BorderRadius.circular(1)))),
                                const SizedBox(width: 4),
                                Expanded(child: Container(height: 3, decoration: BoxDecoration(color: kGrey200, borderRadius: BorderRadius.circular(1)))),
                                const SizedBox(width: 4),
                                Expanded(child: Container(height: 3, decoration: BoxDecoration(color: kGrey200, borderRadius: BorderRadius.circular(1)))),
                                const SizedBox(width: 4),
                                Expanded(child: Container(height: 3, decoration: BoxDecoration(color: kGrey200, borderRadius: BorderRadius.circular(1)))),
                              ],
                            ),
                          )),
                          const Spacer(),
                          // Total section
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              border: Border(top: BorderSide(color: themeColor.withOpacity(0.3), width: 1)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(height: 4, width: 20, decoration: BoxDecoration(color: kGrey300, borderRadius: BorderRadius.circular(1))),
                                const SizedBox(width: 8),
                                Container(height: 5, width: 25, decoration: BoxDecoration(color: themeColor, borderRadius: BorderRadius.circular(1))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Footer
                  Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: themeColor.withOpacity(0.1),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
                    ),
                    child: Center(
                      child: Container(height: 3, width: 40, decoration: BoxDecoration(color: themeColor.withOpacity(0.4), borderRadius: BorderRadius.circular(2))),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String title) => Padding(padding: const EdgeInsets.only(bottom: 12, left: 4), child: Text(title, style: const TextStyle(color: kBlack54, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontFamily: 'NotoSans')));
}

// ==========================================
// GENERAL SETTINGS PAGE
// ==========================================
class GeneralSettingsPage extends StatefulWidget {
  final VoidCallback onBack;
  final Function(String) onNavigate;
  const GeneralSettingsPage({super.key, required this.onBack, required this.onNavigate});
  @override
  State<GeneralSettingsPage> createState() => _GeneralSettingsPageState();
}

class _GeneralSettingsPageState extends State<GeneralSettingsPage> {
  String _selectedLanguage = 'English';
  bool _darkMode = false;
  bool _notificationsEnabled = true;

  @override
  void initState() { super.initState(); _loadSettings(); }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedLanguage = prefs.getString('selected_language') ?? 'English';
      _darkMode = prefs.getBool('dark_mode') ?? false;
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_language', _selectedLanguage);
    await prefs.setBool('dark_mode', _darkMode);
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) { if (!didPop) widget.onBack(); },
      child: Scaffold(
        backgroundColor: kGreyBg,
        appBar: AppBar(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))),
          title: const Text('General Settings', style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 16, fontFamily: 'NotoSans')),
          backgroundColor: kPrimaryColor,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: kWhite, size: 18), onPressed: widget.onBack),
        ),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          _buildSectionLabel('Language'),
          Container(
            decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
            child: ListTile(
              leading: const Icon(Icons.language_rounded, color: kPrimaryColor),
              title: const Text('Language', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, fontFamily: 'NotoSans')),
              subtitle: Text(_selectedLanguage, style: const TextStyle(fontSize: 12, color: kBlack54, fontWeight: FontWeight.w500, fontFamily: 'Lato')),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: kGrey400),
              onTap: () => widget.onNavigate('Language'),
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionLabel('Appearance'),
          Container(
            decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
            child: ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.purple.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.palette_rounded, color: Colors.purple, size: 22),
              ),
              title: Row(
                children: [
                  const Text('App Theme', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, fontFamily: 'NotoSans', color: kBlack87)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: kPrimaryColor.withAlpha(20), borderRadius: BorderRadius.circular(4)),
                    child: const Text('Coming Soon', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kPrimaryColor)),
                  ),
                ],
              ),
              subtitle: const Text('Light, Dark, Modern', style: TextStyle(fontSize: 12, color: kBlack54, fontFamily: 'Lato')),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: kGrey300),
              onTap: null,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildSectionLabel(String title) => Padding(padding: const EdgeInsets.only(bottom: 12, left: 4), child: Text(title, style: const TextStyle(color: kBlack54, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontFamily: 'NotoSans')));
}

// ==========================================
// PRINTER SETUP PAGE
// ==========================================
class PrinterSetupPage extends StatefulWidget {
  final VoidCallback onBack;
  const PrinterSetupPage({super.key, required this.onBack});
  @override State<PrinterSetupPage> createState() => _PrinterSetupPageState();
}

class _PrinterSetupPageState extends State<PrinterSetupPage> {
  bool _isScanning = false, _enableAutoPrint = true;
  List<BluetoothDevice> _bondedDevices = [];
  BluetoothDevice? _selectedDevice;
  String _printerWidth = '58mm';
  int _thermalNumberOfCopies = 1;
  int _a4NumberOfCopies = 1;

  @override void initState() { super.initState(); _loadSettings(); }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _enableAutoPrint = prefs.getBool('enable_auto_print') ?? true;
      _printerWidth = prefs.getString('printer_width') ?? '58mm';
    });

    // Load number of copies from Firestore (backend)
    try {
      final storeDoc = await FirestoreService().getCurrentStoreDoc();
      if (storeDoc != null && storeDoc.exists) {
        final data = storeDoc.data() as Map<String, dynamic>?;
        if (data != null && mounted) {
          setState(() {
            _thermalNumberOfCopies = data['thermalNumberOfCopies'] ?? 1;
            _a4NumberOfCopies = data['a4NumberOfCopies'] ?? 1;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading print copies from Firestore: $e');
    }

    final savedId = prefs.getString('selected_printer_id');
    if (savedId != null) {
      final devices = await FlutterBluePlus.bondedDevices;
      if (mounted) {
        try { setState(() => _selectedDevice = devices.firstWhere((d) => d.remoteId.toString() == savedId)); } catch (_) {}
      }
    }
  }

  Future<void> _updateThermalCopies(int value) async {
    setState(() => _thermalNumberOfCopies = value);
    try {
      final storeId = await FirestoreService().getCurrentStoreId();
      if (storeId != null) {
        await FirebaseFirestore.instance.collection('store').doc(storeId).set(
          {'thermalNumberOfCopies': value},
          SetOptions(merge: true),
        );
      }
    } catch (e) {
      debugPrint('Error saving thermal copies: $e');
    }
  }

  Future<void> _updateA4Copies(int value) async {
    setState(() => _a4NumberOfCopies = value);
    try {
      final storeId = await FirestoreService().getCurrentStoreId();
      if (storeId != null) {
        await FirebaseFirestore.instance.collection('store').doc(storeId).set(
          {'a4NumberOfCopies': value},
          SetOptions(merge: true),
        );
      }
    } catch (e) {
      debugPrint('Error saving A4 copies: $e');
    }
  }

  Future<void> _scanForDevices() async {
    if (await Permission.bluetoothScan.request().isDenied) return;
    setState(() => _isScanning = true);
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
    FlutterBluePlus.scanResults.listen((r) { if(mounted) setState(() {}); });
    await Future.delayed(const Duration(seconds: 4));
    await FlutterBluePlus.stopScan();
    if (mounted) setState(() => _isScanning = false);
  }

  Future<void> _selectDevice(BluetoothDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_printer_id', device.remoteId.toString());
    if (mounted) setState(() => _selectedDevice = device);
  }

  Future<void> _setPrinterWidth(String width) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('printer_width', width);
    if (mounted) setState(() => _printerWidth = width);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),title: const Text("Printer Setup", style: TextStyle(color: kWhite,fontWeight: FontWeight.bold, fontSize: 16)), centerTitle: true, backgroundColor: kPrimaryColor, leading: IconButton(icon: const Icon(Icons.arrow_back, color: kWhite, size: 18), onPressed: widget.onBack)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_selectedDevice != null) Container(padding: const EdgeInsets.all(16), margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGoogleGreen.withOpacity(0.3))), child: Row(children: [const Icon(Icons.print_rounded, color: kGoogleGreen, size: 28), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Active Printer", style: TextStyle(fontSize: 9, color: kGoogleGreen, fontWeight: FontWeight.w900, letterSpacing: 0.5)), Text(_selectedDevice!.platformName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: kBlack87))])), IconButton(onPressed: () => setState(() => _selectedDevice = null), icon: const Icon(Icons.delete_sweep_rounded, color: kErrorColor))])),

          // Printer Width Setting
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Paper Width", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 1.0)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _setPrinterWidth('58mm'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _printerWidth == '58mm' ? kPrimaryColor : kGreyBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _printerWidth == '58mm' ? kPrimaryColor : kGrey300),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.receipt_long_rounded, color: _printerWidth == '58mm' ? kWhite : kBlack54, size: 24),
                              const SizedBox(height: 6),
                              Text("58mm", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: _printerWidth == '58mm' ? kWhite : kBlack87)),
                              Text("2 inch", style: TextStyle(fontSize: 10, color: _printerWidth == '58mm' ? kWhite.withOpacity(0.8) : kBlack54)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _setPrinterWidth('80mm'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _printerWidth == '80mm' ? kPrimaryColor : kGreyBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _printerWidth == '80mm' ? kPrimaryColor : kGrey300),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.receipt_rounded, color: _printerWidth == '80mm' ? kWhite : kBlack54, size: 24),
                              const SizedBox(height: 6),
                              Text("80mm", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: _printerWidth == '80mm' ? kWhite : kBlack87)),
                              Text("3 inch", style: TextStyle(fontSize: 10, color: _printerWidth == '80mm' ? kWhite.withOpacity(0.8) : kBlack54)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Text("Paired Devices", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 1.0)),
          const SizedBox(height: 12),
          _buildDeviceList(),
          const SizedBox(height: 24),

          // Number of Copies Section
          const Text("Print Copies", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 1.0)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: kPrimaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.print_rounded, color: kPrimaryColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text('Thermal Receipt Copies', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, fontFamily: 'Lato')),
                  ]),
                  Row(children: [
                    IconButton(icon: const Icon(Icons.remove_circle_outline, color: kPrimaryColor), onPressed: _thermalNumberOfCopies > 1 ? () => _updateThermalCopies(_thermalNumberOfCopies - 1) : null),
                    Text('$_thermalNumberOfCopies', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    IconButton(icon: const Icon(Icons.add_circle_outline, color: kPrimaryColor), onPressed: () => _updateThermalCopies(_thermalNumberOfCopies + 1)),
                  ]),
                ]),
                const Divider(height: 24),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.orange.withAlpha(25), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.orange, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text('A4 / PDF Copies', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, fontFamily: 'Lato')),
                  ]),
                  Row(children: [
                    IconButton(icon: const Icon(Icons.remove_circle_outline, color: kPrimaryColor), onPressed: _a4NumberOfCopies > 1 ? () => _updateA4Copies(_a4NumberOfCopies - 1) : null),
                    Text('$_a4NumberOfCopies', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    IconButton(icon: const Icon(Icons.add_circle_outline, color: kPrimaryColor), onPressed: () => _updateA4Copies(_a4NumberOfCopies + 1)),
                  ]),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _SettingsGroup(children: [_SwitchTile("Auto Print Receipt", _enableAutoPrint, (v) async { (await SharedPreferences.getInstance()).setBool('enable_auto_print', v); setState(() => _enableAutoPrint = v); }, showDivider: false)]),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: _isScanning ? null : _scanForDevices, backgroundColor: kPrimaryColor, icon: _isScanning ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: kWhite, strokeWidth: 2)) : const Icon(Icons.bluetooth_searching_rounded,color: kWhite), label: Text(_isScanning ? "SCANNING..." : "Scan For Printers", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12,color: kWhite))),
    );
  }

  Widget _buildDeviceList() {
    return FutureBuilder<List<BluetoothDevice>>(
      future: FlutterBluePlus.bondedDevices,
      builder: (ctx, snap) {
        final devices = snap.data ?? [];
        if (devices.isEmpty) return Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)), child: const Center(child: Text("No paired devices found", style: TextStyle(color: kBlack54, fontSize: 13))));
        return Container(decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)), child: Column(children: devices.map((d) => ListTile(onTap: () => _selectDevice(d), leading: const Icon(Icons.print_outlined, color: kPrimaryColor), title: Text(d.platformName.isEmpty ? "Unknown Printer" : d.platformName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), subtitle: Text(d.remoteId.toString(), style: const TextStyle(fontSize: 10)), trailing: const Icon(Icons.add_circle_outline_rounded, color: kPrimaryColor, size: 20))).toList()));
      },
    );
  }
}

// ==========================================
// FEATURE SETTINGS PAGE
// ==========================================
class FeatureSettingsPage extends StatefulWidget {
  final VoidCallback onBack;
  const FeatureSettingsPage({super.key, required this.onBack});
  @override State<FeatureSettingsPage> createState() => _FeatureSettingsPageState();
}

class _FeatureSettingsPageState extends State<FeatureSettingsPage> {
  bool _enableAutoPrint = true, _blockOutOfStock = true; double _decimals = 2;
  @override Widget build(BuildContext context) => Scaffold(backgroundColor: kGreyBg, appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),title: const Text("Features", style: TextStyle(color: kWhite,fontWeight: FontWeight.bold)), backgroundColor: kPrimaryColor, centerTitle: true, elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back, color: kWhite, size: 18), onPressed: widget.onBack)), body: ListView(padding: const EdgeInsets.all(16), children: [_SettingsGroup(children: [_SwitchTile("Auto Print Receipt", _enableAutoPrint, (v) => setState(() => _enableAutoPrint = v)), _SwitchTile("Block Out-of-Stock Sales", _blockOutOfStock, (v) => setState(() => _blockOutOfStock = v)), Padding(padding: const EdgeInsets.all(16), child: Column(children: [Row(children: [const Text("Decimal Precision", style: TextStyle(fontWeight: FontWeight.w700)), const Spacer(), Text(_decimals.toInt().toString(), style: const TextStyle(fontWeight: FontWeight.w900, color: kPrimaryColor))]), Slider(value: _decimals, min: 0, max: 4, divisions: 4, activeColor: kPrimaryColor, onChanged: (v) => setState(() => _decimals = v))]))])]));
}

// ==========================================
// SHARED UI HELPERS (ENTERPRISE FLAT)
// ==========================================
class ReceiptSettingsPage extends StatelessWidget {
  final VoidCallback onBack;
  final Function(String) onNavigate;
  final String uid;
  final String? userEmail;

  const ReceiptSettingsPage({super.key, required this.onBack, required this.onNavigate, required this.uid, this.userEmail});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: kGreyBg,
        appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
          title: const Text("Receipt Settings", style: TextStyle(color: kWhite, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.5)),
          backgroundColor: kPrimaryColor,
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: kWhite, size: 18),
              onPressed: onBack
          ),
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Accent
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                decoration: const BoxDecoration(
                  color: kPrimaryColor,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Hub Configuration", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kWhite)),
                    const SizedBox(height: 8),
                    Text("Manage your thermal hardware and aesthetic presentation in one place.",
                        style: TextStyle(fontSize: 13, color: kWhite.withOpacity(0.8), height: 1.4, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildActionTile(
                      title: "Design Engine",
                      description: "Customize templates, branding, and visibility.",
                      icon: Icons.auto_awesome_mosaic_rounded,
                      color: Colors.indigo,
                      onTap: () => onNavigate('ReceiptCustomization'),
                    ),
                    const SizedBox(height: 16),
                    _buildActionTile(
                      title: "Printer Link",
                      description: "Manage thermal hardware and Bluetooth link.",
                      icon: Icons.print_rounded,
                      color: Colors.blue,
                      onTap: () => onNavigate('PrinterSetup'),
                    ),

                    const SizedBox(height: 40),
                    _buildSectionHeader("Operational Status"),
                    const SizedBox(height: 16),
                    _buildStatusItem("Thermal Engine", "Ready", true),
                    _buildStatusItem("Cloud Synchronization", "Active", true),
                  ],
                ),
              ),
            ],
          ),
        )
    );
  }

  Widget _buildActionTile({required String title, required String description, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: kGrey200),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 8))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: kBlack87)),
                  const SizedBox(height: 4),
                  Text(description, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: kGrey400, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(String label, String status, bool isActive) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGrey200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kBlack87)),
          Row(
            children: [
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(color: isActive ? Colors.green : Colors.red, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                status,
                style: TextStyle(color: isActive ? Colors.green : Colors.red, fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 2.0));
  }
}

class ReceiptCustomizationPage extends StatefulWidget {
  final VoidCallback onBack;
  const ReceiptCustomizationPage({super.key, required this.onBack});
  @override State<ReceiptCustomizationPage> createState() => _ReceiptCustomizationPageState();
}

class _ReceiptCustomizationPageState extends State<ReceiptCustomizationPage> {
  bool _saving = false;
  int _selectedTemplateIndex = 0;

  final _docTitleCtrl = TextEditingController(text: 'Invoice');
  bool _showLogo = true;
  bool _showLocation = true;
  bool _showEmail = true;
  bool _showPhone = true;
  bool _showTaxId = true;

  bool _showCustomer = true;
  bool _showUnits = true;
  bool _showMRP = false;
  bool _showPayMode = true;
  bool _showSavings = true;

  // Document number counters
  final _invoiceNumberCtrl = TextEditingController(text: '100001');
  final _quotationNumberCtrl = TextEditingController(text: '100001');
  final _purchaseNumberCtrl = TextEditingController(text: '100001');
  final _expenseNumberCtrl = TextEditingController(text: '100001');
  final _receiptNumberCtrl = TextEditingController(text: '100001');

  // Prefix controllers
  final _invoicePrefixCtrl = TextEditingController();
  final _quotationPrefixCtrl = TextEditingController();
  final _purchasePrefixCtrl = TextEditingController();
  final _expensePrefixCtrl = TextEditingController();
  final _receiptPrefixCtrl = TextEditingController();

  // Live current numbers (what will actually be used next)
  String _liveInvoiceNumber = '...';
  String _liveQuotationNumber = '...';
  String _livePurchaseNumber = '...';
  String _liveExpenseNumber = '...';
  String _liveReceiptNumber = '...';
  bool _loadingLiveNumbers = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadLiveNumbers();
  }

  /// Load the actual next numbers that will be used
  Future<void> _loadLiveNumbers() async {
    setState(() => _loadingLiveNumbers = true);
    try {
      final results = await Future.wait([
        NumberGeneratorService.peekInvoiceNumber(),
        NumberGeneratorService.peekQuotationNumber(),
        NumberGeneratorService.peekExpenseNumber(),
        NumberGeneratorService.peekPurchaseNumber(),
        NumberGeneratorService.peekPaymentReceiptNumber(),
      ]);
      if (mounted) {
        setState(() {
          _liveInvoiceNumber = results[0];
          _liveQuotationNumber = results[1];
          _liveExpenseNumber = results[2];
          _livePurchaseNumber = results[3];
          _liveReceiptNumber = results[4];
          _loadingLiveNumbers = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading live numbers: $e');
      if (mounted) setState(() => _loadingLiveNumbers = false);
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedTemplateIndex = prefs.getInt('invoice_template') ?? 0;
      _docTitleCtrl.text = prefs.getString('receipt_header') ?? 'Invoice';
      _showLogo = prefs.getBool('receipt_show_logo') ?? true;
      _showLocation = prefs.getBool('receipt_show_location') ?? true;
      _showEmail = prefs.getBool('receipt_show_email') ?? true;
      _showPhone = prefs.getBool('receipt_show_phone') ?? true;
      _showTaxId = prefs.getBool('receipt_show_gst') ?? true;
      _showCustomer = prefs.getBool('receipt_show_customer_details') ?? true;
      _showUnits = prefs.getBool('receipt_show_measuring_unit') ?? true;
      _showMRP = prefs.getBool('receipt_show_mrp') ?? false;
      _showPayMode = prefs.getBool('receipt_show_payment_mode') ?? true;
      _showSavings = prefs.getBool('receipt_show_save_amount') ?? true;
    });

    // Load document number counters from Firestore
    try {
      final storeDoc = await FirestoreService().getCurrentStoreDoc();
      if (storeDoc != null && storeDoc.exists) {
        final data = storeDoc.data() as Map<String, dynamic>?;
        if (data != null) {
          setState(() {
            _invoiceNumberCtrl.text = (data['nextInvoiceNumber'] ?? data['invoiceCounter'] ?? 100001).toString();
            _quotationNumberCtrl.text = (data['nextQuotationNumber'] ?? data['quotationCounter'] ?? 100001).toString();
            _purchaseNumberCtrl.text = (data['nextPurchaseNumber'] ?? data['purchaseCounter'] ?? 100001).toString();
            _expenseNumberCtrl.text = (data['nextExpenseNumber'] ?? data['expenseCounter'] ?? 100001).toString();
            _receiptNumberCtrl.text = (data['nextPaymentReceiptNumber'] ?? 100001).toString();
            _invoicePrefixCtrl.text = data['invoicePrefix']?.toString() ?? '';
            _quotationPrefixCtrl.text = data['quotationPrefix']?.toString() ?? '';
            _purchasePrefixCtrl.text = data['purchasePrefix']?.toString() ?? '';
            _expensePrefixCtrl.text = data['expensePrefix']?.toString() ?? '';
            _receiptPrefixCtrl.text = data['paymentReceiptPrefix']?.toString() ?? '';
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading document counters: $e');
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _saving = true);
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt('invoice_template', _selectedTemplateIndex);
    await prefs.setString('receipt_header', _docTitleCtrl.text);
    await prefs.setBool('receipt_show_logo', _showLogo);
    await prefs.setBool('receipt_show_location', _showLocation);
    await prefs.setBool('receipt_show_email', _showEmail);
    await prefs.setBool('receipt_show_phone', _showPhone);
    await prefs.setBool('receipt_show_gst', _showTaxId);
    await prefs.setBool('receipt_show_customer_details', _showCustomer);
    await prefs.setBool('receipt_show_measuring_unit', _showUnits);
    await prefs.setBool('receipt_show_mrp', _showMRP);
    await prefs.setBool('receipt_show_payment_mode', _showPayMode);
    await prefs.setBool('receipt_show_save_amount', _showSavings);

    final storeId = await FirestoreService().getCurrentStoreId();
    if (storeId != null) {
      // Parse document numbers with validation (default to 100001)
      final invoiceNum = int.tryParse(_invoiceNumberCtrl.text) ?? 100001;
      final quotationNum = int.tryParse(_quotationNumberCtrl.text) ?? 100001;
      final purchaseNum = int.tryParse(_purchaseNumberCtrl.text) ?? 100001;
      final expenseNum = int.tryParse(_expenseNumberCtrl.text) ?? 100001;
      final receiptNum = int.tryParse(_receiptNumberCtrl.text) ?? 100001;

      debugPrint('💾 Saving document numbers: Invoice=$invoiceNum, Quotation=$quotationNum, Purchase=$purchaseNum, Expense=$expenseNum, Receipt=$receiptNum');

      await FirebaseFirestore.instance.collection('store').doc(storeId).update({
        'invoiceSettings.template': _selectedTemplateIndex,
        'invoiceSettings.header': _docTitleCtrl.text,
        'invoiceSettings.showLogo': _showLogo,
        'invoiceSettings.showLocation': _showLocation,
        'invoiceSettings.showEmail': _showEmail,
        'invoiceSettings.showPhone': _showPhone,
        'invoiceSettings.showGST': _showTaxId,
        'invoiceSettings.showCustomerDetails': _showCustomer,
        'invoiceSettings.showMeasuringUnit': _showUnits,
        'invoiceSettings.showMRP': _showMRP,
        'invoiceSettings.showPaymentMode': _showPayMode,
        'invoiceSettings.showSaveAmount': _showSavings,
        // Document number counters
        'nextInvoiceNumber': invoiceNum,
        'nextQuotationNumber': quotationNum,
        'nextPurchaseNumber': purchaseNum,
        'nextExpenseNumber': expenseNum,
        'nextPaymentReceiptNumber': receiptNum,
        // Prefixes
        'invoicePrefix': _invoicePrefixCtrl.text.trim(),
        'quotationPrefix': _quotationPrefixCtrl.text.trim(),
        'purchasePrefix': _purchasePrefixCtrl.text.trim(),
        'expensePrefix': _expensePrefixCtrl.text.trim(),
        'paymentReceiptPrefix': _receiptPrefixCtrl.text.trim(),
      });
    }

    // Refresh live numbers after saving
    await _loadLiveNumbers();

    setState(() => _saving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully!'),
          backgroundColor: kGoogleGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = context.watch<PlanProvider>();

    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        title: const Text("Design Engine", style: TextStyle(color: kWhite, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 2.0)),
        backgroundColor: kPrimaryColor,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: kWhite, size: 18), onPressed: widget.onBack),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _buildSectionHeader("Aesthetic Preset"),
                const SizedBox(height: 16),
                _buildTemplateGrid(),
                const SizedBox(height: 40),

                _buildSettingsSection("Identity & Branding", [
                  _buildInputField(_docTitleCtrl, "Header Label"),
                  _buildToggleItem("Include Business Logo", _showLogo, (v) {
                    if (!plan.canUseLogoOnBill()) {
                      PlanPermissionHelper.showUpgradeDialog(context, 'Logo');
                      return;
                    }
                    setState(() => _showLogo = v);
                  }),
                  _buildToggleItem("Show Business Address", _showLocation, (v) => setState(() => _showLocation = v)),
                  _buildToggleItem("Show Contact Email", _showEmail, (v) => setState(() => _showEmail = v)),
                  _buildToggleItem("Show Phone Number", _showPhone, (v) => setState(() => _showPhone = v)),
                  _buildToggleItem("Show Taxation (GST/VAT)", _showTaxId, (v) => setState(() => _showTaxId = v)),
                ]),

                const SizedBox(height: 32),

                _buildSettingsSection("Visibility Controls", [
                  _buildToggleItem("Customer Information", _showCustomer, (v) => setState(() => _showCustomer = v)),
                  _buildToggleItem("Measuring Units", _showUnits, (v) => setState(() => _showUnits = v)),
                  _buildToggleItem("Show MRP Column", _showMRP, (v) => setState(() => _showMRP = v)),
                  _buildToggleItem("Show Payment Mode", _showPayMode, (v) => setState(() => _showPayMode = v)),
                  _buildToggleItem("Display Savings Alert", _showSavings, (v) => setState(() => _showSavings = v)),
                ]),

                const SizedBox(height: 32),

                // Document Prefixes
                _buildSettingsSection("Document Prefixes", [
                  _buildPrefixField(_invoicePrefixCtrl, "Invoice Prefix", "e.g. INV", Icons.receipt_long_rounded, kPrimaryColor),
                  _buildPrefixField(_quotationPrefixCtrl, "Quotation Prefix", "e.g. QT", Icons.request_quote_rounded, Colors.orange),
                  _buildPrefixField(_purchasePrefixCtrl, "Purchase Prefix", "e.g. PO", Icons.shopping_cart_rounded, Colors.green),
                  _buildPrefixField(_expensePrefixCtrl, "Expense Prefix", "e.g. EXP", Icons.account_balance_wallet_rounded, Colors.purple),
                  _buildPrefixField(_receiptPrefixCtrl, "Payment Receipt Prefix", "e.g. PR", Icons.payment_rounded, Colors.teal),
                ]),

                const SizedBox(height: 32),

                // Current Document Numbers with Edit Option
                _buildSettingsSection("Current Document Numbers", [
                  _buildEditableNumberField(_invoiceNumberCtrl, "Next Invoice Number", Icons.receipt_long_rounded, kPrimaryColor, _liveInvoiceNumber),
                  _buildEditableNumberField(_quotationNumberCtrl, "Next Quotation Number", Icons.request_quote_rounded, Colors.orange, _liveQuotationNumber),
                  _buildEditableNumberField(_purchaseNumberCtrl, "Next Purchase Number", Icons.shopping_cart_rounded, Colors.green, _livePurchaseNumber),
                  _buildEditableNumberField(_expenseNumberCtrl, "Next Expense Number", Icons.account_balance_wallet_rounded, Colors.purple, _liveExpenseNumber),
                  _buildEditableNumberField(_receiptNumberCtrl, "Next Receipt Number", Icons.payment_rounded, Colors.teal, _liveReceiptNumber),
                ]),
                const SizedBox(height: 40),
              ],
            ),
          ),
          _buildActionFooter(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 2.0));
  }

  Widget _buildTemplateGrid() {
    final items = [
      {'t': 'Professional', 'c': Colors.black87},
      {'t': 'Modern Blue', 'c': kPrimaryColor},
      {'t': 'Minimalist', 'c': Colors.blueGrey},
      {'t': 'Vibrant', 'c': Colors.indigo},
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: List.generate(items.length, (i) {
        bool sel = _selectedTemplateIndex == i;
        Color col = items[i]['c'] as Color;
        return GestureDetector(
          onTap: () => setState(() => _selectedTemplateIndex = i),
          child: Container(
            width: (MediaQuery.of(context).size.width - 60) / 2,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: sel ? col : kWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: sel ? col : kGrey200, width: sel ? 1.5 : 1),
              boxShadow: sel ? [BoxShadow(color: col.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))] : [],
            ),
            child: Column(
              children: [
                Icon(Icons.description_outlined, color: sel ? kWhite : kGrey400, size: 28),
                const SizedBox(height: 8),
                Text(items[i]['t'] as String,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: sel ? kWhite : kBlack87)),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildPrefixField(TextEditingController ctrl, String label, String hint, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kBlack54)),
                const SizedBox(height: 4),
                TextField(
                  controller: ctrl,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color),
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                  ],
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: hint,
                    hintStyle: const TextStyle(fontSize: 13, color: kGrey400, fontWeight: FontWeight.w400),
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          if (ctrl.text.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(8)),
              child: Text('${ctrl.text}100001',
                  style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kBlack87)),
        ),
        Container(
          decoration: BoxDecoration(
            color: kWhite,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: kGrey200),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildToggleItem(String label, bool val, Function(bool) fn) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          AppMiniSwitch(value: val, onChanged: fn),
        ],
      ),
    );
  }


  Widget _buildEditableNumberField(TextEditingController ctrl, String label, IconData icon, Color color, String liveValue) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kGrey100))),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kBlack54)),
                const SizedBox(height: 4),
                _loadingLiveNumbers
                    ? const SizedBox(width: 80, height: 24, child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))))
                    : Text(liveValue, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
              ],
            ),
          ),
          // Edit button
          GestureDetector(
            onTap: () => _showEditNumberDialog(ctrl, label, icon, color, liveValue),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.edit_rounded, size: 14, color: kPrimaryColor),
                  SizedBox(width: 4),
                  Text("Edit", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: kPrimaryColor)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditNumberDialog(TextEditingController ctrl, String label, IconData icon, Color color, String currentValue) {
    final editCtrl = TextEditingController(text: currentValue);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Enter the next number to use:", style: TextStyle(fontSize: 12, color: kBlack54)),
            const SizedBox(height: 12),
            TextField(
               controller: editCtrl,
               keyboardType: TextInputType.number,
               inputFormatters: [
                 FilteringTextInputFormatter.digitsOnly,
               ],
               autofocus: true,
               style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color),
              decoration: InputDecoration(
                
                
                
                
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "💡 This will be the next number used for new documents.",
              style: TextStyle(fontSize: 10, color: kBlack54, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: kBlack54, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newValue = int.tryParse(editCtrl.text);
              if (newValue != null && newValue > 0) {
                ctrl.text = editCtrl.text;
                Navigator.pop(context);
                // Save settings and refresh live numbers
                await _saveSettings();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter a valid number"), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Save", style: TextStyle(color: kWhite, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(TextEditingController ctrl, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kGrey100))),
      child: TextFormField(
        controller: ctrl,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kBlack87),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 11, color: kBlack54, fontWeight: FontWeight.w600),
          
        ),
      ),
    );
  }


  Widget _buildActionFooter() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        decoration: BoxDecoration(
          color: kWhite,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _saveSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              _saving ? "Syncing..." : "Save configuration",
              style: const TextStyle(color: kWhite, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 13),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// LANGUAGE PAGE
// ==========================================

class LanguagePage extends StatefulWidget {
  final VoidCallback onBack;
  const LanguagePage({super.key, required this.onBack});

  @override
  State<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends State<LanguagePage> {
  String _selectedLanguage = 'English';

  // Languages ordered as requested:
  // 1. English (default)
  // Languages list - English available, others coming soon
  // International languages first, then Indian languages
  final List<Map<String, dynamic>> _languages = [
    {'code': 'en', 'name': 'English', 'nativeName': 'English', 'available': true},
    {'code': 'ar', 'name': 'Arabic', 'nativeName': 'العربية', 'available': false},
    {'code': 'es', 'name': 'Spanish', 'nativeName': 'Español', 'available': false},
    {'code': 'fr', 'name': 'French', 'nativeName': 'Français', 'available': false},
    {'code': 'de', 'name': 'German', 'nativeName': 'Deutsch', 'available': false},
    {'code': 'zh', 'name': 'Chinese', 'nativeName': '中文', 'available': false},
    {'code': 'ja', 'name': 'Japanese', 'nativeName': '日本語', 'available': false},
    {'code': 'ko', 'name': 'Korean', 'nativeName': '한국어', 'available': false},
    {'code': 'ru', 'name': 'Russian', 'nativeName': 'Русский', 'available': false},
    {'code': 'pt', 'name': 'Portuguese', 'nativeName': 'Português', 'available': false},
    {'code': 'hi', 'name': 'Hindi', 'nativeName': 'हिन्दी', 'available': false},
    {'code': 'bn', 'name': 'Bengali', 'nativeName': 'বাংলা', 'available': false},
    {'code': 'mr', 'name': 'Marathi', 'nativeName': 'मराठी', 'available': false},
    {'code': 'te', 'name': 'Telugu', 'nativeName': 'తెలుగు', 'available': false},
    {'code': 'ta', 'name': 'Tamil', 'nativeName': 'தமிழ்', 'available': false},
  ];

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedLanguage = prefs.getString('selected_language') ?? 'English';
    });
  }

  Future<void> _saveLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_language', language);
    setState(() => _selectedLanguage = language);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        title: const Text('Language', style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 16, fontFamily: 'NotoSans')),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: kWhite, size: 18), onPressed: widget.onBack),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12, left: 4),
            child: Text('Select language', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 1.5, fontFamily: 'NotoSans')),
          ),
          Container(
            decoration: BoxDecoration(
              color: kWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kGrey200),
            ),
            child: Column(
              children: _languages.asMap().entries.map((entry) {
                final index = entry.key;
                final lang = entry.value;
                final isSelected = _selectedLanguage == lang['name'];
                final isAvailable = lang['available'] == true;
                final isComingSoon = !isAvailable;
                return Column(
                  children: [
                    ListTile(
                      onTap: isComingSoon ? null : () => _saveLanguage(lang['name']!),
                      leading: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: isSelected ? kPrimaryColor.withAlpha(25) : kGreyBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(lang['code']!, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: isComingSoon ? kBlack54 : (isSelected ? kPrimaryColor : kBlack54))),
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(
                            lang['name'],
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                              fontSize: 14,
                              fontFamily: 'NotoSans',
                              color: isComingSoon ? kBlack54 : (isSelected ? kPrimaryColor : kBlack87),
                            ),
                          ),
                          if (isComingSoon) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: kPrimaryColor.withAlpha(20), borderRadius: BorderRadius.circular(4)),
                              child: const Text('Launching Soon', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kPrimaryColor)),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(lang['nativeName']!, style: TextStyle(fontSize: 12, color: isComingSoon ? kBlack54 : (isSelected ? kPrimaryColor : kBlack54), fontFamily: 'Lato')),
                      trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: kPrimaryColor, size: 22) : null,
                    ),
                    if (index < _languages.length - 1) const Divider(height: 1, indent: 60, color: kGrey100),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// THEME PAGE
// ==========================================

class ThemePage extends StatefulWidget {
  final VoidCallback onBack;
  const ThemePage({super.key, required this.onBack});

  @override
  State<ThemePage> createState() => _ThemePageState();
}

class _ThemePageState extends State<ThemePage> {
  String _selectedTheme = 'Light';

  final List<Map<String, dynamic>> _themes = [
    {'name': 'Light', 'icon': Icons.light_mode_rounded, 'color': Colors.orange, 'available': true},
    {'name': 'Dark', 'icon': Icons.dark_mode_rounded, 'color': Colors.indigo, 'available': false},
    {'name': 'Modern', 'icon': Icons.auto_awesome_rounded, 'color': Colors.purple, 'available': false},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        title: const Text('App Theme', style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 16, fontFamily: 'NotoSans')),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: kWhite, size: 18), onPressed: widget.onBack),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Launching Soon Banner
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: kPrimaryColor.withAlpha(15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kPrimaryColor.withAlpha(40)),
            ),
            child: Row(
              children: const [
                Icon(Icons.rocket_launch_rounded, color: kPrimaryColor, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text('App Theme will launch soon!', style: TextStyle(color: kPrimaryColor, fontSize: 13, fontWeight: FontWeight.w700, fontFamily: 'NotoSans')),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 12, left: 4),
            child: Text('Select Theme', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 1.5, fontFamily: 'NotoSans')),
          ),
          Container(
            decoration: BoxDecoration(
              color: kWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kGrey200),
            ),
            child: Column(
              children: _themes.asMap().entries.map((entry) {
                final index = entry.key;
                final theme = entry.value;
                final isSelected = _selectedTheme == theme['name'];
                final isAvailable = theme['available'] == true;
                return Column(
                  children: [
                    ListTile(
                      onTap: isAvailable ? () => setState(() => _selectedTheme = theme['name']) : null,
                      leading: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: (theme['color'] as Color).withAlpha(isAvailable ? 25 : 15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(theme['icon'], color: isAvailable ? theme['color'] : kGrey400, size: 22),
                      ),
                      title: Row(
                        children: [
                          Text(
                            theme['name'],
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                              fontSize: 14,
                              fontFamily: 'NotoSans',
                              color: isAvailable ? (isSelected ? kPrimaryColor : kBlack87) : kGrey400,
                            ),
                          ),
                          if (!isAvailable) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: kPrimaryColor.withAlpha(20), borderRadius: BorderRadius.circular(4)),
                              child: const Text('Launching Soon', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kPrimaryColor)),
                            ),
                          ],
                        ],
                      ),
                      trailing: isSelected && isAvailable ? const Icon(Icons.check_circle_rounded, color: kPrimaryColor, size: 22) : null,
                    ),
                    if (index < _themes.length - 1) const Divider(height: 1, indent: 60, color: kGrey100),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// HELP PAGE
// ==========================================

class HelpPage extends StatelessWidget {
  final VoidCallback onBack;
  final Function(String) onNavigate;
  const HelpPage({super.key, required this.onBack, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        title: const Text('Help & Support', style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 16, fontFamily: 'NotoSans')),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: kWhite, size: 18), onPressed: onBack),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12, left: 4),
            child: Text('Resources', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 1.5, fontFamily: 'NotoSans')),
          ),
          Container(
            decoration: BoxDecoration(
              color: kWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kGrey200),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.blue.withAlpha(25), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.help_center_rounded, color: Colors.blue, size: 20),
                  ),
                  title: const Text('FAQs', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, fontFamily: 'NotoSans')),
                  subtitle: const Text('Frequently asked questions', style: TextStyle(fontSize: 11, color: kBlack54, fontWeight: FontWeight.w500, fontFamily: 'Lato')),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: kGrey400),
                  onTap: () => onNavigate('FAQs'),
                ),
                const Divider(height: 1, indent: 60, color: kGrey100),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.red.withAlpha(25), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.play_circle_rounded, color: Colors.red, size: 20),
                  ),
                  title: const Text('Video Tutorials', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, fontFamily: 'NotoSans')),
                  subtitle: const Text('Learn with step-by-step videos', style: TextStyle(fontSize: 11, color: kBlack54, fontWeight: FontWeight.w500, fontFamily: 'Lato')),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: kGrey400),
                  onTap: () => onNavigate('VideoTutorials'),
                ),
                const Divider(height: 1, indent: 60, color: kGrey100),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.purple.withAlpha(25), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.upcoming_rounded, color: Colors.purple, size: 20),
                  ),
                  title: const Text('Upcoming Features', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, fontFamily: 'NotoSans')),
                  subtitle: const Text('What\'s coming next', style: TextStyle(fontSize: 11, color: kBlack54, fontWeight: FontWeight.w500, fontFamily: 'Lato')),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: kGrey400),
                  onTap: () => onNavigate('UpcomingFeatures'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.only(bottom: 12, left: 4),
            child: Text('Contact Us', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 1.5, fontFamily: 'NotoSans')),
          ),
          Container(
            decoration: BoxDecoration(
              color: kWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kGrey200),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.green.withAlpha(25), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.email_rounded, color: Colors.green, size: 20),
                  ),
                  title: const Text('Email Support', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, fontFamily: 'NotoSans')),
                  subtitle: const Text('support@maxbillup.com', style: TextStyle(fontSize: 11, color: kBlack54, fontWeight: FontWeight.w500, fontFamily: 'Lato')),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: kGrey400),
                ),
                const Divider(height: 1, indent: 60, color: kGrey100),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.teal.withAlpha(25), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.chat_rounded, color: Colors.teal, size: 20),
                  ),
                  title: const Text('Live Chat', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, fontFamily: 'NotoSans')),
                  subtitle: const Text('Chat with our team', style: TextStyle(fontSize: 11, color: kBlack54, fontWeight: FontWeight.w500, fontFamily: 'Lato')),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: kGrey400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// FAQs PAGE
// ==========================================

class FAQsPage extends StatelessWidget {
  final VoidCallback onBack;
  const FAQsPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        title: const Text('FAQs', style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 16, fontFamily: 'NotoSans')),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: kWhite, size: 18), onPressed: onBack),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildFAQItem('How do I add products?', 'Go to Inventory > Add Product. Fill in the product details like name, price, and stock quantity.'),
          _buildFAQItem('How do I print receipts?', 'Connect a Bluetooth thermal printer in Settings > Printer Setup. Then enable auto-print in the same settings.'),
          _buildFAQItem('How do I import products from Excel?', 'Go to Inventory > Import. Download the template, fill in your products, and upload the Excel file.'),
          _buildFAQItem('How do I view sales reports?', 'Navigate to Reports from the bottom menu to see daily, weekly, and monthly sales summaries.'),
          _buildFAQItem('How do I manage staff permissions?', 'Go to Settings > User Management. Add staff members and configure their access permissions.'),
        ],
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGrey200),
      ),
      child: ExpansionTile(
        title: Text(question, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, fontFamily: 'NotoSans')),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(answer, style: const TextStyle(fontSize: 13, color: kBlack54, fontFamily: 'Lato', height: 1.5)),
        ],
      ),
    );
  }
}

// ==========================================
// UPCOMING FEATURES PAGE
// ==========================================

class UpcomingFeaturesPage extends StatelessWidget {
  final VoidCallback onBack;
  const UpcomingFeaturesPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        title: const Text('Upcoming Features', style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 16, fontFamily: 'NotoSans')),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: kWhite, size: 18), onPressed: onBack),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildFeatureItem('Dark Mode', 'Coming Soon', Icons.dark_mode_rounded, Colors.indigo),
          _buildFeatureItem('Multi-Store Support', 'Q2 2026', Icons.store_rounded, Colors.blue),
          _buildFeatureItem('Advanced Analytics', 'Q2 2026', Icons.analytics_rounded, Colors.green),
          _buildFeatureItem('E-commerce Integration', 'Q3 2026', Icons.shopping_cart_rounded, Colors.orange),
          _buildFeatureItem('Supplier Management', 'Q3 2026', Icons.local_shipping_rounded, Colors.purple),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String title, String timeline, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGrey200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'NotoSans')),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(timeline, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kPrimaryColor, fontFamily: 'Lato')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// VIDEO TUTORIALS PAGE
// ==========================================

class VideoTutorialsPage extends StatelessWidget {
  final VoidCallback onBack;
  const VideoTutorialsPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        title: const Text('Video Tutorials', style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 16, fontFamily: 'NotoSans')),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: kWhite, size: 18), onPressed: onBack),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildVideoItem('Getting Started', '5 min', Icons.play_circle_filled_rounded),
          _buildVideoItem('Adding Products', '3 min', Icons.play_circle_filled_rounded),
          _buildVideoItem('Making Sales', '4 min', Icons.play_circle_filled_rounded),
          _buildVideoItem('Printer Setup', '2 min', Icons.play_circle_filled_rounded),
          _buildVideoItem('Reports & Analytics', '6 min', Icons.play_circle_filled_rounded),
        ],
      ),
    );
  }

  Widget _buildVideoItem(String title, String duration, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGrey200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 80, height: 50,
          decoration: BoxDecoration(
            color: Colors.red.withAlpha(25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.play_circle_filled_rounded, color: Colors.red, size: 32),
        ),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, fontFamily: 'NotoSans')),
        subtitle: Text(duration, style: const TextStyle(fontSize: 11, color: kBlack54, fontFamily: 'Lato')),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: kGrey400),
      ),
    );
  }
}

// ==========================================
// HELPER WIDGETS
// ==========================================

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGrey200),
      ),
      child: Column(children: children),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String title;
  final bool value;
  final Function(bool) onChanged;
  final bool showDivider;

  const _SwitchTile(this.title, this.value, this.onChanged, {this.showDivider = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, fontFamily: 'Lato'))),
              AppMiniSwitch(value: value, onChanged: onChanged),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1, indent: 16, endIndent: 16, color: kGrey100),
      ],
    );
  }
}

// ==========================================
// UTILITY: Focus-aware field wrapper
// ==========================================
class _FocusAwareField extends StatefulWidget {
  final TextEditingController ctrl;
  final Widget Function(bool isFocused) builder;
  const _FocusAwareField({required this.ctrl, required this.builder});
  @override
  State<_FocusAwareField> createState() => _FocusAwareFieldState();
}

class _FocusAwareFieldState extends State<_FocusAwareField> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() => _isFocused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      child: widget.builder(_isFocused),
    );
  }
}

