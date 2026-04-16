import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:maxbillup/Colors.dart' hide kWhite;
import 'package:maxbillup/components/app_mini_switch.dart';
import 'package:maxbillup/Menu/Menu.dart' hide kPrimaryColor;
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:heroicons/heroicons.dart';

import 'package:maxbillup/components/common_bottom_nav.dart';
import 'package:maxbillup/utils/permission_helper.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/plan_permission_helper.dart';
import 'package:maxbillup/utils/plan_provider.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:maxbillup/services/currency_service.dart';

// ==========================================
// MODERN DESIGN SYSTEM TOKENS
// ==========================================
// Material Blue
const Color kBackgroundColor = Colors.white; // Unified White Background
const Color kSurfaceColor = Colors.white;
const Color kTextPrimary = Color(0xFF1F2937); // Dark Grey
const Color kTextSecondary = Color(0xFF6B7280); // Cool Grey
final Color kBorderColor = Color(0xFFE3F2FD); // Subtle Border

// Feature Colors
const Color kIncomeGreen = Color(0xFF4CAF50);
const Color kExpenseRed = Color(0xFFFF5252);
const Color kWarningOrange = Color(0xFFFF9800);
const Color kPurpleCharts = Color(0xFF9C27B0);
const Color kTealCharts = Color(0xFF009688);

// Colorful Icon Palette (Diverse & Vibrant)
const Color kIndigoColor = Color(0xFF5C6BC0);
const Color kAmberColor = Color(0xFFFFA726);
const Color kCyanColor = Color(0xFF26C6DA);

// Chart Colors Palette (Varied & Distinct)
const Color kChartBlue = Color(0xFF2196F3);
const Color kChartGreen = Color(0xFF66BB6A);
const Color kChartOrange = Color(0xFFFF7043);
const Color kChartPurple = Color(0xFFAB47BC);
const Color kChartTeal = Color(0xFF26A69A);
const Color kChartPink = Color(0xFFEC407A);
const Color kChartIndigo = Color(0xFF5C6BC0);
const Color kChartAmber = Color(0xFFFFCA28);
const Color kChartCyan = Color(0xFF00BCD4);
const Color kChartRed = Color(0xFFEF5350);
const Color kChartLime = Color(0xFFD4E157);
const Color kChartDeepOrange = Color(0xFFFF5722);

// Chart Colors List for easy iteration
const List<Color> kChartColorsList = [
  kChartBlue,
  kChartGreen,
  kChartOrange,
  kChartPurple,
  kChartTeal,
  kChartPink,
  kChartIndigo,
  kChartAmber,
  kChartCyan,
  kChartRed,
  kChartLime,
  kChartDeepOrange,
];

// ==========================================
// 1. MAIN REPORTS MENU (ROUTER)
// ==========================================
class ReportsPage extends StatefulWidget {
  final String uid;
  final String? userEmail;

  const ReportsPage({super.key, required this.uid, this.userEmail});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String? _currentView;
  Map<String, dynamic> _permissions = {};
  String _role = 'staff';
  bool _permissionsLoaded = false;  // Track if permissions are loaded

  final ScrollController _scrollController = ScrollController();
  double _savedScrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    CurrencyService().loadCurrency();
    _loadPermissions();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPermissions() async {
    final userData = await PermissionHelper.getUserPermissions(widget.uid);
    if (mounted) {
      setState(() {
        _permissions = userData['permissions'] as Map<String, dynamic>? ?? {};
        _role = userData['role'] as String? ?? 'staff';
        _permissionsLoaded = true;  // Mark permissions as loaded
      });
    }
  }

  bool get isAdmin => _role.toLowerCase() == 'owner';

  void _reset() {
    setState(() {
      _currentView = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_savedScrollOffset);
        }
      });
    });
  }

  void _navigateTo(String viewName) {
    // Capture scroll offset synchronously before setState to avoid one-frame flash
    _savedScrollOffset =
    _scrollController.hasClients ? _scrollController.offset : 0.0;
    setState(() => _currentView = viewName);
  }

  @override
  Widget build(BuildContext context) {
    // 0ns Latency Check: Synchronous access via PlanProvider
    final planProvider = context.watch<PlanProvider>();

    // IMPORTANT: Don't show lock icons until provider AND permissions are loaded
    // This prevents the brief flash of lock icons when navigating to this page
    final isProviderReady = planProvider.isInitialized;
    final isFullyLoaded = isProviderReady && _permissionsLoaded;
    final isPaidPlan = isProviderReady ? planProvider.canAccessReports() : true; // Assume unlocked until initialized

    if (_currentView != null) {

      // Wrap sub-pages with PopScope to handle Android back button
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            _reset();
          }
        },
        child: _buildSubPage(),
      );
    }

    return _buildMainReportsPage(context, isFullyLoaded, isPaidPlan);
  }

  Widget _buildSubPage() {
    switch (_currentView) {
      case 'Analytics': return AnalyticsPage(uid: widget.uid, onBack: _reset);
      case 'DayBook': return DayBookPage(uid: widget.uid, onBack: _reset);
      case 'Summary': return IncomeSummaryPage(onBack: _reset);
      case 'SalesSummary': return SalesSummaryPage(onBack: _reset);
      case 'SalesReport': return FullSalesHistoryPage(onBack: _reset);
      case 'ExpenseReport': return ExpenseReportPage(onBack: _reset);
      case 'TopProducts': return TopProductsPage(uid: widget.uid, onBack: _reset);
      case 'LowStock': return LowStockPage(uid: widget.uid, onBack: _reset);
      case 'ItemSales': return ItemSalesPage(onBack: _reset);
      case 'TopCategories': return TopCategoriesPage(onBack: _reset);
      case 'TopCustomers': return TopCustomersPage(uid: widget.uid, onBack: _reset);
      case 'StockReport': return StockReportPage(onBack: _reset);
      case 'StaffReport': return StaffSaleReportPage(onBack: _reset);
      case 'TaxReport': return TaxReportPage(onBack: _reset);
      case 'PaymentReport': return PaymentReportPage(onBack: _reset);
      case 'GSTReport': return TaxReportPage(onBack: _reset); // Unified with Tax Report
      default: return _buildMainReportsPage(context, true, true);
    }
  }

  Widget _buildMainReportsPage(BuildContext context, bool isFullyLoaded, bool isPaidPlan) {
    bool isFeatureAvailable(String permission) {
      // Security-first: do NOT show permission-gated tiles until permissions + plan are fully loaded.
      // This prevents staff briefly seeing report tiles before the permission check completes.
      if (!isFullyLoaded) return false;

      // Daybook is free (no paid plan needed), but it should still respect staff permissions.
      // Permission key used across the app is 'daybook' (lowercase).
      if (permission.toLowerCase() == 'daybook') {
        if (isAdmin) return true;
        return _permissions[_getPermissionKey(permission)] == true;
      }
      // Show all cards for admins - upgrade prompt will be shown on click if needed
      if (isAdmin) return true;
      final userPerm = _permissions[permission] == true;
      return userPerm && isPaidPlan;
    }

    // Check if any item in a section is visible
    bool hasAnalyticsItems = isFeatureAvailable('analytics') || isFeatureAvailable('salesSummary');
    bool hasSalesItems = isFeatureAvailable('salesReport') || isFeatureAvailable('itemSalesReport') || isFeatureAvailable('topCustomer') || isFeatureAvailable('staffSalesReport');
    bool hasInventoryItems = isFeatureAvailable('stockReport') || isFeatureAvailable('lowStockProduct') || isFeatureAvailable('topProducts') || isFeatureAvailable('topCategory');
    bool hasFinancialsItems = isFeatureAvailable('expensesReport') || isFeatureAvailable('taxReport');

    final bool hasAnyVisibleTile =
        isFeatureAvailable('daybook') ||
        hasAnalyticsItems ||
        hasSalesItems ||
        hasInventoryItems ||
        hasFinancialsItems;

    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        title: Text(context.tr('reports'),
            style: TextStyle(color: kWhite, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.0)),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: !hasAnyVisibleTile
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const HeroIcon(HeroIcons.lockClosed, size: 42, color: kGrey400),
                    const SizedBox(height: 12),
                    Text(
                      context.tr('No reports available'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kBlack87),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.tr('You do not have access to any reports. Please contact your owner.'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kBlack54),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // Analytics Overview Section
          if (hasAnalyticsItems) _buildSectionLabel(context.tr('analytics_overview')),
          if (isFeatureAvailable('daybook'))
            _buildReportTile(context.tr('daybook_today'), HeroIcons.bookOpen, const Color(0xFFFF5722), 'DayBook', subtitle: 'Daily transaction log'),
          if (isFeatureAvailable('topProducts'))
            _buildReportTile(context.tr('Product Summary'), HeroIcons.arrowTrendingUp, const Color(0xFF00796B), 'TopProducts', subtitle: 'Most sold items'),
          if (isFeatureAvailable('analytics'))
            _buildReportTile(context.tr('Business Summary'), HeroIcons.presentationChartLine, const Color(0xFF9C27B0), 'Analytics', subtitle: 'MAX Plus & data trends'),

          if (isFeatureAvailable('salesSummary'))
            _buildReportTile('Business Insights', HeroIcons.documentText,   kPrimaryColor, 'Summary', subtitle: 'Income, expense & dues'),
          if (isFeatureAvailable('salesSummary'))
            _buildReportTile(context.tr('Sales Report'), HeroIcons.chartPie, const Color(0xFFE91E63), 'SalesSummary', subtitle: 'Sales performance'),

          // Financials & Tax Section

          if (hasFinancialsItems) ...[
            const SizedBox(height: 12),
            _buildSectionLabel(context.tr('financials_tax')),
          ],
          if (isFeatureAvailable('expensesReport'))
            _buildReportTile(context.tr('expense_report'), HeroIcons.wallet, kErrorColor, 'ExpenseReport', subtitle: 'Operating costs tracking'),
          if (isFeatureAvailable('taxReport'))
            _buildReportTile(context.tr('tax_report'), HeroIcons.receiptPercent, kGoogleGreen, 'TaxReport', subtitle: 'Taxable sales compliance'),

          if (isFeatureAvailable('salesSummary'))
            _buildReportTile('Payment Summary', HeroIcons.banknotes,kWarningOrange , 'PaymentReport', subtitle: 'Cash & online breakdown'),

          // Sales & Transactions Section
          if (hasSalesItems) ...[
            const SizedBox(height: 12),
            _buildSectionLabel(context.tr('sales_transactions')),
          ],
          if (isFeatureAvailable('salesReport'))
            _buildReportTile(context.tr('Sales Record'), HeroIcons.shoppingCart, Colors.deepPurple, 'SalesReport', subtitle: 'Detailed invoice history'),
          if (isFeatureAvailable('itemSalesReport'))
            _buildReportTile(context.tr('item_sales_report'), HeroIcons.shoppingBag,Colors.brown  , 'ItemSales', subtitle: 'Sales by product'),
          if (isFeatureAvailable('topCustomer'))
            _buildReportTile(context.tr('top_customers'), HeroIcons.trophy, const Color(0xFFFFC107), 'TopCustomers', subtitle: 'Best performing Customers'),
          if (isFeatureAvailable('staffSalesReport'))
            _buildReportTile(context.tr('staff_sale_report'), HeroIcons.user, const Color(0xFF009688) , 'StaffReport', subtitle: 'Performance by user'),

          // Inventory & Products Section
          if (hasInventoryItems) ...[
            const SizedBox(height: 12),
            _buildSectionLabel(context.tr('inventory_products')),
          ],
          if (isFeatureAvailable('stockReport'))
            _buildReportTile(context.tr('stock_report'), HeroIcons.archiveBox, const Color(0xFF5C6BC0), 'StockReport', subtitle: 'Full inventory valuation'),
          if (isFeatureAvailable('lowStockProduct'))
            _buildReportTile(context.tr('low_stock_products'), HeroIcons.clipboardDocumentList, kOrange, 'LowStock', subtitle: 'Restock action required'),

          if (isFeatureAvailable('topCategory'))
            _buildReportTile(context.tr('top_categories'), HeroIcons.tag, CupertinoColors.systemPurple, 'TopCategories', subtitle: 'Department performance'),


        ],
      ),
      bottomNavigationBar: CommonBottomNav(
        uid: widget.uid,
        userEmail: widget.userEmail,
        currentIndex: 1,
        screenWidth: MediaQuery.of(context).size.width,
      ),
    );
  }

  Widget _buildSectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 12, top: 12),
    child: Text(text,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 1.5)),
  );

  Widget _buildReportTile(String title, HeroIcons icon, Color color, String viewName, {String? subtitle}) {
    // Get current plan from provider
    final planProvider = context.watch<PlanProvider>();
    final currentPlan = planProvider.cachedPlan;
    final isPaidPlan = planProvider.canAccessReports();

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
          onTap: () {
            // Daybook is free (no paid plan required) but must respect staff permission.
            if (viewName == 'DayBook') {
              if (isAdmin || (_permissions[_getPermissionKey('daybook')] == true)) {
                _navigateTo(viewName);
              } else {
                PermissionHelper.showPermissionDeniedDialog(context);
              }
              return;
            }

            // For admins on free/starter plan, show upgrade dialog
            if (isAdmin && !isPaidPlan) {
              PlanPermissionHelper.showUpgradeDialog(
                context,
                title,
                uid: widget.uid,
                currentPlan: currentPlan,
              );
              return;
            }

            // For staff, check user permissions
            if (!isAdmin) {
              // Staff must have both permission AND paid plan
              final hasPermission = _permissions[_getPermissionKey(viewName)] == true;
              if (!hasPermission) {
                PermissionHelper.showPermissionDeniedDialog(context);
                return;
              }
              if (!isPaidPlan) {
                PlanPermissionHelper.showUpgradeDialog(
                  context,
                  title,
                  uid: widget.uid,
                  currentPlan: currentPlan,
                );
                return;
              }
            }

            // All checks passed, open the report
            _navigateTo(viewName);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: HeroIcon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: kBlack87),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle, style: const TextStyle(color: kBlack54, fontSize: 11, fontWeight: FontWeight.w500)),
                      ],
                    ],
                  ),
                ),
                const HeroIcon(HeroIcons.chevronRight, color: kGrey400, size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to map view names to permission keys
  String _getPermissionKey(String viewName) {
    switch (viewName) {
      case 'Analytics': return 'analytics';
      case 'SalesSummary': return 'salesSummary';
      case 'SalesReport': return 'salesReport';
      case 'ItemSales': return 'itemSalesReport';
      case 'TopCustomers': return 'topCustomer';
      case 'StaffReport': return 'staffSalesReport';
      case 'StockReport': return 'stockReport';
      case 'LowStock': return 'lowStockProduct';
      case 'TopProducts': return 'topProducts';
      case 'TopCategories': return 'topCategory';
      case 'ExpenseReport': return 'expensesReport';
      case 'TaxReport': return 'taxReport';
      default: return viewName.toLowerCase();
    }
  }
}
// ==========================================
// HELPER FUNCTIONS
// ==========================================

// Date filter options enum
enum DateFilterOption {
  today,
  yesterday,
  thisWeek,
  last7Days,
  last30Days,
  thisMonth,
  lastMonth,
  custom,
  customDate,
  customPeriod,
  customMonth,
}

// --- MODERN EXECUTIVE DATE FILTER ---
class DateFilterWidget extends StatefulWidget {
  final DateFilterOption selectedOption;
  final DateTime? startDate;
  final DateTime? endDate;
  final Function(DateFilterOption, DateTime, DateTime) onDateChanged;
  final bool showSortButton;
  final VoidCallback? onSortPressed;
  final bool isDescending;

  const DateFilterWidget({
    super.key,
    required this.selectedOption,
    this.startDate,
    this.endDate,
    required this.onDateChanged,
    this.showSortButton = false,
    this.onSortPressed,
    this.isDescending = true,
  });

  @override
  State<DateFilterWidget> createState() => _DateFilterWidgetState();
}

class _DateFilterWidgetState extends State<DateFilterWidget> {
  // Theme Tokens
  static const Color kGreyBg = Color(0xFFF5F5F7);
  static const Color kWhite = Colors.white;
  static const Color kTextSecondary = Color(0xFF757575);

  String _getFilterLabel(DateFilterOption option) {
    switch (option) {
      case DateFilterOption.today: return 'Today';
      case DateFilterOption.yesterday: return 'Yesterday';
      case DateFilterOption.thisWeek: return 'Week';
      case DateFilterOption.last7Days: return '7 Days';
      case DateFilterOption.last30Days: return '30 Days';
      case DateFilterOption.thisMonth: return 'Month';
      case DateFilterOption.lastMonth: return 'Last Month';
      case DateFilterOption.custom: return 'Custom';
      case DateFilterOption.customDate: return 'Date';
      case DateFilterOption.customPeriod: return 'Range';
      case DateFilterOption.customMonth: return 'Target';
    }
  }

  void _handleQuickSelect(DateFilterOption option) {
    final now = DateTime.now();
    DateTime start = now;
    DateTime end = now;

    switch (option) {
      case DateFilterOption.today:
        start = DateTime(now.year, now.month, now.day);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case DateFilterOption.yesterday:
        final yesterday = now.subtract(const Duration(days: 1));
        start = DateTime(yesterday.year, yesterday.month, yesterday.day);
        end = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
        break;
      case DateFilterOption.thisWeek:
        start = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(start.year, start.month, start.day);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case DateFilterOption.thisMonth:
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      default:
        _showAdvancedFilterModal();
        return;
    }
    widget.onDateChanged(option, start, end);
  }

  // --- PICKERS ---

