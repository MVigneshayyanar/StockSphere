import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/components/app_mini_switch.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/Colors.dart';
import 'package:maxbillup/Menu/InviteStaffPage.dart';
import 'package:maxbillup/Settings/RoleManagement.dart';
import 'package:maxbillup/Settings/PermissionEditor.dart';

class StaffManagementPage extends StatefulWidget {
  final String uid;
  final String? userEmail;
  final VoidCallback onBack;

  const StaffManagementPage({
    super.key,
    required this.uid,
    this.userEmail,
    required this.onBack,
  });

  @override
  State<StaffManagementPage> createState() => _StaffManagementPageState();
}

class _StaffManagementPageState extends State<StaffManagementPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final FirestoreService _firestoreService = FirestoreService();
  bool _isCheckingVerifications = false;
  bool _isDialogOpen = false; // Track if any dialog is currently open

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    Future.delayed(const Duration(seconds: 1), _checkAllPendingVerifications);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ==========================================
  // LOGIC METHODS (PRESERVED BIT-BY-BIT)
  // ==========================================

  Future<void> _checkAllPendingVerifications() async {
    if (_isCheckingVerifications) return;
    setState(() => _isCheckingVerifications = true);
    FirebaseApp? tempApp;
    try {
      final snapshot = await _firestoreService.getStoreCollection('users').then((col) => col.get());
      final pendingDocs = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return (data['isEmailVerified'] == false) && (data['tempPassword'] != null);
      }).toList();
      if (pendingDocs.isEmpty) return;
      try {
        var existing = Firebase.app('AutoCheckApp');
        await existing.delete();
      } catch (_) {}
      tempApp = await Firebase.initializeApp(name: 'AutoCheckApp', options: Firebase.app().options);
      final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
      int verifiedCount = 0;
      for (var doc in pendingDocs) {
        final data = doc.data() as Map<String, dynamic>;
        String email = data['email'] ?? '';
        String pass = data['tempPassword'] ?? '';
        if (email.isEmpty || pass.isEmpty) continue;
        try {
          final cred = await tempAuth.signInWithEmailAndPassword(email: email, password: pass);
          if (cred.user != null) {
            await cred.user!.reload();
            if (cred.user!.emailVerified) {
              final updates = {
                'isEmailVerified': true,
                'verifiedAt': FieldValue.serverTimestamp(),
                'tempPassword': FieldValue.delete(),
              };
              await _firestoreService.updateDocument('users', doc.id, updates);
              await FirebaseFirestore.instance.collection('users').doc(doc.id).update(updates).catchError((_) {});
              verifiedCount++;
            }
          }
          await tempAuth.signOut();
        } catch (e) { print("Check skipped for $email: $e"); }
      }
      if (verifiedCount > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ Updated status for $verifiedCount staff member(s)"), backgroundColor: kGoogleGreen));
      }
    } catch (e) { print("Auto-check error: $e"); } finally {
      await tempApp?.delete();
      if (mounted) setState(() => _isCheckingVerifications = false);
    }
  }

  Future<void> _manualCheckVerification(String staffId, String email, String? storedTempPass) async {
    String password = '';
    if (storedTempPass != null && storedTempPass.isNotEmpty) {
      password = storedTempPass;
    } else {
      final result = await showDialog<String>(
          context: context,
          builder: (context) {
            final passCtrl = TextEditingController();
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text("Check Verification", style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Enter the staff's temporary password to check their status.", style: TextStyle(fontSize: 13, color: kBlack54)),
                  const SizedBox(height: 16),
                  _buildDialogField(passCtrl, "Password", Icons.lock_outline, isPassword: true),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, passCtrl.text),
                  style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
                  child: const Text("Check", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
      );
      if (result == null || result.isEmpty) return;
      password = result;
    }

    _showLoading(true);
    FirebaseApp? tempApp;
    try {
      try { var existing = Firebase.app('ManualCheckApp'); await existing.delete(); } catch (_) {}
      tempApp = await Firebase.initializeApp(name: 'ManualCheckApp', options: Firebase.app().options);
      final cred = await FirebaseAuth.instanceFor(app: tempApp).signInWithEmailAndPassword(email: email, password: password);
      await cred.user?.reload();
      if (cred.user?.emailVerified ?? false) {
        final updates = {'isEmailVerified': true, 'verifiedAt': FieldValue.serverTimestamp(), 'tempPassword': FieldValue.delete()};
        await _firestoreService.updateDocument('users', staffId, updates);
        await FirebaseFirestore.instance.collection('users').doc(staffId).set(updates, SetOptions(merge: true)).catchError((_) {});
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Verified! You can now approve.'), backgroundColor: kGoogleGreen));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Not verified yet.'), backgroundColor: kOrange));
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.message}'), backgroundColor: kErrorColor));
    } finally { await tempApp?.delete(); _showLoading(false); }
  }

  void _showLoading(bool show) {
    if (show) {
      setState(() => _isDialogOpen = true);
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => WillPopScope(
          onWillPop: () async => false,
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    } else {
      // Pop the loading dialog and immediately reset the flag
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      setState(() => _isDialogOpen = false);
    }
  }

  Stream<QuerySnapshot> _getStaffStream() {
    // Get all users except the owner (those who have a 'role' field set)
    return _firestoreService.getStoreCollection('users').then((collection) => collection.where('invitedBy', isNotEqualTo: null).snapshots(includeMetadataChanges: true)).asStream().asyncExpand((snapshot) => snapshot);
  }

  // ==========================================
  // UI BUILD METHODS (ENTERPRISE FLAT)
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        // Only trigger navigation if it's not a dialog being dismissed
        if (!didPop && !_isDialogOpen) {
          widget.onBack();
        }
      },
      child: Scaffold(
        backgroundColor: kGreyBg,
        appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
          title: const Text('Staff Management', style: TextStyle(color: kWhite, fontSize: 18, fontWeight: FontWeight.w700)),
          backgroundColor: kPrimaryColor,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: kWhite, size: 22), onPressed: widget.onBack),
          actions: [
            IconButton(
              icon: const Icon(Icons.shield_outlined, color: kWhite, size: 22),
              tooltip: 'Manage Roles',
              onPressed: () {
                Navigator.push(context, CupertinoPageRoute(builder: (_) => RoleManagementPage(uid: widget.uid)));
              },
            ),
            IconButton(
              icon: _isCheckingVerifications ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: kWhite, strokeWidth: 2)) : const Icon(Icons.refresh_rounded, color: kWhite, size: 22),
              onPressed: _isCheckingVerifications ? null : _checkAllPendingVerifications,
            )
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(context, CupertinoPageRoute(builder: (_) => InviteStaffPage(uid: widget.uid)));
          if (result == true) {
            _checkAllPendingVerifications();
          }
        },
        elevation: 0,
        backgroundColor: kPrimaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        icon: const Icon(Icons.person_add_alt_1_rounded, color: kWhite, size: 20),
        label: const Text("Invite Staff", style: TextStyle(fontWeight: FontWeight.w800, color: kWhite, letterSpacing: 0.5)),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            decoration: const BoxDecoration(color: kWhite, border: Border(bottom: BorderSide(color: kGrey200))),
            child: Container(
              height: 46,
              decoration: BoxDecoration(color: kPrimaryColor.withOpacity(0.04), borderRadius: BorderRadius.circular(12)),
              child: ValueListenableBuilder<TextEditingValue>(
      valueListenable: _searchController,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextField(
                controller: _searchController,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kBlack87),
                decoration: InputDecoration(
                  hintText: "Search staff members...",
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

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getStaffStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyState();

                var staffDocs = snapshot.data!.docs.where((doc) {
                  if (_searchQuery.isEmpty) return true;
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final role = (data['role'] ?? '').toString().toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery) || role.contains(_searchQuery) || email.contains(_searchQuery);
                }).toList();

                if (staffDocs.isEmpty) return _buildNoResults();

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: staffDocs.length,
                  separatorBuilder: (c, i) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = staffDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildStaffCard(
                      context, staffId: doc.id, name: data['name'] ?? 'Unknown', phone: data['phone'] ?? 'N/A', email: data['email'] ?? '',
                      role: data['role'] ?? 'Staff', isActive: data['isActive'] ?? false, isEmailVerified: data['isEmailVerified'] ?? false,
                      tempPassword: data['tempPassword'], permissions: data['permissions'] as Map<String, dynamic>? ?? {},
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

  Widget _buildStaffCard(BuildContext context, {required String staffId, required String name, required String phone, required String email, required String role, required bool isActive, required bool isEmailVerified, required Map<String, dynamic> permissions, String? tempPassword}) {
    Color roleColor = _getRoleColor(role);
    String statusText; Color statusColor; IconData statusIcon;

    if (isActive) { statusText = "Active"; statusColor = kGoogleGreen; statusIcon = Icons.check_circle; }
    else if (isEmailVerified) { statusText = "Needs Approval"; statusColor = kOrange; statusIcon = Icons.warning_amber_rounded; }
    else { statusText = "Verification Pending"; statusColor = kBlack54; statusIcon = Icons.mail_outline; }

    return Container(
      decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showStaffDetailsDialog(context, staffId, name, phone, email, role, isActive),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(color: roleColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: roleColor))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontSize: 15,fontWeight: FontWeight.bold, color: kBlack87)),
                          const SizedBox(height: 2),
                          Row(children: [
                            Text(role, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: roleColor, letterSpacing: 0.5)),
                            const SizedBox(width: 8),
                            const Text("•", style: TextStyle(color: kGrey400)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(email, style: const TextStyle(fontSize: 11, color: kBlack54), overflow: TextOverflow.ellipsis)),
                          ]),
                        ],
                      ),
                    ),
                    _buildPopupMenu(context, staffId, name, phone, email, isActive, isEmailVerified, permissions, role),
                  ],
                ),
                const Divider(height: 24, color: kGrey100),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: statusColor.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
                      child: Row(children: [
                        Icon(statusIcon, size: 12, color: statusColor),
                        const SizedBox(width: 6),
                        Text(statusText, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: statusColor, letterSpacing: 0.5)),
                      ]),
                    ),
                    if (!isActive)
                      SizedBox(
                        height: 30,
                        child: ElevatedButton(
                          onPressed: isEmailVerified ? () => _activateStaff(staffId) : () => _manualCheckVerification(staffId, email, tempPassword),
                          style: ElevatedButton.styleFrom(backgroundColor: isEmailVerified ? kGoogleGreen : kPrimaryColor, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          child: Text(isEmailVerified ? "Approve" : "Check Status", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kWhite)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPopupMenu(BuildContext context, String staffId, String name, String phone, String email, bool isActive, bool isVerified, Map<String, dynamic> permissions, String role) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded, color: kPrimaryColor, size: 20),
      elevation: 0,
      offset: const Offset(0, 42),
      color: kWhite, // Changed background to white
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: kPrimaryColor, width: 1), // Changed outline to blue
      ),
      onSelected: (v) async {
        if (v == 'toggle') { if (!isVerified && !isActive) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Email verification required"), backgroundColor: kOrange)); } else { _toggleStaffStatus(staffId, !isActive); } }
        else if (v == 'perms') {
          final currentPerms = Map<String, bool>.from(permissions.map((k, v) => MapEntry(k, v == true)));
          final result = await Navigator.push<Map<String, bool>>(
            context,
            CupertinoPageRoute(
              builder: (_) => PermissionEditorPage(
                title: '$name Permissions',
                permissions: currentPerms,
                isDefault: false,
              ),
            ),
          );
          if (result != null) {
            await _firestoreService.updateDocument('users', staffId, {'permissions': result, 'updatedAt': FieldValue.serverTimestamp()});
            await FirebaseFirestore.instance.collection('users').doc(staffId).set({'permissions': result}, SetOptions(merge: true)).catchError((_) {});

          }
        }
        else if (v == 'edit') _showEditStaffDialog(context, staffId, name, phone, email, role, isActive, permissions);
        else if (v == 'delete') _showDeleteConfirmation(context, staffId, name);
      },
      itemBuilder: (_) => [
        _menuItem('edit', Icons.edit_note_rounded, 'Edit Profile', kPrimaryColor),
        _menuItem('perms', Icons.security_rounded, 'Permissions', kPrimaryColor),
        const PopupMenuDivider(height: 1),
        _menuItem('toggle', isActive ? Icons.block_rounded : Icons.check_circle_outline, isActive ? 'Deactivate' : 'Activate', isActive ? kErrorColor : kGoogleGreen),
        _menuItem('delete', Icons.delete_forever_rounded, 'Remove Staff', kErrorColor),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(String v, IconData i, String l, Color c) {
    return PopupMenuItem(
      value: v,
      height: 50,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(i, size: 18, color: c),
          ),
          const SizedBox(width: 12),
          Text(l, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c)),
        ],
      ),
    );
  }

  void _showStaffDetailsDialog(BuildContext ctx, String id, String n, String p, String e, String r, bool a) {
    setState(() => _isDialogOpen = true);
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: kWhite,
        title: Text(n, style: const TextStyle(fontWeight: FontWeight.w800, color: kBlack87)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _info("Role", r), _info("Email", e), _info("Phone", p), _info("Status", a ? "Active" : "Inactive"),
        ]),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: const Text("Close")
          )
        ],
      )
    ).then((_) {
      if (mounted) setState(() => _isDialogOpen = false);
    });
  }


  Widget _info(String l, String v) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [Text("$l: ", style: const TextStyle(fontSize: 12,fontWeight: FontWeight.bold, color: kBlack54)), Text(v, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kBlack87))]));

  void _showDeleteConfirmation(BuildContext context, String staffId, String name) {
    setState(() => _isDialogOpen = true);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: kWhite,
        title: const Text('Remove Staff Member?', style: TextStyle(fontWeight: FontWeight.w800, color: kBlack87)),
        content: Text('This will permanently delete access for $name. They won\'t be able to login again with their email/password.', style: const TextStyle(color: kBlack54, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.bold, color: kBlack54))
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              // Reset flag immediately since we're starting a new operation
              if (mounted) setState(() => _isDialogOpen = false);
              _showLoading(true);

            try {
              // Get staff data first to retrieve email and tempPassword
              final staffDoc = await _firestoreService.getStoreCollection('users')
                  .then((col) => col.doc(staffId).get());

              if (staffDoc.exists) {
                final staffData = staffDoc.data() as Map<String, dynamic>;
                final email = staffData['email'] as String?;
                final tempPassword = staffData['tempPassword'] as String?;

                // Try to delete Firebase Auth account (email/password only)
                if (email != null && email.isNotEmpty) {
                  await _deleteStaffAuthAccount(email, tempPassword);
                }
              }

              // Delete Firestore documents
              await _firestoreService.deleteDocument('users', staffId);
              await FirebaseFirestore.instance.collection('users').doc(staffId).delete().catchError((_) {});

              _showLoading(false);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ $name removed successfully'),
                    backgroundColor: kGoogleGreen,
                  ),
                );
              }
            } catch (e) {
              _showLoading(false);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error removing staff: $e'),
                    backgroundColor: kErrorColor,
                  ),
                );
              }
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: kErrorColor, elevation: 0),
          child: const Text("Delete", style: TextStyle(color: kWhite, fontWeight: FontWeight.bold)),
        ),
      ],
    )).then((_) {
      if (mounted) setState(() => _isDialogOpen = false);
    });
  }

  /// Deletes the staff member's email/password authentication account from Firebase Auth
  /// This only affects email/password login - Google sign-in with same email remains intact
  Future<void> _deleteStaffAuthAccount(String email, String? tempPassword) async {
    FirebaseApp? tempApp;
    try {
      // Clean up any existing secondary app
      try {
        var existing = Firebase.app('DeleteStaffApp');
        await existing.delete();
      } catch (_) {}

      // Create secondary Firebase app instance
      tempApp = await Firebase.initializeApp(
        name: 'DeleteStaffApp',
        options: Firebase.app().options,
      );

      final tempAuth = FirebaseAuth.instanceFor(app: tempApp);

      // Try to sign in with email/password to get the user
      if (tempPassword != null && tempPassword.isNotEmpty) {
        try {
          final cred = await tempAuth.signInWithEmailAndPassword(
            email: email,
            password: tempPassword,
          );

          // Delete the authenticated user
          if (cred.user != null) {
            await cred.user!.delete();
            debugPrint('✅ Deleted Firebase Auth account for: $email');

            // Wait a moment to ensure Firebase processes the deletion
            await Future.delayed(const Duration(milliseconds: 500));
          }
        } on FirebaseAuthException catch (e) {
          if (e.code == 'user-not-found') {
            debugPrint('⚠️ Auth account not found for: $email (may already be deleted)');
          } else if (e.code == 'wrong-password') {
            debugPrint('⚠️ Cannot delete auth account - password mismatch for: $email');
          } else {
            debugPrint('⚠️ Error deleting auth account for $email: ${e.message}');
          }
        }
      } else {
        debugPrint('⚠️ No tempPassword available for $email - cannot delete auth account');
      }
    } catch (e) {
      debugPrint('⚠️ Error in deleteStaffAuthAccount: $e');
    } finally {
      // Clean up secondary app
      await tempApp?.delete();
    }
  }

  void _showEditStaffDialog(BuildContext ctx, String sid, String cn, String cp, String ce, String cr, bool ca, Map<String, dynamic> cprms) {
    final nameC = TextEditingController(text: cn); String role = cr;
    setState(() => _isDialogOpen = true);
    showDialog(
      context: ctx,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: kWhite,
          title: const Text('Edit Staff Details', style: TextStyle(fontWeight: FontWeight.w800, fontFamily: 'NotoSans')),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            _buildSectionLabel("Identity"),
            _buildDialogField(nameC, 'Full Name', Icons.person),
            const SizedBox(height: 16),
            _buildSectionLabel("Role"),
            _buildDialogDropdown(role, (v) => setDialogState(() => role = v!))
          ]),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.bold, color: kBlack54, fontFamily: 'Lato'))
            ),
            ElevatedButton(
              onPressed: () async {
                final upd = {'name': nameC.text.trim(), 'role': role, 'updatedAt': FieldValue.serverTimestamp()};
                await _firestoreService.updateDocument('users', sid, upd);
                await FirebaseFirestore.instance.collection('users').doc(sid).set(upd, SetOptions(merge: true)).catchError((_) {});
                if(mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0),
              child: const Text("Update", style: TextStyle(color: kWhite, fontWeight: FontWeight.bold, fontFamily: 'Lato'))
            ),
          ],
        )
      )
    ).then((_) {
      if (mounted) setState(() => _isDialogOpen = false);
    });
  }

  void _activateStaff(String staffId) async {
    final updates = {'isActive': true, 'approvedAt': FieldValue.serverTimestamp(), 'approvedBy': widget.uid};
    await _firestoreService.updateDocument('users', staffId, updates);
    await FirebaseFirestore.instance.collection('users').doc(staffId).set(updates, SetOptions(merge: true)).catchError((_) {});
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Staff activated!'), backgroundColor: kGoogleGreen));
  }

  void _toggleStaffStatus(String staffId, bool newStatus) async {
    final updates = {'isActive': newStatus};
    await _firestoreService.updateDocument('users', staffId, updates);
    await FirebaseFirestore.instance.collection('users').doc(staffId).set(updates, SetOptions(merge: true)).catchError((_) {});
  }

  Color _getRoleColor(String role) {
    if (role.toLowerCase().contains('admin')) return kErrorColor;
    if (role.toLowerCase().contains('manager')) return kOrange;
    return kPrimaryColor;
  }

  Map<String, bool> _getDefaultPermissions(String role) {
    bool isAdmin = role.toLowerCase().contains('admin');
    return {
      'quotation': true,
      'billHistory': true,
      'creditNotes': isAdmin,
      'customerManagement': true,
      // Expenses (split into 4 permissions matching Menu.dart sub items)
      'expenses': isAdmin,
      'expenseCategories': isAdmin,
      'stockPurchase': isAdmin,
      'vendors': isAdmin,
      'creditDetails': isAdmin,
      'staffManagement': isAdmin,
      'analytics': isAdmin,
      'daybook': isAdmin,
      'salesSummary': isAdmin,
      'salesReport': isAdmin,
      'itemSalesReport': isAdmin,
      'topCustomer': isAdmin,
      'stockReport': isAdmin,
      'lowStockProduct': isAdmin,
      'topProducts': isAdmin,
      'topCategory': isAdmin,
      'expensesReport': isAdmin,
      'taxReport': isAdmin,
      'staffSalesReport': isAdmin,
      'addProduct': isAdmin,
      'addCategory': isAdmin,
    };
  }

  Widget _buildEmptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.people_outline_rounded, size: 64, color: kGrey300), const SizedBox(height: 16), const Text('No staff members yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kBlack87, fontFamily: 'Lato'))]));
  Widget _buildNoResults() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.search_off_rounded, size: 64, color: kGrey300), const SizedBox(height: 16), Text('No results for "$_searchQuery"', style: const TextStyle(color: kBlack54, fontFamily: 'Lato'))]));

  Widget _buildSectionLabel(String text) => Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(bottom: 8, left: 4), child: Text(text, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kBlack54, letterSpacing: 0.5, fontFamily: 'NotoSans'))));

  Widget _buildDialogField(TextEditingController ctrl, String label, IconData icon, {TextInputType type = TextInputType.text, bool isPassword = false}) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: ctrl,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        // Use the TextField's decoration borders to show colored border on focus and when filled.
        // Avoid an outer border so there are not multiple visible borders at once.
        return Container(
          decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(24)),
          child: TextField(
            controller: ctrl,
            keyboardType: type,
            obscureText: isPassword,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kBlack87, fontFamily: 'Lato'),
            decoration: InputDecoration(
              hintText: label,
              prefixIcon: Icon(icon, color: hasText ? kPrimaryColor : kBlack54, size: 18),
              filled: true,
              fillColor: const Color(0xFFF8F9FA),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              // When not focused: if filled -> primary color, else grey
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: hasText ? kPrimaryColor : kGrey200, width: hasText ? 1.5 : 1.0),
              ),
              // When focused: always primary color
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kPrimaryColor, width: 2.0),
              ),
              labelStyle: TextStyle(color: hasText ? kPrimaryColor : kBlack54, fontSize: 13, fontWeight: FontWeight.w600),
              floatingLabelStyle: TextStyle(color: hasText ? kPrimaryColor : kPrimaryColor, fontSize: 11, fontWeight: FontWeight.w900),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDialogDropdown(String current, Function(String?) onSel) {
    return FutureBuilder<QuerySnapshot>(
      future: FirestoreService().getStoreCollection('roles').then((col) => col.get()),
      builder: (context, snapshot) {
        List<String> roles = ['Staff', 'Manager', 'Admin']; // Default fallback

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          roles = snapshot.data!.docs.map((doc) => doc.id).toList();
        }

        // Ensure current role is in the list
        if (!roles.contains(current)) {
          roles.add(current);
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: current, isExpanded: true, icon: const Icon(Icons.arrow_drop_down_rounded, color: kBlack54),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kBlack87),
              items: roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: onSel,
            ),
          ),
        );
      },
    );
  }
}

