import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:maxbillup/Sales/NewSale.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/services/currency_service.dart';
import 'package:maxbillup/Colors.dart';

class SavedOrdersPage extends StatefulWidget {
  final String uid;
  final String? userEmail;
  final Function(String orderId, Map<String, dynamic> data)? onLoadOrder;

  const SavedOrdersPage({super.key, required this.uid, this.userEmail, this.onLoadOrder});

  @override
  State<SavedOrdersPage> createState() => _SavedOrdersPageState();
}

class _SavedOrdersPageState extends State<SavedOrdersPage> {
  String _currencySymbol = '';

  @override
  void initState() {
    super.initState();
    _loadCurrencySymbol();
  }

  Future<void> _loadCurrencySymbol() async {
    try {
      final doc = await FirestoreService().getCurrentStoreDoc();
      if (doc != null && doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>?;
        setState(() {
          _currencySymbol = CurrencyService.getSymbolWithSpace(data?['currency']);
        });
      }
    } catch (e) {
      debugPrint('Error loading currency: $e');
    }
  }


  void _loadOrder(String orderId, Map<String, dynamic> data) {
    // Ensure orderName is included in the data
    final orderData = Map<String, dynamic>.from(data);
    if (!orderData.containsKey('orderName') && orderData.containsKey('customerName')) {
      // Backward compatibility: use customerName as orderName if orderName doesn't exist
      orderData['orderName'] = orderData['customerName'];
    }

    // Always use direct navigation to ensure orderName is properly displayed
    // Pop current screen if we're in a modal context
    if (widget.onLoadOrder != null) {
      Navigator.pop(context); // Close the saved orders page first
    }

    // Navigate to NewSalePage with saved order data
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewSalePage(
          uid: widget.uid,
          userEmail: widget.userEmail,
          savedOrderData: orderData,
          savedOrderId: orderId,
        ),
      ),
    );
  }

  Future<void> _deleteOrder(String id) async {
    try {
      await FirestoreService().deleteDocument('savedOrders', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('order_deleted'), style: const TextStyle(fontWeight: FontWeight.w600)),
            backgroundColor: kGoogleGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: kErrorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _confirmDelete(String id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('DISCARD ORDER?',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: kErrorColor.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.warning_amber_rounded, color: kErrorColor, size: 32),
            ),
            const SizedBox(height: 16),
            Text('Are you sure you want to permanently discard the saved order for "$name"?',
                textAlign: TextAlign.center,
                style: const TextStyle(color: kBlack54, fontSize: 13, height: 1.5, fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: kBlack54, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteOrder(id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kErrorColor,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Discard', style: TextStyle(color: kWhite, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kGreyBg,
      child: FutureBuilder<Stream<QuerySnapshot>>(
        future: FirestoreService().getCollectionStream('savedOrders'),
        builder: (context, streamSnapshot) {
          if (!streamSnapshot.hasData) {
            return Center(child: CircularProgressIndicator(color: kPrimaryColor));
          }
          return StreamBuilder<QuerySnapshot>(
            stream: streamSnapshot.data,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: kPrimaryColor));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyState(context.tr('no_saved_orders'));
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                itemCount: snapshot.data!.docs.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  return _buildSavedOrderCard(snapshot.data!.docs[index]);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark_border_rounded, size: 64, color: kGrey300),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(fontWeight: FontWeight.w700, color: kBlack54)),
        ],
      ),
    );
  }

  Widget _buildSavedOrderCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = (data['orderName'] ?? data['customerName'] ?? '').toString().trim().isEmpty
        ? 'Guest'
        : (data['orderName'] ?? data['customerName']).toString();
    final total = (data['total'] ?? 0.0).toDouble();
    final items = data['items'] as List<dynamic>? ?? [];
    final timestamp = data['timestamp'] as Timestamp?;
    final dateStr = timestamp != null ? DateFormat('dd MMM yyyy').format(timestamp.toDate()) : '--';
    final timeStr = timestamp != null ? DateFormat('hh:mm a').format(timestamp.toDate()) : '';

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
          onTap: () => _loadOrder(doc.id, data),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              children: [
                // Row 1: draft label | date & time
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      const Icon(Icons.bookmark_rounded, size: 13, color: kPrimaryColor),
                      const SizedBox(width: 5),
                      const Text('Saved Draft',
                          style: TextStyle(fontWeight: FontWeight.w900, color: kPrimaryColor, fontSize: 11, letterSpacing: 0.5)),
                    ]),
                    Text(timeStr.isNotEmpty ? '$dateStr • $timeStr' : dateStr,
                        style: const TextStyle(fontSize: 10.5, color: Colors.black, fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 10),
                // Row 2: customer name | total amount
                Row(
                  children: [
                    Expanded(
                      child: Text(name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text('$_currencySymbol${total.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: kGoogleGreen)),
                  ],
                ),
                const Divider(height: 20, color: kGreyBg),
                // Row 3: items count + draft badge | delete | chevron
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Items', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: kBlack54, letterSpacing: 0.5)),
                        Text('${items.length} ${items.length == 1 ? 'item' : 'items'}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 10, color: kBlack87)),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Material(
                          color: kErrorColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => _confirmDelete(doc.id, name),
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.delete_forever_rounded, color: kErrorColor, size: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.chevron_right_rounded, color: kPrimaryColor, size: 18),
                      ],
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

}