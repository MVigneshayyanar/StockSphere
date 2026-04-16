import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:heroicons/heroicons.dart';
import 'package:maxbillup/Colors.dart';
import 'package:maxbillup/models/cart_item.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/utils/plan_permission_helper.dart';
import 'package:maxbillup/utils/amount_formatter.dart';
import 'package:intl/intl.dart';

class CommonWidgets {
  // Show snackbar message (Standardized)
  static void showSnackBar(BuildContext context, String message, {Color? bgColor}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        backgroundColor: bgColor ?? kPrimaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(milliseconds: 1500),
      ),
    );
  }

  // Action buttons for bottom bar (Enterprise Flat Redesign)
  static Widget buildActionButtons({
    required BuildContext context,
    required VoidCallback onSaveOrder,
    required VoidCallback onBill,
    required double totalBill,
    VoidCallback? onQuotation,
    VoidCallback? onPrint,
    VoidCallback? onCustomer,
    String? customerName,
    String? savedOrderName,
    bool isQuotationMode = false,
    String currencySymbol = 'Rs ',
  }) {
    if (isQuotationMode) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      bottom: false, // Don't add extra safe area padding
      child: Container(
        decoration: const BoxDecoration(
          color: kWhite,
          border: Border(top: BorderSide(color: kGrey200, width: 1)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: Row(
          children: [
            // Save order button with order name display
            _buildActionIconButtonWithText(
              savedOrderName != null && savedOrderName.isNotEmpty
                  ? HeroIcons.bookmark
                  : HeroIcons.bookmark,
              onSaveOrder,
              savedOrderName != null && savedOrderName.isNotEmpty ? kOrange : kPrimaryColor,
              savedOrderName,
            ),
            const SizedBox(width: 10),

            // Customer button
            if (onCustomer != null) ...[
              _buildActionIconButton(
                customerName != null && customerName.isNotEmpty ? HeroIcons.user : HeroIcons.userPlus,
                onCustomer,
                customerName != null && customerName.isNotEmpty ? kOrange : kPrimaryColor,
              ),
              const SizedBox(width: 10),
            ],

            const Spacer(),

            // Main Bill button (Premium UI Upgrade) — debounce-protected
            _DebouncedBillButton(
              onBill: onBill,
              totalBill: totalBill,
              currencySymbol: currencySymbol,
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildActionIconButton(HeroIcons icon, VoidCallback onTap, Color color) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 50,
        width: 50,
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        ),
        child: HeroIcon(icon, color: color, size: 22),
      ),
    );
  }

  static Widget _buildActionIconButtonWithText(HeroIcons icon, VoidCallback onTap, Color color, String? text) {
    if (text == null || text.isEmpty) {
      return _buildActionIconButton(icon, onTap, color);
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HeroIcon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                text,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Save Order Dialog (Enterprise Flat)
  static void showSaveOrderDialog({
    required BuildContext context,
    required String uid,
    required List<CartItem> cartItems,
    required double totalBill,
    required void Function(String orderName, String? orderId) onSuccess,
    String? savedOrderId,
    String? savedOrderName,
    String? savedOrderPhone,
  }) {
    if (cartItems.isEmpty) {
      showSnackBar(context, context.tr('cart_is_empty'), bgColor: kOrange);
      return;
    }

    final orderNameCtrl = TextEditingController(text: savedOrderName ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(savedOrderId != null ? 'Update Order' : 'Save Order',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: kBlack87)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              savedOrderId != null
                  ? 'Update the saved order with new items'
                  : 'Enter a name for this order',
              style: const TextStyle(color: kBlack54, fontSize: 13, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _buildDialogField(
              controller: orderNameCtrl,
              label: 'Order Name',
              icon: HeroIcons.bookmark,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w800, color: kBlack54)),
          ),
          ElevatedButton(
            onPressed: () async {
              final orderName = orderNameCtrl.text.trim();

              // Require order name
              if (orderName.isEmpty) {
                showSnackBar(ctx, 'Please provide an order name', bgColor: kErrorColor);
                return;
              }

              Navigator.pop(ctx);

              String? resultOrderId;
              if (savedOrderId != null) {
                // Update existing saved order
                await _updateOrderInFirebase(
                  orderId: savedOrderId,
                  uid: uid,
                  orderName: orderName,
                  cartItems: cartItems,
                  totalBill: totalBill,
                  context: context,
                );
                resultOrderId = savedOrderId; // Use the same orderId for updates
              } else {
                // Create new saved order and capture the returned orderId
                resultOrderId = await _saveOrderToFirebase(
                  uid: uid,
                  orderName: orderName,
                  cartItems: cartItems,
                  totalBill: totalBill,
                  context: context,
                );
              }
              onSuccess(orderName, resultOrderId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text(savedOrderId != null ? 'Update Order' : 'Save Order',
                style: const TextStyle(fontWeight: FontWeight.w800, color: kWhite)),
          ),
        ],
      ),
    );
  }

  static Widget _buildDialogField({required TextEditingController controller, required String label, required HeroIcons icon, TextInputType? keyboardType, Function(String)? onChanged}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kBlack87),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Padding(
          padding: const EdgeInsets.all(12.0),
          child: HeroIcon(icon, color: kPrimaryColor, size: 18),
        ),
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGrey200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGrey200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimaryColor, width: 2.0)),
        labelStyle: const TextStyle(color: kBlack54, fontSize: 13),
      ),
    );
  }

  static Future<String?> _fetchStaffName(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      return doc.data()?['name'] as String?;
    } catch (e) { return null; }
  }

  static Future<String?> _saveOrderToFirebase({
    required String uid,
    required String orderName,
    required List<CartItem> cartItems,
    required double totalBill,
    required BuildContext context,
  }) async {
    try {
      final staffName = await _fetchStaffName(uid);

      final items = cartItems.map((item) => {
        'productId': item.productId,
        'name': item.name,
        'price': item.price,
        'quantity': item.quantity,
        'total': item.total,
        'taxes': item.taxes,
        'taxName': item.taxName,
        'taxPercentage': item.taxPercentage,
        'taxType': item.taxType,
      }).toList();

      final docRef = await FirestoreService().addDocument('savedOrders', {
        'orderName': orderName,
        'items': items,
        'total': totalBill,
        'timestamp': FieldValue.serverTimestamp(),
        'staffId': uid,
        'staffName': staffName ?? 'Unknown Staff',
      });

      if (context.mounted) showSnackBar(context, 'Order saved successfully', bgColor: kGoogleGreen);
      return docRef.id; // Return the created document ID
    } catch (e) {
      if (context.mounted) showSnackBar(context, 'Error: ${e.toString()}', bgColor: kErrorColor);
      return null;
    }
  }

  static Future<void> _updateOrderInFirebase({
    required String orderId,
    required String uid,
    required String orderName,
    required List<CartItem> cartItems,
    required double totalBill,
    required BuildContext context,
  }) async {
    try {
      final staffName = await _fetchStaffName(uid);

      final items = cartItems.map((item) => {
        'productId': item.productId,
        'name': item.name,
        'price': item.price,
        'quantity': item.quantity,
        'total': item.total,
        'taxes': item.taxes,
        'taxName': item.taxName,
        'taxPercentage': item.taxPercentage,
        'taxType': item.taxType,
      }).toList();

      await FirestoreService().updateDocument('savedOrders', orderId, {
        'orderName': orderName,
        'items': items,
        'total': totalBill,
        'timestamp': FieldValue.serverTimestamp(),
        'staffId': uid,
        'staffName': staffName ?? 'Unknown Staff',
      });

      if (context.mounted) showSnackBar(context, 'Order updated successfully', bgColor: kGoogleGreen);
    } catch (e) {
      if (context.mounted) showSnackBar(context, 'Error: ${e.toString()}', bgColor: kErrorColor);
    }
  }

  // Customer Selection Dialog (Remastered)
  static void showCustomerSelectionDialog({
    required BuildContext context,
    required Function(String phone, String name, String? gst) onCustomerSelected,
    String? selectedCustomerPhone,
  }) {
    final searchController = TextEditingController();
    String searchQuery = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Dialog(
            backgroundColor: kWhite,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              height: 580,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Select Customer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: kBlack87, letterSpacing: 0.5)),
                      IconButton(onPressed: () => Navigator.pop(ctx), icon: const HeroIcon(HeroIcons.xMark, color: kBlack54)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            hintText: 'Search...',
                            prefixIcon: const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: HeroIcon(HeroIcons.magnifyingGlass, color: kPrimaryColor),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8F9FA),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGrey200)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGrey200)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimaryColor, width: 2.0)),
                          ),
                          onChanged: (value) => setDialogState(() => searchQuery = value.toLowerCase()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _squareActionBtn(HeroIcons.userPlus, () { Navigator.pop(ctx); _showAddCustomerDialog(context, onCustomerSelected); }, kPrimaryColor),
                      const SizedBox(width: 8),
                      _squareActionBtn(HeroIcons.phone, () { Navigator.pop(ctx); _importFromContacts(context, onCustomerSelected); }, kGoogleGreen),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (selectedCustomerPhone != null && selectedCustomerPhone.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: InkWell(
                        onTap: () { onCustomerSelected('', '', null); Navigator.pop(ctx); },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                          decoration: BoxDecoration(color: kErrorColor.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                          child: const Row(children: [HeroIcon(HeroIcons.link, size: 16, color: kErrorColor), SizedBox(width: 12), Text('Remove Customer', style: TextStyle(color: kErrorColor, fontWeight: FontWeight.w800, fontSize: 12))]),
                        ),
                      ),
                    ),
                  Expanded(
                    child: FutureBuilder<Stream<QuerySnapshot>>(
                      future: FirestoreService().getCollectionStream('customers'),
                      builder: (context, streamSnapshot) {
                        if (!streamSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                        return StreamBuilder<QuerySnapshot>(
                          stream: streamSnapshot.data,
                          builder: (context, snapshot) {
                            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('No customers found', style: TextStyle(color: kBlack54, fontWeight: FontWeight.w600)));

                            final customers = snapshot.data!.docs.where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final name = (data['name'] ?? '').toString().toLowerCase();
                              final phone = (data['phone'] ?? '').toString().toLowerCase();
                              return name.contains(searchQuery) || phone.contains(searchQuery);
                            }).toList();

                            return ListView.separated(
                              padding: const EdgeInsets.only(top: 10),
                              itemCount: customers.length,
                              separatorBuilder: (ctx, i) => const Divider(height: 1, color: kGrey100),
                              itemBuilder: (context, index) {
                                final data = customers[index].data() as Map<String, dynamic>;
                                final phone = data['phone'] ?? '';
                                final isSelected = selectedCustomerPhone == phone;
                                final balance = (data['balance'] ?? 0.0) as num;
                                final rating = (data['rating'] ?? 0) as num;

                                return ListTile(
                                  onTap: () { onCustomerSelected(phone, data['name'] ?? 'Unknown', data['gst']); Navigator.pop(ctx); },
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  leading: CircleAvatar(
                                    backgroundColor: isSelected ? kPrimaryColor : kGreyBg,
                                    child: Text((data['name'] ?? 'U')[0].toUpperCase(), style: TextStyle(color: isSelected ? kWhite : kPrimaryColor, fontWeight: FontWeight.w900)),
                                  ),
                                  title: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(data['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14), overflow: TextOverflow.ellipsis),
                                      if (rating > 0) ...[
                                        const SizedBox(height: 2),
                                        Row(
                                          children: List.generate(5, (i) => HeroIcon(
                                            HeroIcons.star,
                                            size: 12,
                                            color: i < rating ? kOrange : kGrey300,
                                            style: i < rating ? HeroIconStyle.solid : HeroIconStyle.outline,
                                          )),
                                        ),
                                      ],
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(phone, style: const TextStyle(fontSize: 11, color: kBlack54, fontWeight: FontWeight.w500)),
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('${balance.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.w900, color: balance > 0 ? kErrorColor : kGoogleGreen, fontSize: 13)),
                                      const Text('Balance', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: kBlack54)),
                                    ],
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
            ),
          );
        },
      ),
    );
  }

  static Widget _squareActionBtn(HeroIcons icon, VoidCallback onTap, Color color) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 48, width: 48,
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.2))),
        child: HeroIcon(icon, color: color, size: 20),
      ),
    );
  }

  static void _showAddCustomerDialog(BuildContext context, Function(String phone, String name, String? gst) onCustomerSelected) {
    final phoneCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final gstCtrl = TextEditingController();
    final balanceCtrl = TextEditingController(text: '0');
    bool isLoading = false;
    bool customerExists = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: kWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('New Customer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogField(
                  controller: phoneCtrl,
                  label: 'Phone Number',
                  icon: HeroIcons.phone,
                  keyboardType: TextInputType.phone,
                  onChanged: (value) async {
                    if (value.length >= 10) {
                      setDialogState(() => isLoading = true);
                      try {
                        final collection = await FirestoreService().getStoreCollection('customers');
                        final doc = await collection.doc(value).get();
                        if (doc.exists) {
                          final data = doc.data() as Map<String, dynamic>?;
                          nameCtrl.text = data?['name'] ?? '';
                          gstCtrl.text = data?['gst'] ?? '';
                          final balance = (data?['balance'] ?? 0.0) as num;
                          balanceCtrl.text = balance.toString();
                          setDialogState(() => customerExists = true);
                        } else {
                          setDialogState(() => customerExists = false);
                        }
                      } catch (e) {
                        debugPrint(e.toString());
                      }
                      setDialogState(() => isLoading = false);
                    }
                  },
                ),
                const SizedBox(height: 12),
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(strokeWidth: 3, color: kPrimaryColor),
                  )
                else ...[
                  if (customerExists)
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: kOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kOrange.withOpacity(0.3)),
                      ),
                      child: const Row(
                        children: [
                          HeroIcon(HeroIcons.informationCircle, color: kOrange, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Customer exists! Fields auto-filled.',
                              style: TextStyle(color: kOrange, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  _buildDialogField(controller: nameCtrl, label: 'Full Name', icon: HeroIcons.user),
                  const SizedBox(height: 12),
                  _buildDialogField(controller: gstCtrl, label: 'GST Number (Optional)', icon: HeroIcons.documentText),
                  const SizedBox(height: 12),
                  _buildDialogField(controller: balanceCtrl, label: 'Last Due Amount', icon: HeroIcons.wallet, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.w800, color: kBlack54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () async {
                final phone = phoneCtrl.text.trim();
                final name = nameCtrl.text.trim();
                if (name.isEmpty || phone.isEmpty) return;
                final balance = double.tryParse(balanceCtrl.text) ?? 0.0;
                final newBalance = balance;

                await FirestoreService().setDocument('customers', phone, {
                  'name': name,
                  'phone': phone,
                  'gst': gstCtrl.text.trim().isEmpty ? null : gstCtrl.text.trim(),
                  'balance': newBalance,
                  'totalSales': customerExists ? FieldValue.increment(0) : newBalance,
                  'purchaseCount': customerExists ? FieldValue.increment(0) : 0,
                  'lastUpdated': FieldValue.serverTimestamp(),
                });

                // Only add credit entry if it's a new balance being added
                if (!customerExists && balance > 0) {
                  final credits = await FirestoreService().getStoreCollection('credits');
                  await credits.add({
                    'customerId': phone,
                    'customerName': name,
                    'amount': balance,
                    'type': 'add_credit',
                    'method': 'Manual',
                    'timestamp': FieldValue.serverTimestamp(),
                    'date': DateTime.now().toIso8601String(),
                    'note': 'Opening Balance',
                  });
                }

                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  onCustomerSelected(phone, name, gstCtrl.text.trim().isEmpty ? null : gstCtrl.text.trim());
                }
              },
              child: Text(customerExists ? 'Update Customer' : 'Add Customer', style: const TextStyle(color: kWhite, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _importFromContacts(BuildContext context, Function(String phone, String name, String? gst) onCustomerSelected) async {
    final canImport = await PlanPermissionHelper.canImportContacts();
    if (!canImport) { PlanPermissionHelper.showUpgradeDialog(context, 'Import Contacts'); return; }

    if (!await FlutterContacts.requestPermission()) { showSnackBar(context, 'Contacts permission denied', bgColor: kErrorColor); return; }

    final contacts = await FlutterContacts.getContacts(withProperties: true);
    if (contacts.isEmpty) { showSnackBar(context, 'No contacts found', bgColor: kOrange); return; }

    showDialog(
      context: context,
      builder: (ctx) {
        List<Contact> filtered = contacts;
        final ctrl = TextEditingController();
        return StatefulBuilder(
          builder: (ctx, setDialogState) => Dialog(
            backgroundColor: kWhite,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              height: 550, padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Import Contact', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)), IconButton(onPressed: () => Navigator.pop(ctx), icon: const HeroIcon(HeroIcons.xMark))]),
                  Container(decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(12)), child: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Search...', prefixIcon: Padding(
                    padding: EdgeInsets.all(12.0),
                    child: HeroIcon(HeroIcons.magnifyingGlass, color: kPrimaryColor),
                  )))),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: kGrey100),
                      itemBuilder: (ctx, i) {
                        final c = filtered[i];
                        final phone = c.phones.isNotEmpty ? c.phones.first.number.replaceAll(RegExp(r'[^0-9+]'), '') : '';
                        return ListTile(
                          title: Text(c.displayName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          subtitle: Text(phone, style: const TextStyle(fontSize: 12, color: kBlack54)),
                          onTap: phone.isNotEmpty ? () { Navigator.pop(ctx); _showAddCustomerDialogWithPrefill(context, onCustomerSelected, prefillName: c.displayName, prefillPhone: phone); } : null,
                          trailing: const HeroIcon(HeroIcons.chevronRight, size: 18, color: kGrey400),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static void _showAddCustomerDialogWithPrefill(BuildContext context, Function(String phone, String name, String? gst) onCustomerSelected, {String? prefillName, String? prefillPhone}) {
    final phoneCtrl = TextEditingController(text: prefillPhone);
    final nameCtrl = TextEditingController(text: prefillName);
    final gstCtrl = TextEditingController();
    final balanceCtrl = TextEditingController(text: '0');
    bool isLoading = false;
    bool customerExists = false;

    // Check if customer exists on initial load
    if (prefillPhone != null && prefillPhone.length >= 10) {
      Future.delayed(Duration.zero, () async {
        try {
          final collection = await FirestoreService().getStoreCollection('customers');
          final doc = await collection.doc(prefillPhone).get();
          if (doc.exists) {
            final data = doc.data() as Map<String, dynamic>?;
            nameCtrl.text = data?['name'] ?? prefillName ?? '';
            gstCtrl.text = data?['gst'] ?? '';
            final balance = (data?['balance'] ?? 0.0) as num;
            balanceCtrl.text = balance.toString();
            customerExists = true;
          }
        } catch (e) {
          debugPrint(e.toString());
        }
      });
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: kWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Verify Customer', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogField(
                controller: phoneCtrl,
                label: 'Phone Number',
                icon: HeroIcons.phone,
                keyboardType: TextInputType.phone,
                onChanged: (value) async {
                  if (value.length >= 10) {
                    setDialogState(() => isLoading = true);
                    try {
                      final collection = await FirestoreService().getStoreCollection('customers');
                      final doc = await collection.doc(value).get();
                      if (doc.exists) {
                        final data = doc.data() as Map<String, dynamic>?;
                        nameCtrl.text = data?['name'] ?? '';
                        gstCtrl.text = data?['gst'] ?? '';
                        final balance = (data?['balance'] ?? 0.0) as num;
                        balanceCtrl.text = balance.toString();
                        setDialogState(() => customerExists = true);
                      } else {
                        setDialogState(() => customerExists = false);
                      }
                    } catch (e) {
                      debugPrint(e.toString());
                    }
                    setDialogState(() => isLoading = false);
                  }
                },
              ),
              const SizedBox(height: 12),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(strokeWidth: 3, color: kPrimaryColor),
                )
              else ...[
                if (customerExists)
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: kOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kOrange.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        HeroIcon(HeroIcons.informationCircle, color: kOrange, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Customer exists! Fields auto-filled.',
                            style: TextStyle(color: kOrange, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                _buildDialogField(controller: nameCtrl, label: 'Name', icon: HeroIcons.user),
                const SizedBox(height: 12),
                _buildDialogField(controller: gstCtrl, label: 'GST (Optional)', icon: HeroIcons.documentText),
                const SizedBox(height: 12),
                _buildDialogField(controller: balanceCtrl, label: 'Last Due', icon: HeroIcons.wallet, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.w800, color: kBlack54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () async {
                if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty) return;
                final balance = double.tryParse(balanceCtrl.text) ?? 0.0;

                await FirestoreService().setDocument('customers', phoneCtrl.text.trim(), {
                  'name': nameCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'gst': gstCtrl.text.trim().isEmpty ? null : gstCtrl.text.trim(),
                  'balance': balance,
                  'totalSales': customerExists ? FieldValue.increment(0) : balance,
                  'purchaseCount': customerExists ? FieldValue.increment(0) : 0,
                  'lastUpdated': FieldValue.serverTimestamp(),
                });

                // Only add credit entry if it's a new balance being added
                if (!customerExists && balance > 0) {
                  final credits = await FirestoreService().getStoreCollection('credits');
                  await credits.add({
                    'customerId': phoneCtrl.text.trim(),
                    'customerName': nameCtrl.text.trim(),
                    'amount': balance,
                    'type': 'add_credit',
                    'method': 'Manual',
                    'timestamp': FieldValue.serverTimestamp(),
                    'date': DateTime.now().toIso8601String(),
                    'note': 'Opening Balance',
                  });
                }

                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  onCustomerSelected(phoneCtrl.text.trim(), nameCtrl.text.trim(), gstCtrl.text.trim().isEmpty ? null : gstCtrl.text.trim());
                }
              },
              child: Text(customerExists ? 'Update' : 'Confirm', style: const TextStyle(color: kWhite, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stateful Bill button with tap animation and debounce protection.
/// Prevents double-clicks that cause duplicate backend writes.
class _DebouncedBillButton extends StatefulWidget {
  final VoidCallback onBill;
  final double totalBill;
  final String currencySymbol;

  const _DebouncedBillButton({
    required this.onBill,
    required this.totalBill,
    required this.currencySymbol,
  });

  @override
  State<_DebouncedBillButton> createState() => _DebouncedBillButtonState();
}

class _DebouncedBillButtonState extends State<_DebouncedBillButton>
    with SingleTickerProviderStateMixin {
  bool _tapped = false;
  late AnimationController _animController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (_tapped) return; // Block double-tap
    setState(() => _tapped = true);

    _animController.forward().then((_) => _animController.reverse());

    widget.onBill();

    // Re-enable after 1.5s (enough time for navigation to complete)
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _tapped = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnim,
      child: GestureDetector(
        onTap: _handleTap,
        child: AnimatedOpacity(
          opacity: _tapped ? 0.7 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: kPrimaryColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: kPrimaryColor.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _tapped
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          color: kWhite,
                          strokeWidth: 2,
                        ),
                      )
                    : const HeroIcon(HeroIcons.banknotes, color: kWhite, size: 18),
                const SizedBox(width: 10),
                Text(
                  "${widget.currencySymbol}${AmountFormatter.format(widget.totalBill)}",
                  style: const TextStyle(color: kWhite, fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(width: 10),
                Container(width: 1.5, height: 20, color: kWhite.withOpacity(0.3)),
                const SizedBox(width: 10),
                Text(
                  context.tr('Bill'),
                  style: const TextStyle(color: kWhite, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