// ==========================================
// NEW PAGE: STAFF PERMISSIONS
// ==========================================
class StaffPermissionsPage extends StatefulWidget {
  final String staffId;
  final String staffName;
  final Map<String, dynamic> currentPermissions;

  const StaffPermissionsPage({
    super.key,
    required this.staffId,
    required this.staffName,
    required this.currentPermissions,
  });

  @override
  State<StaffPermissionsPage> createState() => _StaffPermissionsPageState();
}

class _StaffPermissionsPageState extends State<StaffPermissionsPage> {
  late Map<String, bool> perms;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    perms = {
      'quotation': widget.currentPermissions['quotation'] ?? false,
      'billHistory': widget.currentPermissions['billHistory'] ?? false,
      'creditNotes': widget.currentPermissions['creditNotes'] ?? false,
      'customerManagement': widget.currentPermissions['customerManagement'] ?? false,
      // Expenses split (keep legacy 'expenses' as the main expense entry)
      'expenses': widget.currentPermissions['expenses'] ?? false,
      'expenseCategories': widget.currentPermissions['expenseCategories'] ?? false,
      'stockPurchase': widget.currentPermissions['stockPurchase'] ?? false,
      'vendors': widget.currentPermissions['vendors'] ?? false,
      'creditDetails': widget.currentPermissions['creditDetails'] ?? false,
      'staffManagement': widget.currentPermissions['staffManagement'] ?? false,
      'analytics': widget.currentPermissions['analytics'] ?? false,
      'daybook': widget.currentPermissions['daybook'] ?? false,
      'salesSummary': widget.currentPermissions['salesSummary'] ?? false,
      'salesReport': widget.currentPermissions['salesReport'] ?? false,
      'itemSalesReport': widget.currentPermissions['itemSalesReport'] ?? false,
      'topCustomer': widget.currentPermissions['topCustomer'] ?? false,
      'stockReport': widget.currentPermissions['stockReport'] ?? false,
      'lowStockProduct': widget.currentPermissions['lowStockProduct'] ?? false,
      'topProducts': widget.currentPermissions['topProducts'] ?? false,
      'topCategory': widget.currentPermissions['topCategory'] ?? false,
      'expensesReport': widget.currentPermissions['expensesReport'] ?? false,
      'taxReport': widget.currentPermissions['taxReport'] ?? false,
      'staffSalesReport': widget.currentPermissions['staffSalesReport'] ?? false,
      'addProduct': widget.currentPermissions['addProduct'] ?? false,
      'addCategory': widget.currentPermissions['addCategory'] ?? false,
      'saleReturn': widget.currentPermissions['saleReturn'] ?? false,
      'cancelBill': widget.currentPermissions['cancelBill'] ?? false,
      'editBill': widget.currentPermissions['editBill'] ?? false,
    };
  }

  Future<void> _savePermissions() async {
    setState(() => _isSaving = true);
    try {
      final updates = {'permissions': perms, 'updatedAt': FieldValue.serverTimestamp()};
      await FirestoreService().updateDocument('users', widget.staffId, updates);
      await FirebaseFirestore.instance.collection('users').doc(widget.staffId).set(updates, SetOptions(merge: true)).catchError((_) {});

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: kErrorColor));
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
        title: Text('Permissions: ${widget.staffName}', style: const TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 16)),
        backgroundColor: kPrimaryColor, centerTitle: true, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: kWhite, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildPermGroup('Management Tools', [
                  'quotation',
                  'billHistory',
                  'creditNotes',
                  'customerManagement',
                  // Expenses (4 subdivisions)
                  'expenses',
                  'expenseCategories',
                  'stockPurchase',
                  'vendors',
                  'creditDetails',
                  'staffManagement'
                ]),
                const SizedBox(height: 16),
                _buildPermGroup('Analytics & Reports', [
                  'analytics', 'daybook', 'salesSummary', 'salesReport', 'itemSalesReport', 'topCustomer', 'stockReport', 'lowStockProduct', 'topProducts', 'topCategory', 'expensesReport', 'taxReport', 'staffSalesReport'
                ]),
                const SizedBox(height: 16),
                _buildPermGroup('Stocks & Bill Actions', [
                  'addProduct', 'addCategory', 'saleReturn', 'cancelBill', 'editBill'
                ]),
              ],
            ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: const BoxDecoration(color: kWhite, border: Border(top: BorderSide(color: kGrey200))),
              child: SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _savePermissions,
                  style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: kWhite)
                      : const Text('Save permissions', style: TextStyle(color: kWhite, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Maps permission keys to display names matching the actual report tile titles
  String _permissionDisplayName(String key) {
    const displayNames = {
      // Management tools
      'quotation': 'Estimation / Quotation',
      'billHistory': 'Manage Bills',
      'creditNotes': 'Return & Refunds',
      'customerManagement': 'Customer Management',
      // Expenses (4 sub-items)
      'expenses': 'Expenses',
      'expenseCategories': 'Expense Category',
      'stockPurchase': 'Product Purchase',
      'vendors': 'Suppliers',
      'creditDetails': 'Credits & Dues',
      'staffManagement': 'Staff Management',
      // Reports (matching Reports.dart tile titles)
      'daybook': 'Daybook Today',
      'analytics': 'Growth+',
      'salesSummary': 'Business Insights',
      'salesReport': 'Sales Record',
      'itemSalesReport': 'Item Sales Report',
      'topCustomer': 'TOP Customers',
      'stockReport': 'Stock Report',
      'lowStockProduct': 'Low Stock Products',
      'topProducts': 'Product Summary',
      'topCategory': 'TOP Categories',
      'taxReport': 'Tax Report',
      'staffSalesReport': 'Staff Sale Report',
      // Stock & bill actions
      'addProduct': 'Add Product',
      'addCategory': 'Add Category',
      'saleReturn': 'Sale Return',
      'cancelBill': 'Cancel Bill',
      'editBill': 'Edit Bill',
    };
    return displayNames[key] ??
        key.replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(0)}');
  }

  Widget _buildPermGroup(String title, List<String> keys) {
    return Container(
      decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kPrimaryColor, letterSpacing: 0.5)),
          ),
          ...keys.map((k) {
            String label = _permissionDisplayName(k);
            return Column(
              children: [
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  title: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kBlack87)),
                  trailing: AppMiniSwitch(
                    value: perms[k] ?? false,
                    onChanged: (v) => setState(() => perms[k] = v),
                  ),
                ),
                if (k != keys.last) const Divider(height: 1, indent: 16, endIndent: 16, color: kGrey100),
              ],
            );
          }),
        ],
      ),
    );
  }
}

