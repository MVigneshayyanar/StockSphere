import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/utils/permission_helper.dart';
import 'package:maxbillup/utils/translation_helper.dart';

// ==========================================
// EXAMPLE: Permission-Protected Page
// ==========================================

/// This is an example showing how to protect pages and actions with permissions
class ExampleProtectedPage extends StatefulWidget {
  final String uid;
  final String? userEmail;

  const ExampleProtectedPage({
    super.key,
    required this.uid,
    this.userEmail,
  });

  @override
  State<ExampleProtectedPage> createState() => _ExampleProtectedPageState();
}

class _ExampleProtectedPageState extends State<ExampleProtectedPage> {
  Map<String, dynamic>? _userPermissions;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    final permissions = await PermissionHelper.getUserPermissions(widget.uid);
    setState(() {
      _userPermissions = permissions;
      _isLoading = false;
    });
  }

  bool _hasPermission(String permission) {
    if (_userPermissions == null) return false;
    final permissions = _userPermissions!['permissions'] as Map<String, dynamic>;
    return permissions[permission] == true;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Permission Example'),
        backgroundColor: const Color(0xFF2F7CF6),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Example 1: Show/Hide entire sections
          if (_hasPermission('viewProducts'))
            _buildSection(
              'Products Section',
              'You have permission to view products',
              Colors.green,
            ),

          if (!_hasPermission('viewProducts'))
            _buildSection(
              'Products Section - Locked',
              'You don\'t have permission to view products',
              Colors.red,
            ),

          const SizedBox(height: 16),

          // Example 2: Conditional button rendering
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (_hasPermission('createProducts'))
                ElevatedButton.icon(
                  onPressed: _createProduct,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Product'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
              if (_hasPermission('editProducts'))
                ElevatedButton.icon(
                  onPressed: _editProduct,
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Product'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                ),
              if (_hasPermission('deleteProducts'))
                ElevatedButton.icon(
                  onPressed: _deleteProduct,
                  icon: const Icon(Icons.delete),
                  label: const Text('Delete Product'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 24),

          // Example 3: Permission list display
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Permissions:',
                    style: TextStyle(
                      fontSize: 18,
                     fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._buildPermissionList(),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _testPermissionCheck,
        child: const Icon(Icons.security),
        tooltip: 'Test Permission',
      ),
    );
  }

  Widget _buildSection(String title, String description, Color color) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
               fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(description),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPermissionList() {
    if (_userPermissions == null) return [];

    final permissions = _userPermissions!['permissions'] as Map<String, dynamic>;
    final role = _userPermissions!['role'] as String;

    return [
      ListTile(
        leading: const Icon(Icons.person, color: Color(0xFF2F7CF6)),
        title: Text('Role: $role'),
        dense: true,
      ),
      const Divider(),
      ...permissions.entries.map((entry) {
        final hasPermission = entry.value == true;
        return ListTile(
          leading: Icon(
            hasPermission ? Icons.check_circle : Icons.cancel,
            color: hasPermission ? Colors.green : Colors.red,
            size: 20,
          ),
          title: Text(
            _formatPermissionName(entry.key),
            style: TextStyle(
              fontSize: 14,
              color: hasPermission ? Colors.black87 : Colors.grey,
            ),
          ),
          dense: true,
        );
      }).toList(),
    ];
  }

  String _formatPermissionName(String key) {
    return key
        .replaceAllMapped(RegExp(r'[A-Z]'), (match) => ' ${match.group(0)}')
        .trim()
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  // Example protected actions
  Future<void> _createProduct() async {
    // This check is redundant since button only shows if has permission
    // But good practice for extra safety
    final hasPermission = await PermissionHelper.hasPermission(
      widget.uid,
      'createProducts',
    );

    if (!hasPermission) {
      await PermissionHelper.showPermissionDeniedDialog(context);
      return;
    }

    // Show loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Simulate product creation
      await Future.delayed(const Duration(seconds: 1));

      // In real app, create product in Firestore
      // await FirebaseFirestore.instance.collection('Products').add({...});

      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editProduct() async {
    final hasPermission = await PermissionHelper.hasPermission(
      widget.uid,
      'editProducts',
    );

    if (!hasPermission) {
      await PermissionHelper.showPermissionDeniedDialog(context);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Edit product - Permission granted'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<void> _deleteProduct() async {
    final hasPermission = await PermissionHelper.hasPermission(
      widget.uid,
      'deleteProducts',
    );

    if (!hasPermission) {
      await PermissionHelper.showPermissionDeniedDialog(context);
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this product?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(context.tr('delete')),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product deleted'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _testPermissionCheck() async {
    // Test various permission checks
    final isAdmin = await PermissionHelper.isAdmin(widget.uid);
    final isActive = await PermissionHelper.isActive(widget.uid);
    final canViewReports = await PermissionHelper.hasPermission(
      widget.uid,
      'viewReports',
    );

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Check Results'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCheckResult('Is Admin', isAdmin),
            _buildCheckResult('Is Active', isActive),
            _buildCheckResult('Can View Reports', canViewReports),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('ok')),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckResult(String label, bool value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            value ? Icons.check_circle : Icons.cancel,
            color: value ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text('$label: ${value ? "Yes" : "No"}'),
        ],
      ),
    );
  }
}

// ==========================================
// EXAMPLE: Using FutureBuilder for Permissions
// ==========================================

class PermissionAwarePage extends StatelessWidget {
  final String uid;

  const PermissionAwarePage({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: PermissionHelper.getUserPermissions(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: Text('Error loading permissions')),
          );
        }

        final permissions = snapshot.data!['permissions'] as Map<String, dynamic>;
        final role = snapshot.data!['role'] as String;
        final canViewSales = permissions['viewSales'] == true;

        if (!canViewSales) {
          return Scaffold(
            appBar: AppBar(title: const Text('Access Denied')),
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    'You don\'t have permission to view this page',
                    style: TextStyle(fontSize: 18),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('Sales ($role)'),
            backgroundColor: const Color(0xFF2F7CF6),
          ),
          body: Center(
            child: Text('Sales content - You have access!'),
          ),
        );
      },
    );
  }
}