  Future<void> _selectCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => _applyTheme(child!),
    );
    if (picked != null) {
      widget.onDateChanged(DateFilterOption.customDate, picked, DateTime(picked.year, picked.month, picked.day, 23, 59, 59));
    }
  }

  Future<void> _selectCustomPeriod() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: widget.startDate != null && widget.endDate != null
          ? DateTimeRange(start: widget.startDate!, end: widget.endDate!)
          : null,
      builder: (context, child) => _applyTheme(child!),
    );
    if (range != null) {
      widget.onDateChanged(DateFilterOption.customPeriod, range.start, DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59));
    }
  }

  Future<void> _selectCustomMonth() async {
    final now = DateTime.now();
    int selectedYear = now.year;

    await showModalBottomSheet(
      context: context,
      backgroundColor: kWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildIconBtn(HeroIcons.chevronLeft, () => setModalState(() => selectedYear--)),
                  Text('$selectedYear', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kPrimaryColor)),
                  _buildIconBtn(HeroIcons.chevronRight, selectedYear < now.year ? () => setModalState(() => selectedYear++) : null),
                ],
              ),
              const SizedBox(height: 20),
              GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.4),
                itemCount: 12,
                itemBuilder: (context, index) {
                  final month = index + 1;
                  final isDisabled = selectedYear == now.year && month > now.month;
                  return InkWell(
                    onTap: isDisabled ? null : () {
                      final first = DateTime(selectedYear, month, 1);
                      final last = DateTime(selectedYear, month + 1, 0, 23, 59, 59);
                      widget.onDateChanged(DateFilterOption.customMonth, first, last);
                      Navigator.pop(context);
                    },
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isDisabled ? Colors.transparent : kPrimaryColor.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDisabled ? Colors.grey.shade200 : kPrimaryColor.withValues(alpha: 0.15)),
                      ),
                      child: Text(
                        DateFormat('MMM').format(DateTime(2024, month)),
                        style: TextStyle(fontWeight: FontWeight.w900, color: isDisabled ? Colors.grey : kPrimaryColor, fontSize: 12),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAdvancedFilterModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 8.0, bottom: 12),
              child: Text("Advanced Audit Timeframe", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kPrimaryColor, letterSpacing: 1.5)),
            ),
            _buildModalItem(DateFilterOption.last7Days, HeroIcons.calendarDays, () {
              final now = DateTime.now();
              widget.onDateChanged(DateFilterOption.last7Days, now.subtract(const Duration(days: 6)), now);
              Navigator.pop(context);
            }),
            _buildModalItem(DateFilterOption.last30Days, HeroIcons.clock, () {
              final now = DateTime.now();
              widget.onDateChanged(DateFilterOption.last30Days, now.subtract(const Duration(days: 29)), now);
              Navigator.pop(context);
            }),
            _buildModalItem(DateFilterOption.lastMonth, HeroIcons.calendar, () {
              final lastMonth = DateTime(DateTime.now().year, DateTime.now().month - 1, 1);
              widget.onDateChanged(DateFilterOption.lastMonth, lastMonth, DateTime(DateTime.now().year, DateTime.now().month, 0, 23, 59, 59));
              Navigator.pop(context);
            }),
            _buildModalItem(DateFilterOption.customDate, HeroIcons.calendar, () {
              Navigator.pop(context);
              _selectCustomDate();
            }),
            _buildModalItem(DateFilterOption.customMonth, HeroIcons.squares2x2, () {
              Navigator.pop(context);
              _selectCustomMonth();
            }),
            _buildModalItem(DateFilterOption.customPeriod, HeroIcons.calendarDays, () {
              Navigator.pop(context);
              _selectCustomPeriod();
            }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // --- UI HELPERS ---

  Widget _buildModalItem(DateFilterOption option, HeroIcons icon, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: kGreyBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: HeroIcon(icon, size: 18, color: kPrimaryColor),
        title: Text(_getFilterLabel(option), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.black87)),
        trailing: const HeroIcon(HeroIcons.chevronRight, size: 12, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  Widget _applyTheme(Widget child) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.light(primary: kPrimaryColor, onPrimary: kWhite, onSurface: Colors.black87),
        textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: kPrimaryColor)),
        dialogTheme: DialogThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      ),
      child: child,
    );
  }

  Widget _buildIconBtn(HeroIcons icon, VoidCallback? onPressed) {
    return Container(
      decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(12)),
      child: IconButton(icon: HeroIcon(icon, size: 18, color: kPrimaryColor), onPressed: onPressed),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<DateFilterOption> quickOptions = [
      DateFilterOption.today,
      DateFilterOption.yesterday,
      DateFilterOption.thisWeek,
      DateFilterOption.thisMonth,
    ];

    return Container(
      color: kWhite,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16), // Reduced vertical padding
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Executive Info Bar (Compact)
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getFilterLabel(widget.selectedOption),
                      style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: kPrimaryColor, letterSpacing: 0.8), // Smaller label
                    ),
                    const SizedBox(height: 1),
                    Text(
                      widget.startDate != null
                          ? (widget.startDate == widget.endDate || widget.endDate == null
                          ? '${DateFormat('dd MMM yyyy').format(widget.startDate!)} — ${DateFormat('dd MMM yyyy').format(widget.startDate!)}'
                          : '${DateFormat('dd MMM yyyy').format(widget.startDate!)} — ${DateFormat('dd MMM yyyy').format(widget.endDate!)}')
                          : 'Set Period',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black87), // Smaller date text
                    ),
                  ],
                ),
              ),
              if (widget.showSortButton)
                _buildActionSquare(
                  widget.isDescending ? HeroIcons.arrowDown : HeroIcons.arrowUp,
                  widget.onSortPressed,
                ),
            ],
          ),

          const SizedBox(height: 8), // Reduced gap between rows

          // 2. Executive Quick Tiling (More compact height)
          Row(
            children: [
              ...quickOptions.map((opt) {
                bool isSelected = widget.selectedOption == opt;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _handleQuickSelect(opt),
                    child: Container(
                      margin: const EdgeInsets.only(right: 5), // Tightened margin
                      padding: const EdgeInsets.symmetric(vertical: 6), // Reduced tile height
                      decoration: BoxDecoration(
                        color: isSelected ? kPrimaryColor : kGreyBg,
                        borderRadius: BorderRadius.circular(10), // Slightly smaller radius for compact look
                        border: Border.all(
                          color: isSelected ? kPrimaryColor : Colors.transparent,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _getFilterLabel(opt),
                          style: TextStyle(
                            color: isSelected ? kWhite : Colors.black87,
                            fontSize: 10, // Smaller font
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
              // Integrated ALL Button
              Expanded(
                child: GestureDetector(
                  onTap: _showAdvancedFilterModal,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: kGreyBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("All", style: TextStyle(color: Colors.black87, fontSize: 10, fontWeight: FontWeight.w900)),
                        SizedBox(width: 2),
                        HeroIcon(HeroIcons.adjustmentsHorizontal, size: 12, color: kPrimaryColor),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Divider(height: 1, color: Colors.grey.shade100, thickness: 1),
        ],
      ),
    );
  }

  Widget _buildActionSquare(HeroIcons icon, VoidCallback? onPressed) {
    return Container(
      height: 32, // Reduced from 38
      width: 32,  // Reduced from 38
      decoration: BoxDecoration(
        color: kGreyBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: IconButton(
        icon: HeroIcon(icon, color: kPrimaryColor, size: 16), // Smaller icon
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
  }
}

// Empty state widget with illustration
class EmptyStateWidget extends StatelessWidget {
  final String message;

  const EmptyStateWidget({super.key, this.message = 'Sorry, no data for this period'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Simple chart illustration with sad face
          SizedBox(
            height: 100,
            width: 150,
            child: CustomPaint(
              painter: _EmptyChartPainter(),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: kTextSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kPrimaryColor.withValues(alpha: 0.3)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Draw bars
    final barWidth = 6.0;
    final spacing = 10.0;
    final baseY = size.height - 20;
    final heights = [30.0, 50.0, 25.0, 60.0, 35.0, 45.0, 20.0, 55.0, 30.0];

    for (int i = 0; i < heights.length; i++) {
      final x = 20 + i * (barWidth + spacing);
      canvas.drawLine(
        Offset(x, baseY),
        Offset(x, baseY - heights[i]),
        paint,
      );
    }

    // Draw sad face
    final facePaint = Paint()
      ..color = kPrimaryColor.withValues(alpha: 0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final centerX = size.width / 2 + 20;
    final centerY = size.height / 2 - 10;

    // Face circle
    canvas.drawCircle(Offset(centerX, centerY), 20, facePaint);

    // Eyes
    canvas.drawCircle(Offset(centerX - 7, centerY - 5), 2, facePaint..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(centerX + 7, centerY - 5), 2, facePaint);

    // Sad mouth
    final mouthPath = Path()
      ..moveTo(centerX - 8, centerY + 10)
      ..quadraticBezierTo(centerX, centerY + 3, centerX + 8, centerY + 10);
    canvas.drawPath(mouthPath, facePaint..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

AppBar _buildModernAppBar(String title, VoidCallback onBack, {VoidCallback? onDownload}) {
  return AppBar(
    // Rounded bottom corners for modern look
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
    ),
    leading: IconButton(icon: const HeroIcon(HeroIcons.arrowLeft, color: Colors.white, size: 20), onPressed: onBack),
    title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
    backgroundColor: kPrimaryColor,
    elevation: 0,
    centerTitle: true,
    actions: onDownload != null
        ? [
      IconButton(
        icon: const HeroIcon(HeroIcons.arrowDownTray, color: Colors.white, size: 22),
        onPressed: onDownload,
        tooltip: 'Download PDF',
      ),
      const SizedBox(width: 8),
    ]
        : null,
  );
}

// ==========================================
// PDF REPORT GENERATOR HELPER
// ==========================================
class ReportPdfGenerator {
  static Future<void> generateAndDownloadPdf({
    required BuildContext context,
    required String reportTitle,
    required List<String> headers,
    required List<List<String>> rows,
    String? summaryTitle,
    String? summaryValue,
    Map<String, String>? additionalSummary,
  }) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)),
      );

      // Load fonts for currency symbol support
      final fontData = await rootBundle.load("fonts/NotoSans-Regular.ttf");
      final ttf = pw.Font.ttf(fontData);
      final fontBoldData = await rootBundle.load("fonts/NotoSans-Bold.ttf");
      final ttfBold = pw.Font.ttf(fontBoldData);

      final pdf = pw.Document();
      final now = DateTime.now();
      final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(now);
      final shortDate = DateFormat('dd MMM yyyy').format(now);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
          build: (pw.Context context) {
            return [
              // Modern Header with gradient-like effect
              pw.Container(
                decoration: pw.BoxDecoration(
                  gradient: const pw.LinearGradient(
                    colors: [PdfColors.blue800, PdfColors.blue900],
                    begin: pw.Alignment.topLeft,
                    end: pw.Alignment.bottomRight,
                  ),
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                padding: const pw.EdgeInsets.all(20),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            reportTitle,
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.blue700,
                              borderRadius: pw.BorderRadius.circular(20),
                            ),
                            child: pw.Text(
                              '$shortDate',
                              style: const pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Text(
                        'StockSphere',
                        style: pw.TextStyle(
                          color: PdfColors.blue800,
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 24),

              // Modern Summary Cards
              if (summaryTitle != null && summaryValue != null) ...[
                pw.Container(
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(12),
                    border: pw.Border.all(color: PdfColors.grey300, width: 1),
                  ),
                  child: pw.Column(
                    children: [
                      // Main Summary
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.all(20),
                        decoration: pw.BoxDecoration(
                          gradient: const pw.LinearGradient(
                            colors: [PdfColors.blue50, PdfColors.blue100],
                            begin: pw.Alignment.topLeft,
                            end: pw.Alignment.bottomRight,
                          ),
                          borderRadius: const pw.BorderRadius.only(
                            topLeft: pw.Radius.circular(12),
                            topRight: pw.Radius.circular(12),
                          ),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              summaryTitle,
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blue800,
                                letterSpacing: 1,
                              ),
                            ),
                            pw.SizedBox(height: 8),
                            pw.Text(
                              summaryValue,
                              style: pw.TextStyle(
                                fontSize: 32,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blue900,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Additional Summary Grid
                      if (additionalSummary != null && additionalSummary.isNotEmpty) ...[
                        pw.Container(
                          padding: const pw.EdgeInsets.all(20),
                          child: pw.Wrap(
                            spacing: 16,
                            runSpacing: 12,
                            children: additionalSummary.entries.map((e) {
                              return pw.Container(
                                width: 150,
                                padding: const pw.EdgeInsets.all(12),
                                decoration: pw.BoxDecoration(
                                  color: PdfColors.grey100,
                                  borderRadius: pw.BorderRadius.circular(8),
                                  border: pw.Border.all(color: PdfColors.grey200),
                                ),
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  mainAxisAlignment: pw.MainAxisAlignment.center,
                                  children: [
                                    pw.Text(
                                      e.key,
                                      style: const pw.TextStyle(
                                        fontSize: 8,
                                        color: PdfColors.grey600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    pw.SizedBox(height: 4),
                                    pw.Text(
                                      e.value,
                                      style: pw.TextStyle(
                                        fontSize: 12,
                                        fontWeight: pw.FontWeight.bold,
                                        color: PdfColors.grey900,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                pw.SizedBox(height: 24),
              ],

              // Modern Table
              pw.Container(
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(12),
                  border: pw.Border.all(color: PdfColors.grey300, width: 1),
                ),
                child: pw.Table(
                  border: pw.TableBorder(
                    horizontalInside: pw.BorderSide(color: PdfColors.grey200, width: 1),
                    left: pw.BorderSide.none,
                    right: pw.BorderSide.none,
                    top: pw.BorderSide.none,
                    bottom: pw.BorderSide.none,
                  ),
                  columnWidths: {
                    for (int i = 0; i < headers.length; i++)
                      i: const pw.FlexColumnWidth(),
                  },
                  children: [
                    // Header
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        gradient: pw.LinearGradient(
                          colors: [PdfColors.blue800, PdfColors.blue900],
                        ),
                      ),
                      children: headers.map((header) {
                        return pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          child: pw.Text(
                            header,
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    // Data Rows
                    ...rows.asMap().entries.map((entry) {
                      final isEven = entry.key % 2 == 0;
                      return pw.TableRow(
                        decoration: pw.BoxDecoration(
                          color: isEven ? PdfColors.white : PdfColors.grey50,
                        ),
                        children: entry.value.map((cell) {
                          return pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: pw.Text(
                              cell,
                              style: const pw.TextStyle(
                                fontSize: 9,
                                color: PdfColors.grey800,
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    }).toList(),
                  ],
                ),
              ),

              pw.SizedBox(height: 24),

              // Modern Footer
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  gradient: const pw.LinearGradient(
                    colors: [PdfColors.grey50, PdfColors.grey100],
                  ),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Row(
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.blue800,
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                          child: pw.Text(
                            '${rows.length}',
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 10),
                        pw.Text(
                          'Total Records',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Generated by StockSphere',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue800,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          dateStr,
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ];
          },
        ),
      );

      Navigator.pop(context);

      final fileName = '${reportTitle.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd_HHmmss').format(now)}.pdf';
      final pdfBytes = await pdf.save();

      if (Platform.isAndroid) {
        var storageStatus = await Permission.storage.status;
        if (!storageStatus.isGranted) {
          storageStatus = await Permission.storage.request();
          if (!storageStatus.isGranted) {
            final manageStatus = await Permission.manageExternalStorage.request();
            if (!manageStatus.isGranted) {
              final openSettings = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(child: Text('Permission Required', style: TextStyle(fontSize: 18))),
                    ],
                  ),
                  content: const Text(
                    'Storage permission is needed to save PDF reports to Downloads folder.\n\nPlease enable storage permission in app settings.',
                    style: TextStyle(fontSize: 14, color: kTextSecondary, height: 1.5),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Open Settings', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
              if (openSettings == true) await openAppSettings();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.white),
                      SizedBox(width: 12),
                      Expanded(child: Text('Storage permission denied. Cannot save PDF.')),
                    ],
                  ),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  duration: const Duration(seconds: 3),
                ),
              );
              return;
            }
          }
        }
      }

      String? savedPath;
      bool savedToDownloads = false;

      if (Platform.isAndroid) {
        try {
          print('=== PDF SAVE DEBUG ===');
          print('Attempting to save PDF: $fileName');
          final downloadsPath = '/storage/emulated/0/Download';
          final downloadsDir = Directory(downloadsPath);

          if (await downloadsDir.exists()) {
            print('Downloads directory exists: ${downloadsDir.path}');

            // Create app folder inside Downloads
            final maxmybillDir = Directory('${downloadsDir.path}/MAXmybill');
            if (!await maxmybillDir.exists()) {
              await maxmybillDir.create(recursive: true);
              print('✓ Created app folder: ${maxmybillDir.path}');
            } else {
              print('App folder already exists: ${maxmybillDir.path}');
            }

            // Save file in app folder
            final file = File('${maxmybillDir.path}/$fileName');
            await file.writeAsBytes(pdfBytes, flush: true);
            if (await file.exists()) {
              final fileSize = await file.length();
              print('✓ PDF saved to app folder in Downloads: ${file.path}, Size: $fileSize bytes');
              savedPath = file.path;
              savedToDownloads = true;
            }
          } else {
            final extDir = await getExternalStorageDirectory();
            if (extDir != null) {
              final parts = extDir.path.split('/');
              final storageIndex = parts.indexOf('Android');
              if (storageIndex > 0) {
                final basePath = parts.sublist(0, storageIndex).join('/');
                final downloadDir = Directory('$basePath/Download');
                if (await downloadDir.exists()) {
                  // Create app folder
                  final maxmybillDir = Directory('${downloadDir.path}/MAXmybill');
                  if (!await maxmybillDir.exists()) {
                    await maxmybillDir.create(recursive: true);
                  }

                  final file = File('${maxmybillDir.path}/$fileName');
                  await file.writeAsBytes(pdfBytes, flush: true);
                  if (await file.exists()) {
                    savedPath = file.path;
                    savedToDownloads = true;
                    print('✓ PDF saved to app folder in Downloads (fallback): ${file.path}');
                  }
                }
              }
            }
          }
          if (savedPath == null) {
            print('Fallback: Saving to cache directory');
            final cacheDir = await getTemporaryDirectory();
            final tempFile = File('${cacheDir.path}/$fileName');
            await tempFile.writeAsBytes(pdfBytes, flush: true);
            if (await tempFile.exists()) {
              print('✓ PDF saved to cache: ${tempFile.path}');
              savedPath = tempFile.path;
            }
          }
          print('=== END PDF SAVE DEBUG ===');
        } catch (e, stackTrace) {
          print('ERROR saving PDF: $e');
          print('Stack trace: $stackTrace');
          try {
            final cacheDir = await getTemporaryDirectory();
            final tempFile = File('${cacheDir.path}/$fileName');
            await tempFile.writeAsBytes(pdfBytes, flush: true);
            savedPath = tempFile.path;
          } catch (e2) {
            print('Cache fallback failed: $e2');
          }
        }
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(pdfBytes);
        savedPath = file.path;
      }

      if (savedPath != null) {
        final file = File(savedPath);
        showDialog(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: Colors.white,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [kIncomeGreen, kIncomeGreen.withValues(alpha: 0.7)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      // boxShadow: [
                      //   BoxShadow(
                      //     color: kIncomeGreen.withValues(alpha: 0.3),
                      //     blurRadius: 8,
                      //     offset: const Offset(0, 2),
                      //   ),
                      //],
                    ),
                    child: const Icon(Icons.check_circle_outline, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Success!',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    savedToDownloads
                        ? 'Your PDF report has been saved to your Downloads folder'
                        : 'Your PDF report has been generated successfully',
                    style: const TextStyle(fontSize: 14, color: kTextSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade50, Colors.blue.shade100],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: kPrimaryColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fileName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${(pdfBytes.length / 1024).toStringAsFixed(1)} KB',
                                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (savedToDownloads) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: kIncomeGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kIncomeGreen.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.folder_outlined, color: kIncomeGreen, size: 18),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Check your Downloads folder',
                              style: TextStyle(fontSize: 14, color: kIncomeGreen, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: const Text('Close', style: TextStyle(color: kTextSecondary, fontSize: 14)),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    await Share.shareXFiles(
                      [XFile(file.path)],
                      subject: '$reportTitle Report',
                      text: '$reportTitle - Generated on $dateStr',
                    );
                  },
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Share PDF', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                ),
              ],
            );
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Error: Could not generate PDF file')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Error generating PDF: $e')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }
}

// ==========================================
// 2. ANALYTICS PAGE
// ==========================================
class AnalyticsPage extends StatefulWidget {
  final String uid;
  final VoidCallback onBack;

  const AnalyticsPage({super.key, required this.uid, required this.onBack});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  String _selectedDuration = 'Last 7 Days or Last Week';
  final FirestoreService _firestoreService = FirestoreService();
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

  int get _durationDays {
    switch (_selectedDuration) {
      case 'Today': return 0;
      case 'Yesterday': return 1;
      case 'Last 7 Days or Last Week': return 7;
      case 'Last 30 Days': return 30;
      case 'This Month': return DateTime.now().day;
      case 'Last 3 Months': return 90;
      default: return 7;
    }
  }

  bool _isInPeriod(DateTime? dt) {
    if (dt == null) return false;
    final now = DateTime.now();
    if (_selectedDuration == 'Today') {
      return DateFormat('yyyy-MM-dd').format(dt) == DateFormat('yyyy-MM-dd').format(now);
    } else if (_selectedDuration == 'Yesterday') {
      final yesterday = now.subtract(const Duration(days: 1));
      return DateFormat('yyyy-MM-dd').format(dt) == DateFormat('yyyy-MM-dd').format(yesterday);
    } else if (_selectedDuration == 'This Month') {
      return dt.year == now.year && dt.month == now.month;
    } else if (_selectedDuration == 'Last 3 Months') {
      return now.difference(dt).inDays <= 90;
    }
    return now.difference(dt).inDays <= _durationDays;
  }

  // Store calculated data for PDF download
  double _todayRevenue = 0, _todayExpense = 0, _todayTax = 0;
  double _totalOnline = 0, _totalCash = 0;
  double _periodIncome = 0, _periodExpense = 0;
  double _totalRefunds = 0;
  int _todaySaleCount = 0;

  void _downloadPdf(BuildContext context) {
    final rows = [
      ['Today Revenue', '$_currencySymbol${_todayRevenue.toStringAsFixed(2)}'],
      ['Today Expense', '$_currencySymbol${_todayExpense.toStringAsFixed(2)}'],
      ['Today Tax Collected', '$_currencySymbol${_todayTax.toStringAsFixed(2)}'],
      ['Period Income', '$_currencySymbol${_periodIncome.toStringAsFixed(2)}'],
      ['Period Expense', '$_currencySymbol${_periodExpense.toStringAsFixed(2)}'],
      ['Cash Collection', '$_currencySymbol${_totalCash.toStringAsFixed(2)}'],
      ['Online Collection', '$_currencySymbol${_totalOnline.toStringAsFixed(2)}'],
      ['Total Refunds', '$_currencySymbol${_totalRefunds.toStringAsFixed(2)}'],
    ];

    ReportPdfGenerator.generateAndDownloadPdf(
      context: context,
      reportTitle: 'Business Analytics Report',
      headers: ['Metric', 'Amount'],
      rows: rows,
      summaryTitle: "Net Profit",
      summaryValue: "$_currencySymbol${(_periodIncome - _periodExpense).toStringAsFixed(2)}",
      additionalSummary: {
        'Period': _selectedDuration,
        'Total Bills': '$_todaySaleCount',
        'Refunds': '$_currencySymbol${_totalRefunds.toStringAsFixed(2)}',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: _buildModernAppBar("Business Summary", widget.onBack, onDownload: () => _downloadPdf(context)),
      body: FutureBuilder<List<Stream<QuerySnapshot>>>(
        future: Future.wait([
          _firestoreService.getCollectionStream('sales'),
          _firestoreService.getCollectionStream('expenses'),
          _firestoreService.getCollectionStream('stockPurchases'),
        ]),
        builder: (context, streamsSnapshot) {
          if (!streamsSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: kPrimaryColor, strokeWidth: 2));
          }

          final salesStream = streamsSnapshot.data![0];
          final expensesStream = streamsSnapshot.data![1];
          final stockPurchaseStream = streamsSnapshot.data![2];

          return StreamBuilder<QuerySnapshot>(
            stream: salesStream,
            builder: (context, salesSnap) {
              return StreamBuilder<QuerySnapshot>(
                stream: expensesStream,
                builder: (context, expenseSnap) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: stockPurchaseStream,
                    builder: (context, stockSnap) {
                      if (!salesSnap.hasData || !expenseSnap.hasData || !stockSnap.hasData) {
                        return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                      }

                      final now = DateTime.now();
                      final todayStr = DateFormat('yyyy-MM-dd').format(now);

                      double todayRevenue = 0, todayExpense = 0, todayTax = 0;
                      double totalOnline = 0, totalCash = 0;
                      double periodIncome = 0, periodExpense = 0;
                      int todaySaleCount = 0, todayExpenseCount = 0;

                      Map<int, double> weekRevenue = {}, weekExpense = {};

                      double totalRefunds = 0;

                      // --- Process Sales ---
                      for (var doc in salesSnap.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        double amount = double.tryParse(data['total'].toString()) ?? 0.0;
                        double tax = double.tryParse(data['totalTax']?.toString() ?? '0') ?? 0.0;
                        if (tax == 0) {
                          tax = double.tryParse(data['taxAmount']?.toString() ?? data['tax']?.toString() ?? '0') ?? 0.0;
                        }

                        DateTime? dt;
                        if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                        else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());
                        String mode = (data['paymentMode'] ?? '').toString().toLowerCase();

                        // Check if bill is cancelled, returned or edited
                        final String status = (data['status'] ?? '').toString().toLowerCase();
                        final bool isCancelled = status == 'cancelled';
                        final bool isReturned = status == 'returned' || data['hasBeenReturned'] == true;
                        final bool isEdited = status == 'edited' || data['hasBeenEdited'] == true;
                        final bool isRefunded = isCancelled || isReturned;

                        if (dt != null) {
                          if (DateFormat('yyyy-MM-dd').format(dt) == todayStr) {
                            if (!isRefunded) {
                              todayRevenue += amount;
                              todayTax += tax;
                              todaySaleCount++;
                            } else {
                              // Count refunds for today
                              totalRefunds += amount;
                            }
                          }
                          if (_isInPeriod(dt)) {
                            if (!isRefunded) {
                              periodIncome += amount;
                              weekRevenue[dt.day] = (weekRevenue[dt.day] ?? 0) + amount;

                              // Handle Split payments separately
                              if (mode == 'split') {
                                double splitCash = double.tryParse(data['cashReceived_split']?.toString() ?? '0') ?? 0;
                                double splitOnline = double.tryParse(data['onlineReceived_split']?.toString() ?? '0') ?? 0;
                                totalCash += splitCash;
                                totalOnline += splitOnline;
                              } else if (mode.contains('online') || mode.contains('upi') || mode.contains('card')) {
                                totalOnline += amount;
                              } else if (!mode.contains('credit')) {
                                // Cash payment (exclude credit from cash)
                                totalCash += amount;
                              }
                            } else {
                              // Add to refunds instead of cash/online
                              totalRefunds += amount;
                            }
                          }
                        }
                      }

                      // --- Process Expenses ---
                      for (var doc in expenseSnap.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        double amount = double.tryParse(data['amount'].toString()) ?? 0.0;
                        DateTime? dt;
                        if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                        else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());

                        if (dt != null) {
                          if (DateFormat('yyyy-MM-dd').format(dt) == todayStr) {
                            todayExpense += amount;
                            todayExpenseCount++;
                          }
                          if (_isInPeriod(dt)) {
                            periodExpense += amount;
                            weekExpense[dt.day] = (weekExpense[dt.day] ?? 0) + amount;
                          }
                        }
                      }

                      // Store values for PDF download
                      _todayRevenue = todayRevenue;
                      _todayExpense = todayExpense;
                      _todayTax = todayTax;
                      _totalOnline = totalOnline;
                      _totalCash = totalCash;
                      _periodIncome = periodIncome;
                      _periodExpense = periodExpense;
                      _totalRefunds = totalRefunds;
                      _todaySaleCount = todaySaleCount;

                      return CustomScrollView(
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                          // Executive KPI Ribbon
                          SliverToBoxAdapter(
                            child: _buildExecutiveRibbon(todayRevenue, todaySaleCount),
                          ),

                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            sliver: SliverList(
                              delegate: SliverChildListDelegate([
                                // 2x2 Matrix for daily stats
                                _buildSectionHeader("Daily Breakdown"),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(child: _buildMetricTile("Expenses", todayExpense, kExpenseRed, Icons.outbox_rounded)),
                                    const SizedBox(width: 8),
                                    Expanded(child: _buildMetricTile("Tax Coll.", todayTax, kWarningOrange, Icons.description_outlined)),
                                  ],
                                ),
                                const SizedBox(height: 24),

                                // Analytics Trend Section
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildSectionHeader("Financial Velocity"),
                                    _buildDurationFilter(),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                _buildChartCard(
                                  child: _buildCombinedBarChart(weekRevenue, weekExpense),
                                ),
                                const SizedBox(height: 20),

                                // Payment Composition
                                _buildSectionHeader("Settlement Channels"),
                                const SizedBox(height: 10),
                                _buildChartCard(
                                  child: _buildDonutChart(totalCash, totalOnline, totalRefunds),
                                ),
                                const SizedBox(height: 20),

                                // Period Trends
                                Row(
                                  children: [
                                    Expanded(child: _buildCompactTrendTile("Total Income", periodIncome, true)),
                                    const SizedBox(width: 10),
                                    Expanded(child: _buildCompactTrendTile("Total Expense", periodExpense, false)),
                                  ],
                                ),
                                const SizedBox(height: 30),
                              ]),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // --- REFINED UI COMPONENTS ---

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        color: kTextSecondary,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildExecutiveRibbon(double revenue, int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border(bottom: BorderSide(color: kBorderColor.withValues(alpha: 0.5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Today's Revenue", style: TextStyle(color: kTextSecondary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
              const SizedBox(height: 2),
              Text("$_currencySymbol${revenue.toStringAsFixed(2)}", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: kPrimaryColor, letterSpacing: -1)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: kPrimaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kPrimaryColor.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                Text("$count", style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w900, fontSize: 16)),
                const Text("Orders", style: TextStyle(color: kTextSecondary, fontSize: 7, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, double value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: kTextSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                Text("${value.toStringAsFixed(0)}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor.withValues(alpha: 0.7)),
      ),
      child: child,
    );
  }

  Widget _buildDurationFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: kBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorderColor),
      ),
      child: DropdownButton<String>(
        value: _selectedDuration,
        underline: const SizedBox(),
        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 14),
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kPrimaryColor),
        items: ['Today', 'Yesterday', 'Last 7 Days or Last Week', 'Last 30 Days', 'This Month', 'Last 3 Months'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: (v) => setState(() => _selectedDuration = v!),
      ),
    );
  }

  Widget _buildCombinedBarChart(Map<int, double> revenue, Map<int, double> expenses) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildSmallLegend(kPrimaryColor, "Income"),
            const SizedBox(width: 12),
            _buildSmallLegend(kExpenseRed, "Expense"),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 140,
          child: BarChart(
            BarChartData(
              gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: kBorderColor.withValues(alpha: 0.15), strokeWidth: 1)),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (v, m) => Text(v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}k' : v.toStringAsFixed(0), style: const TextStyle(fontSize: 8, color: kTextSecondary, fontWeight: FontWeight.bold)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, m) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 8, color: kTextSecondary, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              barGroups: _generateChartGroups(revenue, expenses),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDonutChart(double cash, double online, [double refunds = 0]) {
    double total = cash + online + refunds;
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: SizedBox(
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 30,
                    sections: [
                      if (cash > 0) PieChartSectionData(color: kChartGreen, value: cash, title: '', radius: 15),
                      if (online > 0) PieChartSectionData(color: kChartBlue, value: online, title: '', radius: 15),
                      if (refunds > 0) PieChartSectionData(color: kChartPurple, value: refunds, title: '', radius: 15),
                      if (total == 0) PieChartSectionData(color: kBorderColor, value: 1, title: '', radius: 15),
                    ],
                  ),
                ),
                const Icon(Icons.pie_chart_outline_rounded, color: kTextSecondary, size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 6,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendRow(kChartGreen, "Cash", cash),
              const SizedBox(height: 8),
              _buildLegendRow(kChartBlue, "Online", online),
              if (refunds > 0) ...[
                const SizedBox(height: 8),
                _buildLegendRow(kChartPurple, "Refunds", refunds),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendRow(Color color, String label, double value) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: kTextSecondary, fontWeight: FontWeight.bold))),
        Text("${value.toStringAsFixed(0)}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildSmallLegend(Color color, String label) {
    return Row(
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(1))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: kTextSecondary)),
      ],
    );
  }

  Widget _buildCompactTrendTile(String label, double value, bool isPositive) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: kTextSecondary, fontSize: 9, fontWeight: FontWeight.bold)),
              Icon(isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded, size: 14, color: isPositive ? kIncomeGreen : kExpenseRed),
            ],
          ),
          const SizedBox(height: 4),
          Text("${value.toStringAsFixed(0)}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        ],
      ),
    );
  }

  List<BarChartGroupData> _generateChartGroups(Map<int, double> revenue, Map<int, double> expenses) {
    List<int> days = revenue.keys.toList()..addAll(expenses.keys.toList());
    days = days.toSet().toList()..sort();
    return days.map((day) {
      return BarChartGroupData(
        x: day,
        barRods: [
          BarChartRodData(
            toY: revenue[day] ?? 0,
            color: kChartGreen,
            width: 8,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
          ),
          BarChartRodData(
            toY: expenses[day] ?? 0,
            color: kChartOrange,
            width: 8,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
          ),
        ],
      );
    }).toList();
  }
}

// ==========================================
// 3. DAYBOOK
// ==========================================
class DayBookPage extends StatefulWidget {
  final String uid;
  final VoidCallback onBack;

  const DayBookPage({super.key, required this.uid, required this.onBack});

  @override
  State<DayBookPage> createState() => _DayBookPageState();
}

class _DayBookPageState extends State<DayBookPage> {
  final FirestoreService _firestoreService = FirestoreService();
  DateTime _selectedDate = DateTime.now();
  String _currencySymbol = '';

  // Store data for PDF download
  List<Map<String, dynamic>> _dayBookData = [];
  double _dayBookTotal = 0;
  // Transaction filter for the timeline: All, Cash, Online, Split, Credit

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
  String _txnFilter = 'All';
  final List<String> _txnFilterOptions = ['All', 'Cash', 'Online', 'Split', 'Credit'];

  // Payment mode colors for differentiation
  static const Map<String, Color> _paymentModeColors = {
    'cash': Color(0xFF4CAF50),
    'online': Color(0xFF2196F3),
    'upi': Color(0xFF2196F3),
    'card': Color(0xFF9C27B0),
    'credit': Color(0xFFFF9800),
    'split': Color(0xFF00BCD4),
  };

  Color _getPaymentModeColor(String mode) {
    final m = mode.toLowerCase();
    for (final entry in _paymentModeColors.entries) {
      if (m.contains(entry.key)) return entry.value;
    }
    return const Color(0xFF4CAF50);
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  void _downloadPdf(BuildContext context) {
    if (_dayBookData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data available to download'), backgroundColor: Colors.orange),
      );
      return;
    }

    // Preparing a high-density table for the PDF
    final rows = _dayBookData.map((data) {
      DateTime? dt;
      if (data['timestamp'] != null) {
        if (data['timestamp'] is Timestamp) {
          dt = (data['timestamp'] as Timestamp).toDate();
        } else if (data['timestamp'] is DateTime) {
          dt = data['timestamp'] as DateTime;
        }
      }
      final timeStr = dt != null ? DateFormat('hh:mm a').format(dt) : 'N/A';
      final amount = double.tryParse(data['total']?.toString() ?? '0') ?? 0;
      final category = data['category']?.toString() ?? '';

      return [
        data['particulars']?.toString() ?? '-',
        timeStr,
        data['name']?.toString() ?? 'N/A',
        data['paymentMode']?.toString() ?? 'Cash',
        "${(category == 'Expense' || category == 'Purchase') ? '-' : ''}$_currencySymbol${amount.toStringAsFixed(2)}",
      ];
    }).toList();

    ReportPdfGenerator.generateAndDownloadPdf(
      context: context,
      reportTitle: 'Executive Daybook - ${DateFormat('dd MMMM yyyy').format(_selectedDate)}',
      headers: ['Particulars', 'Time', 'Name', 'Payment', 'Amount'],
      rows: rows,
      summaryTitle: "Day Summary",
      summaryValue: "$_currencySymbol${_dayBookTotal.toStringAsFixed(2)}",
      additionalSummary: {
        'Total Trans.': '${_dayBookData.length}',
        'Date': DateFormat('dd MMM yyyy').format(_selectedDate),
        'Status': 'Closed'
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String selectedDateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: _buildModernAppBar(
          "DayBook",
          widget.onBack,
          onDownload: () => _downloadPdf(context)
      ),
      body: FutureBuilder<List<Stream<QuerySnapshot>>>(
        future: Future.wait([
          _firestoreService.getCollectionStream('sales'),
          _firestoreService.getCollectionStream('expenses'),
          _firestoreService.getCollectionStream('stockPurchases'),
          _firestoreService.getCollectionStream('credits'),
          _firestoreService.getCollectionStream('purchaseCreditNotes'),
          _firestoreService.getCollectionStream('purchasePayments'),
        ]),
        builder: (context, streamsSnapshot) {
          if (!streamsSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: kPrimaryColor, strokeWidth: 2));
          }
          return StreamBuilder<QuerySnapshot>(
            stream: streamsSnapshot.data![0],
            builder: (context, salesSnapshot) {
              return StreamBuilder<QuerySnapshot>(
                stream: streamsSnapshot.data![1],
                builder: (context, expenseSnapshot) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: streamsSnapshot.data![2],
                    builder: (context, purchaseSnapshot) {
                      return StreamBuilder<QuerySnapshot>(
                        stream: streamsSnapshot.data![3],
                        builder: (context, creditsSnapshot) {
                          return StreamBuilder<QuerySnapshot>(
                            stream: streamsSnapshot.data![4],
                            builder: (context, purchaseCreditsSnapshot) {
                              return StreamBuilder<QuerySnapshot>(
                                stream: streamsSnapshot.data![5],
                                builder: (context, purchasePaymentsSnapshot) {
                              if (!salesSnapshot.hasData || !expenseSnapshot.hasData || !purchaseSnapshot.hasData || !creditsSnapshot.hasData || !purchaseCreditsSnapshot.hasData || !purchasePaymentsSnapshot.hasData) {
                                return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                              }

                              // Filter data for selected date
                              final filteredSales = salesSnapshot.data!.docs.where((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                DateTime? dt;
                                if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                                else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());
                                if (dt == null) return false;
                                return DateFormat('yyyy-MM-dd').format(dt) == selectedDateStr;
                              }).toList();

                              final filteredExpenses = expenseSnapshot.data!.docs.where((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                DateTime? dt;
                                if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                                else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());
                                if (dt == null) return false;
                                return DateFormat('yyyy-MM-dd').format(dt) == selectedDateStr;
                              }).toList();

                              final filteredPurchases = purchaseSnapshot.data!.docs.where((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                DateTime? dt;
                                if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                                else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());
                                if (dt == null) return false;
                                return DateFormat('yyyy-MM-dd').format(dt) == selectedDateStr;
                              }).toList();

                              // Filter credits for selected date
                              final filteredCredits = creditsSnapshot.data!.docs.where((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                DateTime? dt;
                                if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                                else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());
                                if (dt == null) return false;
                                return DateFormat('yyyy-MM-dd').format(dt) == selectedDateStr;
                              }).toList();

                              // Filter purchase credits for selected date
                              final filteredPurchaseCredits = purchaseCreditsSnapshot.data!.docs.where((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                DateTime? dt;
                                if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                                else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());
                                if (dt == null) return false;
                                return DateFormat('yyyy-MM-dd').format(dt) == selectedDateStr;
                              }).toList();

                              // Filter purchase credit settlements (from Credit Tracker) for selected date
                              final filteredPurchasePayments = purchasePaymentsSnapshot.data!.docs.where((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                DateTime? dt;
                                if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                                else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());
                                if (dt == null) return false;
                                return DateFormat('yyyy-MM-dd').format(dt) == selectedDateStr;
                              }).toList();

                              // Calculate comprehensive stats
                              int totalSalesCount = 0, totalExpensesCount = 0, totalPurchasesCount = 0;
                              double totalSalesAmount = 0, totalExpensesAmount = 0, totalPurchasesAmount = 0;
                              double saleCreditGiven = 0, saleCreditReceived = 0;
                              double purchaseCreditAdded = 0, purchaseCreditPaid = 0;
                              double additionCredit = 0; // Manual credit additions from customer profile

                              // Payment breakdown
                              double paymentOutCash = 0, paymentOutOnline = 0;
                              double paymentInCash = 0, paymentInOnline = 0;

                              // Build transaction rows
                              List<Map<String, dynamic>> allTransactions = [];
                              final Set<String> seenTxnIds = {}; // prevent duplicates

                              // Process Sales
                              for (var doc in filteredSales) {
                                final data = doc.data() as Map<String, dynamic>;
                                final String status = (data['status'] ?? '').toString().toLowerCase();
                                if (status == 'cancelled' || status == 'returned' || data['hasBeenReturned'] == true) {
                                  continue;
                                }

                                // Deduplicate by doc ID
                                if (seenTxnIds.contains(doc.id)) continue;
                                seenTxnIds.add(doc.id);

                                double total = double.tryParse(data['total']?.toString() ?? '0') ?? 0;
                                String mode = (data['paymentMode'] ?? 'Cash').toString().toLowerCase();

                                totalSalesCount++;
                                totalSalesAmount += total;

                                // Track cash in — handle each payment mode correctly
                                if (mode.contains('split')) {
                                  // Split: read individual cash & online amounts saved in Firestore
                                  final splitCash = double.tryParse(data['cashReceived_split']?.toString() ?? '0') ?? 0;
                                  final splitOnline = double.tryParse(data['onlineReceived_split']?.toString() ?? '0') ?? 0;
                                  final splitCredit = double.tryParse(data['creditIssued_split']?.toString() ?? '0') ?? 0;
                                  paymentInCash += splitCash;
                                  paymentInOnline += splitOnline;
                                  if (splitCredit > 0) saleCreditGiven += splitCredit;
                                } else if (mode.contains('cash')) {
                                  paymentInCash += total;
                                } else if (mode.contains('online') || mode.contains('upi') || mode.contains('card')) {
                                  paymentInOnline += total;
                                } else if (mode.contains('credit')) {
                                  // Credit sale — use creditAmount (new field) or derive from partials
                                  final partialCash = double.tryParse(data['cashReceived_partial']?.toString() ?? '0') ?? 0;
                                  double creditIssued;
                                  if (data['creditAmount'] != null) {
                                    // New field — always present for credit sales
                                    creditIssued = (double.tryParse(data['creditAmount'].toString()) ?? total);
                                  } else if (data['creditIssued_partial'] != null) {
                                    // Partial credit sale (old format)
                                    creditIssued = (double.tryParse(data['creditIssued_partial'].toString()) ?? (total - partialCash));
                                  } else {
                                    // Full credit sale (old format — no partial fields saved)
                                    creditIssued = total;
                                  }
                                  if (partialCash > 0) paymentInCash += partialCash;
                                  saleCreditGiven += creditIssued;
                                }

                                // cashIn = actual cash/online received (not the credit portion)
                                double cashInAmount;
                                if (mode.contains('split')) {
                                  final splitCash = double.tryParse(data['cashReceived_split']?.toString() ?? '0') ?? 0;
                                  final splitOnline = double.tryParse(data['onlineReceived_split']?.toString() ?? '0') ?? 0;
                                  cashInAmount = splitCash + splitOnline;
                                } else if (mode.contains('credit')) {
                                  cashInAmount = double.tryParse(data['cashReceived_partial']?.toString() ?? '0') ?? 0;
                                } else {
                                  cashInAmount = total;
                                }

                                allTransactions.add({
                                  'category': mode.contains('credit') ? 'Sale On Credit' : 'Sale',
                                  'particulars': data['invoiceNumber']?.toString() ?? 'N/A',
                                  'name': data['customerName']?.toString() ?? 'Guest',
                                  'total': total,
                                  'cashIn': cashInAmount,
                                  'cashOut': 0.0,
                                  'timestamp': data['timestamp'],
                                  'paymentMode': mode,
                                });
                              }

                              // Process Credits (for Sale Credit Received and Manual Additions)
                              for (var doc in filteredCredits) {
                                final data = doc.data() as Map<String, dynamic>;
                                final type = (data['type'] ?? '').toString().toLowerCase();
                                final amount = double.tryParse(data['amount']?.toString() ?? '0') ?? 0;
                                final method = (data['method'] ?? 'Cash').toString().toLowerCase();

                                // Skip entries that are payment-log entries created alongside a sale
                                // ('sale_payment' = Cash/Online sale log, 'credit_sale' = credit sale log)
                                // These are already fully counted from the 'sales' collection above.
                                if (type == 'sale_payment' || type == 'credit_sale') continue;

                                // 'payment_received', 'credit_payment', 'settlement' = customer repaid credit
                                if (type.contains('payment_received') || type.contains('credit_payment') || type == 'settlement') {
                                  // Customer paid back credit
                                  saleCreditReceived += amount;

                                  // Track payment method
                                  if (method.contains('cash')) {
                                    paymentInCash += amount;
                                  } else if (method.contains('online') || method.contains('upi') || method.contains('card')) {
                                    paymentInOnline += amount;
                                  }

                                  allTransactions.add({
                                    'category': 'Credit Collected',
                                    'particulars': data['invoiceNumber']?.toString() ?? 'Payment',
                                    'name': data['customerName']?.toString() ?? 'Customer',
                                    'total': amount,
                                    'cashIn': amount,
                                    'cashOut': 0.0,
                                    'timestamp': data['timestamp'],
                                    'paymentMode': method,
                                  });
                                } else if (type == 'add_credit') {
                                  // Manual credit addition from customer profile (store gives credit OUT to customer)
                                  additionCredit += amount;

                                  // Track as Money OUT — store is giving credit to customer
                                  if (method.contains('cash')) {
                                    paymentOutCash += amount;
                                  } else if (method.contains('online') || method.contains('upi') || method.contains('card')) {
                                    paymentOutOnline += amount;
                                  }

                                  allTransactions.add({
                                    'category': 'Manual Credit',
                                    'particulars': data['note']?.toString() ?? 'Manual Credit Entry',
                                    'name': data['customerName']?.toString() ?? 'Customer',
                                    'total': amount,
                                    'cashIn': 0.0,
                                    'cashOut': amount,
                                    'timestamp': data['timestamp'],
                                    'paymentMode': method.isNotEmpty ? method : 'credit',
                                  });
                                }
                              }

                              // Process Purchase Credits
                              for (var doc in filteredPurchaseCredits) {
                                final data = doc.data() as Map<String, dynamic>;
                                final type = (data['type'] ?? '').toString().toLowerCase();
                                final amount = double.tryParse(data['amount']?.toString() ?? '0') ?? 0;
                                final status = (data['status'] ?? '').toString().toLowerCase();
                                final paidAmount = double.tryParse(data['paidAmount']?.toString() ?? '0') ?? 0;

                                // Deduplicate by doc ID
                                if (seenTxnIds.contains(doc.id)) continue;
                                seenTxnIds.add(doc.id);

                                if (type.contains('purchase') || type.contains('expense') || type.isEmpty || doc.reference.path.contains('purchaseCreditNotes')) {
                                  // Purchase on credit
                                  purchaseCreditAdded += amount;

                                  // If there's a paid amount, track it as purchase credit paid
                                  if (paidAmount > 0) {
                                    purchaseCreditPaid += paidAmount;
                                    paymentOutCash += paidAmount; // Assume cash payment

                                    allTransactions.add({
                                      'category': 'Purchase Credit Paid',
                                      'particulars': data['invoiceNumber']?.toString() ?? data['creditNoteNumber']?.toString() ?? '--',
                                      'name': data['supplierName']?.toString() ?? 'Supplier',
                                      'total': paidAmount,
                                      'cashIn': 0.0,
                                      'cashOut': paidAmount,
                                      'timestamp': data['timestamp'],
                                      'paymentMode': 'cash',
                                    });
                                  }

                                  if (amount > paidAmount) {
                                    allTransactions.add({
                                      'category': 'Purchase Credit',
                                      'particulars': data['invoiceNumber']?.toString() ?? data['creditNoteNumber']?.toString() ?? '--',
                                      'name': data['supplierName']?.toString() ?? 'Supplier',
                                      'total': amount - paidAmount,
                                      'cashIn': 0.0,
                                      'cashOut': 0.0,
                                      'timestamp': data['timestamp'],
                                      'paymentMode': 'credit',
                                    });
                                  }
                                }
                              }

                              // Process Purchase Credit Settlements (from Credit Tracker "Settle" action)
                              for (var doc in filteredPurchasePayments) {
                                final data = doc.data() as Map<String, dynamic>;
                                final amount = double.tryParse(data['amount']?.toString() ?? '0') ?? 0;
                                final mode = (data['paymentMode'] ?? 'Cash').toString().toLowerCase();

                                if (seenTxnIds.contains(doc.id)) continue;
                                seenTxnIds.add(doc.id);

                                purchaseCreditPaid += amount;

                                if (mode.contains('cash')) {
                                  paymentOutCash += amount;
                                } else if (mode.contains('online') || mode.contains('upi') || mode.contains('card')) {
                                  paymentOutOnline += amount;
                                }

                                allTransactions.add({
                                  'category': 'Purchase Credit Paid',
                                  'particulars': data['creditNoteNumber']?.toString() ?? '--',
                                  'name': data['supplierName']?.toString() ?? 'Supplier',
                                  'total': amount,
                                  'cashIn': 0.0,
                                  'cashOut': amount,
                                  'timestamp': data['timestamp'],
                                  'paymentMode': mode,
                                });
                              }

                              // Process Expenses
                              for (var doc in filteredExpenses) {
                                final data = doc.data() as Map<String, dynamic>;
                                double amount = double.tryParse(data['amount']?.toString() ?? '0') ?? 0;
                                String mode = (data['paymentMode'] ?? 'Cash').toString().toLowerCase();

                                totalExpensesCount++;
                                totalExpensesAmount += amount;

                                // Track cash out
                                if (mode.contains('cash')) {
                                  paymentOutCash += amount;
                                } else if (mode.contains('online') || mode.contains('upi') || mode.contains('card')) {
                                  paymentOutOnline += amount;
                                }

                                allTransactions.add({
                                  'category': 'Expense',
                                  'particulars': data['expenseType']?.toString() ?? data['category']?.toString() ?? 'Expense',
                                  'name': data['expenseName']?.toString() ?? data['name']?.toString() ?? data['title']?.toString() ?? 'Expense',
                                  'total': amount,
                                  'cashIn': 0.0,
                                  'cashOut': amount,
                                  'timestamp': data['timestamp'],
                                  'paymentMode': mode,
                                });
                              }

                              // Process Purchases
                              for (var doc in filteredPurchases) {
                                final data = doc.data() as Map<String, dynamic>;
                                double amount = double.tryParse(data['totalAmount']?.toString() ?? '0') ?? 0;
                                String mode = (data['paymentMode'] ?? 'Cash').toString().toLowerCase();

                                // Skip credit-mode purchases — they are handled by purchaseCreditNotes loop
                                if (mode.contains('credit')) continue;

                                // Deduplicate by doc ID
                                if (seenTxnIds.contains(doc.id)) continue;
                                seenTxnIds.add(doc.id);

                                totalPurchasesCount++;
                                totalPurchasesAmount += amount;

                                // Track cash out
                                if (mode.contains('cash')) {
                                  paymentOutCash += amount;
                                } else if (mode.contains('online') || mode.contains('upi') || mode.contains('card')) {
                                  paymentOutOnline += amount;
                                }

                                allTransactions.add({
                                  'category': 'Purchase',
                                  'particulars': data['invoiceNumber']?.toString() ?? '--',
                                  'name': data['supplierName']?.toString() ?? 'Supplier',
                                  'total': amount,
                                  'cashIn': 0.0,
                                  'cashOut': amount,
                                  'timestamp': data['timestamp'],
                                  'paymentMode': mode,
                                });
                              }

                              // Sort transactions by time
                              allTransactions.sort((a, b) {
                                DateTime? dtA, dtB;
                                if (a['timestamp'] != null && a['timestamp'] is Timestamp) dtA = (a['timestamp'] as Timestamp).toDate();
                                if (b['timestamp'] != null && b['timestamp'] is Timestamp) dtB = (b['timestamp'] as Timestamp).toDate();
                                if (dtA == null || dtB == null) return 0;
                                return dtA.compareTo(dtB);
                              });

                              // Update state for PDF download
                              _dayBookData = allTransactions;
                              _dayBookTotal = totalSalesAmount;

                              return Column(
                                children: [
                                  // Date Selector

                                  _buildDayBookDateSelector(),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      physics: const BouncingScrollPhysics(),
                                      padding: const EdgeInsets.only(bottom: 100),
                                      child: Column(
                                        children: [
                                          // Summary Cards
                                          _buildDayBookSummaryCards(
                                            totalSalesCount, totalSalesAmount,
                                            totalExpensesCount, totalExpensesAmount,
                                            totalPurchasesCount, totalPurchasesAmount,
                                            saleCreditGiven, saleCreditReceived,
                                            purchaseCreditAdded, purchaseCreditPaid,
                                            additionCredit,
                                            paymentInCash, paymentInOnline,
                                            paymentOutCash, paymentOutOnline,
                                          ),

                                          const SizedBox(height: 20),

                                          // Payment Breakdown
                                          _buildDayBookPaymentBreakdown(
                                            paymentOutCash, paymentOutOnline,
                                            paymentInCash, paymentInOnline,
                                          ),

                                          const SizedBox(height: 20),

                                          // Transaction Timeline
                                          _buildDayBookTransactionTable(allTransactions),

                                          const SizedBox(height: 30),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              );
                                }, // purchasePaymentsSnapshot builder end
                              );   // StreamBuilder purchasePayments end
                            },
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // --- EXECUTIVE UI COMPONENTS ---

  Widget _buildExecutiveKpiHeader(double total, int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border(bottom: BorderSide(color: kBorderColor.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Net Cashflow", style: TextStyle(color: kTextSecondary, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                const SizedBox(height: 2),
                Text("$_currencySymbol${total.toStringAsFixed(2)}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: kPrimaryColor, letterSpacing: -1)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: kBackgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kBorderColor),
            ),
            child: Column(
              children: [
                Text("$count", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: kPrimaryColor)),
                const Text("Invoices", style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: kTextSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactAnalytics(Map<int, double> data) {
    final Map<int, double> activeHours = {};
    for(int i = 7; i <= 22; i++) {
      activeHours[i] = data[i] ?? 0.0;
    }

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Hourly Performance", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 1.2)),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: BarChart(_getProfessionalBarData(activeHours)),
          ),
        ],
      ),
    );
  }

  BarChartData _getProfessionalBarData(Map<int, double> data) {
    return BarChartData(
      barTouchData: BarTouchData(enabled: true),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 5000,
        getDrawingHorizontalLine: (v) => FlLine(color: kBorderColor.withOpacity(0.15), strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            getTitlesWidget: (v, m) {
              if (v == 0) return const SizedBox();
              String text = v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}k' : v.toStringAsFixed(0);
              return Text(text, style: const TextStyle(fontSize: 8, color: kTextSecondary, fontWeight: FontWeight.bold));
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 22,
            getTitlesWidget: (v, m) {
              int h = v.toInt();
              if (h % 3 != 0) return const SizedBox();
              String suffix = h >= 12 ? ' PM' : ' AM';
              int displayHour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
              if (h == 12) displayHour = 12;
              return SideTitleWidget(meta: m, space: 4, child: Text('$displayHour$suffix', style: const TextStyle(fontSize: 7, color: kTextSecondary, fontWeight: FontWeight.w900)));
            },
          ),
        ),
      ),
      barGroups: data.entries.toList().asMap().entries.map((entry) {
        final e = entry.value;
        final colorIndex = entry.key % kChartColorsList.length;
        return BarChartGroupData(
          x: e.key,
          barRods: [
            BarChartRodData(
              toY: e.value,
              color: kChartColorsList[colorIndex],
              width: 8,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
            )
          ],
        );
      }).toList(),
    );
  }

  Widget _buildHighDensityLedgerRow(Map<String, dynamic> data, bool isLast) {
    double saleTotal = double.tryParse(data['total']?.toString() ?? '0') ?? 0;
    double discount = double.tryParse(data['discount']?.toString() ?? '0') ?? 0;
    double tax = double.tryParse(data['totalTax']?.toString() ?? data['taxAmount']?.toString() ?? '0') ?? 0;
    String mode = (data['paymentMode'] ?? 'Cash').toString().toLowerCase();
    String status = (data['status'] ?? '').toString().toLowerCase();
    bool isCancelled = status == 'cancelled';
    bool isReturned = status == 'returned' || data['hasBeenReturned'] == true;

    Color modeColor = kIncomeGreen;
    if (mode.contains('online') || mode.contains('upi') || mode.contains('card')) modeColor = kPrimaryColor;
    else if (mode.contains('credit')) modeColor = kWarningOrange;

    Color statusColor = kIncomeGreen;
    String statusText = 'Completed';
    if (isCancelled) {
      statusColor = kExpenseRed;
      statusText = 'Cancelled';
    } else if (isReturned) {
      statusColor = kWarningOrange;
      statusText = 'Returned';
    }

    DateTime? dt;
    if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
    final timeStr = dt != null ? DateFormat('hh:mm a').format(dt) : '--:--';
    final dateStr = dt != null ? DateFormat('dd MMM').format(dt) : '--/--';

    // Get items list
    List<dynamic> items = data['items'] ?? [];
    int itemCount = items.length;

    // Get customer details
    String customerName = (data['customerName'] ?? 'Guest').toString();
    String customerPhone = (data['customerPhone'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isCancelled || isReturned ? statusColor.withOpacity(0.3) : kBorderColor.withOpacity(0.4)),
        // boxShadow: [
        //   BoxShadow(
        //     color: Colors.black.withOpacity(0.02),
        //     blurRadius: 4,
        //     offset: const Offset(0, 2),
        //   ),
        // ],
      ),
      child: Column(
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: modeColor.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                // Invoice Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: modeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_rounded, size: 14, color: modeColor),
                      const SizedBox(width: 6),
                      Text(
                        '#${data['invoiceNumber'] ?? 'N/A'}',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: modeColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Time Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: kBackgroundColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.access_time_rounded, size: 12, color: kTextSecondary),
                      const SizedBox(width: 4),
                      Text(timeStr, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kTextSecondary)),
                    ],
                  ),
                ),
                const Spacer(),
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: statusColor, letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
          ),

          // Customer & Items Section
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer Info
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: kPrimaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.person_rounded, size: 16, color: kPrimaryColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customerName,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.black87),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (customerPhone.isNotEmpty)
                            Text(
                              customerPhone,
                              style: const TextStyle(fontSize: 10, color: kTextSecondary, fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Items Summary
                if (itemCount > 0) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kBackgroundColor.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kBorderColor.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.shopping_bag_outlined, size: 14, color: kTextSecondary),
                            const SizedBox(width: 6),
                            Text(
                              '$itemCount ITEM${itemCount > 1 ? 'S' : ''}',
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...items.take(3).map((item) {
                          String itemName = item['name']?.toString() ?? 'Item';
                          int qty = int.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
                          double itemPrice = double.tryParse(item['total']?.toString() ?? '0') ?? 0;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: const BoxDecoration(
                                    color: kPrimaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '$itemName × $qty',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  ' ${itemPrice.toStringAsFixed(0)}',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kPrimaryColor),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        if (itemCount > 3)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '+${itemCount - 3} more items...',
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: kTextSecondary, fontStyle: FontStyle.italic),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Financial Details Row
                Row(
                  children: [
                    // Payment Method
                    Expanded(
                      child: _buildDetailTile(
                        icon: mode.contains('online') || mode.contains('upi')
                            ? Icons.credit_card_rounded
                            : mode.contains('credit')
                            ? Icons.event_note_rounded
                            : Icons.money_rounded,
                        label: 'Payment',
                        value: mode,
                        color: modeColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Discount (if any)
                    if (discount > 0)
                      Expanded(
                        child: _buildDetailTile(
                          icon: Icons.local_offer_rounded,
                          label: 'Discount',
                          value: ' ${discount.toStringAsFixed(0)}',
                          color: kWarningOrange,
                        ),
                      ),
                    if (discount > 0) const SizedBox(width: 8),
                    // Tax (if any)
                    if (tax > 0)
                      Expanded(
                        child: _buildDetailTile(
                          icon: Icons.receipt_long_rounded,
                          label: 'Tax',
                          value: ' ${tax.toStringAsFixed(0)}',
                          color: kIncomeGreen,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Footer with Total
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: modeColor.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border(
                top: BorderSide(color: kBorderColor.withOpacity(0.3)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Amount',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.8),
                ),
                Text(
                  '$_currencySymbol${saleTotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isCancelled || isReturned ? Colors.grey : modeColor,
                    letterSpacing: -0.5,
                    decoration: isCancelled || isReturned ? TextDecoration.lineThrough : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailTile({required IconData icon, required String label, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 10, color: color),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.3)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // --- MODERN DAYBOOK UI COMPONENTS ---

// =====================================================
//  COMPLETELY REDESIGNED UI BODY SECTION
//  AppBar (_buildModernAppBar) is NOT changed.
// =====================================================

// ─── DATE SELECTOR ───────────────────────────────────
  Widget _buildDayBookDateSelector() {
    final isToday = DateFormat('yyyy-MM-dd').format(_selectedDate) ==
        DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          // Prev Day
          _buildNavArrowButton(
            icon: Icons.chevron_left_rounded,
            onTap: () {
              setState(() {
                _selectedDate = _selectedDate.subtract(const Duration(days: 1));
              });
            },
          ),
          const SizedBox(width: 10),

          // Date Pill (center)
          Expanded(
            child: GestureDetector(
              onTap: () => _selectDate(context),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: kSurfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kPrimaryColor.withOpacity(0.25)),
                  // boxShadow: [
                  //   BoxShadow(
                  //     color: kPrimaryColor.withOpacity(0.06),
                  //     blurRadius: 8,
                  //     offset: const Offset(0, 3),
                  //   ),
                  // ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 16, color: kPrimaryColor),
                    const SizedBox(width: 8),
                    Text(
                      isToday
                          ? 'Today — ${DateFormat('dd MMM yyyy').format(_selectedDate)}'
                          : DateFormat('EEE, dd MMM yyyy').format(_selectedDate),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 18, color: kPrimaryColor),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),
          // Next Day
          _buildNavArrowButton(
            icon: Icons.chevron_right_rounded,
            onTap: _selectedDate.isBefore(DateTime.now())
                ? () {
              setState(() {
                _selectedDate =
                    _selectedDate.add(const Duration(days: 1));
              });
            }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildNavArrowButton(
      {required IconData icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: onTap != null ? kPrimaryColor.withOpacity(0.1) : kBorderColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: onTap != null
                  ? kPrimaryColor.withOpacity(0.3)
                  : kBorderColor),
        ),
        child: Icon(icon,
            color: onTap != null ? kPrimaryColor : kTextSecondary, size: 22),
      ),
    );
  }

// ─── SUMMARY CARDS ────────────────────────────────────
  Widget _buildDayBookSummaryCards(
      int salesCount,
      double salesAmount,
      int expensesCount,
      double expensesAmount,
      int purchasesCount,
      double purchasesAmount,
      double saleCreditGiven,
      double saleCreditReceived,
      double purchaseCreditAdded,
      double purchaseCreditPaid,
      double additionCredit,
      double paymentInCash,
      double paymentInOnline,
      double paymentOutCash,
      double paymentOutOnline,
      ) {
    // Net cashflow based on actual cash received/paid (excludes credit given which hasn't been received yet)
    final actualMoneyIn = paymentInCash + paymentInOnline;
    final actualMoneyOut = paymentOutCash + paymentOutOnline;
    final netCashFlow = actualMoneyIn - actualMoneyOut;
    final isPositive = netCashFlow >= 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // ── Net Cashflow banner ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: isPositive
                  ? kGoogleGreen
                  : kGoogleRed,
              borderRadius: BorderRadius.circular(18),
              // boxShadow: [
              //   BoxShadow(
              //     color: (isPositive
              //         ? kGoogleGreen
              //         : kGoogleRed)
              //         .withOpacity(0.25),
              //     blurRadius: 16,
              //     offset: const Offset(0, 6),
              //   ),
              // ],
            ),
            child: Row(
              children: [
                // Icon bubble
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isPositive
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPositive ? 'Actual Cash Flow (In)' : 'Actual Cash Flow (Out)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withOpacity(0.75),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_currencySymbol${netCashFlow.abs().toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (saleCreditGiven > 0)
                        Text(
                          'Total Sales: $_currencySymbol${salesAmount.toStringAsFixed(2)} (incl. $_currencySymbol${saleCreditGiven.toStringAsFixed(2)} credit)',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                    ],
                  ),
                ),
                // Count badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$salesCount',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Sales',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── 2×2 metric grid ──
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'Sales',
                  amount: salesAmount,
                  count: salesCount,
                  icon: Icons.point_of_sale_rounded,
                  iconBg: const Color(0xFFE8F5E9),
                  iconColor: kGoogleGreen,
                  amountColor: kGoogleGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  label: 'Expenses',
                  amount: expensesAmount,
                  count: expensesCount,
                  icon: Icons.shopping_cart_outlined,
                  iconBg: const Color(0xFFFFEBEE),
                  iconColor: kGoogleRed,
                  amountColor: kGoogleRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'Purchases',
                  amount: purchasesAmount,
                  count: purchasesCount,
                  icon: Icons.inventory_2_outlined,
                  iconBg: const Color(0xFFFFEBEE),
                  iconColor: kGoogleRed,
                  amountColor: kGoogleRed,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  label: 'Credit',
                  amount: saleCreditGiven + purchaseCreditAdded,
                  count: 0,
                  icon: Icons.account_balance_wallet_outlined,
                  iconBg: const Color(0xFFFFF3E0),
                  iconColor: kWarningOrange,
                  amountColor: kWarningOrange,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Credit breakdown table ──
          Container(
            decoration: BoxDecoration(
              color: kSurfaceColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kBorderColor.withOpacity(0.4)),
            ),
            child: Column(
              children: [
                _buildCreditDetailRow(
                    'Sale On Credit', saleCreditGiven,
                    Icons.arrow_upward_rounded, kGoogleGreen),
                _divider(),
                _buildCreditDetailRow(
                    'Credit Collected', saleCreditReceived,
                    Icons.arrow_downward_rounded, kGoogleGreen),
                _divider(),
                _buildCreditDetailRow(
                    'Manual Credit', additionCredit,
                    Icons.add_card_outlined, kWarningOrange),
                _divider(),
                _buildCreditDetailRow(
                    'Purchase Credit', purchaseCreditAdded,
                    Icons.add_rounded, kGoogleRed),
                _divider(),
                _buildCreditDetailRow(
                  'Purchase Credit Paid', purchaseCreditPaid,
                  Icons.check_rounded, kGoogleRed,
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() =>
      Divider(height: 1, thickness: 0.8, color: kBorderColor.withOpacity(0.3));

  Widget _buildMetricTile({
    required String label,
    required double amount,
    required int count,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required Color amountColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: iconColor.withOpacity(0.15)),

      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: iconBg, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              if (count > 0)
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: iconColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: kTextSecondary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '$_currencySymbol${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditDetailRow(
      String label, double amount, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Text(
            '$_currencySymbol${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

// ─── PAYMENT BREAKDOWN ────────────────────────────────
  Widget _buildDayBookPaymentBreakdown(
      double outCash, double outOnline, double inCash, double inOnline) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: kSurfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorderColor.withOpacity(0.35)),
          // boxShadow: [
          //   BoxShadow(
          //       color: Colors.black.withOpacity(0.04),
          //       blurRadius: 8,
          //       offset: const Offset(0, 3))
          // ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: kPrimaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.payments_outlined,
                      color: kPrimaryColor, size: 20),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Payment Breakdown',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // In / Out rows
            _buildBreakdownSection(
              title: 'Money IN',
              cash: inCash,
              online: inOnline,
              color: kGoogleGreen,
              icon: Icons.south_west_rounded,
            ),
            const SizedBox(height: 14),
            _buildBreakdownSection(
              title: 'Money OUT',
              cash: outCash,
              online: outOnline,
              color: kGoogleRed,
              icon: Icons.north_east_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownSection({
    required String title,
    required double cash,
    required double online,
    required Color color,
    required IconData icon,
  }) {
    final total = cash + online;
    final cashPct = total > 0 ? (cash / total) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(title,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: 0.4)),
            const Spacer(),
            Text(
              '$_currencySymbol${total.toStringAsFixed(2)}',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w900, color: color),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Segmented bar
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Row(
            children: [
              Flexible(
                flex: (cashPct * 100).round(),
                child: Container(height: 8, color: color),
              ),
              Flexible(
                flex: ((1 - cashPct) * 100).round(),
                child: Container(height: 8, color: color.withOpacity(0.25)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildPaymentChip('Cash', cash, color),
            const SizedBox(width: 10),
            _buildPaymentChip('Online', online, color.withOpacity(0.6)),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentChip(String label, double amount, Color color) {
    return Row(
      children: [
        Container(
            width: 8, height: 8,
            decoration:
            BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(
          '$label  $_currencySymbol${amount.toStringAsFixed(0)}',
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: kTextSecondary),
        ),
      ],
    );
  }

// ─── TRANSACTION TIMELINE TABLE ───────────────────────
  Widget _buildDayBookTransactionTable(
      List<Map<String, dynamic>> transactions) {
    final filteredTransactions = transactions.where((txn) {
      if (_txnFilter == 'All') return true;
      final pm = (txn['paymentMode'] ?? '').toString().toLowerCase();
      final category = txn['category']?.toString().toLowerCase() ?? '';
      switch (_txnFilter) {
        case 'Cash':
          return pm.contains('cash');
        case 'Online':
          return pm.contains('online') ||
              pm.contains('upi') ||
              pm.contains('card');
        case 'Split':
          return pm.contains('split');
        case 'Credit':
          return pm.contains('credit') || category.contains('credit');
        default:
          return true;
      }
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            children: [
              const Text(
                'Transactions',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${filteredTransactions.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: kPrimaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Filter chips ──
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _txnFilterOptions.map((opt) {
                final selected = _txnFilter == opt;
                return GestureDetector(
                  onTap: () => setState(() => _txnFilter = opt),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? kPrimaryColor : kSurfaceColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? kPrimaryColor
                            : kBorderColor.withOpacity(0.5),
                      ),
                    ),
                    child: Text(
                      opt,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : kPrimaryColor,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),

          // ── List / Empty state ──
          if (filteredTransactions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(Icons.inbox_rounded,
                        size: 52, color: kTextSecondary.withOpacity(0.25)),
                    const SizedBox(height: 12),
                    Text(
                      _txnFilter == 'All'
                          ? 'No transactions for this date'
                          : 'No $_txnFilter transactions',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: kTextSecondary),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredTransactions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) =>
                  _buildDayBookTransactionCard(filteredTransactions[index]),
            ),
        ],
      ),
    );
  }

// ─── SINGLE TRANSACTION CARD ──────────────────────────
  Widget _buildDayBookTransactionCard(Map<String, dynamic> txn) {
    final category = txn['category'].toString();
    final paymentMode = (txn['paymentMode'] ?? 'cash').toString();

    DateTime? dt;
    if (txn['timestamp'] != null)
      dt = (txn['timestamp'] as Timestamp).toDate();
    final timeStr = dt != null ? DateFormat('hh:mm a').format(dt) : 'N/A';

    // Per-category theming
    Color accent;
    IconData categoryIcon;
    switch (category) {
      case 'Sale':
        accent = kGoogleGreen;
        categoryIcon = Icons.point_of_sale_rounded;
        break;
      case 'Expense':
        accent = kGoogleRed;
        categoryIcon = Icons.shopping_cart_outlined;
        break;
      case 'Purchase':
        accent = kGoogleRed;
        categoryIcon = Icons.inventory_2_outlined;
        break;
      case 'Credit Collected':
      case 'Credit Received':
        accent = kGoogleGreen;
        categoryIcon = Icons.account_balance_wallet_outlined;
        break;
      case 'Sale On Credit':
        accent = kGoogleGreen;
        categoryIcon = Icons.credit_score_outlined;
        break;
      case 'Manual Credit':
        accent = kWarningOrange;
        categoryIcon = Icons.add_card_outlined;
        break;
      case 'Purchase Credit':
      case 'Purchase Credit Paid':
        accent = kGoogleRed;
        categoryIcon = Icons.credit_card_outlined;
        break;
      default:
        accent = kGoogleGreen;
        categoryIcon = Icons.point_of_sale_rounded;
    }

    final isIncome = category == 'Sale' || category == 'Credit Collected' || category == 'Credit Received' || category == 'Sale On Credit' || category == 'Manual Credit';
    final amount = (txn['total'] as double);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          // Left icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(categoryIcon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),

          // Middle: name / ref / mode
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  txn['name'].toString(),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  txn['particulars'].toString(),
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: kTextSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    // Category tag
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: accent.withOpacity(0.2)),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: accent,
                            letterSpacing: 0.5),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Payment mode
                    Text(
                      paymentMode,
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: kTextSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Right: time + amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                timeStr,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: kTextSecondary),
              ),
              const SizedBox(height: 6),
              Text(
                '${isIncome ? '+' : '-'}$_currencySymbol${amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: isIncome ? kGoogleGreen : kGoogleRed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

}

// ==========================================
// 4. SALES SUMMARY (Enhanced with all features from screenshot)
// ==========================================
class SalesSummaryPage extends StatefulWidget {
  final VoidCallback onBack;

  const SalesSummaryPage({super.key, required this.onBack});

  @override
  State<SalesSummaryPage> createState() => _SalesSummaryPageState();
}

class _SalesSummaryPageState extends State<SalesSummaryPage> {
  final FirestoreService _firestoreService = FirestoreService();
  DateFilterOption _selectedFilter = DateFilterOption.today;
  String _currencySymbol = '';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadCurrency();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
  }

  void _loadCurrency() async {
    final store = await FirestoreService().getCurrentStoreDoc();
    if (store != null && store.exists && mounted) {
      final data = store.data() as Map<String, dynamic>;
      setState(() => _currencySymbol = CurrencyService.getSymbolWithSpace(data['currency']));
    }
  }

  void _onDateChanged(DateFilterOption option, DateTime start, DateTime end) {
    setState(() {
      _selectedFilter = option;
      _startDate = start;
      _endDate = end;
    });
  }

  bool _isInDateRange(DateTime? dt) {
    if (dt == null) return false;
    return dt.isAfter(_startDate.subtract(const Duration(seconds: 1))) &&
        dt.isBefore(_endDate.add(const Duration(seconds: 1)));
  }

  // Store calculated data for PDF download
  double _grossSale = 0, _discount = 0, _netSale = 0, _productCost = 0;
  double _cash = 0, _online = 0, _creditNote = 0, _credit = 0, _unsettled = 0, _refunds = 0;
  int _saleCount = 0;

  void _downloadPdf(BuildContext context) {
    final rows = [
      ['Gross Sales', '$_currencySymbol${_grossSale.toStringAsFixed(2)}'],
      ['Discount', '$_currencySymbol${_discount.toStringAsFixed(2)}'],
      ['Net Sales', '$_currencySymbol${_netSale.toStringAsFixed(2)}'],
      ['Product Cost', '$_currencySymbol${_productCost.toStringAsFixed(2)}'],
      ['Cash', '$_currencySymbol${_cash.toStringAsFixed(2)}'],
      ['Online', '$_currencySymbol${_online.toStringAsFixed(2)}'],
      ['Credit Note/Refunds', '$_currencySymbol${_creditNote.toStringAsFixed(2)}'],
      ['Credit', '$_currencySymbol${_credit.toStringAsFixed(2)}'],
      ['Unsettled', '$_currencySymbol${_unsettled.toStringAsFixed(2)}'],
    ];

    ReportPdfGenerator.generateAndDownloadPdf(
      context: context,
      reportTitle: 'Financial Insights Report',
      headers: ['Metric', 'Amount'],
      rows: rows,
      summaryTitle: "Net Profit",
      summaryValue: "$_currencySymbol${(_netSale - _productCost).toStringAsFixed(2)}",
      additionalSummary: {
        'Period': '${DateFormat('dd/MM/yy').format(_startDate)} - ${DateFormat('dd/MM/yy').format(_endDate)}',
        'Total Bills': '$_saleCount',
        'Refunds': '$_currencySymbol${_refunds.toStringAsFixed(2)}',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: _buildModernAppBar("Sales Report", widget.onBack, onDownload: () => _downloadPdf(context)),
      body: FutureBuilder<List<Stream<QuerySnapshot>>>(
        future: Future.wait([
          _firestoreService.getCollectionStream('sales'),
          _firestoreService.getCollectionStream('expenses'),
        ]),
        builder: (context, streamsSnapshot) {
          if (!streamsSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: kPrimaryColor, strokeWidth: 2));
          }
          return StreamBuilder<QuerySnapshot>(
            stream: streamsSnapshot.data![0],
            builder: (context, salesSnapshot) {
              return StreamBuilder<QuerySnapshot>(
                stream: streamsSnapshot.data![1],
                builder: (context, expenseSnapshot) {
                  if (!salesSnapshot.hasData || !expenseSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                  }

                  // --- Calculation Logic ---
                  double grossSale = 0, discount = 0, netSale = 0, productCost = 0;
                  double cash = 0, online = 0, creditNote = 0, credit = 0, unsettled = 0;
                  double refunds = 0; // Track cancelled/returned bills
                  Map<int, double> hourlyRevenue = {};
                  int saleCount = 0;

                  for (var doc in salesSnapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    DateTime? dt;
                    if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                    else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());

                    if (_isInDateRange(dt)) {
                      double total = double.tryParse(data['total']?.toString() ?? '0') ?? 0;
                      double discountAmt = double.tryParse(data['discount']?.toString() ?? '0') ?? 0;
                      // Compute sale-level total cost: prefer item-level total cost (unit cost * qty) so
                      // profit reflects the Total Cost Price. If item-level costs are not available,
                      // fall back to the sale document's `productCost` (which may already be the total).
                      double saleCost = 0;
                      if (data['items'] != null && data['items'] is List) {
                        try {
                          for (var it in (data['items'] as List)) {
                            double unitCost = double.tryParse(
                                it['cost']?.toString() ?? it['costPrice']?.toString() ?? it['purchasePrice']?.toString() ?? '0') ?? 0;
                            double qty = double.tryParse(it['quantity']?.toString() ?? '0') ?? 0;
                            saleCost += unitCost * qty;
                          }
                        } catch (e) {
                          // ignore malformed item entries and keep saleCost as 0 so fallback is used
                          saleCost = 0;
                        }
                      }
                      // Fallback: use sale-level productCost if item-level data didn't provide totals.
                      if (saleCost == 0) {
                        saleCost = double.tryParse(data['productCost']?.toString() ?? '0') ?? 0;
                      }
                      String mode = (data['paymentMode'] ?? 'Cash').toString().toLowerCase();

                      // Check if bill is cancelled or returned
                      final String status = (data['status'] ?? '').toString().toLowerCase();
                      final bool isCancelled = status == 'cancelled';
                      final bool isReturned = status == 'returned' || data['hasBeenReturned'] == true;
                      final bool isRefunded = isCancelled || isReturned;

                      if (isRefunded) {
                        // Add to refunds instead of regular sales
                        refunds += total;
                        continue; // Skip adding to other totals
                      }

                      grossSale += total + discountAmt;
                      discount += discountAmt;
                      netSale += total;
                      productCost += saleCost;
                      saleCount++;

                      // Handle Split payments separately
                      if (mode == 'split') {
                        // For split payments, get the individual amounts
                        double splitCash = double.tryParse(data['cashReceived_split']?.toString() ?? '0') ?? 0;
                        double splitOnline = double.tryParse(data['onlineReceived_split']?.toString() ?? '0') ?? 0;
                        double splitCredit = double.tryParse(data['creditIssued_split']?.toString() ?? '0') ?? 0;
                        cash += splitCash;
                        online += splitOnline;
                        credit += splitCredit;
                      } else if (mode.contains('online') || mode.contains('upi') || mode.contains('card')) {
                        online += total;
                      } else if (mode.contains('credit') && mode.contains('note')) {
                        creditNote += total;
                      } else if (mode.contains('credit')) {
                        credit += total;
                      } else if (mode.contains('unsettled')) {
                        unsettled += total;
                      } else {
                        // Cash payment
                        cash += total;
                      }

                      if (dt != null) hourlyRevenue[dt.hour] = (hourlyRevenue[dt.hour] ?? 0) + total;
                    }
                  }

                  // Add refunds to creditNote for display (purple section)
                  creditNote += refunds;

                  // If productCost (from sale document) looks too small (e.g., it's zero because cost wasn't set on Add Product),
                  // we'll still show profit as netSale - productCost. Detailed per-item profit is computed in Product Summary.
                  double profit = netSale - productCost;

                  // Store values for PDF download
                  _grossSale = grossSale;
                  _discount = discount;
                  _netSale = netSale;
                  _productCost = productCost;
                  _cash = cash;
                  _online = online;
                  _creditNote = creditNote;
                  _credit = credit;
                  _unsettled = unsettled;
                  _refunds = refunds;
                  _saleCount = saleCount;

                  return CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: DateFilterWidget(
                          selectedOption: _selectedFilter,
                          startDate: _startDate,
                          endDate: _endDate,
                          onDateChanged: _onDateChanged,
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            // Bill Count & Average strip
                            _buildBillSummaryStrip(saleCount, netSale),
                            const SizedBox(height: 16),

                            // Profit Performance Card
                            _buildExecutiveProfitCard(profit, netSale, productCost),
                            const SizedBox(height: 16),

                            // Sales Breakdown
                            _buildSalesBreakdownSection(netSale, grossSale, productCost, discount, saleCount),

                            const SizedBox(height: 20),
                            _buildSectionLabel("Revenue Timeline"),
                            const SizedBox(height: 8),
                            _buildRevenueTimelineCard(hourlyRevenue),

                            const SizedBox(height: 20),
                            _buildSectionLabel("Payment Structure"),
                            const SizedBox(height: 8),
                            _buildPaymentStructureCard(netSale, cash, online, creditNote, credit, unsettled),
                            const SizedBox(height: 30),
                          ]),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // --- MODERN UI COMPONENTS (matching Business Insights theme) ---

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        color: kTextSecondary,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildBillSummaryStrip(int count, double netSale) {
    final avg = count > 0 ? netSale / count : 0.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.receipt_long_rounded, color: kPrimaryColor, size: 16),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Total Bills", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 1)),
                    Text("$count", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kTextPrimary)),
                  ],
                ),
              ],
            ),
          ),
          Container(width: 1, height: 30, color: kBorderColor),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("Avg Bill Value", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 1)),
                    Text(
                      "${CurrencyService().symbol}${avg.toStringAsFixed(0)}",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kTextPrimary),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kIncomeGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.trending_up_rounded, color: kIncomeGreen, size: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExecutiveProfitCard(double profit, double netSale, double cost) {
    final margin = netSale > 0 ? (profit / netSale) * 100 : 0.0;
    final bool isPositive = profit >= 0;

    String performanceLabel;
    Color performanceColor;
    IconData performanceIcon;
    if (isPositive) {
      if (margin > 50) {
        performanceLabel = "Excellent";
        performanceColor = kIncomeGreen;
        performanceIcon = Icons.trending_up_rounded;
      } else if (margin > 20) {
        performanceLabel = "Good";
        performanceColor = kIncomeGreen;
        performanceIcon = Icons.trending_up_rounded;
      } else {
        performanceLabel = "Average";
        performanceColor = kWarningOrange;
        performanceIcon = Icons.trending_flat_rounded;
      }
    } else {
      performanceLabel = "Loss";
      performanceColor = kExpenseRed;
      performanceIcon = Icons.trending_down_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor.withValues(alpha: 0.5)),
        // boxShadow: [
        //   BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        // ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text("Estimated Profit", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 1.2)),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Row(children: [Icon(Icons.info_outline, color: kIncomeGreen), SizedBox(width: 8), Expanded(child: Text('About Estimated Profit'))]),
                          content: const Text('Profit is calculated based on the Total Cost Price'),
                          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
                        ),
                      );
                    },
                    child: const Icon(Icons.info_outline, color: kTextSecondary, size: 13),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: performanceColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(performanceIcon, size: 14, color: performanceColor),
                    const SizedBox(width: 4),
                    Text(performanceLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: performanceColor)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: kIncomeGreen, borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 6),
                        const Text("Net Sale", style: TextStyle(fontSize: 11, color: kTextSecondary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${CurrencyService().symbol}${netSale.toStringAsFixed(0)}",
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: kIncomeGreen, letterSpacing: -0.5),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: kExpenseRed, borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 6),
                        const Text("Cost Value", style: TextStyle(fontSize: 11, color: kTextSecondary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${CurrencyService().symbol}${cost.toStringAsFixed(0)}",
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: kExpenseRed, letterSpacing: -0.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  Expanded(
                    flex: netSale > 0 ? netSale.toInt().clamp(1, 999999) : 1,
                    child: Container(color: kIncomeGreen),
                  ),
                  Expanded(
                    flex: cost > 0 ? cost.toInt().clamp(1, 999999) : 1,
                    child: Container(color: kExpenseRed),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Net profit result
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: (isPositive ? kIncomeGreen : kExpenseRed).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                      size: 16,
                      color: isPositive ? kIncomeGreen : kExpenseRed,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Profit: ${CurrencyService().symbol}${profit.toStringAsFixed(0)}",
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: isPositive ? kIncomeGreen : kExpenseRed),
                    ),
                  ],
                ),
                Text(
                  "${margin.abs().toStringAsFixed(1)}% margin",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: isPositive ? kIncomeGreen : kExpenseRed),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesBreakdownSection(double net, double gross, double cost, double disc, int count) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel("Sales Breakdown"),
        const SizedBox(height: 8),
        _buildBreakdownRow("Gross Sales", gross, kIncomeGreen, Icons.arrow_upward_rounded, net),
        const SizedBox(height: 6),
        _buildBreakdownRow("Net Revenue", net, kIncomeGreen, Icons.arrow_upward_rounded, net),
        const SizedBox(height: 6),
        _buildBreakdownRow("Cost Value", cost, kExpenseRed, Icons.arrow_downward_rounded, net),
        const SizedBox(height: 6),
        _buildBreakdownRow("Discounts", disc, kWarningOrange, Icons.arrow_downward_rounded, net),
      ],
    );
  }

  Widget _buildBreakdownRow(String label, double value, Color color, IconData icon, double total) {
    final pct = total > 0 ? (value / total * 100) : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextPrimary)),
          ),
          Text(
            "${CurrencyService().symbol}${value.toStringAsFixed(0)}",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "${pct.toStringAsFixed(0)}%",
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueTimelineCard(Map<int, double> data) {
    // Find peak hour
    int peakHour = 0;
    double peakVal = 0;
    double totalRev = 0;
    data.forEach((h, v) {
      totalRev += v;
      if (v > peakVal) {
        peakVal = v;
        peakHour = h;
      }
    });
    String peakLabel = peakHour > 0
        ? '${peakHour > 12 ? peakHour - 12 : (peakHour == 0 ? 12 : peakHour)}${peakHour >= 12 ? 'PM' : 'AM'}'
        : '--';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor.withValues(alpha: 0.5)),
        // boxShadow: [
        //   BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        // ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: kPrimaryColor, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 6),
                  const Text("Hourly Revenue", style: TextStyle(fontSize: 10, color: kTextSecondary, fontWeight: FontWeight.w600)),
                ],
              ),
              Text("Peak: $peakLabel", style: const TextStyle(fontSize: 10, color: kTextSecondary, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 150,
            child: data.isEmpty
                ? const Center(child: Text('No data', style: TextStyle(color: kTextSecondary, fontSize: 12)))
                : BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) => FlLine(color: kBorderColor.withValues(alpha: 0.4), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (v, m) {
                        int h = v.toInt();
                        if (h % 4 != 0) return const SizedBox();
                        String label = '${h > 12 ? h - 12 : (h == 0 ? 12 : h)}${h >= 12 ? 'pm' : 'am'}';
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(label, style: const TextStyle(fontSize: 9, color: kTextSecondary, fontWeight: FontWeight.w700)),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (v, m) {
                        if (v == 0) return const SizedBox();
                        String label;
                        if (v >= 1000) {
                          label = '${(v / 1000).toStringAsFixed(0)}K';
                        } else {
                          label = v.toStringAsFixed(0);
                        }
                        return Text(label, style: const TextStyle(fontSize: 8, color: kTextSecondary, fontWeight: FontWeight.w600));
                      },
                    ),
                  ),
                ),
                barGroups: data.entries.map((e) {
                  final isPeak = e.key == peakHour && peakVal > 0;
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value,
                        color: isPeak ? kIncomeGreen : kPrimaryColor.withValues(alpha: 0.6),
                        width: 8,
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                      )
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Summary below chart
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kPrimaryColor.withValues(alpha: 0.12)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Total Revenue", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kTextSecondary)),
                      const SizedBox(height: 2),
                      Text("${CurrencyService().symbol}${totalRev.toStringAsFixed(0)}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: kPrimaryColor)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: kIncomeGreen.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kIncomeGreen.withValues(alpha: 0.12)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Peak Hour", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kTextSecondary)),
                      const SizedBox(height: 2),
                      Text("${CurrencyService().symbol}${peakVal.toStringAsFixed(0)}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: kIncomeGreen)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentStructureCard(double net, double cash, double online, double cn, double credit, double unsettled) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor.withValues(alpha: 0.5)),
        // boxShadow: [
        //   BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        // ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.pie_chart_outline_rounded, color: kTextSecondary, size: 14),
                    SizedBox(width: 6),
                    Text("Payment Breakdown", style: TextStyle(fontSize: 10, color: kTextSecondary, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Text("${CurrencyService().symbol}${net.toStringAsFixed(0)}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: kTextPrimary)),
            ],
          ),
          const SizedBox(height: 14),
          // Donut chart + legend
          Row(
            children: [
              Expanded(
                flex: 4,
                child: SizedBox(
                  height: 130,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 3,
                          centerSpaceRadius: 32,
                          sections: [
                            if (cash > 0) PieChartSectionData(color: kIncomeGreen, value: cash, title: '', radius: 14),
                            if (online > 0) PieChartSectionData(color: kChartBlue, value: online, title: '', radius: 14),
                            if (cn > 0) PieChartSectionData(color: kChartPurple, value: cn, title: '', radius: 14),
                            if (credit > 0) PieChartSectionData(color: kWarningOrange, value: credit, title: '', radius: 14),
                            if (unsettled > 0) PieChartSectionData(color: kChartAmber, value: unsettled, title: '', radius: 14),
                            if (net == 0) PieChartSectionData(color: kBorderColor.withValues(alpha: 0.3), value: 1, title: '', radius: 14),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("${CurrencyService().symbol}${net.toStringAsFixed(0)}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: kTextPrimary)),
                          const Text("Total", style: TextStyle(fontSize: 8, color: kTextSecondary, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 6,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLegendRow(kIncomeGreen, 'Cash', cash, net),
                    _buildLegendRow(kChartBlue, 'Online', online, net),
                    _buildLegendRow(kChartPurple, 'Refunds', cn, net),
                    _buildLegendRow(kWarningOrange, 'Credit', credit, net),
                    if (unsettled > 0) _buildLegendRow(kChartAmber, 'Unsettled', unsettled, net),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 12),
          // Net summary strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: kIncomeGreen.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_rounded, size: 14, color: kIncomeGreen),
                    const SizedBox(width: 6),
                    Text("Cash + Online collected", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kIncomeGreen)),
                  ],
                ),
                Text(
                  "${CurrencyService().symbol}${(cash + online).toStringAsFixed(0)}",
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: kIncomeGreen),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendRow(Color color, String label, double value, double total) {
    final pct = total > 0 ? (value / total * 100) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 10, color: kTextSecondary, fontWeight: FontWeight.w600))),
          Text("${value.toStringAsFixed(0)}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kTextPrimary)),
          const SizedBox(width: 6),
          Text("${pct.toStringAsFixed(0)}%", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

// ==========================================
// 5. FULL SALES REPORT
// ==========================================
class FullSalesHistoryPage extends StatefulWidget {
  final VoidCallback onBack;

  const FullSalesHistoryPage({super.key, required this.onBack});

  @override
  State<FullSalesHistoryPage> createState() => _FullSalesHistoryPageState();
}

class _FullSalesHistoryPageState extends State<FullSalesHistoryPage> {
  final FirestoreService _firestoreService = FirestoreService();

  String _searchQuery = '';
  String _statusFilter = 'All'; // All, Active, Cancelled, Returned
  String _sortBy = 'date'; // date, amount, invoice, customer
  bool _isDescending = true;
  DateFilterOption _selectedFilter = DateFilterOption.last30Days;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  static const Map<String, String> _sortLabels = {
    'date': 'Date',
    'amount': 'Amount',
    'invoice': 'Invoice No.',
    'customer': 'Customer',
  };

  static const List<String> _statusOptions = ['All', 'Active', 'Cancelled', 'Returned'];

  void _onDateChanged(DateFilterOption option, DateTime start, DateTime end) {
    setState(() {
      _selectedFilter = option;
      _startDate = start;
      _endDate = end;
    });
  }

  bool _isInDateRange(DateTime? dt) {
    if (dt == null) return false;
    return dt.isAfter(_startDate.subtract(const Duration(seconds: 1))) &&
        dt.isBefore(_endDate.add(const Duration(seconds: 1)));
  }

  List<Map<String, dynamic>> _applyFilters(List<DocumentSnapshot> docs) {
    List<Map<String, dynamic>> result = [];
    for (var doc in docs) {
      final d = doc.data() as Map<String, dynamic>;
      final String status = (d['status'] ?? '').toString().toLowerCase();
      final bool isCancelled = status == 'cancelled';
      final bool isReturned = status == 'returned' || d['hasBeenReturned'] == true;

      // Status filter
      if (_statusFilter == 'Active' && (isCancelled || isReturned)) continue;
      if (_statusFilter == 'Cancelled' && !isCancelled) continue;
      if (_statusFilter == 'Returned' && !isReturned) continue;

      // Date filter
      DateTime? dt;
      if (d['timestamp'] != null) dt = (d['timestamp'] as Timestamp).toDate();
      else if (d['date'] != null) dt = DateTime.tryParse(d['date'].toString());
      if (!_isInDateRange(dt)) continue;

      // Search filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final customer = (d['customerName'] ?? '').toString().toLowerCase();
        final invoice = (d['invoiceNumber'] ?? '').toString().toLowerCase();
        final mode = (d['paymentMode'] ?? '').toString().toLowerCase();
        if (!customer.contains(q) && !invoice.contains(q) && !mode.contains(q)) continue;
      }

      result.add({...d, '_dt': dt});
    }

    // Sort
    result.sort((a, b) {
      int cmp = 0;
      switch (_sortBy) {
        case 'amount':
          final aAmt = double.tryParse(a['total']?.toString() ?? '0') ?? 0;
          final bAmt = double.tryParse(b['total']?.toString() ?? '0') ?? 0;
          cmp = aAmt.compareTo(bAmt);
          break;
        case 'invoice':
          final aInv = int.tryParse(a['invoiceNumber']?.toString() ?? '0') ?? 0;
          final bInv = int.tryParse(b['invoiceNumber']?.toString() ?? '0') ?? 0;
          cmp = aInv.compareTo(bInv);
          break;
        case 'customer':
          cmp = (a['customerName'] ?? '').toString().compareTo((b['customerName'] ?? '').toString());
          break;
        case 'date':
        default:
          final aDt = a['_dt'] as DateTime? ?? DateTime(2000);
          final bDt = b['_dt'] as DateTime? ?? DateTime(2000);
          cmp = aDt.compareTo(bDt);
      }
      return _isDescending ? -cmp : cmp;
    });

    return result;
  }

  void _downloadPdf(BuildContext context, List<Map<String, dynamic>> rows) {
    double totalSales = 0;
    final pdfRows = rows.where((d) {
      final status = (d['status'] ?? '').toString().toLowerCase();
      return status != 'cancelled' && status != 'returned' && d['hasBeenReturned'] != true;
    }).map((d) {
      final dt = d['_dt'] as DateTime?;
      final dateStr = dt != null ? DateFormat('dd MMM yyyy').format(dt) : 'N/A';
      final total = double.tryParse(d['total']?.toString() ?? '0') ?? 0;
      totalSales += total;
      return [
        (d['invoiceNumber']?.toString() ?? 'N/A'),
        dateStr,
        (d['customerName']?.toString() ?? 'Guest'),
        (d['paymentMode']?.toString() ?? 'Cash'),
        total.toStringAsFixed(2),
      ];
    }).toList();

    ReportPdfGenerator.generateAndDownloadPdf(
      context: context,
      reportTitle: 'Executive Sales Audit Log',
      headers: ['Invoice', 'Date', 'Customer', 'Mode', 'Amount'],
      rows: pdfRows,
      summaryTitle: 'Total Amount Settlement',
      summaryValue: totalSales.toStringAsFixed(2),
      additionalSummary: {
        'Invoices': '${pdfRows.length}',
        'Audit Date': DateFormat('dd MMM yyyy').format(DateTime.now()),
        'Status': 'Verified',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Stream<QuerySnapshot>>(
      future: _firestoreService.getCollectionStream('sales'),
      builder: (context, streamSnapshot) {
        if (!streamSnapshot.hasData) {
          return Scaffold(
            backgroundColor: kBackgroundColor,
            appBar: _buildModernAppBar("Sales Record", widget.onBack),
            body: const Center(child: CircularProgressIndicator(color: kPrimaryColor, strokeWidth: 2)),
          );
        }
        return StreamBuilder<QuerySnapshot>(
          stream: streamSnapshot.data!,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Scaffold(
                backgroundColor: kBackgroundColor,
                appBar: _buildModernAppBar("Sales Record", widget.onBack),
                body: const Center(child: CircularProgressIndicator(color: kPrimaryColor, strokeWidth: 2)),
              );
            }

            final allDocs = snapshot.data!.docs;
            final filtered = _applyFilters(allDocs);

            // Stats across ALL docs (no date filter) for header
            double grandTotal = 0;
            int cancelledCount = 0;
            int returnedCount = 0;
            for (var doc in allDocs) {
              final d = doc.data() as Map<String, dynamic>;
              final status = (d['status'] ?? '').toString().toLowerCase();
              if (status == 'cancelled') { cancelledCount++; continue; }
              if (status == 'returned' || d['hasBeenReturned'] == true) { returnedCount++; continue; }
              grandTotal += double.tryParse(d['total']?.toString() ?? '0') ?? 0;
            }

            // Trend from filtered active docs
            final Map<String, double> dailySales = {};
            for (var d in filtered) {
              final status = (d['status'] ?? '').toString().toLowerCase();
              if (status == 'cancelled' || status == 'returned' || d['hasBeenReturned'] == true) continue;
              final dt = d['_dt'] as DateTime?;
              if (dt != null) {
                final key = DateFormat('dd/MM').format(dt);
                dailySales[key] = (dailySales[key] ?? 0) + (double.tryParse(d['total']?.toString() ?? '0') ?? 0);
              }
            }
            final trendEntries = dailySales.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
            final displayTrend = trendEntries.length > 7 ? trendEntries.sublist(trendEntries.length - 7) : trendEntries;

            return Scaffold(
              backgroundColor: kBackgroundColor,
              appBar: _buildModernAppBar(
                "Sales Record",
                widget.onBack,
                onDownload: () => _downloadPdf(context, filtered),
              ),
              body: Column(
                children: [
                  _buildHeader(grandTotal, allDocs.length - cancelledCount - returnedCount, cancelledCount, returnedCount),
                  DateFilterWidget(
                    selectedOption: _selectedFilter,
                    startDate: _startDate,
                    endDate: _endDate,
                    onDateChanged: _onDateChanged,
                    showSortButton: false,
                    isDescending: _isDescending,
                    onSortPressed: () {},
                  ),
                  _buildControlStrip(),
                  Expanded(
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        if (displayTrend.isNotEmpty && _searchQuery.isEmpty) ...[
                          const SliverToBoxAdapter(child: SizedBox(height: 16)),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            sliver: SliverToBoxAdapter(
                              child: _buildSectionHeader("Sales Trend"),
                            ),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 10)),
                          SliverToBoxAdapter(child: _buildTrendAreaChart(displayTrend)),
                        ],
                        const SliverToBoxAdapter(child: SizedBox(height: 16)),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          sliver: SliverToBoxAdapter(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildSectionHeader("Invoice Ledger"),
                                Text(
                                  "${filtered.length} RECORDS",
                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: kPrimaryColor),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 8)),
                        filtered.isEmpty
                            ? const SliverFillRemaining(
                                child: Center(
                                  child: Text("No records found", style: TextStyle(color: kTextSecondary)),
                                ),
                              )
                            : SliverToBoxAdapter(child: _buildSalesTable(filtered)),
                        const SliverToBoxAdapter(child: SizedBox(height: 40)),
                      ],
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

  // ─── UI Components ────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    return Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 1.2));
  }

  Widget _buildHeader(double total, int active, int cancelled, int returned) {
    final symbol = CurrencyService().symbol;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border(bottom: BorderSide(color: kBorderColor.withValues(alpha: 0.5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Net Sales Value", style: TextStyle(color: kTextSecondary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
              const SizedBox(height: 2),
              Text("$symbol${total.toStringAsFixed(2)}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: kPrimaryColor, letterSpacing: -1)),
            ],
          ),
          Row(
            children: [
              _buildHeaderBadge("$active", "Active", kIncomeGreen),
              const SizedBox(width: 6),
              if (cancelled > 0) ...[
                _buildHeaderBadge("$cancelled", "Cancelled", kExpenseRed),
                const SizedBox(width: 6),
              ],
              if (returned > 0)
                _buildHeaderBadge("$returned", "Returned", kWarningOrange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBadge(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14)),
          Text(label, style: const TextStyle(color: kTextSecondary, fontSize: 7, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildControlStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border(bottom: BorderSide(color: kBorderColor.withValues(alpha: 0.5))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 34,
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Search invoice, customer, mode...',
                      hintStyle: const TextStyle(fontSize: 11, color: kTextSecondary),
                      prefixIcon: const Icon(Icons.search_rounded, size: 16, color: kTextSecondary),
                      filled: true,
                      fillColor: kBackgroundColor,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: kBorderColor.withValues(alpha: 0.4))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: kBorderColor.withValues(alpha: 0.4))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kPrimaryColor)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildSortButton(),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () => setState(() => _isDescending = !_isDescending),
                icon: Icon(_isDescending ? Icons.south_rounded : Icons.north_rounded, size: 18, color: kPrimaryColor),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Status filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _statusOptions.map((s) {
                final selected = _statusFilter == s;
                Color chipColor = kPrimaryColor;
                if (s == 'Cancelled') chipColor = kExpenseRed;
                if (s == 'Returned') chipColor = kWarningOrange;
                if (s == 'Active') chipColor = kIncomeGreen;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _statusFilter = s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: selected ? chipColor : kBackgroundColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: selected ? chipColor : kBorderColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        s,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : kTextSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortButton() {
    return InkWell(
      onTap: () => showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text("Sort By", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1, color: kTextSecondary)),
            ),
            _sortTile(ctx, Icons.calendar_today_rounded, 'Date', 'date'),
            _sortTile(ctx, Icons.attach_money_rounded, 'Amount', 'amount'),
            _sortTile(ctx, Icons.receipt_rounded, 'Invoice No.', 'invoice'),
            _sortTile(ctx, Icons.person_rounded, 'Customer', 'customer'),
            const SizedBox(height: 20),
          ],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: kPrimaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            const Icon(Icons.tune_rounded, size: 14, color: kPrimaryColor),
            const SizedBox(width: 6),
            Text(_sortLabels[_sortBy] ?? _sortBy, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kPrimaryColor)),
          ],
        ),
      ),
    );
  }

  ListTile _sortTile(BuildContext ctx, IconData icon, String label, String key) {
    final bool selected = _sortBy == key;
    return ListTile(
      dense: true,
      leading: Icon(icon, color: selected ? kPrimaryColor : kTextSecondary, size: 20),
      title: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: selected ? kPrimaryColor : Colors.black87)),
      trailing: selected ? Icon(_isDescending ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, size: 16, color: kPrimaryColor) : null,
      selected: selected,
      selectedTileColor: kPrimaryColor.withValues(alpha: 0.06),
      onTap: () {
        setState(() {
          if (_sortBy == key) {
            _isDescending = !_isDescending;
          } else {
            _sortBy = key;
            _isDescending = true;
          }
        });
        Navigator.pop(ctx);
      },
    );
  }

  Widget _buildTrendAreaChart(List<MapEntry<String, double>> trend) {
    final double maxVal = trend.isEmpty
        ? 1000
        : trend.fold<double>(0, (prev, e) => e.value > prev ? e.value : prev);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(12, 24, 20, 12),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor.withValues(alpha: 0.7)),
      ),
      child: SizedBox(
        height: 130,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: maxVal * 1.2,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (v) => FlLine(color: kBorderColor.withValues(alpha: 0.2), strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  getTitlesWidget: (v, m) {
                    if (v == 0) return const SizedBox();
                    final text = v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}k' : v.toStringAsFixed(0);
                    return Text(text, style: const TextStyle(fontSize: 8, color: kTextSecondary, fontWeight: FontWeight.bold));
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  getTitlesWidget: (v, m) {
                    final index = v.toInt();
                    if (index < 0 || index >= trend.length) return const SizedBox();
                    return SideTitleWidget(
                      meta: m,
                      space: 8,
                      child: Text(trend[index].key, style: const TextStyle(fontSize: 8, color: kTextSecondary, fontWeight: FontWeight.w900)),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: trend.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList(),
                isCurved: true,
                curveSmoothness: 0.35,
                color: kIncomeGreen,
                barWidth: 2.5,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                    radius: 3,
                    color: Colors.white,
                    strokeWidth: 2,
                    strokeColor: kIncomeGreen,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [kIncomeGreen.withValues(alpha: 0.15), kIncomeGreen.withValues(alpha: 0)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSalesTable(List<Map<String, dynamic>> rows) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border.symmetric(horizontal: BorderSide(color: kBorderColor.withValues(alpha: 0.5))),
      ),
      child: Column(
        children: [
          // Header row
          Container(
            color: kBackgroundColor.withValues(alpha: 0.5),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: const Row(
              children: [
                Expanded(flex: 1, child: Text("Invoice", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.4))),
                SizedBox(width: 4),
                Expanded(flex: 2, child: Text("Customer", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.4))),
                Expanded(flex: 2, child: Text("Date", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.4))),
                Expanded(flex: 1, child: Text("Mode", textAlign: TextAlign.center, style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.4))),
                Expanded(flex: 2, child: Text("Amount", textAlign: TextAlign.right, style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.4))),
              ],
            ),
          ),
          Container(height: 1, color: kBorderColor.withValues(alpha: 0.5)),
          ...rows.asMap().entries.map((e) => _buildSalesRow(e.value, e.key)),
        ],
      ),
    );
  }

  Widget _buildSalesRow(Map<String, dynamic> data, int index) {
    final symbol = CurrencyService().symbol;
    final double total = double.tryParse(data['total']?.toString() ?? '0') ?? 0.0;
    final String status = (data['status'] ?? '').toString().toLowerCase();
    final bool isCancelled = status == 'cancelled';
    final bool isReturned = status == 'returned' || data['hasBeenReturned'] == true;
    final bool isEven = index % 2 == 0;

    final String modeRaw = (data['paymentMode'] ?? 'Cash').toString();
    final String modeLower = modeRaw.toLowerCase();
    Color modeColor = kIncomeGreen;
    if (modeLower.contains('online') || modeLower.contains('upi') || modeLower.contains('card')) modeColor = kPrimaryColor;
    else if (modeLower.contains('credit')) modeColor = kWarningOrange;

    final DateTime? dt = data['_dt'] as DateTime?;
    final String dateStr = dt != null ? DateFormat('dd MMM yyy').format(dt) : '--';
    final String timeStr = dt != null ? DateFormat('hh:mm a').format(dt) : '';

    Color rowBg = isEven ? kBackgroundColor.withValues(alpha: 0.4) : kSurfaceColor;
    if (isCancelled) rowBg = kExpenseRed.withValues(alpha: 0.04);
    if (isReturned) rowBg = kWarningOrange.withValues(alpha: 0.04);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: rowBg,
        border: Border(bottom: BorderSide(color: kBorderColor.withValues(alpha: 0.3))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Invoice number
          Expanded(
            flex:1,
            child: Text(
              '#${data['invoiceNumber'] ?? 'N/A'}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: isCancelled ? kExpenseRed : (isReturned ? kWarningOrange : kPrimaryColor),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          // Customer name + status badge
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (data['customerName'] ?? 'Guest').toString(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isCancelled || isReturned ? kTextSecondary : Colors.black87,
                    decoration: isCancelled ? TextDecoration.lineThrough : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (isCancelled || isReturned)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: isCancelled ? kExpenseRed.withValues(alpha: 0.1) : kWarningOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isCancelled ? 'Cancelled' : 'Returned',
                      style: TextStyle(
                        fontSize: 7,
                        fontWeight: FontWeight.w900,
                        color: isCancelled ? kExpenseRed : kWarningOrange,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Date
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateStr, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black87)),
                if (timeStr.isNotEmpty)
                  Text(timeStr, style: const TextStyle(fontSize: 9, color: kTextSecondary)),
              ],
            ),
          ),
          // Payment mode chip
          Expanded(
            flex: 1,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: modeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  modeRaw.length > 6 ? modeRaw.substring(0, 5) : modeRaw,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: modeColor),
                  maxLines: 1,
                ),
              ),
            ),
          ),
          // Amount
          Expanded(
            flex: 2,
            child: Text(
              '$symbol${total.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: isCancelled ? kTextSecondary : (isReturned ? kWarningOrange : kPrimaryColor),
                decoration: isCancelled ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
// ==========================================
// 6. TOP CUSTOMERS
// ==========================================
class TopCustomersPage extends StatefulWidget {
  final String uid;
  final VoidCallback onBack;

  const TopCustomersPage({super.key, required this.uid, required this.onBack});

  @override
  State<TopCustomersPage> createState() => _TopCustomersPageState();
}

class _TopCustomersPageState extends State<TopCustomersPage> {
  final FirestoreService _firestoreService = FirestoreService();
  String _searchQuery = '';
  String _sortBy = 'totalSales'; // totalSales, name, bills, creditDue
  bool _isDescending = true;

  static const Map<String, String> _sortLabels = {
    'totalSales': 'Total Sales',
    'name': 'Customer Name',
    'bills': 'No. of Bills',
    'creditDue': 'Credit Due',
  };

  void _downloadPdf(BuildContext context, List<Map<String, dynamic>> customers) {
    final rows = customers.asMap().entries.map((e) {
      final c = e.value;
      return [
        '${e.key + 1}',
        c['name'].toString(),
        '${c['bills']}',
        (c['creditDue'] as double).toStringAsFixed(2),
        (c['totalSales'] as double).toStringAsFixed(2),
      ];
    }).toList();

    final grandTotal = customers.fold<double>(0, (s, c) => s + (c['totalSales'] as double));
    final totalCredit = customers.fold<double>(0, (s, c) => s + (c['creditDue'] as double));

    ReportPdfGenerator.generateAndDownloadPdf(
      context: context,
      reportTitle: 'Customer Contribution Audit',
      headers: ['Rank', 'Customer Name', 'NO. BILLS', 'Credit Due', 'Total Sales'],
      rows: rows,
      summaryTitle: 'Grand Total Sales',
      summaryValue: grandTotal.toStringAsFixed(2),
      additionalSummary: {
        'Customer Base': '${customers.length} Unique Customers',
        'Total Credit Due': totalCredit.toStringAsFixed(2),
        'Audit Date': DateFormat('dd MMM yyyy').format(DateTime.now()),
      },
    );
  }

  List<Map<String, dynamic>> _sortCustomers(List<Map<String, dynamic>> list) {
    final sorted = List<Map<String, dynamic>>.from(list);
    sorted.sort((a, b) {
      int result = 0;
      switch (_sortBy) {
        case 'name':
          result = (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase());
          break;
        case 'bills':
          result = (a['bills'] as int).compareTo(b['bills'] as int);
          break;
        case 'creditDue':
          result = (a['creditDue'] as double).compareTo(b['creditDue'] as double);
          break;
        case 'totalSales':
        default:
          result = (a['totalSales'] as double).compareTo(b['totalSales'] as double);
          break;
      }
      return _isDescending ? -result : result;
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Stream<QuerySnapshot>>>(
      future: Future.wait([
        _firestoreService.getCollectionStream('sales'),
        _firestoreService.getCollectionStream('customers'),
      ]),
      builder: (context, streamSnapshot) {
        if (!streamSnapshot.hasData) {
          return Scaffold(
            backgroundColor: kBackgroundColor,
            appBar: _buildModernAppBar("Top Customers", widget.onBack),
            body: const Center(child: CircularProgressIndicator(color: kPrimaryColor, strokeWidth: 2)),
          );
        }

        return StreamBuilder<QuerySnapshot>(
          stream: streamSnapshot.data![0],
          builder: (context, salesSnap) {
            return StreamBuilder<QuerySnapshot>(
              stream: streamSnapshot.data![1],
              builder: (context, custSnap) {
                if (!salesSnap.hasData || !custSnap.hasData) {
                  return Scaffold(
                    backgroundColor: kBackgroundColor,
                    appBar: _buildModernAppBar("Top Customers", widget.onBack),
                    body: const Center(child: CircularProgressIndicator(color: kPrimaryColor)),
                  );
                }

                // --- Build customer map from sales ---
                // name -> {bills, salesTotal}
                Map<String, int> billCount = {};
                Map<String, double> salesTotal = {};

                for (var d in salesSnap.data!.docs) {
                  final data = d.data() as Map<String, dynamic>;
                  final status = (data['status'] ?? '').toString().toLowerCase();
                  if (status == 'cancelled' || status == 'returned' || data['hasBeenReturned'] == true) continue;
                  final name = (data['customerName'] ?? '').toString().trim();
                  if (name.isEmpty || name.toLowerCase() == 'guest') continue;
                  final amt = double.tryParse(data['total']?.toString() ?? '0') ?? 0;
                  billCount[name] = (billCount[name] ?? 0) + 1;
                  salesTotal[name] = (salesTotal[name] ?? 0) + amt;
                }

                // --- Build credit due map from customers collection ---
                // name -> balance (credit due)
                Map<String, double> creditDueMap = {};
                for (var d in custSnap.data!.docs) {
                  final data = d.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().trim();
                  if (name.isEmpty) continue;
                  final balance = (data['balance'] is num) ? (data['balance'] as num).toDouble() : 0.0;
                  // Take the max if there are duplicates
                  creditDueMap[name] = (creditDueMap[name] ?? 0) + balance;
                }

                // --- Merge into a single list ---
                final allNames = {...salesTotal.keys, ...creditDueMap.keys};
                List<Map<String, dynamic>> customers = allNames
                    .where((name) => salesTotal.containsKey(name) || creditDueMap.containsKey(name))
                    .map((name) => {
                          'name': name,
                          'bills': billCount[name] ?? 0,
                          'totalSales': salesTotal[name] ?? 0.0,
                          'creditDue': creditDueMap[name] ?? 0.0,
                        })
                    .toList();

                // Apply search filter
                if (_searchQuery.isNotEmpty) {
                  final q = _searchQuery.toLowerCase();
                  customers = customers.where((c) => (c['name'] as String).toLowerCase().contains(q)).toList();
                }

                // Sort
                customers = _sortCustomers(customers);

                // Totals for header
                final grandTotal = customers.fold<double>(0, (s, c) => s + (c['totalSales'] as double));
                final totalCredit = customers.fold<double>(0, (s, c) => s + (c['creditDue'] as double));
                final top6 = customers.take(6).toList();

                return Scaffold(
                  backgroundColor: kBackgroundColor,
                  appBar: _buildModernAppBar(
                    "Top Customers",
                    widget.onBack,
                    onDownload: () => _downloadPdf(context, customers),
                  ),
                  body: Column(
                    children: [
                      _buildExecutiveCustomerHeader(grandTotal, totalCredit, customers.length),
                      _buildControlStrip(),
                      Expanded(
                        child: CustomScrollView(
                          physics: const BouncingScrollPhysics(),
                          slivers: [
                            if (top6.isNotEmpty && _searchQuery.isEmpty) ...[
                              const SliverToBoxAdapter(child: SizedBox(height: 16)),
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                sliver: SliverToBoxAdapter(child: _buildSectionHeader("Revenue Contribution")),
                              ),
                              const SliverToBoxAdapter(child: SizedBox(height: 10)),
                              SliverToBoxAdapter(child: _buildContributionGraph(top6)),
                            ],
                            const SliverToBoxAdapter(child: SizedBox(height: 24)),
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              sliver: SliverToBoxAdapter(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildSectionHeader("Customer Valuation Ledger"),
                                    Text(
                                      "${customers.length} Customers",
                                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: kPrimaryColor),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SliverToBoxAdapter(child: SizedBox(height: 8)),
                            customers.isEmpty
                                ? const SliverFillRemaining(
                                    child: Center(
                                      child: Text("No customer data found", style: TextStyle(color: kTextSecondary)),
                                    ),
                                  )
                                : SliverToBoxAdapter(child: _buildCustomerTable(customers)),
                            const SliverToBoxAdapter(child: SizedBox(height: 40)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildSectionHeader(String title) {
    return Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 1.2));
  }

  Widget _buildExecutiveCustomerHeader(double grandTotal, double totalCredit, int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border(bottom: BorderSide(color: kBorderColor.withOpacity(0.5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Grand Total Sales", style: TextStyle(color: kTextSecondary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
              const SizedBox(height: 2),
              Text(grandTotal.toStringAsFixed(2), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: kPrimaryColor, letterSpacing: -1)),
            ],
          ),
          Row(
            children: [
              _buildHeaderBadge("$count", "Customers", kPrimaryColor),
              const SizedBox(width: 8),
              _buildHeaderBadge(totalCredit.toStringAsFixed(0), "Credit Due", kExpenseRed),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBadge(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 15)),
          Text(label, style: const TextStyle(color: kTextSecondary, fontSize: 7, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildControlStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border(bottom: BorderSide(color: kBorderColor.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 34,
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Search customers...',
                  hintStyle: const TextStyle(fontSize: 12, color: kTextSecondary),
                  prefixIcon: const Icon(Icons.search_rounded, size: 16, color: kTextSecondary),
                  filled: true,
                  fillColor: kBackgroundColor,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: kBorderColor.withOpacity(0.4))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: kBorderColor.withOpacity(0.4))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kPrimaryColor)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildSortButton(),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => setState(() => _isDescending = !_isDescending),
            icon: Icon(_isDescending ? Icons.south_rounded : Icons.north_rounded, size: 18, color: kPrimaryColor),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildSortButton() {
    return InkWell(
      onTap: () => showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text("Sort By", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1, color: kTextSecondary)),
            ),
            _sortTile(ctx, Icons.attach_money_rounded, 'Total Sales', 'totalSales'),
            _sortTile(ctx, Icons.sort_by_alpha_rounded, 'Customer Name', 'name'),
            _sortTile(ctx, Icons.receipt_long_rounded, 'No. of Bills', 'bills'),
            _sortTile(ctx, Icons.credit_card_off_rounded, 'Credit Due', 'creditDue'),
            const SizedBox(height: 20),
          ],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: kPrimaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            const Icon(Icons.tune_rounded, size: 14, color: kPrimaryColor),
            const SizedBox(width: 6),
            Text(_sortLabels[_sortBy] ?? _sortBy, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kPrimaryColor)),
          ],
        ),
      ),
    );
  }

  ListTile _sortTile(BuildContext ctx, IconData icon, String label, String key) {
    final bool selected = _sortBy == key;
    return ListTile(
      dense: true,
      leading: Icon(icon, color: selected ? kPrimaryColor : kTextSecondary, size: 20),
      title: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: selected ? kPrimaryColor : Colors.black87)),
      trailing: selected ? Icon(_isDescending ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, size: 16, color: kPrimaryColor) : null,
      selected: selected,
      selectedTileColor: kPrimaryColor.withOpacity(0.06),
      onTap: () {
        setState(() {
          if (_sortBy == key) {
            _isDescending = !_isDescending;
          } else {
            _sortBy = key;
            _isDescending = true;
          }
        });
        Navigator.pop(ctx);
      },
    );
  }

  Widget _buildContributionGraph(List<Map<String, dynamic>> top6) {
    final double maxVal = top6.isEmpty ? 100 : (top6.first['totalSales'] as double);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(12, 20, 16, 12),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor.withOpacity(0.7)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 140,
            child: BarChart(
              BarChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxVal > 0 ? maxVal / 4 : 5,
                  getDrawingHorizontalLine: (v) => FlLine(color: kBorderColor.withOpacity(0.2), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (v, m) {
                        if (v == 0) return const SizedBox();
                        return Text(v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}k' : v.toStringAsFixed(0),
                            style: const TextStyle(fontSize: 8, color: kTextSecondary, fontWeight: FontWeight.bold));
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (v, m) {
                        int index = v.toInt();
                        if (index < 0 || index >= top6.length) return const SizedBox();
                        String label = top6[index]['name'] as String;
                        if (label.length > 6) label = '${label.substring(0, 5)}..';
                        return SideTitleWidget(
                          meta: m,
                          space: 8,
                          child: Text(label, style: const TextStyle(fontSize: 7, color: kTextSecondary, fontWeight: FontWeight.w900)),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: top6.asMap().entries.map((e) {
                  final colorIndex = e.key % kChartColorsList.length;
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value['totalSales'] as double,
                        color: kChartColorsList[colorIndex],
                        width: 16,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: 0,
                          color: kBorderColor.withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text("Financial weight of top customers by total sales", style: TextStyle(fontSize: 8, color: kTextSecondary, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildCustomerTable(List<Map<String, dynamic>> customers) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border.symmetric(horizontal: BorderSide(color: kBorderColor.withOpacity(0.5))),
      ),
      child: Column(
        children: [
          // Header
          Container(
            color: kBackgroundColor.withOpacity(0.5),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Row(
              children: const [
                SizedBox(width: 28, child: Text("Rank", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.4))),
                SizedBox(width: 4),
                Expanded(flex: 3, child: Text("Customer Name", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.4))),
                Expanded(flex: 1, child: Text("Bills", textAlign: TextAlign.center, style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.4))),
                Expanded(flex: 2, child: Text("Credit Due", textAlign: TextAlign.right, style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.4))),
                Expanded(flex: 2, child: Text("Total Sales", textAlign: TextAlign.right, style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.4))),
              ],
            ),
          ),
          Container(height: 1, color: kBorderColor.withOpacity(0.5)),
          ...customers.asMap().entries.map((e) {
            final rank = e.key + 1;
            final c = e.value;
            final isEven = e.key % 2 == 0;
            final creditDue = c['creditDue'] as double;
            final totalSales = c['totalSales'] as double;
            final bills = c['bills'] as int;

            return Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: isEven ? kBackgroundColor.withOpacity(0.4) : kSurfaceColor,
                border: Border(bottom: BorderSide(color: kBorderColor.withOpacity(0.3))),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                      decoration: BoxDecoration(
                        color: rank <= 3 ? kPrimaryColor.withValues(alpha: 0.12) : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$rank',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: rank <= 3 ? kPrimaryColor : kTextSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    flex: 3,
                    child: Text(
                      c['name'] as String,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      '$bills',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextSecondary),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      creditDue.toStringAsFixed(2),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: creditDue > 0 ? kExpenseRed : kTextSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      totalSales.toStringAsFixed(2),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: kPrimaryColor),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

// ==========================================
// 7. STOCK REPORT (Enhanced with all features from screenshot)
// ==========================================
class StockReportPage extends StatefulWidget {
  final VoidCallback onBack;

  const StockReportPage({super.key, required this.onBack});

  @override
  State<StockReportPage> createState() => _StockReportPageState();
}

class _StockReportPageState extends State<StockReportPage> {
  final FirestoreService _firestoreService = FirestoreService();
  String _searchQuery = '';
  bool _isDescending = false;
  String _sortBy = 'productCode'; // name, productCode, stock, cost, profit, retailValue

  static const Map<String, String> _sortLabels = {
    'name': 'Item Name',
    'productCode': 'Product Code',
    'stock': 'Stock',
    'cost': 'Cost Value',
    'profit': 'Profit',
    'retailValue': 'Retail Value',
  };

  void _downloadPdf(BuildContext context, List<DocumentSnapshot> docs, double totalInvValue, int stockCount, double retailValue, double potentialProfit) {
    final rows = List.generate(docs.length, (i) {
      final d = docs[i].data() as Map<String, dynamic>;
      final cost = double.tryParse(d['costPrice']?.toString() ?? d['cost']?.toString() ?? d['purchasePrice']?.toString() ?? '0') ?? 0;
      final price = double.tryParse(d['price']?.toString() ?? '0') ?? 0;
      final stock = double.tryParse(d['currentStock']?.toString() ?? '0') ?? 0;
      final retailVal = price * stock;
      final profit = retailVal - (cost * stock);
      return [
        '${i + 1}',
        d['productCode']?.toString() ?? 'N/A',
        (d['itemName']?.toString() ?? 'Unknown'),
        stock.toStringAsFixed(0),
        (cost * stock).toStringAsFixed(2),
        profit.toStringAsFixed(2),
        retailVal.toStringAsFixed(2),
      ];
    });

    ReportPdfGenerator.generateAndDownloadPdf(
      context: context,
      reportTitle: 'Executive Stock Valuation Audit',
      headers: ['SL.', 'Product Code', 'Item Name', 'Stock', 'Cost', 'Profit', 'Retail Val'],
      rows: rows,
      summaryTitle: 'Total Retail Value',
      summaryValue: '${retailValue.toStringAsFixed(2)}',
      additionalSummary: {
        'Inventory Cost': '${totalInvValue.toStringAsFixed(2)}',
        'Stock Count': '$stockCount Units',
        'Potential Profit': '${potentialProfit.toStringAsFixed(2)}',
        'Audit Date': DateFormat('dd MMM yyyy').format(DateTime.now()),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Stream<QuerySnapshot>>(
      future: _firestoreService.getCollectionStream('Products'),
      builder: (context, streamSnapshot) {
        if (!streamSnapshot.hasData) {
          return Scaffold(
            backgroundColor: kBackgroundColor,
            appBar: _buildModernAppBar("Stock Report", widget.onBack),
            body: const Center(child: CircularProgressIndicator(color: kPrimaryColor, strokeWidth: 2)),
          );
        }
        return StreamBuilder<QuerySnapshot>(
          stream: streamSnapshot.data!,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Scaffold(
                backgroundColor: kBackgroundColor,
                appBar: _buildModernAppBar("Stock Report", widget.onBack),
                body: const Center(child: CircularProgressIndicator(color: kPrimaryColor, strokeWidth: 2)),
              );
            }

            double totalInventoryValue = 0; // Cost * Stock
            double totalRetailValue = 0; // Price * Stock
            int totalStockCount = 0;

            List<DocumentSnapshot> allDocs = snapshot.data!.docs;

            for (var d in allDocs) {
              var data = d.data() as Map<String, dynamic>;
              double cost = double.tryParse(data['costPrice']?.toString() ?? data['cost']?.toString() ?? data['purchasePrice']?.toString() ?? '0') ?? 0;
              double price = double.tryParse(data['price']?.toString() ?? '0') ?? 0;
              double stock = double.tryParse(data['currentStock']?.toString() ?? '0') ?? 0;

              if (stock > 0) {
                totalInventoryValue += cost * stock;
                totalRetailValue += price * stock;
                totalStockCount += stock.toInt();
              }
            }

            double potentialProfit = totalRetailValue - totalInventoryValue;

            // --- Search & Filter logic ---
            var filteredDocs = allDocs.where((d) {
              var data = d.data() as Map<String, dynamic>;
              String query = _searchQuery.toLowerCase();
              return (data['itemName']?.toString().toLowerCase() ?? '').contains(query) ||
                  (data['productCode']?.toString().toLowerCase() ?? '').contains(query) ||
                  (data['category']?.toString().toLowerCase() ?? '').contains(query);
            }).toList();

            filteredDocs.sort((a, b) {
              var dataA = a.data() as Map<String, dynamic>;
              var dataB = b.data() as Map<String, dynamic>;
              int result = 0;
              switch (_sortBy) {
                case 'name':
                  result = (dataA['itemName'] ?? '').toString().toLowerCase().compareTo((dataB['itemName'] ?? '').toString().toLowerCase());
                  break;
                case 'productCode':
                  final codeA = int.tryParse(dataA['productCode']?.toString() ?? '') ?? 0;
                  final codeB = int.tryParse(dataB['productCode']?.toString() ?? '') ?? 0;
                  result = codeA != 0 && codeB != 0
                      ? codeA.compareTo(codeB)
                      : (dataA['productCode'] ?? '').toString().compareTo((dataB['productCode'] ?? '').toString());
                  break;
                case 'stock':
                  result = (double.tryParse(dataA['currentStock']?.toString() ?? '0') ?? 0)
                      .compareTo(double.tryParse(dataB['currentStock']?.toString() ?? '0') ?? 0);
                  break;
                case 'cost':
                  final costA = (double.tryParse(dataA['costPrice']?.toString() ?? dataA['cost']?.toString() ?? '0') ?? 0) *
                      (double.tryParse(dataA['currentStock']?.toString() ?? '0') ?? 0);
                  final costB = (double.tryParse(dataB['costPrice']?.toString() ?? dataB['cost']?.toString() ?? '0') ?? 0) *
                      (double.tryParse(dataB['currentStock']?.toString() ?? '0') ?? 0);
                  result = costA.compareTo(costB);
                  break;
                case 'profit':
                  final priceA = double.tryParse(dataA['price']?.toString() ?? '0') ?? 0;
                  final cA = double.tryParse(dataA['costPrice']?.toString() ?? dataA['cost']?.toString() ?? '0') ?? 0;
                  final stkA = double.tryParse(dataA['currentStock']?.toString() ?? '0') ?? 0;
                  final profitA = (priceA - cA) * stkA;

                  final priceB = double.tryParse(dataB['price']?.toString() ?? '0') ?? 0;
                  final cB = double.tryParse(dataB['costPrice']?.toString() ?? dataB['cost']?.toString() ?? '0') ?? 0;
                  final stkB = double.tryParse(dataB['currentStock']?.toString() ?? '0') ?? 0;
                  final profitB = (priceB - cB) * stkB;
                  result = profitA.compareTo(profitB);
                  break;
                case 'retailValue':
                  final retA = (double.tryParse(dataA['price']?.toString() ?? '0') ?? 0) *
                      (double.tryParse(dataA['currentStock']?.toString() ?? '0') ?? 0);
                  final retB = (double.tryParse(dataB['price']?.toString() ?? '0') ?? 0) *
                      (double.tryParse(dataB['currentStock']?.toString() ?? '0') ?? 0);
                  result = retA.compareTo(retB);
                  break;
                case 'price':
                  result = (double.tryParse(dataA['price']?.toString() ?? '0') ?? 0)
                      .compareTo(double.tryParse(dataB['price']?.toString() ?? '0') ?? 0);
                  break;
              }
              return _isDescending ? -result : result;
            });

            return Scaffold(
              backgroundColor: kBackgroundColor,
              appBar: _buildModernAppBar(
                "Stock Report",
                widget.onBack,
                onDownload: () => _downloadPdf(context, filteredDocs, totalInventoryValue, totalStockCount, totalRetailValue, potentialProfit),
              ),
              body: Column(
                children: [
                  _buildExecutiveValuationRibbon(totalInventoryValue, totalRetailValue, potentialProfit, totalStockCount),
                  _buildIntegratedControlStrip(),
                  Expanded(
                    child: filteredDocs.isEmpty
                        ? const Center(child: Text("No inventory items match your audit criteria", style: TextStyle(color: kTextSecondary)))
                        : CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        const SliverToBoxAdapter(child: SizedBox(height: 8)),
                        SliverToBoxAdapter(
                          child: _buildHighDensityStockLedger(filteredDocs),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 40)),
                      ],
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

  // --- EXECUTIVE UI COMPONENTS ---

  Widget _buildExecutiveValuationRibbon(double cost, double retail, double profit, int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border(bottom: BorderSide(color: kBorderColor.withOpacity(0.5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildRibbonSegment("INV. VALUE (COST)", "${cost.toStringAsFixed(0)}", kTextSecondary),
          _buildRibbonSegment("Retail Value", "${retail.toStringAsFixed(0)}", kPrimaryColor),
          _buildRibbonSegment("Potential Profit", "${profit.toStringAsFixed(0)}", kIncomeGreen),
          _buildRibbonSegment("Total Stock", "$count", kPurpleCharts),
        ],
      ),
    );
  }

  Widget _buildRibbonSegment(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color, letterSpacing: -0.5)),
      ],
    );
  }

  Widget _buildIntegratedControlStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border(bottom: BorderSide(color: kBorderColor.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          // Search
          Expanded(
            child: SizedBox(
              height: 34,
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Search name, code or category...',
                  hintStyle: const TextStyle(fontSize: 12, color: kTextSecondary),
                  prefixIcon: const Icon(Icons.search_rounded, size: 16, color: kTextSecondary),
                  filled: true,
                  fillColor: kBackgroundColor,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: kBorderColor.withValues(alpha: 0.4))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: kBorderColor.withValues(alpha: 0.4))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kPrimaryColor)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Sort button
          _buildSortAction(),
          const SizedBox(width: 4),
          // Asc/Desc toggle
          IconButton(
            onPressed: () => setState(() => _isDescending = !_isDescending),
            icon: Icon(_isDescending ? Icons.south_rounded : Icons.north_rounded, size: 18, color: kPrimaryColor),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildSortAction() {
    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, setModalState) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text("Sort Inventory By", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1, color: kTextSecondary)),
                ),
                _sortTile(ctx, Icons.tag_rounded, 'Product Code', 'productCode'),
                _sortTile(ctx, Icons.sort_by_alpha_rounded, 'Item Name', 'name'),
                _sortTile(ctx, Icons.inventory_2_rounded, 'Stock Qty', 'stock'),
                _sortTile(ctx, Icons.money_off_rounded, 'Cost Value', 'cost'),
                _sortTile(ctx, Icons.trending_up_rounded, 'Profit', 'profit'),
                _sortTile(ctx, Icons.sell_rounded, 'Retail Value', 'retailValue'),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: kPrimaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            const Icon(Icons.tune_rounded, size: 14, color: kPrimaryColor),
            const SizedBox(width: 6),
            Text(
              _sortLabels[_sortBy] ?? _sortBy,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kPrimaryColor),
            ),
          ],
        ),
      ),
    );
  }

  ListTile _sortTile(BuildContext ctx, IconData icon, String label, String key) {
    final bool selected = _sortBy == key;
    return ListTile(
      dense: true,
      leading: Icon(icon, color: selected ? kPrimaryColor : kTextSecondary, size: 20),
      title: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: selected ? kPrimaryColor : Colors.black87)),
      trailing: selected ? Icon(_isDescending ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, size: 16, color: kPrimaryColor) : null,
      selected: selected,
      selectedTileColor: kPrimaryColor.withOpacity(0.06),
      onTap: () {
        setState(() {
          if (_sortBy == key) {
            _isDescending = !_isDescending; // toggle direction on re-tap
          } else {
            _sortBy = key;
            _isDescending = false; // default ascending for new column
          }
        });
        Navigator.pop(ctx);
      },
    );
  }

  Widget _buildHighDensityStockLedger(List<DocumentSnapshot> docs) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border.symmetric(horizontal: BorderSide(color: kBorderColor.withOpacity(0.5))),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            color: kBackgroundColor.withOpacity(0.5),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            child: const Row(
              children: [
                SizedBox(width: 28, child: Text("SL.", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5))),
                SizedBox(width: 6),
                Expanded(flex: 2, child: Text("Product Code", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5))),
                Expanded(flex: 3, child: Text("Item Name", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5))),
                Expanded(flex: 1, child: Text("Stock", textAlign: TextAlign.right, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5))),
                Expanded(flex: 2, child: Text("Cost", textAlign: TextAlign.right, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5))),
                Expanded(flex: 2, child: Text("Profit", textAlign: TextAlign.right, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5))),
                Expanded(flex: 2, child: Text("Retail Val", textAlign: TextAlign.right, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5))),
              ],
            ),
          ),
          // Divider
          Container(height: 1, color: kBorderColor.withOpacity(0.5)),
          ...List.generate(docs.length, (index) => _buildStockLedgerRow(docs[index].data() as Map<String, dynamic>, index + 1)),
        ],
      ),
    );
  }

  Widget _buildStockLedgerRow(Map<String, dynamic> data, int sl) {
    final double stock = double.tryParse(data['currentStock']?.toString() ?? '0') ?? 0;
    final double price = double.tryParse(data['price']?.toString() ?? '0') ?? 0;
    final double cost = double.tryParse(data['costPrice']?.toString() ?? data['cost']?.toString() ?? data['purchasePrice']?.toString() ?? '0') ?? 0;
    final double retailValue = price * stock;
    final double costValue = cost * stock;
    final double profit = retailValue - costValue;
    final bool isEven = sl % 2 == 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: isEven ? kBackgroundColor.withOpacity(0.4) : kSurfaceColor,
        border: Border(bottom: BorderSide(color: kBorderColor.withOpacity(0.3))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // SL
          SizedBox(
            width: 28,
            child: Text(
              '$sl',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextSecondary),
            ),
          ),
          const SizedBox(width: 6),
          // Product Code
          Expanded(
            flex: 2,
            child: Text(
              data['productCode']?.toString() ?? 'N/A',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kPrimaryColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Item Name
          Expanded(
            flex: 3,
            child: Text(
              (data['itemName'] ?? 'Unknown').toString(),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black87),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Stock
          Expanded(
            flex: 1,
            child: Text(
              stock.toStringAsFixed(0),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextSecondary),
            ),
          ),
          // Cost (total cost value)
          Expanded(
            flex: 2,
            child: Text(
              costValue.toStringAsFixed(0),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextSecondary),
            ),
          ),
          // Profit
          Expanded(
            flex: 2,
            child: Text(
              profit.toStringAsFixed(0),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: profit >= 0 ? kIncomeGreen : kExpenseRed,
              ),
            ),
          ),
          // Retail Value
          Expanded(
            flex: 2,
            child: Text(
              retailValue.toStringAsFixed(0),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: kPrimaryColor),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 8. OTHER PAGES (Enhanced Functionality)
// ==========================================

class ItemSalesPage extends StatelessWidget {
  final VoidCallback onBack;
  final FirestoreService _firestoreService = FirestoreService();

  ItemSalesPage({super.key, required this.onBack});

  void _downloadPdf(BuildContext context, List<MapEntry<String, int>> sorted) {
    final rows = sorted.asMap().entries.map((e) => [
      '${e.key + 1}',
      e.value.key,
      e.value.value.toString(),
    ]).toList();

    final totalQty = sorted.fold<int>(0, (sum, e) => sum + e.value);

    ReportPdfGenerator.generateAndDownloadPdf(
      context: context,
      reportTitle: 'Item Sales Report',
      headers: ['Rank', 'Item Description', 'Units Sold'],
      rows: rows,
      summaryTitle: 'Total Unit Settlement',
      summaryValue: '$totalQty UNITS',
      additionalSummary: {
        'Inventory Scope': '${sorted.length} Unique SKUs',
        'Audit Date': DateFormat('dd MMM yyyy').format(DateTime.now()),
        'Status': 'Verified'
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Stream<QuerySnapshot>>(
      future: _firestoreService.getCollectionStream('sales'),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: kBackgroundColor,
            appBar: _buildModernAppBar("Item Sales Report", onBack),
            body: const Center(child: CircularProgressIndicator(color: kPrimaryColor, strokeWidth: 2)),
          );
        }
        return StreamBuilder<QuerySnapshot>(
          stream: snapshot.data!,
          builder: (context, salesSnap) {
            if (!salesSnap.hasData) {
              return Scaffold(
                backgroundColor: kBackgroundColor,
                appBar: _buildModernAppBar("Item Sales Report", onBack),
                body: const Center(child: CircularProgressIndicator(color: kPrimaryColor)),
              );
            }

            // --- Aggregation Logic ---
            Map<String, int> qtyMap = {};
            for (var d in salesSnap.data!.docs) {
              var data = d.data() as Map<String, dynamic>;

              // Skip cancelled or returned bills
              final String status = (data['status'] ?? '').toString().toLowerCase();
              if (status == 'cancelled' || status == 'returned' || data['hasBeenReturned'] == true) {
                continue;
              }

              if (data['items'] != null) {
                for (var item in (data['items'] as List)) {
                  String name = item['name']?.toString() ?? 'Unknown';

                  // Skip quick items (item1, item2, etc.) - only count properly named items
                  if (name.toLowerCase().startsWith('item') &&
                      RegExp(r'^item\d+$', caseSensitive: false).hasMatch(name.toLowerCase())) {
                    continue; // Skip quick items
                  }

                  int q = int.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
                  qtyMap[name] = (qtyMap[name] ?? 0) + q;
                }
              }
            }
            var sorted = qtyMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
            var top6 = sorted.take(6).toList();
            int grandTotal = sorted.fold(0, (sum, e) => sum + e.value);

            return Scaffold(
              backgroundColor: kBackgroundColor,
              appBar: _buildModernAppBar(
                  "Item Sales Report",
                  onBack,
                  onDownload: () => _downloadPdf(context, sorted)
              ),
              body: Column(
                children: [
                  _buildExecutiveSalesHeader(grandTotal, sorted.length),
                  Expanded(
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        if (top6.isNotEmpty) ...[
                          const SliverToBoxAdapter(child: SizedBox(height: 16)),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            sliver: SliverToBoxAdapter(child: _buildSectionHeader("Sales Velocity Chart")),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 10)),
                          SliverToBoxAdapter(
                            child: _buildPerformanceChart(top6),
                          ),
                        ],

                        const SliverToBoxAdapter(child: SizedBox(height: 24)),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          sliver: SliverToBoxAdapter(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildSectionHeader("Product Ranking Ledger"),
                                Text(
                                  "${sorted.length} SKUs ANALYZED",
                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: kPrimaryColor),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 8)),

                        sorted.isEmpty
                            ? const SliverFillRemaining(child: Center(child: Text("No sales recorded", style: TextStyle(color: kTextSecondary))))
                            : SliverToBoxAdapter(
                          child: _buildItemSalesTable(sorted),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 40)),
                      ],
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

  // --- EXECUTIVE UI COMPONENTS ---

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 1.2),
    );
  }

  Widget _buildExecutiveSalesHeader(int totalQty, int uniqueCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border(bottom: BorderSide(color: kBorderColor.withOpacity(0.5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Total Units Sold", style: TextStyle(color: kTextSecondary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
              const SizedBox(height: 2),
              Text("$totalQty", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: kPrimaryColor, letterSpacing: -1)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: kPrimaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kPrimaryColor.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                Text("$uniqueCount", style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w900, fontSize: 16)),
                const Text("Varieties", style: TextStyle(color: kTextSecondary, fontSize: 7, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceChart(List<MapEntry<String, int>> top6) {
    final double maxVal = top6.isEmpty ? 10 : top6.first.value.toDouble();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(12, 20, 16, 12),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor.withOpacity(0.7)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxVal > 0 ? maxVal / 4 : 5,
                  getDrawingHorizontalLine: (v) => FlLine(color: kBorderColor.withOpacity(0.2), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (v, m) {
                        if (v == 0) return const SizedBox();
                        return Text(v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}k' : v.toStringAsFixed(0),
                            style: const TextStyle(fontSize: 8, color: kTextSecondary, fontWeight: FontWeight.bold));
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (v, m) {
                        int index = v.toInt();
                        if (index < 0 || index >= top6.length) return const SizedBox();
                        String label = top6[index].key;
                        if (label.length > 6) label = label.substring(0, 5) + "..";
                        return SideTitleWidget(
                          meta: m,
                          space: 8,
                          child: Text(label, style: const TextStyle(fontSize: 7, color: kTextSecondary, fontWeight: FontWeight.w900)),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: top6.asMap().entries.map((e) {
                  final colorIndex = e.key % kChartColorsList.length;
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.value.toDouble(),
                        color: kChartColorsList[colorIndex],
                        width: 14,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: 0,
                          color: kBorderColor.withValues(alpha: 0.1),
                        ),
                      )
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text("Top selling SKUs by unit quantity movement", style: TextStyle(fontSize: 8, color: kTextSecondary, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildItemSalesTable(List<MapEntry<String, int>> rows) {
    final int grandTotal = rows.fold(0, (sum, e) => sum + e.value);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border.symmetric(horizontal: BorderSide(color: kBorderColor.withOpacity(0.5))),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            color: kBackgroundColor.withOpacity(0.5),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: const Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text("Rank", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5)),
                ),
                SizedBox(width: 6),
                Expanded(
                  flex: 4,
                  child: Text("Item Name", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5)),
                ),
                Expanded(
                  flex: 2,
                  child: Text("Units Sold", textAlign: TextAlign.right, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5)),
                ),
                Expanded(
                  flex: 2,
                  child: Text("SHARE %", textAlign: TextAlign.right, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5)),
                ),
              ],
            ),
          ),
          // Divider
          Container(height: 1, color: kBorderColor.withOpacity(0.5)),
          // Rows
          ...rows.asMap().entries.map((e) => _buildItemSalesRow(e.value, e.key + 1, grandTotal)),
        ],
      ),
    );
  }

  Widget _buildItemSalesRow(MapEntry<String, int> entry, int rank, int grandTotal) {
    final bool isEven = rank % 2 == 0;
    final double share = grandTotal > 0 ? (entry.value / grandTotal) * 100 : 0;

    Color rankColor;
    if (rank == 1) rankColor = const Color(0xFFFFD700); // Gold
    else if (rank == 2) rankColor = const Color(0xFFC0C0C0); // Silver
    else if (rank == 3) rankColor = const Color(0xFFCD7F32); // Bronze
    else rankColor = kTextSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: isEven ? kBackgroundColor.withOpacity(0.4) : kSurfaceColor,
        border: Border(bottom: BorderSide(color: kBorderColor.withOpacity(0.3))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Rank badge
          SizedBox(
            width: 32,
            child: Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: rank <= 3 ? rankColor.withOpacity(0.15) : kBackgroundColor,
                borderRadius: BorderRadius.circular(6),
                border: rank <= 3 ? Border.all(color: rankColor.withOpacity(0.4)) : null,
              ),
              child: Text(
                "$rank",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: rank <= 3 ? rankColor : kTextSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Item Name
          Expanded(
            flex: 4,
            child: Text(
              entry.key,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black87),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Units Sold
          Expanded(
            flex: 2,
            child: Text(
              "${entry.value}",
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: kPrimaryColor),
            ),
          ),
          // Share %
          Expanded(
            flex: 2,
            child: Text(
              "${share.toStringAsFixed(1)}%",
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: share >= 20 ? kIncomeGreen : kTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// LOW STOCK PRODUCTS (Enhanced with all features from screenshot)
// ==========================================
class LowStockPage extends StatefulWidget {
  final String uid;
  final VoidCallback onBack;

  const LowStockPage({super.key, required this.uid, required this.onBack});

  @override
  State<LowStockPage> createState() => _LowStockPageState();
}

class _LowStockPageState extends State<LowStockPage> {
  final FirestoreService _firestoreService = FirestoreService();
  String _selectedCategory = 'All';
  List<String> _categories = ['All'];
  String _searchQuery = '';
  bool _isDescending = false;
  String _sortBy = 'productCode'; // productCode, name, stock, minStock
  
  static const Map<String, String> _sortLabels = {
    'productCode': 'Product Code',
    'name': 'Item Name',
    'stock': 'Stock',
    'minStock': 'Min Stock',
  };

  void _downloadPdf(BuildContext context, List<Map<String, dynamic>> low, List<Map<String, dynamic>> out) {
    int sl = 1;
    final rows = [
      ...low.map((e) => [
        '${sl++}',
        e['productCode']?.toString() ?? 'N/A',
        e['name'].toString(),
        e['category'].toString(),
        (e['minStock'] is num ? (e['minStock'] as num).toDouble() : 0.0).toStringAsFixed(0),
        (e['currentStock'] is num ? (e['currentStock'] as num).toDouble() : 0.0).toStringAsFixed(0),
        'Low Stock',
      ]),
      ...out.map((e) => [
        '${sl++}',
        e['productCode']?.toString() ?? 'N/A',
        e['name'].toString(),
        e['category'].toString(),
        (e['minStock'] is num ? (e['minStock'] as num).toDouble() : 0.0).toStringAsFixed(0),
        (e['currentStock'] is num ? (e['currentStock'] as num).toDouble() : 0.0).toStringAsFixed(0),
        'Out Of Stock',
      ]),
    ];

    ReportPdfGenerator.generateAndDownloadPdf(
      context: context,
      reportTitle: 'Stock Replenishment Audit',
      headers: ['SL.', 'Product Code', 'Item Name', 'Category', 'MIN REQ.', 'On Hand', 'Status'],
      rows: rows,
      summaryTitle: 'Total Alerts',
      summaryValue: '${low.length + out.length} ITEMS',
      additionalSummary: {
        'Critical (Out)': '${out.length}',
        'Warning (Low)': '${low.length}',
        'Audit Date': DateFormat('dd MMM yyyy').format(DateTime.now()),
      },
    );
  }

  List<Map<String, dynamic>> _sortItems(List<Map<String, dynamic>> items) {
    final sorted = List<Map<String, dynamic>>.from(items);
    sorted.sort((a, b) {
      int result = 0;
      switch (_sortBy) {
        case 'productCode':
          final codeA = int.tryParse(a['productCode']?.toString() ?? '') ?? 0;
          final codeB = int.tryParse(b['productCode']?.toString() ?? '') ?? 0;
          result = codeA != 0 && codeB != 0
              ? codeA.compareTo(codeB)
              : (a['productCode'] ?? '').toString().compareTo((b['productCode'] ?? '').toString());
          break;
        case 'name':
          result = (a['name'] ?? '').toString().toLowerCase().compareTo((b['name'] ?? '').toString().toLowerCase());
          break;
        case 'stock':
          result = ((a['currentStock'] as double?) ?? 0).compareTo((b['currentStock'] as double?) ?? 0);
          break;
        case 'minStock':
          result = ((a['minStock'] as double?) ?? 0).compareTo((b['minStock'] as double?) ?? 0);
          break;
      }
      return _isDescending ? -result : result;
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Stream<QuerySnapshot>>(
      future: _firestoreService.getCollectionStream('Products'),
      builder: (context, streamSnapshot) {
        if (!streamSnapshot.hasData) {
          return Scaffold(
            backgroundColor: kBackgroundColor,
            appBar: _buildModernAppBar("Low Stock Items", widget.onBack),
            body: const Center(child: CircularProgressIndicator(color: kPrimaryColor, strokeWidth: 2)),
          );
        }
        return StreamBuilder<QuerySnapshot>(
          stream: streamSnapshot.data!,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Scaffold(
                backgroundColor: kBackgroundColor,
                appBar: _buildModernAppBar("Low Stock Items", widget.onBack),
                body: const Center(child: CircularProgressIndicator(color: kPrimaryColor)),
              );
            }

            List<Map<String, dynamic>> lowStockItems = [];
            List<Map<String, dynamic>> outOfStockItems = [];
            Set<String> categorySet = {'All'};

            for (var doc in snapshot.data!.docs) {
              var data = doc.data() as Map<String, dynamic>;
              String category = data['category']?.toString() ?? 'Uncategorized';
              categorySet.add(category);

              if (!(data['stockEnabled'] ?? false)) continue;

              final currentStock = double.tryParse(data['currentStock']?.toString() ?? '0') ?? 0;
              final minStock = double.tryParse(data['lowStockAlert']?.toString() ?? '0') ?? 0;
              final alertLevel = minStock > 0 ? minStock : 5;

              if (_selectedCategory != 'All' && category != _selectedCategory) continue;

              if (currentStock <= alertLevel) {
                Map<String, dynamic> item = {
                  'productCode': data['productCode']?.toString() ?? 'N/A',
                  'name': data['itemName']?.toString() ?? 'Unknown',
                  'minStock': alertLevel,
                  'currentStock': currentStock,
                  'category': category,
                };
                if (currentStock <= 0) {
                  outOfStockItems.add(item);
                } else {
                  lowStockItems.add(item);
                }
              }
            }

            _categories = categorySet.toList()..sort();

            // Search filter
            final query = _searchQuery.toLowerCase();
            if (query.isNotEmpty) {
              lowStockItems = lowStockItems.where((e) =>
                (e['name']?.toString().toLowerCase() ?? '').contains(query) ||
                (e['productCode']?.toString().toLowerCase() ?? '').contains(query) ||
                (e['category']?.toString().toLowerCase() ?? '').contains(query)
              ).toList();
              outOfStockItems = outOfStockItems.where((e) =>
                (e['name']?.toString().toLowerCase() ?? '').contains(query) ||
                (e['productCode']?.toString().toLowerCase() ?? '').contains(query) ||
                (e['category']?.toString().toLowerCase() ?? '').contains(query)
              ).toList();
            }

            // Sort
            lowStockItems = _sortItems(lowStockItems);
            outOfStockItems = _sortItems(outOfStockItems);

            return Scaffold(
              backgroundColor: kBackgroundColor,
              appBar: _buildModernAppBar(
                "Low Stock Items",
                widget.onBack,
                onDownload: () => _downloadPdf(context, lowStockItems, outOfStockItems),
              ),
              body: Column(
                children: [
                  _buildExecutiveStockHeader(lowStockItems.length, outOfStockItems.length),
                  _buildControlStrip(),
                  Expanded(
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        if (outOfStockItems.isNotEmpty) ...[
                          const SliverToBoxAdapter(child: SizedBox(height: 16)),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            sliver: SliverToBoxAdapter(child: _buildSectionHeader("Critical: Out of Stock")),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 8)),
                          SliverToBoxAdapter(child: _buildTable(outOfStockItems, kExpenseRed)),
                        ],
                        if (lowStockItems.isNotEmpty) ...[
                          const SliverToBoxAdapter(child: SizedBox(height: 24)),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            sliver: SliverToBoxAdapter(child: _buildSectionHeader("Warning: Low Stock Level")),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 8)),
                          SliverToBoxAdapter(child: _buildTable(lowStockItems, kWarningOrange)),
                        ],
                        if (lowStockItems.isEmpty && outOfStockItems.isEmpty)
                          const SliverFillRemaining(child: Center(child: Text("Inventory levels are optimal", style: TextStyle(color: kTextSecondary)))),
                        const SliverToBoxAdapter(child: SizedBox(height: 40)),
                      ],
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

  // --- UI COMPONENTS ---

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 1.2),
    );
  }

  Widget _buildExecutiveStockHeader(int low, int out) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border(bottom: BorderSide(color: kBorderColor.withOpacity(0.5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Items Requiring Attention", style: TextStyle(color: kTextSecondary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
              const SizedBox(height: 2),
              Text("${low + out}", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: kPrimaryColor, letterSpacing: -1)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: kExpenseRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kExpenseRed.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                Text("$out", style: const TextStyle(color: kExpenseRed, fontWeight: FontWeight.w900, fontSize: 16)),
                const Text("Critical", style: TextStyle(color: kTextSecondary, fontSize: 7, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border(bottom: BorderSide(color: kBorderColor.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          // Search
          Expanded(
            child: SizedBox(
              height: 34,
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Search items...',
                  hintStyle: const TextStyle(fontSize: 12, color: kTextSecondary),
                  prefixIcon: const Icon(Icons.search_rounded, size: 16, color: kTextSecondary),
                  filled: true,
                  fillColor: kBackgroundColor,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: kBorderColor.withOpacity(0.4))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: kBorderColor.withOpacity(0.4))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kPrimaryColor)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Category filter
          SizedBox(
            height: 34,
            child: DropdownButtonHideUnderline(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: kBackgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kBorderColor.withOpacity(0.4)),
                ),
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isDense: true,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kPrimaryColor),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _selectedCategory = v!),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Sort button
          _buildSortAction(),
          const SizedBox(width: 4),
          // Asc/Desc toggle
          IconButton(
            onPressed: () => setState(() => _isDescending = !_isDescending),
            icon: Icon(_isDescending ? Icons.south_rounded : Icons.north_rounded, size: 18, color: kPrimaryColor),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildSortAction() {
    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          builder: (ctx) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text("Sort By", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1, color: kTextSecondary)),
              ),
              _sortTile(ctx, Icons.tag_rounded, 'Product Code', 'productCode'),
              _sortTile(ctx, Icons.sort_by_alpha_rounded, 'Item Name', 'name'),
              _sortTile(ctx, Icons.inventory_2_rounded, 'Stock', 'stock'),
              _sortTile(ctx, Icons.warning_amber_rounded, 'Min Stock', 'minStock'),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: kPrimaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            const Icon(Icons.tune_rounded, size: 14, color: kPrimaryColor),
            const SizedBox(width: 6),
            Text(
              _sortLabels[_sortBy] ?? _sortBy,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kPrimaryColor),
            ),
          ],
        ),
      ),
    );
  }

  ListTile _sortTile(BuildContext ctx, IconData icon, String label, String key) {
    final bool selected = _sortBy == key;
    return ListTile(
      dense: true,
      leading: Icon(icon, color: selected ? kPrimaryColor : kTextSecondary, size: 20),
      title: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: selected ? kPrimaryColor : Colors.black87)),
      trailing: selected ? Icon(_isDescending ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, size: 16, color: kPrimaryColor) : null,
      selected: selected,
      selectedTileColor: kPrimaryColor.withOpacity(0.06),
      onTap: () {
        setState(() {
          if (_sortBy == key) {
            _isDescending = !_isDescending;
          } else {
            _sortBy = key;
            _isDescending = false;
          }
        });
        Navigator.pop(ctx);
      },
    );
  }

  Widget _buildTable(List<Map<String, dynamic>> items, Color accentColor) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border.symmetric(horizontal: BorderSide(color: kBorderColor.withOpacity(0.5))),
      ),
      child: Column(
        children: [
          // Header row
          Container(
            color: kBackgroundColor.withOpacity(0.5),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              children: const [
                SizedBox(width: 28, child: Text("SL.", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5))),
                SizedBox(width: 6),
                Expanded(flex: 2, child: Text("Product Code", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5))),
                Expanded(flex: 3, child: Text("Item Name", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5))),
                Expanded(flex: 2, child: Text("Category", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5))),
                Expanded(flex: 1, child: Text("Min", textAlign: TextAlign.right, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5))),
                Expanded(flex: 1, child: Text("Stock", textAlign: TextAlign.right, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5))),
              ],
            ),
          ),
          Container(height: 1, color: kBorderColor.withOpacity(0.5)),
          ...List.generate(items.length, (i) {
            final item = items[i];
            final isEven = i % 2 == 0;
            final stock = (item['currentStock'] is num ? (item['currentStock'] as num).toDouble() : 0.0);
            final min = (item['minStock'] is num ? (item['minStock'] as num).toDouble() : 0.0);
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 16),
              decoration: BoxDecoration(
                color: isEven ? kBackgroundColor.withOpacity(0.4) : kSurfaceColor,
                border: Border(bottom: BorderSide(color: kBorderColor.withOpacity(0.3))),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextSecondary),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 2,
                    child: Text(
                      item['productCode']?.toString() ?? 'N/A',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: kPrimaryColor),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      item['name'].toString(),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      item['category'].toString(),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: kTextSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      min.toStringAsFixed(0),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextSecondary),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      stock.toStringAsFixed(0),
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: accentColor),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ==========================================
// TOP PRODUCTS (Enhanced with all features from screenshot)
// ==========================================
class TopProductsPage extends StatefulWidget {
  final String uid;
  final VoidCallback onBack;

  const TopProductsPage({super.key, required this.uid, required this.onBack});

  @override
  State<TopProductsPage> createState() => _TopProductsPageState();
}

class _TopProductsPageState extends State<TopProductsPage> {
  final FirestoreService _firestoreService = FirestoreService();
  DateFilterOption _selectedFilter = DateFilterOption.today;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  bool _isDescending = true;
  int _selectedTab = 0; // 0 = Sold, 1 = Not Sold


  // Cache the Products future so it does not re-fire on every setState
  Future<QuerySnapshot>? _productsFuture;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    _productsFuture = _firestoreService.getStoreCollection('Products').then((c) => c.get());
  }

  void _onDateChanged(DateFilterOption option, DateTime start, DateTime end) {
    setState(() {
      _selectedFilter = option;
      _startDate = start;
      _endDate = end;
    });
  }


  bool _isInDateRange(DateTime? dt) {
    if (dt == null) return false;
    return dt.isAfter(_startDate.subtract(const Duration(seconds: 1))) &&
        dt.isBefore(_endDate.add(const Duration(seconds: 1)));
  }

  void _downloadPdf(BuildContext context, List<MapEntry<String, Map<String, dynamic>>> products, double totalRev, double totalProfit) {
    final symbol = CurrencyService().symbol;
    final rows = products.map((e) => [
      e.key,
      (e.key == 'Total') ? '' : (e.value['quantity'] as double).toStringAsFixed(2),
      "$symbol${(e.value['amount'] as double).toStringAsFixed(2)}",
      "$symbol${(e.value['profit'] as double).toStringAsFixed(2)}",
    ]).toList();

    ReportPdfGenerator.generateAndDownloadPdf(
      context: context,
      reportTitle: 'Product Performance Audit',
      headers: ['Product Name', 'Qty', 'Revenue', 'Profit'],
      rows: rows,
      summaryTitle: 'Net Product Revenue',
      summaryValue: "$symbol${totalRev.toStringAsFixed(2)}",
      additionalSummary: {
        'Period': '${DateFormat('dd/MM/yy').format(_startDate)} - ${DateFormat('dd/MM/yy').format(_endDate)}',
        'Total Profit': '$symbol${totalProfit.toStringAsFixed(2)}',
        'Audit Status': 'Certified'
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Stream<QuerySnapshot>>(
      future: _firestoreService.getCollectionStream('sales'),
      builder: (context, streamSnapshot) {
        if (!streamSnapshot.hasData) {
          return Scaffold(
            backgroundColor: kBackgroundColor,
            appBar: _buildModernAppBar("Product Summary", widget.onBack),
            body: const Center(child: CircularProgressIndicator(color: kPrimaryColor, strokeWidth: 2)),
          );
        }
        return StreamBuilder<QuerySnapshot>(
          stream: streamSnapshot.data!,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Scaffold(
                backgroundColor: kBackgroundColor,
                appBar: _buildModernAppBar("Product Summary", widget.onBack),
                body: const Center(child: CircularProgressIndicator(color: kPrimaryColor)),
              );
            }

            // --- Fetch Current Products for Costs + Not-Sold List ---
            return FutureBuilder<QuerySnapshot>(
              future: _productsFuture,
              builder: (context, productsSnapshot) {
                Map<String, double> currentCosts = {};
                List<Map<String, dynamic>> allProductDocs = [];
                if (productsSnapshot.hasData) {
                  for (var doc in productsSnapshot.data!.docs) {
                    final d = doc.data() as Map<String, dynamic>;
                    final name = d['itemName']?.toString() ?? '';
                    final cost = double.tryParse(d['costPrice']?.toString() ?? d['cost']?.toString() ?? '0') ?? 0;
                    if (name.isNotEmpty) {
                      currentCosts[name] = cost;
                      allProductDocs.add(d);
                    }
                  }
                }

                Map<String, Map<String, dynamic>> productData = {};
                double grandTotalRevenue = 0;
                double grandTotalProfit = 0;

                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  DateTime? dt;
                  if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                  else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());

                  if (_isInDateRange(dt)) {
                    final String status = (data['status'] ?? '').toString().toLowerCase();
                    if (status == 'cancelled' || status == 'returned' || data['hasBeenReturned'] == true) {
                      continue;
                    }

                    if (data['items'] != null && data['items'] is List) {
                      for (var item in (data['items'] as List)) {
                        String name = item['name']?.toString() ?? 'Unknown';
                        double qty = double.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
                        double price = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
                        double cost = double.tryParse(item['cost']?.toString() ?? item['costPrice']?.toString() ?? item['purchasePrice']?.toString() ?? '0') ?? (currentCosts[name] ?? 0);
                        double total = double.tryParse(item['total']?.toString() ?? '0') ?? 0;
                        if (total == 0) total = price * qty;
                        double profit = (price * qty) - (cost * qty);

                        if (!productData.containsKey(name)) {
                          productData[name] = {'quantity': 0.0, 'amount': 0.0, 'profit': 0.0};
                        }
                        productData[name]!['quantity'] = (productData[name]!['quantity'] as double) + qty;
                        productData[name]!['amount'] = (productData[name]!['amount'] as double) + total;
                        productData[name]!['profit'] = (productData[name]!['profit'] as double) + profit;
                        grandTotalRevenue += total;
                        grandTotalProfit += profit;
                      }
                    }
                  }
                }

                var sortedProducts = productData.entries.toList();
                sortedProducts.sort((a, b) {
                  int result = (a.value['amount'] as double).compareTo(b.value['amount'] as double);
                  return _isDescending ? -result : result;
                });

                // Build not-sold: all products NOT sold in the same date range
                final soldNames = productData.keys.toSet();
                final notSoldProducts = allProductDocs
                    .where((d) => !soldNames.contains(d['itemName']?.toString() ?? ''))
                    .toList();
                notSoldProducts.sort((a, b) =>
                    (a['itemName']?.toString() ?? '').compareTo(b['itemName']?.toString() ?? ''));

                return Scaffold(
                  backgroundColor: kBackgroundColor,
                  appBar: _buildModernAppBar(
                    "Product Summary",
                    widget.onBack,
                    onDownload: () => _downloadPdf(context, sortedProducts, grandTotalRevenue, grandTotalProfit),
                  ),
                  body: Column(
                    children: [
                      _buildExecutiveProductHeader(grandTotalRevenue, grandTotalProfit),
                      // Single shared date filter for both tabs
                      DateFilterWidget(
                        selectedOption: _selectedFilter,
                        startDate: _startDate,
                        endDate: _endDate,
                        onDateChanged: _onDateChanged,
                        showSortButton: _selectedTab == 0,
                        isDescending: _isDescending,
                        onSortPressed: () => setState(() => _isDescending = !_isDescending),
                      ),
                      // Tab bar: Sold / Not Sold
                      Container(
                        color: kSurfaceColor,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedTab = 0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _selectedTab == 0 ? kPrimaryColor : kGreyBg,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Sold (${sortedProducts.length})',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: _selectedTab == 0 ? Colors.white : kTextSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedTab = 1),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _selectedTab == 1 ? kGoogleRed : kGreyBg,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Unsold (${notSoldProducts.length})',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: _selectedTab == 1 ? Colors.white : kTextSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _selectedTab == 0
                            ? CustomScrollView(
                          physics: const BouncingScrollPhysics(),
                          slivers: [
                            if (sortedProducts.isNotEmpty) ...[
                              const SliverToBoxAdapter(child: SizedBox(height: 16)),
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                sliver: SliverToBoxAdapter(child: _buildSectionHeader("Revenue contribution")),
                              ),
                              const SliverToBoxAdapter(child: SizedBox(height: 10)),
                              SliverToBoxAdapter(
                                child: _buildContributionGraph(sortedProducts, 'amount', kPrimaryColor),
                              ),
                            ],
                            const SliverToBoxAdapter(child: SizedBox(height: 24)),
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              sliver: SliverToBoxAdapter(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildSectionHeader("Product Performance Ledger"),
                                    Text(
                                      "${sortedProducts.length} ITEMS",
                                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: kPrimaryColor),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SliverToBoxAdapter(child: SizedBox(height: 8)),
                            sortedProducts.isEmpty
                                ? const SliverFillRemaining(child: Center(child: Text("No entries found", style: TextStyle(color: kTextSecondary))))
                                : SliverToBoxAdapter(child: _buildHighDensityProductTable(sortedProducts)),
                            const SliverToBoxAdapter(child: SizedBox(height: 40)),
                          ],
                        )
                            : _buildNotSoldProductList(notSoldProducts),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // --- EXECUTIVE UI COMPONENTS ---

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 1.2),
    );
  }

  Widget _buildExecutiveProductHeader(double revenue, double profit) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border(bottom: BorderSide(color: kBorderColor.withOpacity(0.5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Total Product Revenue", style: TextStyle(color: kTextSecondary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text("${revenue.toStringAsFixed(2)}", style:TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: kPrimaryColor  , letterSpacing: -1)),
                  const SizedBox(width: 8),
                  // Green info icon with black explanatory text
                  // Tooltip(
                  //   message: 'Profit is calculated based on the Total Cost Price',
                  //   child: Container(
                  //     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  //     decoration: BoxDecoration(
                  //       color: kIncomeGreen.withOpacity(0.12),
                  //       borderRadius: BorderRadius.circular(8),
                  //     ),
                  //     child: Row(
                  //       children: [
                  //         const Icon(Icons.info_outline, color: kIncomeGreen, size: 16),
                  //         const SizedBox(width: 6),
                  //         const Text(
                  //           'Profit is calculated based on the Total Cost Price',
                  //           style: TextStyle(
                  //             color: Colors.black,
                  //             fontSize: 12,
                  //             fontWeight: FontWeight.w700,
                  //           ),
                  //         ),
                  //       ],
                  //     ),
                  //   ),
                  // ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              color: kTextSecondary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kTextSecondary.withOpacity(0.1)),
            ),
            child: Column(
              children: [

                const Text("Profit", style: TextStyle(color: kTextSecondary, fontSize: 7, fontWeight: FontWeight.bold)),
                Text("${profit.toStringAsFixed(0)}", style: const TextStyle(color: kIncomeGreen, fontWeight: FontWeight.w900, fontSize: 26)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContributionGraph(List<MapEntry<String, Map<String, dynamic>>> data, String key, Color barColor) {
    // Top 6 products for chart clarity
    final chartData = data.take(6).toList();
    final double maxVal = _getMaxValue(chartData, key);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(12, 20, 16, 12),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor.withOpacity(0.7)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 140,
            child: BarChart(
              BarChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxVal > 0 ? maxVal / 4 : 10,
                  getDrawingHorizontalLine: (v) => FlLine(color: kBorderColor.withOpacity(0.2), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (v, m) {
                        if (v == 0) return const SizedBox();
                        String text = v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}k' : v.toStringAsFixed(0);
                        return Text(text, style: const TextStyle(fontSize: 8, color: kTextSecondary, fontWeight: FontWeight.bold));
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (v, m) {
                        int index = v.toInt();
                        if (index < 0 || index >= chartData.length) return const SizedBox();
                        String label = chartData[index].key;
                        if (label.length > 6) label = label.substring(0, 5) + "..";
                        return SideTitleWidget(
                          meta: m,
                          space: 8,
                          child: Text(label, style: const TextStyle(fontSize: 7, color: kTextSecondary, fontWeight: FontWeight.w900)),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: chartData.asMap().entries.map((e) {
                  final colorIndex = e.key % kChartColorsList.length;
                  // Each bar represents top product revenue
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: (e.value.value[key] as double),
                        color: kChartColorsList[colorIndex],
                        width: 16,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: 0,
                          color: kBorderColor.withValues(alpha: 0.1),
                        ),
                      )
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Caption
          Text(
            "Top products by revenue contribution",
            style: const TextStyle(fontSize: 9, color: kTextSecondary, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  double _getMaxValue(List<MapEntry<String, Map<String, dynamic>>> data, String key) {
    if (data.isEmpty) return 100;
    double max = 0;
    for (var e in data) {
      if (e.value[key] > max) max = e.value[key];
    }
    return max == 0 ? 100 : max;
  }

  Widget _buildHighDensityProductTable(List<MapEntry<String, Map<String, dynamic>>> rows) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border.symmetric(horizontal: BorderSide(color: kBorderColor.withOpacity(0.5))),
      ),
      child: Column(
        children: [
          Container(
            color: kBackgroundColor.withValues(alpha: 0.5),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              children: const [
                Expanded(flex: 1, child: Text("#", textAlign: TextAlign.left, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: kTextSecondary))),
                Expanded(flex: 4, child: Text("Product Name", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5))),
                Expanded(flex: 2, child: Text("Qty", textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: kTextSecondary))),
                Expanded(flex: 2, child: Text("Price", textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: kTextSecondary))),
                Expanded(flex: 2, child: Text("Revenue", textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: kTextSecondary))),
              ],
            ),
          ),
          ...rows.asMap().entries.map((entry) => _buildProductTableRowWithIndex(entry.key, entry.value)).toList(),
        ],
      ),
    );
  }

  Widget _buildProductTableRowWithIndex(int index, MapEntry<String, Map<String, dynamic>> entry) {
    final name = entry.key;
    final qty = (entry.value['quantity'] as double);
    final amount = (entry.value['amount'] as double);
    final price = qty > 0 ? (amount / qty) : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: kBorderColor.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          Expanded(flex: 1, child: Text('${index + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: kTextSecondary))),
          Expanded(
            flex: 4,
            child: Text(
              name,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black87),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(qty.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextSecondary)),
          ),
          Expanded(
            flex: 2,
            child: Text(price.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: kPrimaryColor)),
          ),
          Expanded(
            flex: 2,
            child: Text(amount.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: kPrimaryColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildProductTableRow(MapEntry<String, Map<String, dynamic>> entry) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: kBorderColor.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              entry.key,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black87),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              (entry.value['quantity'] as double).toStringAsFixed(0),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextSecondary),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "${(entry.value['amount'] as double).toStringAsFixed(0)}",
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: kPrimaryColor),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "${(entry.value['profit'] as double).toStringAsFixed(0)}",
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: kIncomeGreen),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotSoldProductList(List<Map<String, dynamic>> products) {
    if (products.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'All products have been sold in this period!',
            textAlign: TextAlign.center,
            style: TextStyle(color: kTextSecondary, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    return Column(
      children: [
        // Header count
        Container(
          width: double.infinity,
          color: kSurfaceColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Unsold Products', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 1)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: kGoogleRed.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: Text('${products.length} ITEMS', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kGoogleRed)),
              ),
            ],
          ),
        ),
        // Table header
        Container(
          color: kGreyBg,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: const Row(
            children: [
              Expanded(flex: 1, child: Text('#', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kTextSecondary))),
              Expanded(flex: 4, child: Text('Product Name', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5))),
              Expanded(flex: 2, child: Text('Stock', textAlign: TextAlign.right, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kTextSecondary))),
              Expanded(flex: 2, child: Text('Price', textAlign: TextAlign.right, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kTextSecondary))),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final d = products[index];
              final name = d['itemName']?.toString() ?? 'Unknown';
              final price = double.tryParse(d['price']?.toString() ?? '0') ?? 0;
              final stock = double.tryParse(d['currentStock']?.toString() ?? '0') ?? 0;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: kSurfaceColor,
                  border: Border(bottom: BorderSide(color: kBorderColor.withValues(alpha: 0.3))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Text('${index + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: kTextSecondary)),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(stock.toStringAsFixed(0), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextSecondary)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(price.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: kGoogleRed)),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ==========================================
// TOP CATEGORIES (Enhanced with all features from screenshot)
// ==========================================
class TopCategoriesPage extends StatefulWidget {
  final VoidCallback onBack;

  const TopCategoriesPage({super.key, required this.onBack});

  @override
  State<TopCategoriesPage> createState() => _TopCategoriesPageState();
}

class _TopCategoriesPageState extends State<TopCategoriesPage> {
  final FirestoreService _firestoreService = FirestoreService();
  DateFilterOption _selectedFilter = DateFilterOption.today;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  bool _isDescending = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
  }

  void _onDateChanged(DateFilterOption option, DateTime start, DateTime end) {
    setState(() {
      _selectedFilter = option;
      _startDate = start;
      _endDate = end;
    });
  }

  bool _isInDateRange(DateTime? dt) {
    if (dt == null) return false;
    return dt.isAfter(_startDate.subtract(const Duration(seconds: 1))) &&
        dt.isBefore(_endDate.add(const Duration(seconds: 1)));
  }

  void _downloadPdf(BuildContext context, List<MapEntry<String, Map<String, dynamic>>> categories, double totalRevenue) {
    final symbol = CurrencyService().symbol;
    final rows = categories.map((e) => [
      e.key,
      (e.value['quantity'] as double).toStringAsFixed(2),
      "$symbol${(e.value['amount'] as double).toStringAsFixed(2)}",
    ]).toList();

    ReportPdfGenerator.generateAndDownloadPdf(
      context: context,
      reportTitle: 'Category Performance Audit',
      headers: ['Category Name', 'Qty Sold', 'Revenue Amt'],
      rows: rows,
      summaryTitle: 'Total Category Sales',
      summaryValue: "$symbol${totalRevenue.toStringAsFixed(2)}",
      additionalSummary: {
        'Period': '${DateFormat('dd/MM/yy').format(_startDate)} - ${DateFormat('dd/MM/yy').format(_endDate)}',
        'Unique Categories': '${categories.length}',
        'Report Status': 'Finalized'
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Stream<QuerySnapshot>>(
      future: _firestoreService.getCollectionStream('sales'),
      builder: (context, streamSnapshot) {
        if (!streamSnapshot.hasData) {
          return Scaffold(
            backgroundColor: kBackgroundColor,
            appBar: _buildModernAppBar("Top Categories", widget.onBack),
            body: const Center(child: CircularProgressIndicator(color: kPrimaryColor, strokeWidth: 2)),
          );
        }
        return StreamBuilder<QuerySnapshot>(
          stream: streamSnapshot.data!,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Scaffold(
                backgroundColor: kBackgroundColor,
                appBar: _buildModernAppBar("Top Categories", widget.onBack),
                body: const Center(child: CircularProgressIndicator(color: kPrimaryColor)),
              );
            }

            Map<String, Map<String, dynamic>> categoryData = {};
            double totalRevenue = 0;
            double totalQty = 0;

            for (var doc in snapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              DateTime? dt;
              if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
              else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());

              if (_isInDateRange(dt)) {
                // Skip cancelled or returned bills
                final String status = (data['status'] ?? '').toString().toLowerCase();
                if (status == 'cancelled' || status == 'returned' || data['hasBeenReturned'] == true) {
                  continue;
                }

                if (data['items'] != null && data['items'] is List) {
                  for (var item in (data['items'] as List)) {
                    String category = item['category']?.toString() ?? 'Uncategorized';
                    double qty = double.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
                    double total = double.tryParse(item['total']?.toString() ?? '0') ?? 0;
                    if (total == 0) {
                      double price = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
                      total = price * qty;
                    }

                    if (!categoryData.containsKey(category)) {
                      categoryData[category] = {'quantity': 0.0, 'amount': 0.0};
                    }
                    categoryData[category]!['quantity'] = (categoryData[category]!['quantity'] as double) + qty;
                    categoryData[category]!['amount'] = (categoryData[category]!['amount'] as double) + total;
                    totalRevenue += total;
                    totalQty += qty;
                  }
                }
              }
            }

            var sortedCategories = categoryData.entries.toList();
            sortedCategories.sort((a, b) {
              int result = (a.value['amount'] as double).compareTo(b.value['amount'] as double);
              return _isDescending ? -result : result;
            });

            return Scaffold(
              backgroundColor: kBackgroundColor,
              appBar: _buildModernAppBar(
                "Top Categories",
                widget.onBack,
                onDownload: () => _downloadPdf(context, sortedCategories, totalRevenue),
              ),
              body: Column(
                children: [
                  _buildExecutiveCategoryHeader(totalRevenue, sortedCategories.length),
                  DateFilterWidget(
                    selectedOption: _selectedFilter,
                    startDate: _startDate,
                    endDate: _endDate,
                    onDateChanged: _onDateChanged,
                    showSortButton: true,
                    isDescending: _isDescending,
                    onSortPressed: () => setState(() => _isDescending = !_isDescending),
                  ),
                  Expanded(
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        if (sortedCategories.isNotEmpty) ...[
                          const SliverToBoxAdapter(child: SizedBox(height: 16)),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            sliver: SliverToBoxAdapter(child: _buildSectionHeader("Revenue contribution")),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 10)),
                          SliverToBoxAdapter(
                            child: _buildSingleBarDashboard(sortedCategories),
                          ),
                        ],

                        const SliverToBoxAdapter(child: SizedBox(height: 24)),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          sliver: SliverToBoxAdapter(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildSectionHeader("Detailed Inventory Ledger"),
                                Text(
                                  "${sortedCategories.length} GROUPS",
                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: kPrimaryColor),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 8)),

                        sortedCategories.isEmpty
                            ? const SliverFillRemaining(child: Center(child: Text("No entries found", style: TextStyle(color: kTextSecondary))))
                            : SliverToBoxAdapter(
                          child: _buildHighDensityTable(sortedCategories),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 40)),
                      ],
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

  // --- EXECUTIVE UI COMPONENTS ---

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 1.2),
    );
  }

  Widget _buildExecutiveCategoryHeader(double revenue, int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border(bottom: BorderSide(color: kBorderColor.withOpacity(0.5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Total Category Revenue", style: TextStyle(color: kTextSecondary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
              const SizedBox(height: 2),
              Text("${revenue.toStringAsFixed(2)}", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: kPrimaryColor, letterSpacing: -1)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: kPrimaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kPrimaryColor.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                Text("$count", style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w900, fontSize: 16)),
                const Text("Groups", style: TextStyle(color: kTextSecondary, fontSize: 7, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleBarDashboard(List<MapEntry<String, Map<String, dynamic>>> data) {
    // Take top 6 categories for the chart to keep it clean
    final chartData = data.take(6).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(12, 20, 16, 12),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor.withOpacity(0.7)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 140,
            child: BarChart(
              BarChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 10000,
                  getDrawingHorizontalLine: (v) => FlLine(color: kBorderColor.withOpacity(0.2), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (v, m) {
                        if (v == 0) return const SizedBox();
                        return Text(v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}k' : v.toStringAsFixed(0),
                            style: const TextStyle(fontSize: 8, color: kTextSecondary, fontWeight: FontWeight.bold));
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (v, m) {
                        int index = v.toInt();
                        if (index < 0 || index >= chartData.length) return const SizedBox();
                        String label = chartData[index].key;
                        if (label.length > 6) label = label.substring(0, 5) + "..";
                        return SideTitleWidget(
                          meta: m,
                          space: 8,
                          child: Text(label, style: const TextStyle(fontSize: 7, color: kTextSecondary, fontWeight: FontWeight.w900)),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: chartData.asMap().entries.map((e) {
                  final colorIndex = e.key % kChartColorsList.length;
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.value['amount'],
                        color: kChartColorsList[colorIndex],
                        width: 16,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: 0,
                          color: kBorderColor.withValues(alpha: 0.1),
                        ),
                      )
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text("Financial performance by top category segments", style: TextStyle(fontSize: 8, color: kTextSecondary, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildHighDensityTable(List<MapEntry<String, Map<String, dynamic>>> rows) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border.symmetric(horizontal: BorderSide(color: kBorderColor.withOpacity(0.5))),
      ),
      child: Column(
        children: [
          Container(
            color: kBackgroundColor.withOpacity(0.5),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              children: const [
                Expanded(flex: 3, child: Text("Category Name", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5))),
                Expanded(flex: 2, child: Text("Qty Sold", textAlign: TextAlign.right, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5))),
                Expanded(flex: 2, child: Text("Net Revenue", textAlign: TextAlign.right, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5))),
              ],
            ),
          ),
          ...rows.map((row) => _buildTableRow(row)).toList(),
        ],
      ),
    );
  }

  Widget _buildTableRow(MapEntry<String, Map<String, dynamic>> entry) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: kBorderColor.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              entry.key,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black87),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              (entry.value['quantity'] as double).toStringAsFixed(2),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextSecondary),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "${(entry.value['amount'] as double).toStringAsFixed(0)}",
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: kPrimaryColor),
            ),
          ),
        ],
      ),
    );
  }
}

class ExpenseReportPage extends StatefulWidget {
  final VoidCallback onBack;

  const ExpenseReportPage({super.key, required this.onBack});

  @override
  State<ExpenseReportPage> createState() => _ExpenseReportPageState();
}

class _ExpenseReportPageState extends State<ExpenseReportPage> {
  final FirestoreService _firestoreService = FirestoreService();
  String _currencySymbol = '';

  DateFilterOption _selectedFilter = DateFilterOption.thisMonth;
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();

  bool _showCombinedCategory = false;

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

  void _onDateChanged(DateFilterOption filter, DateTime start, DateTime end) {
    setState(() {
      _selectedFilter = filter;
      _startDate = start;
      _endDate = end;
    });
  }

  bool _isInRange(DateTime? dt, DateTime start, DateTime end) {
    if (dt == null) return false;
    final date = DateTime(dt.year, dt.month, dt.day);
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    return !date.isBefore(s) && !date.isAfter(e);
  }

  void _downloadPdf(BuildContext context, List<Map<String, dynamic>> all, double totalAmount, double cashTotal, double onlineTotal, double creditTotal) {
    final rows = all.map((e) => [
      e['title']?.toString() ?? 'N/A',
      e['category']?.toString() ?? e['type']?.toString() ?? 'N/A',
      "$_currencySymbol${(e['amount'] as double).toStringAsFixed(2)}",
      e['paymentMode']?.toString() ?? 'Cash',
      e['date'] is DateTime ? DateFormat('dd/MM/yy').format(e['date'] as DateTime) : '--',
    ]).toList();

    ReportPdfGenerator.generateAndDownloadPdf(
      context: context,
      reportTitle: 'Expense Report - ${DateFormat('MMMM yyyy').format(_startDate)}',
      headers: ['Description', 'Category', 'Amount', 'Mode', 'Date'],
      rows: rows,
      summaryTitle: 'Total Expenditure',
      summaryValue: "$_currencySymbol${totalAmount.toStringAsFixed(2)}",
      additionalSummary: {
        'Period': '${DateFormat('dd/MM/yy').format(_startDate)} - ${DateFormat('dd/MM/yy').format(_endDate)}',
        'Cash Payments': '$_currencySymbol${cashTotal.toStringAsFixed(2)}',
        'Online Payments': '$_currencySymbol${onlineTotal.toStringAsFixed(2)}',
        'Credit Outstanding': '$_currencySymbol${creditTotal.toStringAsFixed(2)}',
        'Total Records': '${all.length}',
      },
    );
  }

  String _getInitials(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length >= 2) return '${words[0][0]}${words[1][0]}';
    if (name.length >= 2) return name.substring(0, 2);
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: FutureBuilder<List<Stream<QuerySnapshot>>>(
        future: Future.wait([
          _firestoreService.getCollectionStream('expenses'),
          _firestoreService.getCollectionStream('stockPurchases'),
          _firestoreService.getCollectionStream('purchaseCreditNotes'),
        ]),
        builder: (context, streams) {
          if (!streams.hasData) {
            return Scaffold(
              appBar: _buildModernAppBar("Expense Report", widget.onBack),
              body: const Center(child: CircularProgressIndicator(color: kPrimaryColor, strokeWidth: 2)),
            );
          }
          return StreamBuilder<QuerySnapshot>(
            stream: streams.data![0],
            builder: (ctx, expSnap) {
              return StreamBuilder<QuerySnapshot>(
                stream: streams.data![1],
                builder: (ctx, stockSnap) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: streams.data![2],
                    builder: (ctx, creditNotesSnap) {
                      if (!expSnap.hasData || !stockSnap.hasData || !creditNotesSnap.hasData) {
                        return Scaffold(
                          appBar: _buildModernAppBar("Expense Report", widget.onBack),
                          body: const Center(child: CircularProgressIndicator(color: kPrimaryColor)),
                        );
                      }

                      // ── Calculate actual remaining credit from purchaseCreditNotes ──
                      // This reflects settled payments (paidAmount updates when user settles)
                      double totalRemainingCredit = 0;
                      double expRemainingCredit = 0;
                      double purchRemainingCredit = 0;
                      for (var doc in creditNotesSnap.data!.docs) {
                        final cnData = doc.data() as Map<String, dynamic>;
                        final cnAmt = ((cnData['amount'] ?? 0.0) as num).toDouble();
                        final cnPaid = ((cnData['paidAmount'] ?? 0.0) as num).toDouble();
                        final remaining = (cnAmt - cnPaid).clamp(0.0, double.infinity);

                        // Check timestamp to see if it falls in the selected date range
                        DateTime? cnDt;
                        if (cnData['timestamp'] != null) cnDt = (cnData['timestamp'] as Timestamp).toDate();

                        if (_isInRange(cnDt, _startDate, _endDate) && remaining > 0) {
                          totalRemainingCredit += remaining;
                          // Distinguish expense credit vs purchase credit
                          final cnType = (cnData['type'] ?? '').toString().toLowerCase();
                          final cnSupplier = (cnData['supplierName'] ?? '').toString().toLowerCase();
                          if (cnType.contains('expense') || cnSupplier.startsWith('expense:')) {
                            expRemainingCredit += remaining;
                          } else {
                            purchRemainingCredit += remaining;
                          }
                        }
                      }

                      // ── Data processing ──
                      List<Map<String, dynamic>> all = [];
                      double totalAmount = 0;
                      Map<String, double> categoryTotals = {};
                      Map<int, double> dayTotals = {};
                      Map<int, double> expDayTotals = {};
                      Map<int, double> purchDayTotals = {};
                      double cashTotal = 0, onlineTotal = 0;
                      int expenseCount = 0;
                      int opExpCount = 0, purchaseCount = 0;
                      double opExpTotal = 0, purchaseTotal = 0;
                      Map<String, Map<String, dynamic>> nameGrouped = {};

                      for (var d in expSnap.data!.docs) {
                        var data = d.data() as Map<String, dynamic>;
                        double amt = double.tryParse(data['amount'].toString()) ?? 0;
                        DateTime? dt;
                        if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                        else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());
                        String mode = (data['paymentMode'] ?? (data['isOnline'] == true ? 'Online' : 'Cash')).toString();

                        if (_isInRange(dt, _startDate, _endDate)) {
                          totalAmount += amt;
                          expenseCount++;
                          opExpCount++;
                          opExpTotal += amt;
                          // Firestore fields: expenseName, expenseType (not title/category)
                          String category = data['expenseType']?.toString() ?? data['category']?.toString() ?? 'General';
                          String title = data['expenseName']?.toString() ?? data['title']?.toString() ?? 'Expense';
                          categoryTotals[category] = (categoryTotals[category] ?? 0) + amt;
                          if (dt != null) {
                            dayTotals[dt.day] = (dayTotals[dt.day] ?? 0) + amt;
                            expDayTotals[dt.day] = (expDayTotals[dt.day] ?? 0) + amt;
                          }
                          // Payment mode breakdown using actual paid/credit amounts
                          final modeLower = mode.toLowerCase();
                          if (modeLower == 'credit') {
                            double paid = double.tryParse(data['paidAmount']?.toString() ?? '0') ?? 0;
                            cashTotal += paid;
                          } else if (modeLower.contains('online') || modeLower.contains('upi') || modeLower.contains('card')) {
                            onlineTotal += amt;
                          } else if (modeLower == 'split') {
                            double splitCash = double.tryParse(data['cashReceived_split']?.toString() ?? '0') ?? 0;
                            double splitOnline = double.tryParse(data['onlineReceived_split']?.toString() ?? '0') ?? 0;
                            cashTotal += splitCash;
                            onlineTotal += splitOnline;
                          } else {
                            cashTotal += amt;
                          }
                          final key = _showCombinedCategory ? category : title;
                          if (!nameGrouped.containsKey(key)) nameGrouped[key] = {'category': category, 'count': 0, 'amount': 0.0};
                          nameGrouped[key]!['count'] = (nameGrouped[key]!['count'] as int) + 1;
                          nameGrouped[key]!['amount'] = (nameGrouped[key]!['amount'] as double) + amt;
                          all.add({'title': title, 'amount': amt, 'type': 'Expense', 'category': category, 'date': dt ?? DateTime.now(), 'paymentMode': mode});
                        }
                      }

                      for (var d in stockSnap.data!.docs) {
                        var data = d.data() as Map<String, dynamic>;
                        double amt = double.tryParse(data['totalAmount']?.toString() ?? data['total']?.toString() ?? '0') ?? 0;
                        DateTime? dt;
                        if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                        else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());
                        String mode = (data['paymentMode'] ?? (data['isOnline'] == true ? 'Online' : 'Cash')).toString();

                        if (_isInRange(dt, _startDate, _endDate)) {
                          totalAmount += amt;
                          expenseCount++;
                          purchaseCount++;
                          purchaseTotal += amt;
                          String category = 'Purchase';
                          String title = data['supplierName']?.toString() ?? 'Purchase';
                          categoryTotals[category] = (categoryTotals[category] ?? 0) + amt;
                          if (dt != null) {
                            dayTotals[dt.day] = (dayTotals[dt.day] ?? 0) + amt;
                            purchDayTotals[dt.day] = (purchDayTotals[dt.day] ?? 0) + amt;
                          }
                          // Payment mode breakdown using actual paid/credit amounts
                          final modeLower = mode.toLowerCase();
                          if (modeLower == 'credit') {
                            double paid = double.tryParse(data['paidAmount']?.toString() ?? '0') ?? 0;
                            cashTotal += paid;
                          } else if (modeLower.contains('online') || modeLower.contains('upi') || modeLower.contains('card')) {
                            onlineTotal += amt;
                          } else if (modeLower == 'split') {
                            double splitCash = double.tryParse(data['cashReceived_split']?.toString() ?? '0') ?? 0;
                            double splitOnline = double.tryParse(data['onlineReceived_split']?.toString() ?? '0') ?? 0;
                            cashTotal += splitCash;
                            onlineTotal += splitOnline;
                          } else {
                            cashTotal += amt;
                          }
                          final key = _showCombinedCategory ? category : title;
                          if (!nameGrouped.containsKey(key)) nameGrouped[key] = {'category': category, 'count': 0, 'amount': 0.0};
                          nameGrouped[key]!['count'] = (nameGrouped[key]!['count'] as int) + 1;
                          nameGrouped[key]!['amount'] = (nameGrouped[key]!['amount'] as double) + amt;
                          all.add({'title': title, 'amount': amt, 'type': 'Stock', 'category': category, 'date': dt ?? DateTime.now(), 'paymentMode': mode});
                        }
                      }

                      all.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
                      var sortedNameEntries = nameGrouped.entries.toList()..sort((a, b) => (b.value['amount'] as double).compareTo(a.value['amount'] as double));
                      var sortedCategories = categoryTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

                      return Scaffold(
                        backgroundColor: kGreyBg,
                        appBar: _buildModernAppBar(
                          "Expense Report",
                          widget.onBack,
                          onDownload: () => _downloadPdf(context, all, totalAmount, cashTotal, onlineTotal, totalRemainingCredit),
                        ),
                        body: CustomScrollView(
                          physics: const BouncingScrollPhysics(),
                          slivers: [
                            SliverToBoxAdapter(
                              child: DateFilterWidget(
                                selectedOption: _selectedFilter,
                                startDate: _startDate,
                                endDate: _endDate,
                                onDateChanged: _onDateChanged,
                              ),
                            ),

                            // ── Expense Summary Strip ──
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: _buildExpSummaryStrip(expenseCount, totalAmount, opExpCount, opExpTotal, purchaseCount, purchaseTotal),
                              ),
                            ),

                            SliverPadding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              sliver: SliverList(
                                delegate: SliverChildListDelegate([
                                  const SizedBox(height: 4),
                                  _buildExpSectionLabel("Expense & Purchase Timeline"),
                                  const SizedBox(height: 8),
                                  _buildExpTimelineCard(dayTotals, expDayTotals, purchDayTotals),
                                  const SizedBox(height: 20),

                                  _buildExpSectionLabel("Expense Category"),
                                  const SizedBox(height: 8),
                                  _buildExpCategoryCard(sortedCategories, expenseCount, totalAmount),
                                  const SizedBox(height: 20),

                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      _buildExpSectionLabel("Expense By Category"),
                                      _buildExpCombinedToggle(),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  _buildExpNameTable(sortedNameEntries, totalAmount),
                                  const SizedBox(height: 20),
                                ]),
                              ),
                            ),

                            // ── Expense Name Table entries already shown above ──

                            SliverPadding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              sliver: SliverList(
                                delegate: SliverChildListDelegate([
                                  const SizedBox(height: 20),
                                  _buildExpSectionLabel("Payment Breakdown"),
                                  const SizedBox(height: 8),
                                  _buildExpPaymentCard(cashTotal, onlineTotal, totalRemainingCredit),

                                  // ── Credit Outstanding Section ──
                                  if (totalRemainingCredit > 0) ...[
                                    const SizedBox(height: 20),
                                    _buildExpSectionLabel("Credit Outstanding"),
                                    const SizedBox(height: 8),
                                    _buildExpCreditCard(totalRemainingCredit, expRemainingCredit, purchRemainingCredit),
                                  ],
                                  const SizedBox(height: 30),
                                ]),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // ─── Section Label (matches SalesSummary _buildSectionLabel) ───
  Widget _buildExpSectionLabel(String text) {
    return Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 1.2));
  }

  // ─── Summary Strip (matches SalesSummary _buildBillSummaryStrip) ───
  Widget _buildExpSummaryStrip(int count, double total, int opCount, double opTotal, int purchCount, double purchTotal) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: kSurfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorderColor.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: kExpenseRed.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.receipt_long_rounded, color: kExpenseRed, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Total Expenditure", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 1)),
                        Text("$_currencySymbol${total.toStringAsFixed(2)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kExpenseRed)),
                      ],
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 30, color: kBorderColor),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Records", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 1)),
                        Text("$count", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kTextPrimary)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Expense vs Purchase breakdown
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: kSurfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kExpenseRed.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: kExpenseRed.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.shopping_cart_outlined, size: 14, color: kExpenseRed),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Expense ($opCount)", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kTextSecondary)),
                          Text("$_currencySymbol${opTotal.toStringAsFixed(0)}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: kExpenseRed)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: kSurfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kWarningOrange.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: kWarningOrange.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.inventory_2_outlined, size: 14, color: kWarningOrange),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Purchase ($purchCount)", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kTextSecondary)),
                          Text("$_currencySymbol${purchTotal.toStringAsFixed(0)}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: kWarningOrange)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Timeline Chart (matches SalesSummary _buildRevenueTimelineCard) ───
  Widget _buildExpTimelineCard(Map<int, double> dayTotals, Map<int, double> expDays, Map<int, double> purchDays) {
    final allDays = dayTotals.keys.toList()..sort();
    int peakDay = 0;
    double peakVal = 0;
    dayTotals.forEach((d, v) { if (v > peakVal) { peakVal = v; peakDay = d; } });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor.withValues(alpha: 0.5)),
        //boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: kChartRed, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 4),
                const Text("Expense", style: TextStyle(fontSize: 10, color: kTextSecondary, fontWeight: FontWeight.w600)),
                const SizedBox(width: 10),
                Container(width: 10, height: 10, decoration: BoxDecoration(color: kWarningOrange, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 4),
                const Text("Purchase", style: TextStyle(fontSize: 10, color: kTextSecondary, fontWeight: FontWeight.w600)),
              ]),
              Text("Peak: Day $peakDay", style: const TextStyle(fontSize: 10, color: kTextSecondary, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 150,
            child: allDays.isEmpty
                ? const Center(child: Text('No data', style: TextStyle(color: kTextSecondary, fontSize: 12)))
                : BarChart(BarChartData(
              alignment: BarChartAlignment.spaceAround,
              gridData: FlGridData(
                show: true, drawVerticalLine: false,
                getDrawingHorizontalLine: (v) => FlLine(color: kBorderColor.withValues(alpha: 0.4), strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true, reservedSize: 22,
                  getTitlesWidget: (v, m) {
                    int d = v.toInt();
                    if (allDays.length > 10 && d % 3 != 1) return const SizedBox();
                    return Padding(padding: const EdgeInsets.only(top: 4), child: Text('$d', style: const TextStyle(fontSize: 9, color: kTextSecondary, fontWeight: FontWeight.w700)));
                  },
                )),
                leftTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true, reservedSize: 36,
                  getTitlesWidget: (v, m) {
                    if (v == 0) return const SizedBox();
                    String label = v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}K' : v.toStringAsFixed(0);
                    return Text(label, style: const TextStyle(fontSize: 8, color: kTextSecondary, fontWeight: FontWeight.w600));
                  },
                )),
              ),
              barGroups: allDays.map((day) {
                final expVal = expDays[day] ?? 0;
                final purchVal = purchDays[day] ?? 0;
                final barWidth = allDays.length > 20 ? 3.0 : allDays.length > 10 ? 4.0 : 5.0;
                return BarChartGroupData(x: day, barRods: [
                  if (expVal > 0) BarChartRodData(toY: expVal, color: kChartRed, width: barWidth, borderRadius: const BorderRadius.vertical(top: Radius.circular(2))),
                  if (purchVal > 0) BarChartRodData(toY: purchVal, color: kWarningOrange, width: barWidth, borderRadius: const BorderRadius.vertical(top: Radius.circular(2))),
                  if (expVal == 0 && purchVal == 0) BarChartRodData(toY: 0, color: kBorderColor, width: barWidth),
                ], barsSpace: 2);
              }).toList(),
            )),
          ),
        ],
      ),
    );
  }

  // ─── Category Donut Card (matches SalesSummary _buildPaymentStructureCard pattern) ───
  Widget _buildExpCategoryCard(List<MapEntry<String, double>> sorted, int count, double total) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor.withValues(alpha: 0.5)),
        //boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 4,
                child: SizedBox(
                  height: 130,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(PieChartData(
                        sectionsSpace: 3,
                        centerSpaceRadius: 32,
                        sections: sorted.isEmpty
                            ? [PieChartSectionData(color: kBorderColor.withValues(alpha: 0.3), value: 1, title: '', radius: 14)]
                            : sorted.asMap().entries.map((e) {
                          final c = kChartColorsList[e.key % kChartColorsList.length];
                          return PieChartSectionData(color: c, value: e.value.value, title: '', radius: 14);
                        }).toList(),
                      )),
                      Column(mainAxisSize: MainAxisSize.min, children: [
                        Text("$count", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: kTextPrimary)),
                        const Text("Recorded", style: TextStyle(fontSize: 8, color: kTextSecondary, fontWeight: FontWeight.w600)),
                      ]),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 6,
                child: Column(
                  children: sorted.map((entry) {
                    final idx = sorted.indexOf(entry);
                    final color = kChartColorsList[idx % kChartColorsList.length];
                    final pct = total > 0 ? (entry.value / total * 100) : 0.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 8),
                        Expanded(child: Text(entry.key, style: const TextStyle(fontSize: 10, color: kTextSecondary, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                        Text("${entry.value.toStringAsFixed(0)}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kTextPrimary)),
                        const SizedBox(width: 6),
                        Text("${pct.toStringAsFixed(0)}%", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
                      ]),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: kExpenseRed.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Icon(Icons.account_balance_wallet_rounded, size: 14, color: kExpenseRed),
                  const SizedBox(width: 6),
                  const Text("Total Expenditure", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kExpenseRed)),
                ]),
                Text("$_currencySymbol${total.toStringAsFixed(0)}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: kExpenseRed)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Combined Category Toggle ───
  Widget _buildExpCombinedToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        GestureDetector(
          onTap: () => setState(() => _showCombinedCategory = !_showCombinedCategory),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _showCombinedCategory ? kPrimaryColor.withValues(alpha: 0.08) : kSurfaceColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _showCombinedCategory ? kPrimaryColor.withValues(alpha: 0.3) : kBorderColor.withValues(alpha: 0.5)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text("Group by Category", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _showCombinedCategory ? kPrimaryColor : kTextSecondary)),
              const SizedBox(width: 6),
              AppMiniSwitch(value: _showCombinedCategory, onChanged: (v) => setState(() => _showCombinedCategory = v)),
            ]),
          ),
        ),
      ],
    );
  }

  // ─── Expense Name Table (Table Format) ───
  Widget _buildExpNameTable(List<MapEntry<String, Map<String, dynamic>>> entries, double total) {
    if (entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 36),
        decoration: BoxDecoration(
          color: kSurfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorderColor.withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            Icon(Icons.inbox_rounded, size: 42, color: kTextSecondary.withValues(alpha: 0.2)),
            const SizedBox(height: 8),
            const Text("No expenses for this period", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextSecondary)),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: kBorderColor.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 4, child: Text("Name", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kTextSecondary, letterSpacing: 0.5))),
                Expanded(flex: 2, child: Text("Category", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kTextSecondary, letterSpacing: 0.5))),
                SizedBox(width: 30, child: Text("Qty", textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kTextSecondary, letterSpacing: 0.5))),
                Expanded(flex: 2, child: Text("Amount", textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kTextSecondary, letterSpacing: 0.5))),
                SizedBox(width: 40, child: Text("%", textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kTextSecondary, letterSpacing: 0.5))),
              ],
            ),
          ),
          // Table Rows
          ...entries.asMap().entries.map((e) {
            final idx = e.key;
            final entry = e.value;
            final name = entry.key;
            final double amt = entry.value['amount'] as double;
            final int count = entry.value['count'] as int;
            final String category = entry.value['category'] as String;
            final double pct = total > 0 ? (amt / total * 100) : 0.0;
            final Color rowColor = kChartColorsList[idx % kChartColorsList.length];

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: kBorderColor.withValues(alpha: 0.3))),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Row(
                      children: [
                        Container(
                          width: 6, height: 6,
                          decoration: BoxDecoration(color: rowColor, borderRadius: BorderRadius.circular(2)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextPrimary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(category, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: kTextSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  SizedBox(width: 30, child: Text("$count", textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextSecondary))),
                  Expanded(
                    flex: 2,
                    child: Text("$_currencySymbol${amt.toStringAsFixed(1)}", textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: kExpenseRed)),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text("${pct.toStringAsFixed(1)}%", textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: rowColor)),
                  ),
                ],
              ),
            );
          }),
          // Total Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: kExpenseRed.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Expanded(flex: 4, child: Text("Total", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: kExpenseRed))),
                const Expanded(flex: 2, child: SizedBox()),
                SizedBox(width: 30, child: Text("${entries.fold<int>(0, (s, e) => s + (e.value['count'] as int))}", textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: kExpenseRed))),
                Expanded(flex: 2, child: Text("$_currencySymbol${total.toStringAsFixed(1)}", textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: kExpenseRed))),
                const SizedBox(width: 40, child: Text("100%", textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kExpenseRed))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Name Row (matches app's _buildBreakdownRow pattern) ───
  Widget _buildExpNameRow(MapEntry<String, Map<String, dynamic>> entry, double total, int idx) {
    final name = entry.key;
    final double amt = entry.value['amount'] as double;
    final int count = entry.value['count'] as int;
    final String category = entry.value['category'] as String;
    final double pct = total > 0 ? (amt / total * 100) : 0.0;
    final Color avatarColor = kChartColorsList[idx % kChartColorsList.length];
    final String initials = _getInitials(name);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: avatarColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: Text(initials, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: avatarColor)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(category, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: kTextSecondary, letterSpacing: 0.3)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("$_currencySymbol${amt.toStringAsFixed(1)}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: kExpenseRed)),
              const SizedBox(height: 2),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: kExpenseRed.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                  child: Text("${pct.toStringAsFixed(1)}%", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kExpenseRed)),
                ),
                const SizedBox(width: 4),
                Text("×$count", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kTextSecondary)),
              ]),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Payment Card (matches SalesSummary _buildPaymentStructureCard) ───
  Widget _buildExpPaymentCard(double cash, double online, double credit) {
    final total = cash + online + credit;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor.withValues(alpha: 0.5)),
        //boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Expanded(child: Row(children: [
              Icon(Icons.pie_chart_outline_rounded, color: kTextSecondary, size: 14),
              SizedBox(width: 6),
              Text("Payment Breakdown", style: TextStyle(fontSize: 10, color: kTextSecondary, fontWeight: FontWeight.w600)),
            ])),
            Text("$_currencySymbol${total.toStringAsFixed(0)}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: kTextPrimary)),
          ]),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: SizedBox(
                  height: 130,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(PieChartData(
                        sectionsSpace: 3,
                        centerSpaceRadius: 32,
                        sections: [
                          if (cash > 0) PieChartSectionData(color: kIncomeGreen, value: cash, title: '', radius: 14),
                          if (online > 0) PieChartSectionData(color: kChartBlue, value: online, title: '', radius: 14),
                          if (credit > 0) PieChartSectionData(color: kWarningOrange, value: credit, title: '', radius: 14),
                          if (total == 0) PieChartSectionData(color: kBorderColor.withValues(alpha: 0.3), value: 1, title: '', radius: 14),
                        ],
                      )),
                      Column(mainAxisSize: MainAxisSize.min, children: [
                        Text("$_currencySymbol${total.toStringAsFixed(0)}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: kTextPrimary)),
                        const Text("Total", style: TextStyle(fontSize: 8, color: kTextSecondary, fontWeight: FontWeight.w600)),
                      ]),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 6,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildExpLegendRow(kIncomeGreen, 'Cash', cash, total),
                    _buildExpLegendRow(kChartBlue, 'Online', online, total),
                    if (credit > 0) _buildExpLegendRow(kWarningOrange, 'Credit', credit, total),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: kIncomeGreen.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(children: [
                  Icon(Icons.account_balance_wallet_rounded, size: 14, color: kIncomeGreen),
                  SizedBox(width: 6),
                  Text("Cash + Online paid", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kIncomeGreen)),
                ]),
                Text("$_currencySymbol${(cash + online).toStringAsFixed(0)}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: kIncomeGreen)),
              ],
            ),
          ),
          if (credit > 0) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: kWarningOrange.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(children: [
                    Icon(Icons.credit_card_rounded, size: 14, color: kWarningOrange),
                    SizedBox(width: 6),
                    Text("Credit (to pay)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kWarningOrange)),
                  ]),
                  Text("$_currencySymbol${credit.toStringAsFixed(0)}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: kWarningOrange)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Credit Outstanding Card ───
  Widget _buildExpCreditCard(double totalCredit, double expCredit, double purchCredit) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kWarningOrange.withValues(alpha: 0.3)),
        //boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: kWarningOrange.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.credit_card_rounded, color: kWarningOrange, size: 16),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Remaining To Pay", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 1)),
                  Text("Credit outstanding for this period", style: TextStyle(fontSize: 10, color: kTextSecondary, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Text("$_currencySymbol${totalCredit.toStringAsFixed(2)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kWarningOrange)),
          ]),
          const SizedBox(height: 14),
          // Expense credit row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: kExpenseRed.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kExpenseRed.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: kExpenseRed.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.shopping_cart_outlined, size: 14, color: kExpenseRed),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text("Expense Credit", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextPrimary)),
                ),
                Text("$_currencySymbol${expCredit.toStringAsFixed(2)}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: kExpenseRed)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Purchase credit row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: kWarningOrange.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kWarningOrange.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: kWarningOrange.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.inventory_2_outlined, size: 14, color: kWarningOrange),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text("Purchase Credit", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextPrimary)),
                ),
                Text("$_currencySymbol${purchCredit.toStringAsFixed(2)}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: kWarningOrange)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpLegendRow(Color color, String label, double value, double total) {
    final pct = total > 0 ? (value / total * 100) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 10, color: kTextSecondary, fontWeight: FontWeight.w600))),
        Text("${value.toStringAsFixed(0)}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kTextPrimary)),
        const SizedBox(width: 6),
        Text("${pct.toStringAsFixed(0)}%", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

// ==========================================
// UNIFIED TAX REPORT PAGE (Tax + GST Combined)
// ==========================================
class TaxReportPage extends StatefulWidget {
  final VoidCallback onBack;

  const TaxReportPage({super.key, required this.onBack});

  @override
  State<TaxReportPage> createState() => _TaxReportPageState();
}

class _TaxReportPageState extends State<TaxReportPage> {
  final FirestoreService _firestoreService = FirestoreService();
  String _currencySymbol = '';

  DateTime? _fromDate;
  DateTime? _toDate;
  bool _showReport = false;

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

  Future<void> _selectFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now().subtract(const Duration(days: 30)),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _fromDate = picked);
    }
  }

  Future<void> _selectToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? DateTime.now(),
      firstDate: _fromDate ?? DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _toDate = picked);
    }
  }

  bool _isInDateRange(DateTime? dt, DateTime start, DateTime end) {
    if (dt == null) return false;
    final date = DateTime(dt.year, dt.month, dt.day);
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    return !date.isBefore(s) && !date.isAfter(e);
  }

  void _downloadPdf({
    required BuildContext context,
    required List<Map<String, dynamic>> taxableDocs,
    required double totalTaxAmount,
    required Map<String, double> taxBreakdown,
    required List<Map<String, dynamic>> salesRows,
    required List<Map<String, dynamic>> purchaseRows,
    required double totalSalesGST,
    required double totalPurchaseGST,
    required double netLiability,
  }) {
    final List<List<String>> allRows = [];

    // Add Sales Tax Data
    for (var d in taxableDocs) {
      allRows.add([
        DateFormat('dd/MM/yy').format(d['date'] ?? DateTime.now()),
        'TAX - SALES',
        d['invoiceNumber']?.toString() ?? 'N/A',
        d['customerName']?.toString() ?? 'Guest',
        "$_currencySymbol${(double.tryParse(d['total']?.toString() ?? '0') ?? 0).toStringAsFixed(2)}",
        "$_currencySymbol${(d['calculatedTax'] as double).toStringAsFixed(2)}",
      ]);
    }

    // Add GST Sales Data
    for (var row in salesRows) {
      allRows.add([
        DateFormat('dd/MM/yy').format(row['date']),
        'TAX - ${row['category']}',
        row['invoice'],
        row['gstNumber'],
        "$_currencySymbol${(row['amount'] as double).toStringAsFixed(2)}",
        "$_currencySymbol${(row['gst'] as double).toStringAsFixed(2)}",
      ]);
    }

    // Add GST Purchase Data
    for (var row in purchaseRows) {
      allRows.add([
        DateFormat('dd/MM/yy').format(row['date']),
        'TAX - ${row['category']}',
        row['invoice'],
        row['gstNumber'],
        "$_currencySymbol${(row['amount'] as double).toStringAsFixed(2)}",
        "$_currencySymbol${(row['gst'] as double).toStringAsFixed(2)}",
      ]);
    }

    ReportPdfGenerator.generateAndDownloadPdf(
      context: context,
      reportTitle: 'Comprehensive Tax Report',
      headers: ['Date', 'Type', 'Invoice', 'Party', 'Total', 'Tax Amount'],
      rows: allRows,
      summaryTitle: 'Tax Breakdown',
      summaryValue: "",

      additionalSummary: {
        'Period': '${DateFormat('dd/MM/yy').format(_fromDate!)} to ${DateFormat('dd/MM/yy').format(_toDate!)}',
        'Sales Tax': '$_currencySymbol${totalTaxAmount.toStringAsFixed(2)}',
        'Purchase Tax': '$_currencySymbol${totalPurchaseGST.toStringAsFixed(2)}',
        'Audit Status': 'Verified'
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_showReport) {
      return Scaffold(
        backgroundColor: kBackgroundColor,
        appBar: _buildModernAppBar("Tax Report Period", widget.onBack),
        // In build(), replace the !_showReport body:
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader("Select Audit Duration"),
                const SizedBox(height: 10),
                _buildDateTile("Start Date", _fromDate, _selectFromDate),
                const SizedBox(height: 8),
                _buildDateTile("End Date", _toDate, _selectToDate),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_fromDate != null && _toDate != null)
                        ? () => setState(() => _showReport = true)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Generate Audit Report',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),

      );
    }

    return FutureBuilder<List<dynamic>>(
      // Fetch streams + one-time customers snapshot so we can resolve customer tax numbers
      future: Future.wait([
        _firestoreService.getCollectionStream('sales'),
        _firestoreService.getCollectionStream('expenses'),
        _firestoreService.getCollectionStream('stockPurchases'),
        _firestoreService.getCollectionStream('creditNotes'),
        _firestoreService.getStoreCollection('customers').then((c) => c.get()),
      ]),
      builder: (context, streamsSnapshot) {
        if (!streamsSnapshot.hasData) {
          return Scaffold(
            backgroundColor: kBackgroundColor,
            appBar: _buildModernAppBar("Tax Report", () => setState(() => _showReport = false)),
            body: const Center(child: CircularProgressIndicator(color: kPrimaryColor, strokeWidth: 2)),
          );
        }

        // unpack the results: first 4 are streams, last is customers QuerySnapshot
        final salesStream = streamsSnapshot.data![0] as Stream<QuerySnapshot>;
        final expensesStream = streamsSnapshot.data![1] as Stream<QuerySnapshot>;
        final purchasesStream = streamsSnapshot.data![2] as Stream<QuerySnapshot>;
        final creditNotesStream = streamsSnapshot.data![3] as Stream<QuerySnapshot>;
        final customersSnapshot = streamsSnapshot.data![4] as QuerySnapshot;

        // Build a map from customer doc id (phone) -> gstin/gst
        final Map<String, String> customersGst = {};
        try {
          for (var doc in customersSnapshot.docs) {
            final d = doc.data() as Map<String, dynamic>;
            final gstVal = (d['gstin']?.toString() ?? d['gst']?.toString() ?? '').trim();
            if (gstVal.isNotEmpty) customersGst[doc.id] = gstVal;
          }
        } catch (_) {}

        return StreamBuilder<QuerySnapshot>(
          stream: salesStream,
          builder: (context, salesSnapshot) {
            return StreamBuilder<QuerySnapshot>(
              stream: expensesStream,
              builder: (context, expenseSnapshot) {
                return StreamBuilder<QuerySnapshot>(
                  stream: purchasesStream,
                  builder: (context, purchaseSnapshot) {
                    return StreamBuilder<QuerySnapshot>(
                      stream: creditNotesStream,
                      builder: (context, creditNoteSnapshot) {
                        if (!salesSnapshot.hasData || !expenseSnapshot.hasData || !purchaseSnapshot.hasData) {
                          return Scaffold(
                              appBar: _buildModernAppBar("Tax Report", () => setState(() => _showReport = false)),
                              body: const Center(child: CircularProgressIndicator(color: kPrimaryColor))
                          );
                        }

                        // --- Data Processing (Current Period) ---
                        double totalTaxAmount = 0;
                        Map<String, double> taxBreakdown = {};
                        var taxableDocs = <Map<String, dynamic>>[];

                        List<Map<String, dynamic>> salesRows = [];
                        double totalSalesGST = 0;

                        // Comparison Variables (Last Month/Prev Period)
                        int periodDays = _toDate!.difference(_fromDate!).inDays + 1;
                        DateTime prevStart = _fromDate!.subtract(Duration(days: periodDays));
                        DateTime prevEnd = _fromDate!.subtract(const Duration(days: 1));
                        double prevTaxAmount = 0;
                        double prevSalesGST = 0;

                        for (var d in salesSnapshot.data!.docs) {
                          var data = d.data() as Map<String, dynamic>;
                          DateTime? dt;
                          if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                          else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());

                          final String status = (data['status'] ?? '').toString().toLowerCase();
                          bool isCancelled = status == 'cancelled' || status == 'returned' || data['hasBeenReturned'] == true;

                          if (_isInDateRange(dt, _fromDate!, _toDate!)) {
                            if (isCancelled) continue;

                            double saleTax = double.tryParse(data['totalTax']?.toString() ?? '0') ?? 0;
                            if (saleTax == 0) {
                              saleTax = double.tryParse(data['taxAmount']?.toString() ?? data['tax']?.toString() ?? '0') ?? 0;
                            }

                            if (saleTax > 0) {
                              totalTaxAmount += saleTax;
                              if (data['taxes'] != null && data['taxes'] is List) {
                                for (var taxItem in (data['taxes'] as List)) {
                                  if (taxItem is Map<String, dynamic>) {
                                    String taxName = taxItem['name']?.toString() ?? 'Tax';
                                    double taxAmount = double.tryParse(taxItem['amount']?.toString() ?? '0') ?? 0;
                                    taxBreakdown[taxName] = (taxBreakdown[taxName] ?? 0) + taxAmount;
                                  }
                                }
                              } else {
                                taxBreakdown['Sales Tax'] = (taxBreakdown['Sales Tax'] ?? 0) + saleTax;
                              }
                              data['calculatedTax'] = saleTax;
                              data['date'] = dt;
                              taxableDocs.add(data);
                            }

                            // TAX details (use sale-level customerGST if present, otherwise fallback to customers collection gstin/gst)
                            String gstNum = (data['customerGST']?.toString() ?? '').trim();
                            if (gstNum.isEmpty) {
                              final phoneKey = (data['customerPhone']?.toString() ?? data['customerId']?.toString() ?? '').trim();
                              gstNum = customersGst[phoneKey] ?? '';
                            }
                            if (gstNum.isEmpty) gstNum = '--';

                            salesRows.add({
                              'date': dt,
                              'category': 'Sale',
                              'invoice': data['invoiceNumber']?.toString() ?? 'N/A',
                              'gstNumber': gstNum,
                              'amount': double.tryParse(data['total']?.toString() ?? '0') ?? 0,
                              'gst': saleTax,
                            });
                            totalSalesGST += saleTax;

                          } else if (_isInDateRange(dt, prevStart, prevEnd)) {
                            if (isCancelled) continue;
                            double saleTax = double.tryParse(data['totalTax']?.toString() ?? data['taxAmount']?.toString() ?? '0') ?? 0;
                            prevTaxAmount += saleTax;
                            prevSalesGST += saleTax;
                          }
                        }

                        List<Map<String, dynamic>> purchaseRows = [];
                        double totalPurchaseGST = 0;

                        void processInward(
                            QuerySnapshot snap,
                            String cat,
                            String amtKey,
                            String gstKey,
                            String gstNumKey, {
                              String invoiceKey = 'invoiceNumber',
                              String invoiceAutoKey = '',
                            }) {
                          for (var doc in snap.docs) {
                            final data = doc.data() as Map<String, dynamic>;
                            DateTime? dt;
                            if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                            else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());

                            if (_isInDateRange(dt, _fromDate!, _toDate!)) {
                              double amount = double.tryParse(data[amtKey]?.toString() ?? '0') ?? 0;
                              // gst may be stored under different keys (taxAmount, gst, etc.)
                              double gst = double.tryParse(data[gstKey]?.toString() ?? '0') ?? 0;

                              String gstNum = '';
                              if (gstNumKey != '--') {
                                gstNum = (data[gstNumKey]?.toString() ?? '').trim();
                              }
                              if (gstNum.isEmpty) {
                                final supplierKey = (data['supplierPhone']?.toString() ?? data['supplierId']?.toString() ?? data['customerPhone']?.toString() ?? data['customerId']?.toString() ?? '').trim();
                                gstNum = customersGst[supplierKey] ?? '';
                              }
                              if (gstNum.isEmpty) gstNum = '--';

                              // invoice handling: hide if auto-generated flag is set
                              String invRaw = (data[invoiceKey]?.toString() ?? '--');
                              String invoice = invRaw;
                              if (invoiceAutoKey.isNotEmpty) {
                                final auto = data[invoiceAutoKey];
                                if (auto == true) invoice = '--';
                              }

                              purchaseRows.add({
                                'date': dt,
                                'category': cat,
                                'invoice': invoice,
                                'gstNumber': gstNum,
                                'amount': amount,
                                'gst': gst,
                              });
                              totalPurchaseGST += gst;
                            }
                          }
                        }

                        // Expenses: use 'amount' and 'taxAmount' and 'taxNumber', reference/invoice key is 'referenceNumber'
                        processInward(expenseSnapshot.data!, 'Expense', 'amount', 'taxAmount', 'taxNumber', invoiceKey: 'referenceNumber', invoiceAutoKey: 'referenceAutoGenerated');
                        // Purchases: use 'totalAmount' and 'taxAmount' and 'supplierGstin'
                        processInward(purchaseSnapshot.data!, 'Purchase', 'totalAmount', 'taxAmount', 'supplierGstin', invoiceKey: 'invoiceNumber', invoiceAutoKey: 'invoiceAutoGenerated');
                        if (creditNoteSnapshot.hasData) {
                          // Credit notes may use 'amount' and 'gst' but likely don't need gst num mapping
                          processInward(creditNoteSnapshot.data!, 'Credit Note', 'amount', 'gst', '--', invoiceKey: 'invoiceNumber');
                        }

                        double gstNetLiability = totalSalesGST - totalPurchaseGST;
                        double totalNetTax = totalTaxAmount + gstNetLiability;

                        return Scaffold(
                          backgroundColor: kBackgroundColor,
                          appBar: _buildModernAppBar(
                              "Tax Report",
                                  () => setState(() => _showReport = false),
                              onDownload: () => _downloadPdf(
                                  context: context,
                                  taxableDocs: taxableDocs,
                                  totalTaxAmount: totalTaxAmount,
                                  taxBreakdown: taxBreakdown,
                                  salesRows: salesRows,
                                  purchaseRows: purchaseRows,
                                  totalSalesGST: totalSalesGST,
                                  totalPurchaseGST: totalPurchaseGST,
                                  netLiability: gstNetLiability
                              )
                          ),
                          bottomNavigationBar: SafeArea(
                            child: Container(
                              height: 130,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              color: kSurfaceColor,
                              child: _buildTaxSummary(salesRows, purchaseRows),
                            ),
                          ),
                          body: CustomScrollView(
                            physics: const BouncingScrollPhysics(),
                            slivers: [
                              SliverPadding(
                                padding: const EdgeInsets.only(
                                  left: 12, right: 12, top: 12,
                                  bottom: 120, // Enough to clear the floating bottom bar if it overlap
                                ),
                                sliver: SliverList(
                                  delegate: SliverChildListDelegate([
                                    // Date range card
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      margin: const EdgeInsets.only(bottom: 16),
                                      decoration: BoxDecoration(
                                        color: kSurfaceColor,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: kBorderColor.withOpacity(0.4)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(children: [
                                            const Text('From', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54, letterSpacing: 0.3)),
                                            const SizedBox(width: 8),
                                            const Text(':', style: TextStyle(color: Colors.black54)),
                                            const SizedBox(width: 8),
                                            Text(DateFormat('dd-MM-yyyy').format(_fromDate!), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black87)),
                                          ]),
                                          const SizedBox(height: 6),
                                          Row(children: [
                                            const Text('To      ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54, letterSpacing: 0.3)),
                                            const SizedBox(width: 8),
                                            const Text(':', style: TextStyle(color: Colors.black54)),
                                            const SizedBox(width: 8),
                                            Text(DateFormat('dd-MM-yyyy').format(_toDate!), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black87)),
                                          ]),
                                        ],
                                      ),
                                    ),

                                    _buildSectionHeader("Tax On Sales"),
                                    const SizedBox(height: 12),
                                    _buildGstTable(salesRows),
                                    const SizedBox(height: 24),
                                    _buildSectionHeader("Tax On Purchases"),
                                    const SizedBox(height: 12),
                                    _buildGstTable(purchaseRows),
                                    const SizedBox(height: 24),
                                  ]),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  // --- EXECUTIVE UI COMPONENTS ---

// ─── SECTION HEADER ──────────────────────────────────
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        title,
        style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: kTextSecondary,
            letterSpacing: 1.1),
      ),
    );
  }

// ─── DATE TILE ───────────────────────────────────────
  Widget _buildDateTile(String label, DateTime? date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: kSurfaceColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorderColor),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded,
                size: 14, color: kPrimaryColor.withOpacity(0.7)),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: kTextSecondary,
                        letterSpacing: 0.8)),
                const SizedBox(height: 2),
                Text(
                  date != null
                      ? DateFormat('dd MMM yyyy').format(date)
                      : 'Tap to select',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color:
                      date != null ? Colors.black87 : kTextSecondary),
                ),
              ],
            ),
            const Spacer(),
            Icon(Icons.keyboard_arrow_down_rounded,
                color: kPrimaryColor.withOpacity(0.4), size: 18),
          ],
        ),
      ),
    );
  }

