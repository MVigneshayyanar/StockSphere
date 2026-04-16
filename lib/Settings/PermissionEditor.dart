import 'package:flutter/material.dart';
import 'package:maxbillup/Colors.dart';
import 'package:maxbillup/components/app_mini_switch.dart';

class PermissionEditorPage extends StatefulWidget {
  final String title;
  final Map<String, bool> permissions;
  final bool isDefault; // For visual indicator

  const PermissionEditorPage({
    super.key,
    required this.title,
    required this.permissions,
    this.isDefault = false,
  });

  @override
  State<PermissionEditorPage> createState() => _PermissionEditorPageState();
}

class _PermissionEditorPageState extends State<PermissionEditorPage> {
  late Map<String, bool> _editedPermissions;
  static const String _invoiceMasterKey = 'billHistory';
  static const List<String> _invoiceDependentKeys = [
    'editInvoice',
    'returnInvoice',
    'cancelInvoice',
  ];

  // Permission categories for organized display
  final Map<String, List<String>> _categories = {
    'Sales & Billing': ['customerManagement', 'creditDetails','quotation', 'creditNotes'],
    'Invoice Actions': ['billHistory', 'editInvoice', 'returnInvoice', 'cancelInvoice'],
    'Expenses Management': ['expenses', 'expenseCategories', 'stockPurchase', 'vendors'],
    'Growth+': [
      'daybook', 'salesSummary', 'salesReport', 'analytics','itemSalesReport',
      'topCustomer', 'stockReport', 'lowStockProduct', 'topProducts',
      'topCategory', 'expensesReport', 'taxReport', 'staffSalesReport'
    ],
    'Product Management': ['addProduct', 'addCategory'],
    'Settings': ['editBusinessProfile', 'receiptCustomization', 'taxSettings'],
  };

  @override
  void initState() {
    super.initState();
    _editedPermissions = Map.from(widget.permissions);

    // Ensure all known permissions exist (add missing ones with default false)
    final allKnownPermissions = <String>[];
    for (var permList in _categories.values) {
      allKnownPermissions.addAll(permList);
    }

    for (var perm in allKnownPermissions) {
      if (!_editedPermissions.containsKey(perm)) {
        _editedPermissions[perm] = false;
      }
    }

    _normalizeInvoiceActions();
  }

  void _normalizeInvoiceActions() {
    final masterValue = _editedPermissions[_invoiceMasterKey] ?? false;
    for (final key in _invoiceDependentKeys) {
      _editedPermissions[key] = masterValue;
    }
  }

  void _handlePermissionToggle(String key, bool newValue) {
    setState(() {
      _editedPermissions[key] = newValue;

      if (key == _invoiceMasterKey) {
        for (final depKey in _invoiceDependentKeys) {
          _editedPermissions[depKey] = newValue;
        }
      }
    });
  }

