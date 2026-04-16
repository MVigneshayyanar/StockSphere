import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/Colors.dart';
import 'package:maxbillup/Settings/PermissionEditor.dart';

class RoleManagementPage extends StatefulWidget {
  final String uid;

  const RoleManagementPage({super.key, required this.uid});

  @override
  State<RoleManagementPage> createState() => _RoleManagementPageState();
}

class _RoleManagementPageState extends State<RoleManagementPage> {
  final FirestoreService _firestoreService = FirestoreService();

  // Default roles with their predefined permissions
  final Map<String, Map<String, bool>> _defaultRoles = {
    'Admin': {
      'quotation': true,
      'billHistory': true,
      'creditNotes': true,
      'customerManagement': true,
      'expenses': true,
      'creditDetails': true,
      'staffManagement': true,
      'analytics': true,
      'daybook': true,
      'salesSummary': true,
      'salesReport': true,
      'itemSalesReport': true,
      'topCustomer': true,
      'stockReport': true,
      'lowStockProduct': true,
      'topProducts': true,
      'topCategory': true,
      'expensesReport': true,
      'taxReport': true,
      'staffSalesReport': true,
      'addProduct': true,
      'addCategory': true,
      // Invoice permissions
      'editInvoice': true,
      'returnInvoice': true,
      'cancelInvoice': true,
      // Settings permissions
      'editBusinessProfile': true,
      'receiptCustomization': true,
      'taxSettings': true,
    },
    'Manager': {
      'quotation': true,
      'billHistory': true,
      'creditNotes': true,
      'customerManagement': true,
      'expenses': true,
      'creditDetails': true,
      'staffManagement': false,
      'analytics': true,
      'daybook': true,
      'salesSummary': true,
      'salesReport': true,
      'itemSalesReport': true,
      'topCustomer': true,
      'stockReport': true,
      'lowStockProduct': true,
      'topProducts': true,
      'topCategory': true,
      'expensesReport': true,
      'taxReport': true,
      'staffSalesReport': true,
      'addProduct': true,
      'addCategory': true,
      // Invoice permissions
      'editInvoice': true,
      'returnInvoice': true,
      'cancelInvoice': true,
      // Settings permissions
      'editBusinessProfile': false,
      'receiptCustomization': true,
      'taxSettings': true,
    },
    'Staff': {
      'quotation': true,
      'billHistory': true,
      'creditNotes': false,
      'customerManagement': true,
      'expenses': false,
      'creditDetails': false,
      'staffManagement': false,
      'analytics': false,
      'daybook': false,
      'salesSummary': false,
      'salesReport': false,
      'itemSalesReport': false,
      'topCustomer': false,
      'stockReport': false,
      'lowStockProduct': false,
      'topProducts': false,
      'topCategory': false,
      'expensesReport': false,
      'taxReport': false,
      'staffSalesReport': false,
      'addProduct': false,
      'addCategory': false,
      // Invoice permissions
      'editInvoice': false,
      'returnInvoice': false,
      'cancelInvoice': false,
      // Settings permissions
      'editBusinessProfile': false,
      'receiptCustomization': false,
      'taxSettings': false,
    },
  };

  @override
  void initState() {
    super.initState();
    _initializeDefaultRoles();
  }

