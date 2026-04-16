import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:maxbillup/utils/firestore_service.dart';

/// Shared helper to compute the ledger closing balance for a customer.
/// This replays all sales (credit/split) and credit transactions to get
/// the real outstanding credit amount.
class LedgerHelper {
  /// Compute the closing balance for a customer by replaying all transactions.
  /// Returns the outstanding credit amount (positive = customer owes money).
  static Future<double> computeClosingBalance(String customerId, {bool syncToFirestore = false}) async {
    try {
      final salesCollection = await FirestoreService().getStoreCollection('sales');
      final creditsCollection = await FirestoreService().getStoreCollection('credits');

      final salesSnap = await salesCollection
          .where('customerPhone', isEqualTo: customerId)
          .get();
      final creditsSnap = await creditsCollection
          .where('customerId', isEqualTo: customerId)
          .get();

      // Each entry: (date, balanceImpact)
      List<_BalanceEntry> entries = [];

      // Process sales
      for (var doc in salesSnap.docs) {
        final d = doc.data() as Map<String, dynamic>;
        final date = (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
        final total = (d['total'] ?? 0.0).toDouble();
        final mode = d['paymentMode'] ?? 'Unknown';
        final isCancelled = d['status'] == 'cancelled';

        if (isCancelled) {
          entries.add(_BalanceEntry(date: date, balanceImpact: 0));
        } else if (mode == 'Cash' || mode == 'Online') {
          entries.add(_BalanceEntry(date: date, balanceImpact: 0));
        } else if (mode == 'Credit') {
          entries.add(_BalanceEntry(date: date, balanceImpact: total));
        } else if (mode == 'Split') {
          final cashPaid = (d['cashReceived'] ?? 0.0).toDouble();
          final onlinePaid = (d['onlineReceived'] ?? 0.0).toDouble();
          final creditAmt = total - cashPaid - onlinePaid;
          entries.add(_BalanceEntry(date: date, balanceImpact: creditAmt > 0 ? creditAmt : 0));
        } else {
          entries.add(_BalanceEntry(date: date, balanceImpact: 0));
        }
      }

      // Process credits
      for (var doc in creditsSnap.docs) {
        final d = doc.data() as Map<String, dynamic>;
        final date = (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
        final amt = (d['amount'] ?? 0.0).toDouble();
        final type = d['type'] ?? '';
        final isCancelled = d['status'] == 'cancelled';

        if (isCancelled) {
          entries.add(_BalanceEntry(date: date, balanceImpact: 0));
        } else if (type == 'payment_received') {
          entries.add(_BalanceEntry(date: date, balanceImpact: -amt));
        } else if (type == 'settlement') {
          entries.add(_BalanceEntry(date: date, balanceImpact: -amt));
        } else if (type == 'add_credit') {
          entries.add(_BalanceEntry(date: date, balanceImpact: amt));
        }
        // credit_sale and sale_payment are tracked via sales collection
      }

      // Sort by date and compute running balance
      entries.sort((a, b) => a.date.compareTo(b.date));
      double balance = 0;
      for (var e in entries) {
        balance += e.balanceImpact;
      }

      if (syncToFirestore) {
        final customersCollection = await FirestoreService().getStoreCollection('customers');
        await customersCollection.doc(customerId).update({
          'balance': balance,
          'lastLedgerSync': FieldValue.serverTimestamp(),
        });
      }

      return balance;
    } catch (e) {
      debugPrint('LedgerHelper: Error computing closing balance: $e');
      return 0.0;
    }
  }
}

class _BalanceEntry {
  final DateTime date;
  final double balanceImpact;
  _BalanceEntry({required this.date, required this.balanceImpact});
}