// ─── UNIFIED TAX HEADER ──────────────────────────────


  Widget _buildTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }

// ─── BREAKDOWN MATRIX ────────────────────────────────
  Widget _buildBreakdownMatrix(List<MapEntry<String, double>> types) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorderColor.withOpacity(0.5)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: types.map((entry) {
          return Container(
            width: (MediaQuery.of(context).size.width - 64) / 2,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: kBackgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kBorderColor.withOpacity(0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.key,
                  style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: kTextSecondary,
                      letterSpacing: 0.5),
                ),
                const SizedBox(height: 3),
                Text(
                  "$_currencySymbol${entry.value.toStringAsFixed(2)}",
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

// ─── GST TABLE ───────────────────────────────────────
  Widget _buildGstTable(List<Map<String, dynamic>> rows,
      {Color headerColor = kPrimaryColor}) {
    double totalAmount = 0, totalTax = 0;
    for (var r in rows) {
      totalAmount += double.tryParse((r['amount'] ?? 0).toString()) ?? 0;
      totalTax += double.tryParse((r['gst'] ?? 0).toString()) ?? 0;
    }

    // Compact column style
    const headerStyle = TextStyle(
        fontSize: 9, fontWeight: FontWeight.w900, color: kTextSecondary);
    const cellStyle =
    TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.black87);
    const dimStyle =
    TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: kTextSecondary);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorderColor.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            decoration: BoxDecoration(
              color: headerColor.withOpacity(0.08),
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(9)),
            ),
            child: Row(
              children: const [
                Expanded(flex: 2, child: Text("Date", style: headerStyle)),
                Expanded(flex: 2, child: Text("Cat", style: headerStyle)),
                Expanded(flex: 2, child: Text("INV#", style: headerStyle)),
                Expanded(
                    flex: 3,
                    child: Text("TAX NO.", style: headerStyle)),
                Expanded(
                    flex: 2,
                    child: Text("Amt", textAlign: TextAlign.right, style: headerStyle)),
                Expanded(
                    flex: 2,
                    child: Text("Tax", textAlign: TextAlign.right, style: headerStyle)),
              ],
            ),
          ),

          // Empty state
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text("No data available",
                  style: TextStyle(
                      fontSize: 12,
                      color: kTextSecondary,
                      fontWeight: FontWeight.w600)),
            )
          else
            ...rows.map((row) {
              final DateTime? dt = row['date'] is DateTime
                  ? row['date'] as DateTime
                  : null;
              final String dateStr = dt != null
                  ? DateFormat('dd/MM/yy').format(dt)
                  : '--';
              final String category =
              (row['category']?.toString() ?? '');
              final String inv = (row['invoice']?.toString() ?? '--');
              final String gstNum =
              (row['gstNumber']?.toString() ?? '--');
              final double amount =
                  double.tryParse((row['amount'] ?? 0).toString()) ?? 0;
              final double gst =
                  double.tryParse((row['gst'] ?? 0).toString()) ?? 0;

              return Container(
                padding:
                const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
                decoration: BoxDecoration(
                  border: Border(
                      bottom: BorderSide(
                          color: kBorderColor.withOpacity(0.15))),
                ),
                child: Row(
                  children: [
                    Expanded(
                        flex: 2,
                        child: Text(dateStr, style: dimStyle)),
                    Expanded(
                        flex: 2,
                        child: Text(category, style: dimStyle)),
                    Expanded(
                        flex: 2,
                        child: Text(
                          inv,
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: kPrimaryColor),
                        )),
                    Expanded(
                        flex: 3,
                        child: Text(
                          gstNum.isEmpty ? '--' : gstNum,
                          style: dimStyle,
                          overflow: TextOverflow.ellipsis,
                        )),
                    Expanded(
                        flex: 2,
                        child: Text(
                          "$_currencySymbol${amount.toStringAsFixed(0)}",
                          textAlign: TextAlign.right,
                          style: cellStyle,
                        )),
                    Expanded(
                        flex: 2,
                        child: Text(
                          "$_currencySymbol${gst.toStringAsFixed(0)}",
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87),
                        )),
                  ],
                ),
              );
            }).toList(),

          // Totals row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
            decoration: BoxDecoration(
              color: kBackgroundColor.withOpacity(0.05),
              borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(9)),
            ),
            child: Row(
              children: [
                const Expanded(flex: 9, child: Text('Total',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: kTextSecondary))),
                Expanded(
                    flex: 2,
                    child: Text(
                      "$_currencySymbol${totalAmount.toStringAsFixed(0)}",
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w900),
                    )),
                Expanded(
                    flex: 2,
                    child: Text(
                      "$_currencySymbol${totalTax.toStringAsFixed(0)}",
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w900),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

// ─── BOTTOM SUMMARY BAR ──────────────────────────────
  Widget _buildTaxSummary(List<Map<String, dynamic>> salesRows,
      List<Map<String, dynamic>> purchaseRows) {
    double salesAmount = 0, salesGst = 0;
    for (var r in salesRows) {
      salesAmount += double.tryParse((r['amount'] ?? 0).toString()) ?? 0;
      salesGst += double.tryParse((r['gst'] ?? 0).toString()) ?? 0;
    }
    double purchaseAmount = 0, purchaseGst = 0;
    for (var r in purchaseRows) {
      purchaseAmount += double.tryParse((r['amount'] ?? 0).toString()) ?? 0;
      purchaseGst += double.tryParse((r['gst'] ?? 0).toString()) ?? 0;
    }
    final double netGst = salesGst - purchaseGst;

    Widget cell(String title, String value,
        {bool highlight = false, Color? color}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: kTextSecondary)),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: highlight ? (color ?? Colors.black87) : Colors.black87)),
        ],
      );
    }

    return Row(
      children: [
        // Sales
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: kBackgroundColor,
                borderRadius: BorderRadius.circular(8),
                border:
                Border.all(color: kBorderColor.withOpacity(0.3))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tax On Sales',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: kPrimaryColor)),
                const SizedBox(height: 5),
                cell('Taxable', '$_currencySymbol${salesAmount.toStringAsFixed(0)}'),
                const SizedBox(height: 4),
                cell('Tax', '$_currencySymbol${salesGst.toStringAsFixed(0)}',
                    highlight: true, color: kIncomeGreen),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Purchases
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: kBackgroundColor,
                borderRadius: BorderRadius.circular(8),
                border:
                Border.all(color: kBorderColor.withOpacity(0.3))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tax On Purchases',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: kPrimaryColor)),
                const SizedBox(height: 5),
                cell('Taxable', '$_currencySymbol${purchaseAmount.toStringAsFixed(0)}'),
                const SizedBox(height: 4),
                cell('Tax Paid', '$_currencySymbol${purchaseGst.toStringAsFixed(0)}',
                    highlight: true, color: kExpenseRed),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Net
        // Expanded(
        //   child: Container(
        //     padding: const EdgeInsets.all(8),
        //     decoration: BoxDecoration(
        //         color: kBackgroundColor,
        //         borderRadius: BorderRadius.circular(8),
        //         border:
        //             Border.all(color: kBorderColor.withOpacity(0.3))),
        //     child: Column(
        //       crossAxisAlignment: CrossAxisAlignment.start,
        //       children: [
        //         const Text('Net Tax Due',
        //             style: TextStyle(
        //                 fontSize: 9,
        //                 fontWeight: FontWeight.w900,
        //                 color: kPrimaryColor)),
        //         const SizedBox(height: 5),
        //         cell('Total Tax Due',
        //             '$_currencySymbol${netGst.toStringAsFixed(0)}',
        //             highlight: true,
        //             color: netGst >= 0 ? kExpenseRed : kIncomeGreen),
        //         const SizedBox(height: 4),
        //         cell('Advice',
        //             netGst >= 0 ? 'Pay Govt' : 'Claim Refund'),
        //       ],
        //     ),
        //   ),
        // ),
      ],
    );
  }