  Future<void> _initializeDefaultRoles() async {
    try {
      final rolesCollection = await _firestoreService.getStoreCollection('roles');

      // Initialize default roles if they don't exist, or update with new permissions
      for (var entry in _defaultRoles.entries) {
        final roleDoc = await rolesCollection.doc(entry.key).get();
        if (!roleDoc.exists) {
          // Create new role
          await rolesCollection.doc(entry.key).set({
            'name': entry.key,
            'permissions': entry.value,
            'isDefault': true,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } else {
          // Update existing role with any new permissions (preserve existing values)
          final existingData = roleDoc.data() as Map<String, dynamic>;
          final existingPermissions = Map<String, bool>.from(existingData['permissions'] ?? {});

          bool hasNewPermissions = false;
          final updatedPermissions = Map<String, bool>.from(existingPermissions);

          // Add any new permissions that don't exist yet
          for (var permKey in entry.value.keys) {
            if (!existingPermissions.containsKey(permKey)) {
              updatedPermissions[permKey] = entry.value[permKey]!;
              hasNewPermissions = true;
            }
          }

          // Only update if there are new permissions to add
          if (hasNewPermissions) {
            await rolesCollection.doc(entry.key).update({
              'permissions': updatedPermissions,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error initializing default roles: $e');
    }
  }

  Future<void> _createCustomRole() async {
    final nameController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Create Custom Role', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<TextEditingValue>(
      valueListenable: nameController,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Role Name',
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: kBlack54)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;

              final roleName = nameController.text.trim();

              // Check if role already exists
              final rolesCollection = await _firestoreService.getStoreCollection('roles');
              final existingRole = await rolesCollection.doc(roleName).get();

              if (existingRole.exists) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Role with this name already exists'),
                      backgroundColor: kErrorColor,
                    ),
                  );
                }
                return;
              }

              // Create role with default permissions (all false)
              Map<String, bool> defaultPerms = {};
              for (var key in _defaultRoles['Staff']!.keys) {
                defaultPerms[key] = false;
              }

              await rolesCollection.doc(roleName).set({
                'name': roleName,
                'permissions': defaultPerms,
                'isDefault': false,
                'createdAt': FieldValue.serverTimestamp(),
                'createdBy': widget.uid,
              });

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Custom role created successfully'),
                    backgroundColor: kGoogleGreen,
                  ),
                );
                setState(() {});
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Create', style: TextStyle(color: kWhite)),
          ),
        ],
      ),
    );
  }

  Future<void> _editRolePermissions(String roleName, Map<String, bool> currentPermissions, bool isDefault) async {
    final result = await Navigator.push<Map<String, bool>>(
      context,
      CupertinoPageRoute(
        builder: (_) => PermissionEditorPage(
          title: '$roleName Permissions',
          permissions: currentPermissions,
          isDefault: isDefault,
        ),
      ),
    );

    if (result != null) {
      final rolesCollection = await _firestoreService.getStoreCollection('roles');

      // 1. Update the role document
      await rolesCollection.doc(roleName).update({
        'permissions': result,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Also sync updated permissions to all users who have this role
      //    so that changes take effect even on cached user documents.
      try {
        final usersCollection = await _firestoreService.getStoreCollection('users');
        final usersSnapshot = await usersCollection
            .where('role', isEqualTo: roleName)
            .get();

        final batch = FirebaseFirestore.instance.batch();
        for (final userDoc in usersSnapshot.docs) {
          batch.update(userDoc.reference, {
            'permissions': result,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          // Also update root users collection
          final rootRef = FirebaseFirestore.instance
              .collection('users')
              .doc(userDoc.id);
          batch.set(rootRef, {'permissions': result}, SetOptions(merge: true));
        }
        await batch.commit();
      } catch (e) {
        debugPrint('Error syncing permissions to users: $e');
      }


    }
  }

  Future<void> _deleteRole(String roleName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Delete Role?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to delete the "$roleName" role?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: kBlack54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kErrorColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete', style: TextStyle(color: kWhite)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final rolesCollection = await _firestoreService.getStoreCollection('roles');
      await rolesCollection.doc(roleName).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Role deleted successfully'),
            backgroundColor: kGoogleGreen,
          ),
        );
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        title: const Text(
          'Role Management',
          style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kWhite, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: _firestoreService.getStoreCollection('roles').then((col) => col.get()),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield_outlined, size: 64, color: kGrey300),
                  const SizedBox(height: 16),
                  const Text(
                    'No roles found',
                    style: TextStyle(color: kBlack54, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }

          final roles = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: roles.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final roleDoc = roles[index];
              final roleData = roleDoc.data() as Map<String, dynamic>;
              final roleName = roleData['name'] ?? roleDoc.id;
              final permissions = Map<String, bool>.from(roleData['permissions'] ?? {});
              final isDefault = roleData['isDefault'] ?? false;

              final enabledCount = permissions.values.where((v) => v).length;
              final totalCount = permissions.length;

              // Calculate category-wise permission status
              final categoryStatus = _getCategoryStatus(permissions);

              return Container(
                decoration: BoxDecoration(
                  color: kWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDefault ? kOrange.withOpacity(0.3) : kGrey200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isDefault ? kOrange.withOpacity(0.1) : kPrimaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isDefault ? Icons.shield : Icons.person_outline,
                          color: isDefault ? kOrange : kPrimaryColor,
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              roleName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (isDefault)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: kOrange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Default',
                                style: TextStyle(
                                  color: kOrange,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '$enabledCount of $totalCount permissions enabled',
                          style: const TextStyle(
                            fontSize: 12,
                            color: kBlack54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: kPrimaryColor, size: 20),
                            onPressed: () => _editRolePermissions(roleName, permissions, isDefault),
                          ),
                          if (!isDefault)
                            IconButton(
                              icon: const Icon(Icons.delete, color: kErrorColor, size: 20),
                              onPressed: () => _deleteRole(roleName),
                            ),
                        ],
                      ),
                    ),
                    // Category-wise permission summary
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: categoryStatus.entries.map((entry) {
                          final enabled = entry.value['enabled'] ?? 0;
                          final total = entry.value['total'] ?? 0;
                          final hasAccess = enabled > 0;
                          final allEnabled = enabled == total;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: allEnabled
                                  ? kGoogleGreen.withOpacity(0.1)
                                  : hasAccess
                                      ? kOrange.withOpacity(0.1)
                                      : kGrey100,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: allEnabled
                                    ? kGoogleGreen.withOpacity(0.3)
                                    : hasAccess
                                        ? kOrange.withOpacity(0.3)
                                        : kGrey200,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  allEnabled
                                      ? Icons.check_circle
                                      : hasAccess
                                          ? Icons.remove_circle_outline
                                          : Icons.cancel_outlined,
                                  size: 12,
                                  color: allEnabled
                                      ? kGoogleGreen
                                      : hasAccess
                                          ? kOrange
                                          : kBlack54,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  entry.key,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Lato',
                                    color: allEnabled
                                        ? kGoogleGreen
                                        : hasAccess
                                            ? kOrange
                                            : kBlack54,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createCustomRole,
        backgroundColor: kPrimaryColor,
        icon: const Icon(Icons.add, color: kWhite),
        label: const Text('Create Role', style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontFamily: 'Lato')),
      ),
    );
  }

  // Helper method to calculate category-wise permission status
  Map<String, Map<String, int>> _getCategoryStatus(Map<String, bool> permissions) {
    final categories = {
      'Estimation/Quotation': ['quotation'],
      'Manage Bills': ['billHistory'],
      'Returns & Refunds': ['creditNotes'],
      'Invoice': ['editInvoice', 'returnInvoice', 'cancelInvoice'],
      'Customers': ['customerManagement'],
      'Credits & Dues': ['creditDetails'],
      'Expenses': ['expenses'],
      'Staff Access & Roles': ['staffManagement', 'analytics'],
      'Reports': ['daybook', 'salesSummary', 'salesReport', 'itemSalesReport', 'topCustomer', 'stockReport', 'lowStockProduct', 'topProducts', 'topCategory', 'expensesReport', 'taxReport', 'staffSalesReport'],
      'Products': ['addProduct', 'addCategory'],
      'Settings': ['editBusinessProfile', 'receiptCustomization', 'taxSettings'],
    };

    final result = <String, Map<String, int>>{};

    for (var entry in categories.entries) {
      int enabled = 0;
      int total = entry.value.length;
      for (var perm in entry.value) {
        if (permissions[perm] == true) enabled++;
      }
      result[entry.key] = {'enabled': enabled, 'total': total};
    }

    return result;
  }
}

