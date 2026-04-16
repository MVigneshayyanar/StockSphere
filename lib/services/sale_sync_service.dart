import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sale.dart';
import '../utils/firestore_service.dart';
import 'local_stock_service.dart';

class SaleSyncService {
  static const String boxName = 'sales';
  Box<Sale>? _box;
  StreamSubscription? _connectivitySub;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) {
      print('⚠️ SaleSyncService already initialized');
      return;
    }

    print('🔧 Initializing SaleSyncService...');

    if (!Hive.isBoxOpen(boxName)) {
      print('📦 Opening Hive box: $boxName');
      _box = await Hive.openBox<Sale>(boxName);
    } else {
      print('📦 Hive box already open: $boxName');
      _box = Hive.box<Sale>(boxName);
    }

    print('🎧 Setting up connectivity listener...');
    _connectivitySub = Connectivity().onConnectivityChanged.listen((result) {
      // result is now List<ConnectivityResult>
      print('📡 Connectivity changed: $result');
      if (!result.contains(ConnectivityResult.none)) {
        print('🌐 Connection detected! Starting sync...');
        syncAll();
      } else {
        print('📵 No connection detected');
      }
    });

    _initialized = true;
    print('✅ SaleSyncService initialized successfully');

    // Try to sync on init if online
    print('🔄 Checking for pending sales on init...');
    syncAll();
  }

  Future<void> dispose() async {
    await _connectivitySub?.cancel();
    await _box?.close();
    _initialized = false;
  }

  Future<void> saveSale(Sale sale) async {
    if (!_initialized || _box == null || !_box!.isOpen) {
      await init();
    }
    await _box!.put(sale.id, sale);
    
    // Update local stock immediately
    await _updateLocalStockFromSale(sale);
    
    if (await _isOnline()) {
      await syncSale(sale.id);
    }
  }

  Future<void> _updateLocalStockFromSale(Sale sale) async {
    try {
      final items = sale.data['items'] as List<dynamic>?;
      if (items == null) return;

      final localStockService = LocalStockService();
      
      for (var item in items) {
        final productId = item['productId'] as String?;
        final quantity = item['quantity'] as num?;
        
        // Skip Quick Sale items (qs_) and invalid items
        if (productId == null || quantity == null || productId.startsWith('qs_')) continue;
        
        // Update local stock (decrement)
        await localStockService.updateLocalStock(productId, -(quantity.toInt()));
      }
    } catch (e) {
      print('⚠️ Error updating local stock from sale: $e');
    }
  }

  Future<void> syncAll() async {
    print('🔍 syncAll() called');

    if (_box == null) {
      print('❌ Box is null, cannot sync');
      return;
    }

    if (!_box!.isOpen) {
      print('❌ Box is not open, cannot sync');
      return;
    }

    final allSales = _box!.values.toList();
    print('📦 Total sales in Hive: ${allSales.length}');

    final unsyncedSales = allSales.where((s) => !s.isSynced).toList();
    print('📤 Unsynced sales: ${unsyncedSales.length}');

    if (unsyncedSales.isEmpty) {
      print('✅ No sales to sync');
      return;
    }

    print('🚀 Starting sync of ${unsyncedSales.length} offline sales...');

    int successCount = 0;
    int failCount = 0;

    for (var sale in unsyncedSales) {
      print('⏳ Syncing sale ${successCount + failCount + 1}/${unsyncedSales.length}: ${sale.id}');
      try {
        await syncSale(sale.id);
        successCount++;
      } catch (e) {
        failCount++;
        print('❌ Failed to sync ${sale.id}: $e');
      }
      // Add small delay to avoid overwhelming Firestore
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Clear pending local stock updates after successful sync
    if (successCount > 0) {
      try {
        final localStockService = LocalStockService();
        await localStockService.clearPendingUpdates();
        print('📦 Cleared pending local stock updates');
      } catch (e) {
        print('⚠️ Error clearing local stock updates: $e');
      }
    }

    print('✅ Sync complete: $successCount successful, $failCount failed');
  }

  Future<void> syncSale(String id) async {
    if (_box == null || !_box!.isOpen) {
      print('❌ Box not available for sync');
      return;
    }

    final sale = _box!.get(id);
    if (sale == null) {
      print('⚠️ Sale $id not found in Hive');
      return;
    }

    if (sale.isSynced) {
      print('✅ Sale $id already synced, skipping');
      return;
    }

    try {
      print('🔄 Syncing sale: ${sale.id}');
      final saleData = sale.toFirestore();
      // Normalize date/timestamp fields so Firestore gets Timestamp objects instead of Strings.
      dynamic _normalizeDates(dynamic value) {
        if (value is String) {
          try {
            final dt = DateTime.parse(value);
            return {'__timestamp': Timestamp.fromDate(dt)}; // marker to be handled by caller
          } catch (_) {
            return {'__raw': value};
          }
        }
        if (value is Map<String, dynamic>) {
          final out = <String, dynamic>{};
          value.forEach((k, v) {
            final conv = _normalizeDates(v);
            if (conv is Map && conv.containsKey('__timestamp')) {
              out[k] = conv['__timestamp'];
            } else if (conv is Map && conv.containsKey('__raw')) {
              out[k] = conv['__raw'];
            } else {
              out[k] = conv;
            }
          });
          return out;
        }
        if (value is List) {
          return value.map((e) {
            final conv = _normalizeDates(e);
            if (conv is Map && conv.containsKey('__timestamp')) return conv['__timestamp'];
            if (conv is Map && conv.containsKey('__raw')) return conv['__raw'];
            return conv;
          }).toList();
        }
        return value;
      }

      // Apply normalization but keep a separate normalized map to avoid mutating original.
      final normalizedData = <String, dynamic>{};
      saleData.forEach((k, v) {
        final conv = _normalizeDates(v);
        if (conv is Map && conv.containsKey('__timestamp')) {
          normalizedData[k] = conv['__timestamp'];
        } else if (conv is Map && conv.containsKey('__raw')) {
          normalizedData[k] = conv['__raw'];
        } else {
          normalizedData[k] = conv;
        }
      });

      // Ensure createdAt (from the Hive Sale object) is uploaded as a Timestamp.
      try {
        normalizedData['createdAt'] = Timestamp.fromDate(sale.createdAt);
      } catch (_) {
        // ignore - if createdAt is not set for some reason, leave as-is
      }

      final firestoreService = FirestoreService();

      // 1. Save the sale to Firestore (store-scoped) using an auto-generated document ID
      print('  📝 Saving to Firestore (store-scoped)...');
      DocumentReference docRef;

      // Check if this is an update to an unsettled sale
      if (saleData['unsettledSaleId'] != null) {
        final unsettledId = saleData['unsettledSaleId'];
        print('  🔄 Updating unsettled sale: $unsettledId');

        // Add settled info
        normalizedData['paymentStatus'] = 'settled';
        normalizedData['settledAt'] = FieldValue.serverTimestamp();

        await firestoreService.updateDocument('sales', unsettledId, normalizedData);
        docRef = (await firestoreService.getStoreCollection('sales')).doc(unsettledId);
      } else {
        // New sale: before blindly adding, check if a sale with same invoiceNumber already exists
        final storeSalesColl = await firestoreService.getStoreCollection('sales');
        final invoiceNum = (normalizedData['invoiceNumber'] ?? '').toString().trim();
        if (invoiceNum.isNotEmpty) {
          try {
            final querySnapshot = await storeSalesColl.where('invoiceNumber', isEqualTo: invoiceNum).limit(1).get();
            if (querySnapshot.docs.isNotEmpty) {
              // A sale with same invoiceNumber already exists - update it instead of creating duplicate
              final existingDoc = querySnapshot.docs.first;
              print('  ⚠️ Existing sale found for invoice $invoiceNum. Updating document ${existingDoc.id} instead of creating a duplicate.');
              await firestoreService.updateDocument('sales', existingDoc.id, normalizedData);
              docRef = storeSalesColl.doc(existingDoc.id);
            } else {
              // No existing sale with this invoiceNumber - safe to add
              docRef = await firestoreService.addDocument('sales', normalizedData);
            }
          } catch (e) {
            print('  ⚠️ Invoice uniqueness check failed: $e -- falling back to addDocument');
            docRef = await firestoreService.addDocument('sales', normalizedData);
          }
        } else {
          // No invoice nusmber present - fall back to add
          docRef = await firestoreService.addDocument('sales', normalizedData);
        }
      }

      print('  ✅ Sale saved to Firestore: ${docRef.id}');

      // Update the Hive Sale record with the generated Firestore ID so future syncs/refs match
      try {
        sale.id = docRef.id;
        sale.isSynced = true;
        sale.syncError = null;
        await sale.save();
      } catch (e) {
        print('  ⚠️ Could not update Hive sale id: $e');
      }

      // 2. Update product stock
      if (saleData['items'] != null) {
        print('  📦 Updating product stock...');
        await _updateProductStock(saleData['items']);
        print('  ✅ Stock updated');
      }

      // 3. Update customer credit if payment mode is Credit
      if (saleData['paymentMode'] == 'Credit' && saleData['customerPhone'] != null) {
        print('  💳 Updating customer credit...');
        await _updateCustomerCredit(
          saleData['customerPhone'],
          saleData['total'],
          sale.id,
        );
        print('  ✅ Customer credit updated');
      }

      // 3b. Update customer totalSales for ALL payment types
      if (saleData['customerPhone'] != null && saleData['customerPhone'].toString().isNotEmpty) {
        print('  📊 Updating customer total sales...');
        await _updateCustomerTotalSales(saleData['customerPhone'], saleData['total']);
        
        // Add payment log entry for non-credit payments (Cash/Online/Split)
        // (Credit sales handled by _updateCustomerCredit)
        if (saleData['paymentMode'] != 'Credit') {
          print('  📒 Adding payment log entry...');
          if (saleData['paymentMode'] == 'Split') {
             await _addSplitPaymentLogEntry(
               saleData['customerPhone'],
               saleData['customerName'],
               (saleData['cashReceived_split'] ?? 0.0),
               (saleData['onlineReceived_split'] ?? 0.0),
               (saleData['creditIssued_split'] ?? 0.0),
               sale.id // Using sync ID which matches invoice number usually, or doc ID
             );
          } else {
            await _addPaymentLogEntry(
              saleData['customerPhone'],
              saleData['customerName'],
              saleData['total'],
              saleData['paymentMode'],
              sale.id
            );
          }
        }
        
        print('  ✅ Customer total sales and logs updated');
      }

      // 4. Delete saved order if exists
      if (saleData['savedOrderId'] != null) {
        try {
          print('  🗑️ Deleting saved order...');
          await firestoreService.deleteDocument('savedOrders', saleData['savedOrderId']);
          print('  ✅ Saved order deleted');
        } catch (e) {
          print('  ⚠️ Error deleting saved order: $e');
        }
      }

      // 5. Mark credit notes as used
      if (saleData['selectedCreditNotes'] != null) {
        print('  🎫 Marking credit notes as used...');
        final double creditUsed = (saleData['creditUsed'] ?? 0.0).toDouble();
        await _markCreditNotesAsUsed(sale.id, saleData['selectedCreditNotes'], creditUsed);
        print('  ✅ Credit notes updated');
      }

      // 6. Update quotation status if exists
      if (saleData['quotationId'] != null && saleData['quotationId'].toString().isNotEmpty) {
        try {
          print('  📄 Updating quotation...');
          await firestoreService.updateDocument('quotations', saleData['quotationId'], {
            'status': 'settled',
            'billed': true,
            'settledAt': FieldValue.serverTimestamp(),
          });
          print('  ✅ Quotation updated');
        } catch (e) {
          print('  ⚠️ Error updating quotation: $e');
        }
      }

      // 7. Update customer purchase count (for first-time customer rating feature)
      if (saleData['customerPhone'] != null && saleData['customerPhone'].toString().isNotEmpty) {
        try {
          print('  👤 Updating customer purchase count...');
          await _updateCustomerPurchaseCount(saleData['customerPhone']);
          print('  ✅ Customer purchase count updated');
        } catch (e) {
          print('  ⚠️ Error updating customer purchase count: $e');
        }
      }

      // Mark as synced
      sale.isSynced = true;
      sale.syncError = null;
      await sale.save();

      print('✅ Successfully synced sale: ${sale.id}');
    } catch (e, stackTrace) {
      print('❌ Error syncing sale ${sale.id}: $e');
      print('Stack trace: $stackTrace');
      sale.syncError = e.toString();
      await sale.save();
      rethrow; // Rethrow so syncAll can count failures
    }
  }

  Future<void> _updateProductStock(List<dynamic> items) async {
    try {
      final firestoreService = FirestoreService();
      final productsCollection = await firestoreService.getStoreCollection('Products');

      for (var item in items) {
        final productId = item['productId'];
        final quantity = item['quantity'];

        if (productId != null && quantity != null) {
          try {
            // Get product reference and update stock
            final productRef = productsCollection.doc(productId);
            final productDoc = await productRef.get();

            if (productDoc.exists) {
              final currentQty = (productDoc.data() as Map<String, dynamic>?)?['currentStock'] ?? 0;
              final newQty = ((currentQty as num) - (quantity as num)).clamp(0, double.infinity);

              // Update with new quantity
              await productRef.update({
                'currentStock': newQty,
              });
              print('    ✅ Stock updated for $productId: $currentQty -> $newQty');
            } else {
              print('    ⚠️ Product $productId not found');
            }
          } catch (e) {
            print('    ⚠️ Error updating product $productId: $e');
          }
        }
      }
    } catch (e) {
      print('Error updating product stock: $e');
      rethrow;
    }
  }

  Future<void> _updateCustomerCredit(String phone, double amount, String invoiceNumber) async {
    try {
      final firestoreService = FirestoreService();
      final customersCollection = await firestoreService.getStoreCollection('customers');
      final creditsCollection = await firestoreService.getStoreCollection('credits');

      final customerQuery = await customersCollection
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();

      if (customerQuery.docs.isNotEmpty) {
        final customerDoc = customerQuery.docs.first;
        final data = customerDoc.data() as Map<String, dynamic>?;
        final currentBalance = (data?['balance'] ?? 0.0) as num;
        final customerName = data?['name'] ?? 'Customer';

        await customerDoc.reference.update({
          'balance': currentBalance + amount,
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        // Add credit history entry to subcollection
        await customerDoc.reference.collection('creditHistory').add({
          'amount': amount,
          'type': 'credit',
          'invoiceNumber': invoiceNumber,
          'date': FieldValue.serverTimestamp(),
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Add to main credits collection for ledger and payment log tracking
        await creditsCollection.add({
          'customerId': phone,
          'customerName': customerName,
          'amount': amount,
          'type': 'credit_sale',
          'method': 'Credit Sale (Synced)',
          'invoiceNumber': invoiceNumber,
          'timestamp': FieldValue.serverTimestamp(),
          'date': DateTime.now().toIso8601String(),
          'note': 'Credit sale - Invoice #$invoiceNumber (synced)',
        });
      }
    } catch (e) {
      print('Error updating customer credit: $e');
      rethrow;
    }
  }

  /// Updates customer totalSales for ALL payment types
  Future<void> _updateCustomerTotalSales(String phone, double amount) async {
    try {
      final firestoreService = FirestoreService();
      final customersCollection = await firestoreService.getStoreCollection('customers');

      final customerQuery = await customersCollection
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();

      if (customerQuery.docs.isNotEmpty) {
        final customerDoc = customerQuery.docs.first;
        final data = customerDoc.data() as Map<String, dynamic>?;
        final currentTotalSales = (data?['totalSales'] ?? 0.0) as num;

        await customerDoc.reference.update({
          'totalSales': currentTotalSales + amount,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error updating customer total sales: $e');
      // Don't rethrow - totalSales update is not critical
    }
  }

  Future<void> _markCreditNotesAsUsed(String invoiceNumber, List<dynamic> creditNotes, double amountToDeduct) async {
    try {
      final firestoreService = FirestoreService();
      
      double remainingToDeduct = amountToDeduct;

      for (var note in creditNotes) {
        if (remainingToDeduct <= 0) break;
        
        final noteId = note['id'];
        final double noteAmount = (note['amount'] ?? 0).toDouble();
        
        if (noteId != null) {
          if (noteAmount <= remainingToDeduct) {
             // Fully used
             await firestoreService.updateDocument('creditNotes', noteId, {
              'status': 'Used',
              'usedAt': FieldValue.serverTimestamp(),
              'usedInInvoice': invoiceNumber,
              'amount': 0.0
            });
            remainingToDeduct -= noteAmount;
          } else {
             // Partially used
             await firestoreService.updateDocument('creditNotes', noteId, {
              'amount': noteAmount - remainingToDeduct,
              'lastPartialUseAt': FieldValue.serverTimestamp(),
              'lastPartialInvoice': invoiceNumber
            });
            remainingToDeduct = 0;
          }
        }
      }
    } catch (e) {
      print('Error marking credit notes as used: $e');
      rethrow;
    }
  }

  Future<void> _addPaymentLogEntry(String phone, String? customerName, double amount, String paymentMode, String invoiceNumber) async {
    try {
       final firestoreService = FirestoreService();
       final creditsCollection = await firestoreService.getStoreCollection('credits');

       String type = 'sale_payment';
       String method = paymentMode; // Cash, Online
       String note = '$paymentMode payment - Invoice #$invoiceNumber';
       
       if (paymentMode == 'Cash') {
         note = 'Cash payment - Invoice #$invoiceNumber';
       } else if (paymentMode == 'Online') {
         note = 'Online payment - Invoice #$invoiceNumber';
       }

       await creditsCollection.add({
        'customerId': phone,
        'customerName': customerName ?? 'Customer',
        'amount': amount,
        'type': type,
        'method': method,
        'invoiceNumber': invoiceNumber,
        'timestamp': FieldValue.serverTimestamp(),
        'date': DateTime.now().toIso8601String(),
        'note': note,
      });

    } catch (e) {
       print('Error adding payment log: $e');
       // Don't rethrow
    }
  }
  
  Future<void> _addSplitPaymentLogEntry(String phone, String? customerName, double cashAmount, double onlineAmount, double creditAmount, String invoiceNumber) async {
    try {
       final firestoreService = FirestoreService();
       final creditsCollection = await firestoreService.getStoreCollection('credits');
       final totalPaid = cashAmount + onlineAmount;
       
       if (totalPaid > 0) {
         String method = '';
         // Logic matched from Bill.dart
         // Note: we don't have currency symbol here, just using generic logic
         if (cashAmount > 0 && onlineAmount > 0) {
           method = 'Cash ($cashAmount) + Online ($onlineAmount)';
         } else if (cashAmount > 0) {
           method = 'Cash';
         } else {
           method = 'Online';
         }

         await creditsCollection.add({
          'customerId': phone,
          'customerName': customerName ?? 'Customer',
          'amount': totalPaid,
          'type': 'sale_payment',
          'method': method,
          'invoiceNumber': invoiceNumber,
          'timestamp': FieldValue.serverTimestamp(),
          'date': DateTime.now().toIso8601String(),
          'note': 'Split payment - Invoice #$invoiceNumber',
        });
       }
    } catch (e) {
       print('Error adding split payment log: $e');
    }
  }

  Future<void> _updateCustomerPurchaseCount(String phone) async {
    try {
      final firestoreService = FirestoreService();
      final customersCollection = await firestoreService.getStoreCollection('customers');

      final customerDoc = await customersCollection.doc(phone).get();

      if (customerDoc.exists) {
        final data = customerDoc.data() as Map<String, dynamic>?;
        final currentCount = (data?['purchaseCount'] ?? 0) as num;

        await customerDoc.reference.update({
          'purchaseCount': currentCount + 1,
          'lastPurchaseAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Customer doesn't exist, create with purchase count of 1
        await customersCollection.doc(phone).set({
          'phone': phone,
          'purchaseCount': 1,
          'lastPurchaseAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('Error updating customer purchase count: $e');
      // Don't rethrow - this is not critical to the sale
    }
  }

  Future<bool> _isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  List<Sale> getUnsyncedSales() => _box?.values.where((s) => !s.isSynced).toList() ?? [];

  int getUnsyncedCount() => _box?.values.where((s) => !s.isSynced).length ?? 0;
}