  String _formatPermissionName(String key) {
    // Custom display names for permission keys (matching Reports.dart tile titles)
    const displayNames = {
      'quotation': 'Estimation / Quotation',
      'billHistory': 'Manage Bills',
      'creditNotes': 'Return & Refunds',
      'customerManagement': 'Customers',
      'creditDetails': 'Credits & Dues',
      'staffManagement': 'Staff Access & Roles',
      // Expenses (4 sub-items)
      'expenses': 'Expenses',
      'expenseCategories': 'Expense Category',
      'stockPurchase': 'Product Purchase',
      'vendors': 'Suppliers',
      // Reports
      'daybook': 'Daybook Today',
      'analytics': 'Business Summary',
      'salesSummary': 'Business Insights',
      'salesReport': 'Sales Record',
      'itemSalesReport': 'Item Sales Report',
      'topCustomer': 'Top Customers',
      'stockReport': 'Stock Report',
      'lowStockProduct': 'Low Stock Products',
      'topProducts': 'Product Summary',
      'topCategory': 'Top Categories',
      'expensesReport': 'Expense Report',
      'taxReport': 'Tax Report',
      'staffSalesReport': 'Staff Sale Report',
      // Invoice Actions
      'editInvoice': 'Edit Bill',
      'returnInvoice': 'Return Bill',
      'cancelInvoice': 'Cancel Bill',
      // Product Management
      'addProduct': 'Add Product',
      'addCategory': 'Add Category',
      // Settings
      'editBusinessProfile': 'Edit Business Profile',
      'receiptCustomization': 'Bill & Receipt Settings',
      'taxSettings': 'Tax Settings',
    };
    if (displayNames.containsKey(key)) return displayNames[key]!;
    return key
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(0)}')
        .split(' ')
        .map((word) => word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '')
        .join(' ')
        .trim();
  }

  void _toggleAll(bool value) {
    setState(() {
      for (var key in _editedPermissions.keys) {
        _editedPermissions[key] = value;
      }
      _normalizeInvoiceActions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final enabledCount = _editedPermissions.values.where((v) => v).length;
    final totalCount = _editedPermissions.length;

    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 16),
        ),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: kWhite, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (widget.isDefault)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: kOrange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Center(
                child: Text(
                  'Default',
                  style: TextStyle(
                    color: kWhite,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Lato',
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Summary Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: kWhite,
              border: Border(bottom: BorderSide(color: kGrey200)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.security, color: kPrimaryColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$enabledCount of $totalCount permissions enabled',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: kBlack87,
                          fontFamily: 'NotoSans',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Toggle permissions below',
                        style: TextStyle(
                          fontSize: 12,
                          color: kBlack54,
                          fontFamily: 'Lato',
                        ),
                      ),
                    ],
                  ),
                ),
                // Quick actions
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: kBlack54),
                  onSelected: (value) {
                    if (value == 'enable_all') _toggleAll(true);
                    if (value == 'disable_all') _toggleAll(false);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'enable_all',
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: kGoogleGreen, size: 20),
                          SizedBox(width: 12),
                          Text('Enable All'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'disable_all',
                      child: Row(
                        children: [
                          Icon(Icons.cancel, color: kErrorColor, size: 20),
                          SizedBox(width: 12),
                          Text('Disable All'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Permission List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: _buildPermissionsList(),
            ),
          ),

          // Save Button
          SafeArea(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: kWhite,
                border: Border(top: BorderSide(color: kGrey200)),
              ),
              child: ElevatedButton(
                onPressed: () {
                  _normalizeInvoiceActions();
                  Navigator.pop(context, _editedPermissions);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text(
                  'Save Permissions',
                  style: TextStyle(
                    color: kWhite,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    fontFamily: 'Lato',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPermissionsList() {
    List<Widget> widgets = [];

    _categories.forEach((category, permKeys) {
      // Category Header
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: kPrimaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                category,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: kPrimaryColor,
                  letterSpacing: 1,
                  fontFamily: 'NotoSans',
                ),
              ),
            ],
          ),
        ),
      );

      // Permission Items
      List<Widget> permissionItems = [];
      for (var key in permKeys) {
        if (_editedPermissions.containsKey(key)) {
          permissionItems.add(
            _buildPermissionTile(key, _editedPermissions[key] ?? false),
          );
        }
      }

      if (permissionItems.isNotEmpty) {
        widgets.add(
          Container(
            decoration: BoxDecoration(
              color: kWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kGrey200),
            ),
            child: Column(children: permissionItems),
          ),
        );
      }
    });

    return widgets;
  }

  Widget _buildPermissionTile(String key, bool value) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: kGrey100)),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          _formatPermissionName(key),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: kBlack87,
            fontFamily: 'Lato',
          ),
        ),
        trailing: AppMiniSwitch(
          value: value,
          onChanged: (newValue) {
            _handlePermissionToggle(key, newValue);
          },
        ),
      ),
    );
  }
}