// Keep this — used in _buildComprehensiveSummary
  Widget _buildSummaryRecord(String label, double val, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: kTextSecondary)),
        Text("$_currencySymbol${val.toStringAsFixed(2)}",
            style: TextStyle(
                fontWeight: FontWeight.w900, fontSize: 12, color: color)),
      ],
    );
  }

}
// ==========================================
// INCOME SUMMARY PAGE (Enhanced with all features from screenshot)
// ==========================================
class IncomeSummaryPage extends StatefulWidget {
  final VoidCallback onBack;

  const IncomeSummaryPage({super.key, required this.onBack});

  @override
  State<IncomeSummaryPage> createState() => _IncomeSummaryPageState();
}

class _IncomeSummaryPageState extends State<IncomeSummaryPage> {
  final FirestoreService _firestoreService = FirestoreService();

  // Streams for credit tracker data
  Stream<QuerySnapshot>? _customersStream;   // Sales credit – total receivable
  Stream<QuerySnapshot>? _purchaseCreditStream; // Purchase credit – total payable

  @override
  void initState() {
    super.initState();
    _initCreditStreams();
  }

  void _initCreditStreams() async {
    final storeId = await _firestoreService.getCurrentStoreId();
    if (storeId == null || !mounted) return;
    setState(() {
      // customers with balance > 0 → total receivable
      _customersStream = FirebaseFirestore.instance
          .collection('store')
          .doc(storeId)
          .collection('customers')
          .where('balance', isGreaterThan: 0)
          .snapshots();

      // purchaseCreditNotes → total payable (amount - paidAmount)
      _purchaseCreditStream = FirebaseFirestore.instance
          .collection('store')
          .doc(storeId)
          .collection('purchaseCreditNotes')
          .snapshots();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: _buildModernAppBar("Business Insights", widget.onBack),
      body: FutureBuilder<List<Stream<QuerySnapshot>>>(
        future: Future.wait([
          _firestoreService.getCollectionStream('sales'),
          _firestoreService.getCollectionStream('expenses'),
          _firestoreService.getCollectionStream('stockPurchases'),
          _firestoreService.getCollectionStream('credits'),
        ]),
        builder: (context, streamsSnapshot) {
          if (!streamsSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: kPrimaryColor, strokeWidth: 2));
          }
          return StreamBuilder<QuerySnapshot>(
            stream: streamsSnapshot.data![0],
            builder: (context, salesSnapshot) {
              return StreamBuilder<QuerySnapshot>(
                stream: streamsSnapshot.data![1],
                builder: (context, expenseSnapshot) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: streamsSnapshot.data![2],
                    builder: (context, purchaseSnapshot) {
                      return StreamBuilder<QuerySnapshot>(
                        stream: streamsSnapshot.data![3],
                        builder: (context, creditsSnapshot) {
                          // Credit tracker streams
                          return StreamBuilder<QuerySnapshot>(
                            stream: _customersStream,
                            builder: (context, customersSnapshot) {
                              return StreamBuilder<QuerySnapshot>(
                                stream: _purchaseCreditStream,
                                builder: (context, purchaseCreditSnapshot) {
                                  if (!salesSnapshot.hasData || !expenseSnapshot.hasData || !purchaseSnapshot.hasData) {
                                    return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                                  }

                                  final now = DateTime.now();
                                  final todayStart = DateTime(now.year, now.month, now.day);
                                  final yesterday = now.subtract(const Duration(days: 1));
                                  final yesterdayStart = DateTime(yesterday.year, yesterday.month, yesterday.day);
                                  final last7Days = now.subtract(const Duration(days: 7));
                                  final thisMonthStart = DateTime(now.year, now.month, 1);

                                  double incomeToday = 0, incomeYesterday = 0, incomeLast7Days = 0, incomeThisMonth = 0;
                                  double expenseToday = 0, expenseYesterday = 0, expenseLast7Days = 0, expenseThisMonth = 0;

                                  // --- Process Sales (skip cancelled/returned like DayBook) ---
                                  for (var doc in salesSnapshot.data!.docs) {
                                    final data = doc.data() as Map<String, dynamic>;
                                    final String status = (data['status'] ?? '').toString().toLowerCase();
                                    if (status == 'cancelled' || status == 'returned' || data['hasBeenReturned'] == true) {
                                      continue;
                                    }
                                    DateTime? dt;
                                    if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                                    else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());

                                    double total = double.tryParse(data['total']?.toString() ?? '0') ?? 0;

                                    if (dt != null) {
                                      if (dt.isAfter(todayStart)) incomeToday += total;
                                      if (dt.isAfter(yesterdayStart) && dt.isBefore(todayStart)) incomeYesterday += total;
                                      if (dt.isAfter(last7Days)) incomeLast7Days += total;
                                      if (dt.isAfter(thisMonthStart)) incomeThisMonth += total;
                                    }
                                  }

                                  // --- Process Credits (credit collected = income, manual credit = expense, like DayBook) ---
                                  if (creditsSnapshot.hasData) {
                                    for (var doc in creditsSnapshot.data!.docs) {
                                      final data = doc.data() as Map<String, dynamic>;
                                      final type = (data['type'] ?? '').toString().toLowerCase();
                                      final amount = double.tryParse(data['amount']?.toString() ?? '0') ?? 0;
                                      DateTime? dt;
                                      if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                                      else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());

                                      // Skip sale_payment / credit_sale (already counted in sales)
                                      if (type == 'sale_payment' || type == 'credit_sale') continue;

                                      if (dt != null) {
                                        if (type.contains('payment_received') || type.contains('credit_payment') || type == 'settlement') {
                                          // Credit collected from customer = money IN (income)
                                          if (dt.isAfter(todayStart)) incomeToday += amount;
                                          if (dt.isAfter(yesterdayStart) && dt.isBefore(todayStart)) incomeYesterday += amount;
                                          if (dt.isAfter(last7Days)) incomeLast7Days += amount;
                                          if (dt.isAfter(thisMonthStart)) incomeThisMonth += amount;
                                        } else if (type == 'add_credit') {
                                          // Manual credit given to customer = money OUT (expense)
                                          if (dt.isAfter(todayStart)) expenseToday += amount;
                                          if (dt.isAfter(yesterdayStart) && dt.isBefore(todayStart)) expenseYesterday += amount;
                                          if (dt.isAfter(last7Days)) expenseLast7Days += amount;
                                          if (dt.isAfter(thisMonthStart)) expenseThisMonth += amount;
                                        }
                                      }
                                    }
                                  }

                                  // --- Process Expenses ---
                                  for (var doc in expenseSnapshot.data!.docs) {
                                    final data = doc.data() as Map<String, dynamic>;
                                    DateTime? dt;
                                    if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                                    else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());

                                    double amount = double.tryParse(data['amount']?.toString() ?? '0') ?? 0;

                                    if (dt != null) {
                                      if (dt.isAfter(todayStart)) expenseToday += amount;
                                      if (dt.isAfter(yesterdayStart) && dt.isBefore(todayStart)) expenseYesterday += amount;
                                      if (dt.isAfter(last7Days)) expenseLast7Days += amount;
                                      if (dt.isAfter(thisMonthStart)) expenseThisMonth += amount;
                                    }
                                  }

                                  // --- Credit Tracker: Total Receivable (customers.balance) ---
                                  double totalReceivable = 0;
                                  if (customersSnapshot.hasData) {
                                    for (var doc in customersSnapshot.data!.docs) {
                                      final data = doc.data() as Map<String, dynamic>;
                                      totalReceivable += ((data['balance'] ?? 0.0) as num).toDouble();
                                    }
                                  }

                                  // --- Credit Tracker: Total Payable (purchaseCreditNotes: amount - paidAmount) ---
                                  double totalPayable = 0;
                                  if (purchaseCreditSnapshot.hasData) {
                                    for (var doc in purchaseCreditSnapshot.data!.docs) {
                                      final data = doc.data() as Map<String, dynamic>;
                                      final amt = ((data['amount'] ?? 0.0) as num).toDouble();
                                      final paid = ((data['paidAmount'] ?? 0.0) as num).toDouble();
                                      totalPayable += (amt - paid).clamp(0, double.infinity);
                                    }
                                  }

                                  // --- Process Stock Purchases as expenses ---
                                  double purchaseToday = 0, purchaseYesterday = 0, purchaseLast7Days = 0, purchaseThisMonth = 0;
                                  for (var doc in purchaseSnapshot.data!.docs) {
                                    final data = doc.data() as Map<String, dynamic>;
                                    DateTime? dt;
                                    if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                                    else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());

                                    double amount = double.tryParse(data['totalAmount']?.toString() ?? data['amount']?.toString() ?? '0') ?? 0;

                                    if (dt != null) {
                                      if (dt.isAfter(todayStart)) purchaseToday += amount;
                                      if (dt.isAfter(yesterdayStart) && dt.isBefore(todayStart)) purchaseYesterday += amount;
                                      if (dt.isAfter(last7Days)) purchaseLast7Days += amount;
                                      if (dt.isAfter(thisMonthStart)) purchaseThisMonth += amount;
                                    }
                                  }

                                  // Total expenses = expenses + purchases
                                  final totalExpToday = expenseToday + purchaseToday;
                                  final totalExpYesterday = expenseYesterday + purchaseYesterday;
                                  final totalExpWeek = expenseLast7Days + purchaseLast7Days;
                                  final totalExpMonth = expenseThisMonth + purchaseThisMonth;

                                  // Build weekly data for chart (last 7 days, day-wise)
                                  final Map<int, double> weeklyIncome = {};
                                  final Map<int, double> weeklyExpense = {};
                                  for (int i = 6; i >= 0; i--) {
                                    weeklyIncome[6 - i] = 0;
                                    weeklyExpense[6 - i] = 0;
                                  }
                                  for (var doc in salesSnapshot.data!.docs) {
                                    final data = doc.data() as Map<String, dynamic>;
                                    // Skip cancelled/returned
                                    final String status = (data['status'] ?? '').toString().toLowerCase();
                                    if (status == 'cancelled' || status == 'returned' || data['hasBeenReturned'] == true) continue;
                                    DateTime? dt;
                                    if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                                    else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());
                                    double total = double.tryParse(data['total']?.toString() ?? '0') ?? 0;
                                    if (dt != null && dt.isAfter(last7Days)) {
                                      final daysAgo = now.difference(DateTime(dt.year, dt.month, dt.day)).inDays;
                                      if (daysAgo >= 0 && daysAgo <= 6) {
                                        weeklyIncome[6 - daysAgo] = (weeklyIncome[6 - daysAgo] ?? 0) + total;
                                      }
                                    }
                                  }
                                  // Credits for chart: credit collected = income, manual credit = expense
                                  if (creditsSnapshot.hasData) {
                                    for (var doc in creditsSnapshot.data!.docs) {
                                      final data = doc.data() as Map<String, dynamic>;
                                      final type = (data['type'] ?? '').toString().toLowerCase();
                                      final amount = double.tryParse(data['amount']?.toString() ?? '0') ?? 0;
                                      if (type == 'sale_payment' || type == 'credit_sale') continue;
                                      DateTime? dt;
                                      if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                                      else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());
                                      if (dt != null && dt.isAfter(last7Days)) {
                                        final daysAgo = now.difference(DateTime(dt.year, dt.month, dt.day)).inDays;
                                        if (daysAgo >= 0 && daysAgo <= 6) {
                                          if (type.contains('payment_received') || type.contains('credit_payment') || type == 'settlement') {
                                            weeklyIncome[6 - daysAgo] = (weeklyIncome[6 - daysAgo] ?? 0) + amount;
                                          } else if (type == 'add_credit') {
                                            weeklyExpense[6 - daysAgo] = (weeklyExpense[6 - daysAgo] ?? 0) + amount;
                                          }
                                        }
                                      }
                                    }
                                  }
                                  for (var doc in expenseSnapshot.data!.docs) {
                                    final data = doc.data() as Map<String, dynamic>;
                                    DateTime? dt;
                                    if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                                    else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());
                                    double amount = double.tryParse(data['amount']?.toString() ?? '0') ?? 0;
                                    if (dt != null && dt.isAfter(last7Days)) {
                                      final daysAgo = now.difference(DateTime(dt.year, dt.month, dt.day)).inDays;
                                      if (daysAgo >= 0 && daysAgo <= 6) {
                                        weeklyExpense[6 - daysAgo] = (weeklyExpense[6 - daysAgo] ?? 0) + amount;
                                      }
                                    }
                                  }
                                  for (var doc in purchaseSnapshot.data!.docs) {
                                    final data = doc.data() as Map<String, dynamic>;
                                    DateTime? dt;
                                    if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                                    else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());
                                    double amount = double.tryParse(data['totalAmount']?.toString() ?? data['amount']?.toString() ?? '0') ?? 0;
                                    if (dt != null && dt.isAfter(last7Days)) {
                                      final daysAgo = now.difference(DateTime(dt.year, dt.month, dt.day)).inDays;
                                      if (daysAgo >= 0 && daysAgo <= 6) {
                                        weeklyExpense[6 - daysAgo] = (weeklyExpense[6 - daysAgo] ?? 0) + amount;
                                      }
                                    }
                                  }

                                  return Column(
                                    children: [
                                      Expanded(
                                        child: CustomScrollView(
                                          physics: const BouncingScrollPhysics(),
                                          slivers: [
                                            SliverPadding(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                              sliver: SliverList(
                                                delegate: SliverChildListDelegate([
                                                  // ── Income VS Expense Performance Card ──
                                                  _buildPerformanceCard(incomeThisMonth, totalExpMonth),

                                                  const SizedBox(height: 16),

                                                  // ── Income VS Expense Bar Chart (Last 7 Days) ──
                                                  _buildIncomeExpenseChart(weeklyIncome, weeklyExpense, incomeLast7Days, totalExpWeek),

                                                  const SizedBox(height: 16),

                                                  // ── Comparison Cards with arrows ──
                                                  _buildSectionHeader("Income Vs Expense"),
                                                  const SizedBox(height: 8),
                                                  _buildComparisonRow("Today", incomeToday, totalExpToday),
                                                  const SizedBox(height: 8),
                                                  _buildComparisonRow("Yesterday", incomeYesterday, totalExpYesterday),
                                                  const SizedBox(height: 8),
                                                  _buildComparisonRow("Last 7 Days", incomeLast7Days, totalExpWeek),
                                                  const SizedBox(height: 8),
                                                  _buildComparisonRow("This Month", incomeThisMonth, totalExpMonth),

                                                  const SizedBox(height: 24),
                                                  _buildSectionHeader("Credit Tracker – Settlement Monitor"),
                                                  const SizedBox(height: 8),
                                                  _buildCreditSummaryBanner(totalReceivable, totalPayable),
                                                  const SizedBox(height: 8),
                                                  Row(
                                                    children: [
                                                      Expanded(child: _buildDuesTile("Total Receivable", totalReceivable, kIncomeGreen, Icons.call_received_rounded)),
                                                      const SizedBox(width: 8),
                                                      Expanded(child: _buildDuesTile("Total Payable", totalPayable, kExpenseRed, Icons.call_made_rounded)),
                                                    ],
                                                  ),

                                                  const SizedBox(height: 30),
                                                ]),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // ── Business Performance Card ──
  Widget _buildPerformanceCard(double totalIncome, double totalExpense) {
    final isHealthy = totalIncome >= totalExpense;
    final percentage = totalIncome > 0
        ? ((totalIncome - totalExpense) / totalIncome * 100).clamp(-999, 999)
        : (totalExpense > 0 ? -100.0 : 0.0);

    String performanceLabel;
    Color performanceColor;
    IconData performanceIcon;
    if (isHealthy) {
      if (percentage > 50) {
        performanceLabel = "Excellent";
        performanceColor = kIncomeGreen;
        performanceIcon = Icons.trending_up_rounded;
      } else if (percentage > 20) {
        performanceLabel = "Good";
        performanceColor = kIncomeGreen;
        performanceIcon = Icons.trending_up_rounded;
      } else {
        performanceLabel = "Average";
        performanceColor = kWarningOrange;
        performanceIcon = Icons.trending_flat_rounded;
      }
    } else {
      performanceLabel = "Needs Attention";
      performanceColor = kExpenseRed;
      performanceIcon = Icons.trending_down_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor.withOpacity(0.5)),
        // boxShadow: [
        //   BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        // ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Business Performance", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 1.2)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: performanceColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(performanceIcon, size: 14, color: performanceColor),
                    const SizedBox(width: 4),
                    Text(performanceLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: performanceColor)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Income vs Expense header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: kIncomeGreen, borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 6),
                        const Text("Total Income", style: TextStyle(fontSize: 11, color: kTextSecondary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${CurrencyService().symbol}${totalIncome.toStringAsFixed(0)}",
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: kIncomeGreen, letterSpacing: -0.5),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: kExpenseRed, borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 6),
                        const Text("Total Expense", style: TextStyle(fontSize: 11, color: kTextSecondary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${CurrencyService().symbol}${totalExpense.toStringAsFixed(0)}",
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: kExpenseRed, letterSpacing: -0.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  Expanded(
                    flex: totalIncome > 0 ? totalIncome.toInt().clamp(1, 999999) : 1,
                    child: Container(color: kIncomeGreen),
                  ),
                  Expanded(
                    flex: totalExpense > 0 ? totalExpense.toInt().clamp(1, 999999) : 1,
                    child: Container(color: kExpenseRed),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Net result
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: (isHealthy ? kIncomeGreen : kExpenseRed).withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isHealthy ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                      size: 16,
                      color: isHealthy ? kIncomeGreen : kExpenseRed,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isHealthy ? "Income exceeds expenses" : "Expenses exceed income",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isHealthy ? kIncomeGreen : kExpenseRed),
                    ),
                  ],
                ),
                Text(
                  "${percentage.abs().toStringAsFixed(1)}%",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: isHealthy ? kIncomeGreen : kExpenseRed),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Income vs Expense Bar Chart (Last 7 Days) ──
  Widget _buildIncomeExpenseChart(Map<int, double> weeklyIncome, Map<int, double> weeklyExpense, double totalWeekIncome, double totalWeekExpense) {
    final now = DateTime.now();
    final dayLabels = List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      return DateFormat('EEE').format(day);
    });

    double maxVal = 0;
    for (int i = 0; i < 7; i++) {
      final inc = weeklyIncome[i] ?? 0;
      final exp = weeklyExpense[i] ?? 0;
      if (inc > maxVal) maxVal = inc;
      if (exp > maxVal) maxVal = exp;
    }
    if (maxVal == 0) maxVal = 1000;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor.withOpacity(0.5)),
        // boxShadow: [
        //   BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        // ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Income Vs Expense", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 1.2)),
              const Text("Last 7 Days", style: TextStyle(fontSize: 10, color: kTextSecondary, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          // Legend
          Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: kIncomeGreen, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 4),
              const Text("Income", style: TextStyle(fontSize: 10, color: kTextSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(width: 16),
              Container(width: 10, height: 10, decoration: BoxDecoration(color: kExpenseRed, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 4),
              const Text("Expense", style: TextStyle(fontSize: 10, color: kTextSecondary, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal * 1.2,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final label = rodIndex == 0 ? 'Income' : 'Expense';
                      return BarTooltipItem(
                        '$label\n${CurrencyService().symbol}${rod.toY.toStringAsFixed(0)}',
                        TextStyle(color: rodIndex == 0 ? kIncomeGreen : kExpenseRed, fontWeight: FontWeight.w700, fontSize: 11),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < dayLabels.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(dayLabels[idx], style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kTextSecondary)),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                      reservedSize: 24,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        String label;
                        if (value >= 1000) {
                          label = '${(value / 1000).toStringAsFixed(1)}K';
                        } else {
                          label = value.toStringAsFixed(0);
                        }
                        return Text(label, style: const TextStyle(fontSize: 9, color: kTextSecondary, fontWeight: FontWeight.w600));
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxVal * 1.2 / 4,
                  getDrawingHorizontalLine: (value) => FlLine(color: kBorderColor.withOpacity(0.5), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(7, (i) {
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: weeklyIncome[i] ?? 0,
                        color: kIncomeGreen,
                        width: 10,
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                      ),
                      BarChartRodData(
                        toY: weeklyExpense[i] ?? 0,
                        color: kExpenseRed,
                        width: 10,
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Totals below chart
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    color: kIncomeGreen.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kIncomeGreen.withOpacity(0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Total Income", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kTextSecondary)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.arrow_upward_rounded, size: 14, color: kIncomeGreen),
                          const SizedBox(width: 2),
                          Text(
                            "${CurrencyService().symbol}${totalWeekIncome.toStringAsFixed(0)}",
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: kIncomeGreen),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    color: kExpenseRed.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kExpenseRed.withOpacity(0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Total Expense", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kTextSecondary)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.arrow_downward_rounded, size: 14, color: kExpenseRed),
                          const SizedBox(width: 2),
                          Text(
                            "${CurrencyService().symbol}${totalWeekExpense.toStringAsFixed(0)}",
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: kExpenseRed),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Comparison Row with arrows ──
  Widget _buildComparisonRow(String period, double income, double expense) {
    final isHealthy = income >= expense;
    final pct = income > 0
        ? ((income - expense) / income * 100).abs()
        : (expense > 0 ? 100.0 : 0.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderColor.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          // Period label
          SizedBox(
            width: 80,
            child: Text(period, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextPrimary)),
          ),
          // Income
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.arrow_upward_rounded, size: 13, color: kIncomeGreen),
                const SizedBox(width: 2),
                Text(
                  "${CurrencyService().symbol}${income.toStringAsFixed(0)}",
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kIncomeGreen),
                ),
              ],
            ),
          ),
          // Expense
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.arrow_downward_rounded, size: 13, color: kExpenseRed),
                const SizedBox(width: 2),
                Text(
                  "${CurrencyService().symbol}${expense.toStringAsFixed(0)}",
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kExpenseRed),
                ),
              ],
            ),
          ),
          // Status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (isHealthy ? kIncomeGreen : kExpenseRed).withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isHealthy ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  size: 12,
                  color: isHealthy ? kIncomeGreen : kExpenseRed,
                ),
                Text(
                  "${pct.toStringAsFixed(0)}%",
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: isHealthy ? kIncomeGreen : kExpenseRed),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditSummaryBanner(double receivable, double payable) {
    final net = receivable - payable;
    final isPositive = net >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPositive
              ? [kIncomeGreen.withOpacity(0.08), kIncomeGreen.withOpacity(0.02)]
              : [kExpenseRed.withOpacity(0.08), kExpenseRed.withOpacity(0.02)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (isPositive ? kIncomeGreen : kExpenseRed).withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Net Credit Position", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 1.2)),
              const SizedBox(height: 4),
              Text(
                "${CurrencyService().symbol}${net.abs().toStringAsFixed(2)}",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isPositive ? kIncomeGreen : kExpenseRed, letterSpacing: -0.5),
              ),
              Text(
                isPositive ? "Net amount to collect" : "Net amount to pay",
                style: TextStyle(fontSize: 10, color: isPositive ? kIncomeGreen : kExpenseRed, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isPositive ? kIncomeGreen : kExpenseRed).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              color: isPositive ? kIncomeGreen : kExpenseRed,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  // --- EXECUTIVE UI COMPONENTS ---

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        color: kTextSecondary,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildDailyCashStrip(double income, double expense) {
    final net = income - expense;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border(bottom: BorderSide(color: kBorderColor.withOpacity(0.5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Net Cash Position Today", style: TextStyle(color: kTextSecondary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 2),
              Text("${CurrencyService().symbol}${net.toStringAsFixed(2)}", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: net >= 0 ? kIncomeGreen : kExpenseRed, letterSpacing: -1)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("${CurrencyService().symbol}${income.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: kIncomeGreen)),
              Text("${CurrencyService().symbol}${expense.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: kExpenseRed)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonGrid(double today, double yesterday, double week, double month, Color themeColor) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildMetricTile("Today", today, themeColor)),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricTile("Yesterday", yesterday, themeColor)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildMetricTile("Last 7 Days", week, themeColor)),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricTile("This Month", month, themeColor)),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: kTextSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            "${CurrencyService().symbol}${value.toStringAsFixed(0)}",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color, letterSpacing: -0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildDuesTile(String label, double value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                Text("${CurrencyService().symbol}${value.toStringAsFixed(0)}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearlyInsightRow(String period, double income, double expense) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor.withOpacity(0.6)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(period, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Row(
            children: [
              Text("${CurrencyService().symbol}${income.toStringAsFixed(0)}", style: const TextStyle(color: kIncomeGreen, fontWeight: FontWeight.w900, fontSize: 14)),
              const Text("  /  ", style: TextStyle(color: kTextSecondary)),
              Text("${CurrencyService().symbol}${expense.toStringAsFixed(0)}", style: const TextStyle(color: kExpenseRed, fontWeight: FontWeight.w900, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }
}

// ==========================================
// Payment Summary PAGE (Enhanced with all features from screenshot)
// ==========================================
class PaymentReportPage extends StatefulWidget {
  final VoidCallback onBack;

  const PaymentReportPage({super.key, required this.onBack});

  @override
  State<PaymentReportPage> createState() => _PaymentReportPageState();
}

class _PaymentReportPageState extends State<PaymentReportPage> {
  final FirestoreService _firestoreService = FirestoreService();
  DateFilterOption _selectedFilter = DateFilterOption.today;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  String _currencySymbol = '';

  @override
  void initState() {
    super.initState();
    _loadCurrency();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
  }

  Future<void> _loadCurrency() async {
    await CurrencyService().loadCurrency();
    if (mounted) {
      setState(() {
        _currencySymbol = CurrencyService().symbolWithSpace;
      });
    }
  }

  void _onDateChanged(DateFilterOption option, DateTime start, DateTime end) {
    setState(() {
      _selectedFilter = option;
      _startDate = start;
      _endDate = end;
    });
  }

  bool _isInDateRange(DateTime? dt) {
    if (dt == null) return false;
    return dt.isAfter(_startDate.subtract(const Duration(seconds: 1))) &&
        dt.isBefore(_endDate.add(const Duration(seconds: 1)));
  }

  // Store calculated data for PDF download
  double _incomeCash = 0, _incomeOnline = 0, _incomeCredit = 0;
  double _expenseCash = 0, _expenseOnline = 0;
  int _incomeCashCount = 0, _incomeOnlineCount = 0, _incomeCreditCount = 0;
  int _expenseCashCount = 0, _expenseOnlineCount = 0;

  void _downloadPdf(BuildContext context) {
    final rows = [
      ['Income - Cash', '$_currencySymbol${_incomeCash.toStringAsFixed(2)}', '$_incomeCashCount txns'],
      ['Income - Online', '$_currencySymbol${_incomeOnline.toStringAsFixed(2)}', '$_incomeOnlineCount txns'],
      ['Income - Credit', '$_currencySymbol${_incomeCredit.toStringAsFixed(2)}', '$_incomeCreditCount txns'],
      ['Expense - Cash', '$_currencySymbol${_expenseCash.toStringAsFixed(2)}', '$_expenseCashCount txns'],
      ['Expense - Online', '$_currencySymbol${_expenseOnline.toStringAsFixed(2)}', '$_expenseOnlineCount txns'],
    ];

    double totalNet = (_incomeCash + _incomeOnline) - (_expenseCash + _expenseOnline);

    ReportPdfGenerator.generateAndDownloadPdf(
      context: context,
      reportTitle: 'Payment Summary Report',
      headers: ['Type', 'Amount', 'Transactions'],
      rows: rows,
      summaryTitle: "Net Cash Position",
      summaryValue: "$_currencySymbol${totalNet.toStringAsFixed(2)}",
      additionalSummary: {
        'Period': '${DateFormat('dd/MM/yy').format(_startDate)} - ${DateFormat('dd/MM/yy').format(_endDate)}',
        'Total Inflow': '$_currencySymbol${(_incomeCash + _incomeOnline).toStringAsFixed(2)}',
        'Total Outflow': '$_currencySymbol${(_expenseCash + _expenseOnline).toStringAsFixed(2)}',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: _buildModernAppBar("Payment Summary", widget.onBack, onDownload: () => _downloadPdf(context)),
      body: FutureBuilder<List<Stream<QuerySnapshot>>>(
        future: Future.wait([
          _firestoreService.getCollectionStream('sales'),
          _firestoreService.getCollectionStream('expenses'),
          _firestoreService.getCollectionStream('stockPurchases'),
          _firestoreService.getCollectionStream('credits'),
          _firestoreService.getCollectionStream('purchaseCreditNotes'),
        ]),
        builder: (context, streamsSnapshot) {
          if (!streamsSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: kPrimaryColor, strokeWidth: 2));
          }
          return StreamBuilder<QuerySnapshot>(
            stream: streamsSnapshot.data![0],
            builder: (context, salesSnapshot) {
              return StreamBuilder<QuerySnapshot>(
                stream: streamsSnapshot.data![1],
                builder: (context, expenseSnapshot) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: streamsSnapshot.data![2],
                    builder: (context, purchaseSnapshot) {
                      return StreamBuilder<QuerySnapshot>(
                        stream: streamsSnapshot.data![3],
                        builder: (context, creditsSnapshot) {
                          return StreamBuilder<QuerySnapshot>(
                            stream: streamsSnapshot.data![4],
                            builder: (context, purchaseCreditsSnapshot) {
                  if (!salesSnapshot.hasData || !expenseSnapshot.hasData || !purchaseSnapshot.hasData || !creditsSnapshot.hasData || !purchaseCreditsSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                  }

                  // --- Income from Sales (Money IN) ---
                  double incomeCash = 0, incomeOnline = 0, incomeCredit = 0;
                  int incomeCashCount = 0, incomeOnlineCount = 0, incomeCreditCount = 0;

                  // --- Credit Collections (Money IN from credit repayments) ---
                  double creditCollectedCash = 0, creditCollectedOnline = 0;
                  int creditCollectedCashCount = 0, creditCollectedOnlineCount = 0;

                  // --- Manual Credit Given (Money OUT) ---
                  double manualCreditCash = 0, manualCreditOnline = 0;
                  int manualCreditCashCount = 0, manualCreditOnlineCount = 0;

                  for (var doc in salesSnapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    DateTime? dt;
                    if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                    else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());

                    if (_isInDateRange(dt)) {
                      final String status = (data['status'] ?? '').toString().toLowerCase();
                      if (status == 'cancelled' || status == 'returned' || data['hasBeenReturned'] == true) continue;

                      double total = double.tryParse(data['total']?.toString() ?? '0') ?? 0;
                      String mode = (data['paymentMode'] ?? 'Cash').toString().toLowerCase();

                      if (mode == 'split') {
                        double splitCash = double.tryParse(data['cashReceived_split']?.toString() ?? '0') ?? 0;
                        double splitOnline = double.tryParse(data['onlineReceived_split']?.toString() ?? '0') ?? 0;
                        double splitCredit = double.tryParse(data['creditIssued_split']?.toString() ?? '0') ?? 0;
                        if (splitCash > 0) { incomeCash += splitCash; incomeCashCount++; }
                        if (splitOnline > 0) { incomeOnline += splitOnline; incomeOnlineCount++; }
                        if (splitCredit > 0) { incomeCredit += splitCredit; incomeCreditCount++; }
                      } else if (mode.contains('online') || mode.contains('upi') || mode.contains('card')) {
                        incomeOnline += total; incomeOnlineCount++;
                      } else if (mode.contains('credit')) {
                        final partialCash = double.tryParse(data['cashReceived_partial']?.toString() ?? '0') ?? 0;
                        final creditIssued = double.tryParse(data['creditIssued_partial']?.toString() ?? '0') ?? total;
                        if (partialCash > 0) { incomeCash += partialCash; incomeCashCount++; }
                        incomeCredit += creditIssued; incomeCreditCount++;
                      } else {
                        incomeCash += total; incomeCashCount++;
                      }
                    }
                  }

                  // --- Process Credits Collection ---
                  for (var doc in creditsSnapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    DateTime? dt;
                    if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                    else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());
                    if (_isInDateRange(dt)) {
                      final type = (data['type'] ?? '').toString().toLowerCase();
                      final amount = double.tryParse(data['amount']?.toString() ?? '0') ?? 0;
                      final method = (data['method'] ?? 'Cash').toString().toLowerCase();
                      if (type == 'sale_payment' || type == 'credit_sale') continue;
                      if (type.contains('payment_received') || type.contains('credit_payment') || type == 'settlement') {
                        if (method.contains('online') || method.contains('upi') || method.contains('card')) {
                          creditCollectedOnline += amount; creditCollectedOnlineCount++;
                        } else {
                          creditCollectedCash += amount; creditCollectedCashCount++;
                        }
                      } else if (type == 'add_credit') {
                        if (method.contains('online') || method.contains('upi') || method.contains('card')) {
                          manualCreditOnline += amount; manualCreditOnlineCount++;
                        } else {
                          manualCreditCash += amount; manualCreditCashCount++;
                        }
                      }
                    }
                  }

                  // --- Expense Calculations ---
                  double expenseCash = 0, expenseOnline = 0;
                  int expenseCashCount = 0, expenseOnlineCount = 0;
                  for (var doc in expenseSnapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    DateTime? dt;
                    if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                    else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());
                    if (_isInDateRange(dt)) {
                      double amount = double.tryParse(data['amount']?.toString() ?? '0') ?? 0;
                      String mode = (data['paymentMode'] ?? 'Cash').toString().toLowerCase();
                      if (mode.contains('online') || mode.contains('upi') || mode.contains('card')) {
                        expenseOnline += amount; expenseOnlineCount++;
                      } else {
                        expenseCash += amount; expenseCashCount++;
                      }
                    }
                  }

                  // --- Stock Purchase Calculations ---
                  double purchaseCash = 0, purchaseOnline = 0;
                  int purchaseCashCount = 0, purchaseOnlineCount = 0;
                  for (var doc in purchaseSnapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    DateTime? dt;
                    if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                    else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());
                    if (_isInDateRange(dt)) {
                      double amount = double.tryParse(data['totalAmount']?.toString() ?? '0') ?? 0;
                      String mode = (data['paymentMode'] ?? 'Cash').toString().toLowerCase();
                      if (mode.contains('online') || mode.contains('upi') || mode.contains('card')) {
                        purchaseOnline += amount; purchaseOnlineCount++;
                      } else if (mode.contains('credit')) {
                        // Purchase on credit — no actual money out yet
                      } else {
                        purchaseCash += amount; purchaseCashCount++;
                      }
                    }
                  }

                  // --- Purchase Credit Notes (payments made against purchase credits) ---
                  double purchaseCreditPaidCash = 0, purchaseCreditPaidOnline = 0;
                  int purchaseCreditPaidCashCount = 0, purchaseCreditPaidOnlineCount = 0;
                  for (var doc in purchaseCreditsSnapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    DateTime? dt;
                    if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                    else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());
                    if (_isInDateRange(dt)) {
                      final paidAmount = double.tryParse(data['paidAmount']?.toString() ?? '0') ?? 0;
                      final method = (data['paymentMethod'] ?? data['method'] ?? 'Cash').toString().toLowerCase();
                      if (paidAmount > 0) {
                        if (method.contains('online') || method.contains('upi') || method.contains('card')) {
                          purchaseCreditPaidOnline += paidAmount; purchaseCreditPaidOnlineCount++;
                        } else {
                          purchaseCreditPaidCash += paidAmount; purchaseCreditPaidCashCount++;
                        }
                      }
                    }
                  }

                  // --- Aggregate Totals ---
                  double totalInCash = incomeCash + creditCollectedCash;
                  double totalInOnline = incomeOnline + creditCollectedOnline;
                  int totalInCashCount = incomeCashCount + creditCollectedCashCount;
                  int totalInOnlineCount = incomeOnlineCount + creditCollectedOnlineCount;

                  double totalOutCash = expenseCash + purchaseCash + purchaseCreditPaidCash + manualCreditCash;
                  double totalOutOnline = expenseOnline + purchaseOnline + purchaseCreditPaidOnline + manualCreditOnline;
                  int totalOutCashCount = expenseCashCount + purchaseCashCount + purchaseCreditPaidCashCount + manualCreditCashCount;
                  int totalOutOnlineCount = expenseOnlineCount + purchaseOnlineCount + purchaseCreditPaidOnlineCount + manualCreditOnlineCount;

                  double totalIn = totalInCash + totalInOnline;
                  double totalOut = totalOutCash + totalOutOnline;
                  double totalNet = totalIn - totalOut;

                  // Store values for PDF download
                  _incomeCash = totalInCash;
                  _incomeOnline = totalInOnline;
                  _incomeCredit = incomeCredit;
                  _expenseCash = totalOutCash;
                  _expenseOnline = totalOutOnline;
                  _incomeCashCount = totalInCashCount;
                  _incomeOnlineCount = totalInOnlineCount;
                  _incomeCreditCount = incomeCreditCount;
                  _expenseCashCount = totalOutCashCount;
                  _expenseOnlineCount = totalOutOnlineCount;

                  return Column(
                    children: [
                      DateFilterWidget(
                        selectedOption: _selectedFilter,
                        startDate: _startDate,
                        endDate: _endDate,
                        onDateChanged: _onDateChanged,
                      ),
                      Expanded(
                        child: CustomScrollView(
                          physics: const BouncingScrollPhysics(),
                          slivers: [
                            SliverToBoxAdapter(
                              child: _buildNetPositionStrip(totalNet, totalIn, totalOut),
                            ),
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              sliver: SliverList(
                                delegate: SliverChildListDelegate([
                                  _buildSectionHeader("MONEY IN — INCOME"),
                                  const SizedBox(height: 8),
                                  _buildFlowAnalyticsCard(
                                    "Sales Receipts",
                                    incomeCash + incomeOnline,
                                    incomeCash,
                                    incomeOnline,
                                    kIncomeGreen,
                                    incomeCashCount + incomeOnlineCount,
                                  ),
                                  if (creditCollectedCash + creditCollectedOnline > 0) ...[
                                    const SizedBox(height: 12),
                                    _buildFlowAnalyticsCard(
                                      "Credit Collections",
                                      creditCollectedCash + creditCollectedOnline,
                                      creditCollectedCash,
                                      creditCollectedOnline,
                                      kIncomeGreen,
                                      creditCollectedCashCount + creditCollectedOnlineCount,
                                    ),
                                  ],
                                  if (incomeCredit > 0) ...[
                                    const SizedBox(height: 12),
                                    _buildCreditCard("Credit Sales (Pending)", incomeCredit, incomeCreditCount, kWarningOrange),
                                  ],
                                  const SizedBox(height: 24),
                                  _buildSectionHeader("MONEY OUT — EXPENSES"),
                                  const SizedBox(height: 8),
                                  _buildFlowAnalyticsCard(
                                    "Expenses",
                                    expenseCash + expenseOnline,
                                    expenseCash,
                                    expenseOnline,
                                    kExpenseRed,
                                    expenseCashCount + expenseOnlineCount,
                                  ),
                                  if (purchaseCash + purchaseOnline > 0) ...[
                                    const SizedBox(height: 12),
                                    _buildFlowAnalyticsCard(
                                      "Stock Purchases",
                                      purchaseCash + purchaseOnline,
                                      purchaseCash,
                                      purchaseOnline,
                                      kExpenseRed,
                                      purchaseCashCount + purchaseOnlineCount,
                                    ),
                                  ],
                                  if (purchaseCreditPaidCash + purchaseCreditPaidOnline > 0) ...[
                                    const SizedBox(height: 12),
                                    _buildCreditCard("Purchase Credits Paid", purchaseCreditPaidCash + purchaseCreditPaidOnline,
                                        purchaseCreditPaidCashCount + purchaseCreditPaidOnlineCount, kExpenseRed),
                                  ],
                                  if (manualCreditCash + manualCreditOnline > 0) ...[
                                    const SizedBox(height: 12),
                                    _buildCreditCard("Manual Credit Given", manualCreditCash + manualCreditOnline,
                                        manualCreditCashCount + manualCreditOnlineCount, kWarningOrange),
                                  ],
                                  const SizedBox(height: 24),
                                  _buildSectionHeader("Settlement Summary"),
                                  const SizedBox(height: 8),
                                  _buildLedgerRow("Cash Position", totalInCash, totalOutCash, kIncomeGreen),
                                  const SizedBox(height: 4),
                                  _buildLedgerRow("Online Balance", totalInOnline, totalOutOnline, kPrimaryColor),
                                  if (incomeCredit > 0) ...[
                                    const SizedBox(height: 4),
                                    _buildLedgerRow("Credit Outstanding", incomeCredit, 0, kWarningOrange),
                                  ],
                                  const SizedBox(height: 40),
                                ]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // --- EXECUTIVE UI COMPONENTS ---

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        color: kTextSecondary,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildNetPositionStrip(double net, double income, double expense) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border(bottom: BorderSide(color: kBorderColor.withOpacity(0.5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Net Cash Position", style: TextStyle(color: kTextSecondary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 2),
              Text(" ${net.toStringAsFixed(2)}", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: net >= 0 ? kIncomeGreen : kExpenseRed, letterSpacing: -1)),
            ],
          ),
          Row(
            children: [
              _buildSmallTrend(income, kIncomeGreen, Icons.arrow_downward_rounded),
              const SizedBox(width: 12),
              _buildSmallTrend(expense, kExpenseRed, Icons.arrow_upward_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallTrend(double val, Color color, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 4),
            Text(" ${val.toStringAsFixed(0)}", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
        Text(color == kIncomeGreen ? "IN" : "Out", style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: kTextSecondary)),
      ],
    );
  }

  Widget _buildFlowAnalyticsCard(String label, double total, double cash, double online, Color themeColor, int count) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor.withOpacity(0.6)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: kTextSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                  Text("${total.toStringAsFixed(2)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: themeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text("$count TXNS", style: TextStyle(color: themeColor, fontSize: 10, fontWeight: FontWeight.w900)),
              )
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: SizedBox(
                  height: 100,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 28,
                          sections: [
                            PieChartSectionData(color: kChartGreen, value: cash, title: '', radius: 12),
                            PieChartSectionData(color: kChartBlue, value: online, title: '', radius: 12),
                            if (total == 0) PieChartSectionData(color: kBorderColor, value: 1, title: '', radius: 12),
                          ],
                        ),
                      ),
                      const Icon(Icons.donut_large_rounded, size: 16, color: kTextSecondary),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 6,
                child: Column(
                  children: [
                    _buildCompactDistributionRow("Cash Mode", cash, total, kChartGreen),
                    const SizedBox(height: 8),
                    _buildCompactDistributionRow("Online Mode", online, total, kChartBlue),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactDistributionRow(String label, double val, double total, Color color) {
    final percent = total > 0 ? (val / total) * 100 : 0.0;
    return Row(
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: kTextSecondary, fontWeight: FontWeight.w600)),
              Text("${val.toStringAsFixed(0)}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        Text("${percent.toStringAsFixed(0)}%", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
      ],
    );
  }

  Widget _buildLedgerRow(String label, double income, double expense, Color themeColor) {
    final net = income - expense;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(width: 3, height: 24, decoration: BoxDecoration(color: themeColor, borderRadius: BorderRadius.circular(10))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                Text(
                  "IN: ${income.toStringAsFixed(0)} • OUT: ${expense.toStringAsFixed(0)}",
                  style: const TextStyle(fontSize: 9, color: kTextSecondary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Text(
            "${net.toStringAsFixed(0)}",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: net >= 0 ? kIncomeGreen : kExpenseRed),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditCard(String label, double amount, int count, Color themeColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: themeColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: themeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.credit_card_rounded, color: themeColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                Text("$count transactions", style: const TextStyle(fontSize: 9, color: kTextSecondary, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Text("${amount.toStringAsFixed(0)}", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: themeColor)),
        ],
      ),
    );
  }
}

// ==========================================
// GST REPORT NOW MERGED INTO TAX REPORT
// Use TaxReport for comprehensive tax and GST reporting
// ==========================================

class StaffSaleReportPage extends StatefulWidget {
  final VoidCallback onBack;

  const StaffSaleReportPage({super.key, required this.onBack});

  @override
  State<StaffSaleReportPage> createState() => _StaffSaleReportPageState();
}

class _StaffSaleReportPageState extends State<StaffSaleReportPage> {
  final FirestoreService _firestoreService = FirestoreService();
  DateFilterOption _selectedFilter = DateFilterOption.today;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  bool _isDescending = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
  }

  void _onDateChanged(DateFilterOption option, DateTime start, DateTime end) {
    setState(() {
      _selectedFilter = option;
      _startDate = start;
      _endDate = end;
    });
  }

  bool _isInDateRange(DateTime? dt) {
    if (dt == null) return false;
    return dt.isAfter(_startDate.subtract(const Duration(seconds: 1))) &&
        dt.isBefore(_endDate.add(const Duration(seconds: 1)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: _buildModernAppBar("Staff Performance", widget.onBack),
      body: FutureBuilder<Stream<QuerySnapshot>>(
        future: _firestoreService.getCollectionStream('sales'),
        builder: (context, streamSnapshot) {
          if (!streamSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: kPrimaryColor, strokeWidth: 2));
          }
          return StreamBuilder<QuerySnapshot>(
            stream: streamSnapshot.data!,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
              }

              // --- Process staff data ---
              Map<String, Map<String, dynamic>> staffData = {};
              double grandTotal = 0;
              int grandBills = 0;

              // Keep track of processed invoice identifiers to avoid duplicate counting
              final Set<String> _processedInvoices = <String>{};

              for (var doc in snapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                // Resolve an invoice identifier (prefer explicit invoiceNumber, fallback to doc id)
                final String invoiceId = (data['invoiceNumber'] ?? data['invoice'] ?? doc.id).toString();

                // Skip duplicate invoice entries if they appear multiple times in the snapshot
                if (_processedInvoices.contains(invoiceId)) continue;
                _processedInvoices.add(invoiceId);
                DateTime? dt;
                if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());

                if (_isInDateRange(dt)) {
                  // Skip cancelled or returned bills
                  final String status = (data['status'] ?? '').toString().toLowerCase();
                  if (status == 'cancelled' || status == 'returned' || data['hasBeenReturned'] == true) {
                    continue;
                  }

                  String staffName = data['staffName']?.toString() ?? 'owner';
                  double total = double.tryParse(data['total']?.toString() ?? '0') ?? 0;
                  double discount = double.tryParse(data['discount']?.toString() ?? '0') ?? 0;
                  String paymentMode = (data['paymentMode'] ?? 'Cash').toString().toLowerCase();

                  grandTotal += total;
                  grandBills++;

                  if (!staffData.containsKey(staffName)) {
                    staffData[staffName] = {
                      'salesCount': 0,
                      'totalAmount': 0.0,
                      'cashCount': 0,
                      'cashAmount': 0.0,
                      'onlineCount': 0,
                      'onlineAmount': 0.0,
                      'creditCount': 0,
                      'creditAmount': 0.0,
                      'creditNoteCount': 0,
                      'creditNoteAmount': 0.0,
                      'totalDiscount': 0.0,
                    };
                  }

                  staffData[staffName]!['salesCount'] = (staffData[staffName]!['salesCount'] as int) + 1;
                  staffData[staffName]!['totalAmount'] = (staffData[staffName]!['totalAmount'] as double) + total;
                  staffData[staffName]!['totalDiscount'] = (staffData[staffName]!['totalDiscount'] as double) + discount;

                  // Handle Split payments separately
                  if (paymentMode == 'split') {
                    double splitCash = double.tryParse(data['cashReceived_split']?.toString() ?? '0') ?? 0;
                    double splitOnline = double.tryParse(data['onlineReceived_split']?.toString() ?? '0') ?? 0;
                    double splitCredit = double.tryParse(data['creditIssued_split']?.toString() ?? '0') ?? 0;
                    if (splitCash > 0) {
                      staffData[staffName]!['cashCount'] = (staffData[staffName]!['cashCount'] as int) + 1;
                      staffData[staffName]!['cashAmount'] = (staffData[staffName]!['cashAmount'] as double) + splitCash;
                    }
                    if (splitOnline > 0) {
                      staffData[staffName]!['onlineCount'] = (staffData[staffName]!['onlineCount'] as int) + 1;
                      staffData[staffName]!['onlineAmount'] = (staffData[staffName]!['onlineAmount'] as double) + splitOnline;
                    }
                    if (splitCredit > 0) {
                      staffData[staffName]!['creditCount'] = (staffData[staffName]!['creditCount'] as int) + 1;
                      staffData[staffName]!['creditAmount'] = (staffData[staffName]!['creditAmount'] as double) + splitCredit;
                    }
                  } else if (paymentMode.contains('online') || paymentMode.contains('upi') || paymentMode.contains('card')) {
                    staffData[staffName]!['onlineCount'] = (staffData[staffName]!['onlineCount'] as int) + 1;
                    staffData[staffName]!['onlineAmount'] = (staffData[staffName]!['onlineAmount'] as double) + total;
                  } else if (paymentMode.contains('credit') && paymentMode.contains('note')) {
                    staffData[staffName]!['creditNoteCount'] = (staffData[staffName]!['creditNoteCount'] as int) + 1;
                    staffData[staffName]!['creditNoteAmount'] = (staffData[staffName]!['creditNoteAmount'] as double) + total;
                  } else if (paymentMode.contains('credit')) {
                    staffData[staffName]!['creditCount'] = (staffData[staffName]!['creditCount'] as int) + 1;
                    staffData[staffName]!['creditAmount'] = (staffData[staffName]!['creditAmount'] as double) + total;
                  } else {
                    staffData[staffName]!['cashCount'] = (staffData[staffName]!['cashCount'] as int) + 1;
                    staffData[staffName]!['cashAmount'] = (staffData[staffName]!['cashAmount'] as double) + total;
                  }
                }
              }

              var sortedEntries = staffData.entries.toList();
              sortedEntries.sort((a, b) {
                int result = (a.value['totalAmount'] as double).compareTo(b.value['totalAmount'] as double);
                return _isDescending ? -result : result;
              });

              return Column(
                children: [
                  _buildStaffExecutiveHeader(grandTotal, grandBills),
                  DateFilterWidget(
                    selectedOption: _selectedFilter,
                    startDate: _startDate,
                    endDate: _endDate,
                    onDateChanged: _onDateChanged,
                    showSortButton: true,
                    isDescending: _isDescending,
                    onSortPressed: () => setState(() => _isDescending = !_isDescending),
                  ),
                  Expanded(
                    child: sortedEntries.isEmpty
                        ? const Center(child: Text("No staff sales recorded for this period", style: TextStyle(color: kTextSecondary)))
                        : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      itemCount: sortedEntries.length,
                      itemBuilder: (context, index) {
                        final entry = sortedEntries[index];
                        return _buildStaffPerformanceCard(entry.key, entry.value);
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

  // --- EXECUTIVE UI COMPONENTS ---

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 1.2),
    );
  }

  Widget _buildStaffExecutiveHeader(double total, int bills) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border(bottom: BorderSide(color: kBorderColor.withOpacity(0.5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Total Staff Revenue", style: TextStyle(color: kTextSecondary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 2),
              Text("${total.toStringAsFixed(2)}", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: kPrimaryColor, letterSpacing: -1)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: kPrimaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kPrimaryColor.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                Text("$bills", style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w900, fontSize: 16)),
                const Text("Bills", style: TextStyle(color: kTextSecondary, fontSize: 7, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffPerformanceCard(String name, Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorderColor.withOpacity(0.7)),
        //boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: kPrimaryColor.withOpacity(0.1),
                    child: Text(name[0], style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.black87)),
                      Text("${data['salesCount']} TRANSACTIONS", style: const TextStyle(fontSize: 9, color: kTextSecondary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("${(data['totalAmount'] as double).toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: kPrimaryColor, letterSpacing: -0.5)),
                  const Text("Total Contribution", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionHeader("Payment Breakdown"),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildMiniStatTile("CASH", data['cashAmount'], kIncomeGreen)),
              const SizedBox(width: 8),
              Expanded(child: _buildMiniStatTile("ONLINE", data['onlineAmount'], kPrimaryColor)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildMiniStatTile("CREDIT", data['creditAmount'], kWarningOrange)),
              const SizedBox(width: 8),
              Expanded(child: _buildMiniStatTile("DISCOUNT", data['totalDiscount'], kExpenseRed)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatTile(String label, double val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: kBackgroundColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: kTextSecondary)),
          Text("${val.toStringAsFixed(0)}", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color.withOpacity(0.8))),
        ],
      ),
    );
  }
}
