import '../utils/firestore_service.dart';

/// Service to generate sequential numbers for invoices, credit notes, and quotations
class NumberGeneratorService {
  static const int _defaultStartNumber = 100001;

  /// Get custom starting number from store settings
  static Future<int> _getCustomStartNumber(String field) async {
    try {
      // Force refresh to get latest settings
      final storeDoc = await FirestoreService().getCurrentStoreDoc(forceRefresh: true);
      if (storeDoc != null && storeDoc.exists) {
        final data = storeDoc.data() as Map<String, dynamic>?;
        print('📝 _getCustomStartNumber: field=$field, data[$field]=${data?[field]}');
        if (data != null && data[field] != null) {
          final value = int.tryParse(data[field].toString()) ?? _defaultStartNumber;
          print('📝 _getCustomStartNumber: Returning $value for $field');
          return value;
        }
      }
      print('📝 _getCustomStartNumber: No custom value found for $field, using default $_defaultStartNumber');
    } catch (e) {
      print('❌ Error getting custom start number for $field: $e');
    }
    return _defaultStartNumber;
  }

  /// Get custom prefix from store settings
  static Future<String> _getCustomPrefix(String field) async {
    try {
      // Force refresh to get latest settings
      final storeDoc = await FirestoreService().getCurrentStoreDoc(forceRefresh: true);
      if (storeDoc != null && storeDoc.exists) {
        final data = storeDoc.data() as Map<String, dynamic>?;
        print('📝 _getCustomPrefix: field=$field, value=${data?[field]}');
        if (data != null && data[field] != null) {
          final prefix = data[field].toString();
          print('📝 _getCustomPrefix: Returning "$prefix" for $field');
          return prefix;
        }
      }
      print('📝 _getCustomPrefix: No prefix found for $field, returning empty');
    } catch (e) {
      print('❌ Error getting custom prefix for $field: $e');
    }
    return '';
  }

  /// Increment a number field in store settings
  static Future<void> _incrementNumber(String field, int currentValue) async {
    try {
      final storeDoc = await FirestoreService().getCurrentStoreDoc(forceRefresh: true);
      if (storeDoc != null && storeDoc.exists) {
        await storeDoc.reference.update({field: currentValue + 1});
        print('📝 Incremented $field to ${currentValue + 1}');
      }
    } catch (e) {
      print('❌ Error incrementing $field: $e');
    }
  }

  /// Get invoice prefix
  static Future<String> getInvoicePrefix() async {
    return await _getCustomPrefix('invoicePrefix');
  }

  /// Get quotation prefix
  static Future<String> getQuotationPrefix() async {
    return await _getCustomPrefix('quotationPrefix');
  }

  /// Get purchase prefix
  static Future<String> getPurchasePrefix() async {
    return await _getCustomPrefix('purchasePrefix');
  }

  /// Get expense prefix
  static Future<String> getExpensePrefix() async {
    return await _getCustomPrefix('expensePrefix');
  }

  /// Get payment receipt prefix
  static Future<String> getPaymentReceiptPrefix() async {
    return await _getCustomPrefix('paymentReceiptPrefix');
  }

  /// Generate next invoice number - uses nextInvoiceNumber from settings directly
  static Future<String> generateInvoiceNumber() async {
    try {
      final nextNumber = await _getCustomStartNumber('nextInvoiceNumber');
      print('📝 Using invoice number from settings: $nextNumber');

      // Increment the number in settings for next time
      await _incrementNumber('nextInvoiceNumber', nextNumber);

      return nextNumber.toString();
    } catch (e) {
      print('❌ Error generating invoice number: $e');
      return _defaultStartNumber.toString();
    }
  }

  /// Generate next quotation number - uses nextQuotationNumber from settings directly
  static Future<String> generateQuotationNumber() async {
    try {
      final nextNumber = await _getCustomStartNumber('nextQuotationNumber');
      print('📝 Using quotation number from settings: $nextNumber');

      // Increment the number in settings for next time
      await _incrementNumber('nextQuotationNumber', nextNumber);

      return nextNumber.toString();
    } catch (e) {
      print('❌ Error generating quotation number: $e');
      return _defaultStartNumber.toString();
    }
  }

  /// Generate next purchase number - uses nextPurchaseNumber from settings directly
  static Future<String> generatePurchaseNumber() async {
    try {
      final nextNumber = await _getCustomStartNumber('nextPurchaseNumber');
      print('📝 Using purchase number from settings: $nextNumber');

      // Increment the number in settings for next time
      await _incrementNumber('nextPurchaseNumber', nextNumber);

      return nextNumber.toString();
    } catch (e) {
      print('❌ Error generating purchase number: $e');
      return _defaultStartNumber.toString();
    }
  }

  /// Generate next expense number - uses nextExpenseNumber from settings directly
  static Future<String> generateExpenseNumber() async {
    try {
      final nextNumber = await _getCustomStartNumber('nextExpenseNumber');
      print('📝 Using expense number from settings: $nextNumber');

      // Increment the number in settings for next time
      await _incrementNumber('nextExpenseNumber', nextNumber);

      return nextNumber.toString();
    } catch (e) {
      print('❌ Error generating expense number: $e');
      return _defaultStartNumber.toString();
    }
  }

  /// Generate next payment receipt number - uses nextPaymentReceiptNumber from settings directly
  static Future<String> generatePaymentReceiptNumber() async {
    try {
      final nextNumber = await _getCustomStartNumber('nextPaymentReceiptNumber');
      print('📝 Using payment receipt number from settings: $nextNumber');

      // Increment the number in settings for next time
      await _incrementNumber('nextPaymentReceiptNumber', nextNumber);

      return nextNumber.toString();
    } catch (e) {
      print('❌ Error generating payment receipt number: $e');
      return _defaultStartNumber.toString();
    }
  }

  /// Generate next credit note number by checking the last credit note
  static Future<String> generateCreditNoteNumber() async {
    try {
      final collection = await FirestoreService().getStoreCollection('creditNotes');

      final query = await collection
          .orderBy('creditNoteNumber', descending: true)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        print('📝 No previous credit notes found, starting from CN$_defaultStartNumber');
        return 'CN$_defaultStartNumber';
      }

      final lastCreditNoteNumber = query.docs.first['creditNoteNumber']?.toString() ?? '';
      final numericPart = lastCreditNoteNumber.replaceAll(RegExp(r'[^0-9]'), '');
      final lastNumber = int.tryParse(numericPart) ?? (_defaultStartNumber - 1);
      final nextNumber = lastNumber + 1;

      print('📝 Last credit note: $lastCreditNoteNumber, Next credit note: CN$nextNumber');
      return 'CN$nextNumber';
    } catch (e) {
      print('❌ Error generating credit note number: $e');
      return 'CN$_defaultStartNumber';
    }
  }

  /// Generate next expense credit note number
  static Future<String> generateExpenseCreditNoteNumber() async {
    try {
      final collection = await FirestoreService().getStoreCollection('creditNotes');

      final query = await collection
          .where('creditNoteNumber', isGreaterThanOrEqualTo: 'ECN')
          .where('creditNoteNumber', isLessThan: 'ECO')
          .orderBy('creditNoteNumber', descending: true)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        print('📝 No previous expense credit notes found, starting from ECN$_defaultStartNumber');
        return 'ECN$_defaultStartNumber';
      }

      final lastNumber = query.docs.first['creditNoteNumber']?.toString() ?? '';
      final numericPart = lastNumber.replaceAll(RegExp(r'[^0-9]'), '');
      final lastNum = int.tryParse(numericPart) ?? (_defaultStartNumber - 1);
      final nextNumber = lastNum + 1;

      print('📝 Last expense credit note: $lastNumber, Next: ECN$nextNumber');
      return 'ECN$nextNumber';
    } catch (e) {
      print('❌ Error generating expense credit note number: $e');
      return 'ECN$_defaultStartNumber';
    }
  }

  /// Generate next purchase credit note number
  static Future<String> generatePurchaseCreditNoteNumber() async {
    try {
      final collection = await FirestoreService().getStoreCollection('creditNotes');

      final query = await collection
          .where('creditNoteNumber', isGreaterThanOrEqualTo: 'PCN')
          .where('creditNoteNumber', isLessThan: 'PCO')
          .orderBy('creditNoteNumber', descending: true)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        print('📝 No previous purchase credit notes found, starting from PCN$_defaultStartNumber');
        return 'PCN$_defaultStartNumber';
      }

      final lastNumber = query.docs.first['creditNoteNumber']?.toString() ?? '';
      final numericPart = lastNumber.replaceAll(RegExp(r'[^0-9]'), '');
      final lastNum = int.tryParse(numericPart) ?? (_defaultStartNumber - 1);
      final nextNumber = lastNum + 1;

      print('📝 Last purchase credit note: $lastNumber, Next: PCN$nextNumber');
      return 'PCN$nextNumber';
    } catch (e) {
      print('❌ Error generating purchase credit note number: $e');
      return 'PCN$_defaultStartNumber';
    }
  }

  /// PEEK: Read the next number WITHOUT incrementing (for display/preview only)
  static Future<String> peekInvoiceNumber() async {
    return (await _getCustomStartNumber('nextInvoiceNumber')).toString();
  }

  static Future<String> peekQuotationNumber() async {
    return (await _getCustomStartNumber('nextQuotationNumber')).toString();
  }

  static Future<String> peekExpenseNumber() async {
    return (await _getCustomStartNumber('nextExpenseNumber')).toString();
  }

  static Future<String> peekPurchaseNumber() async {
    return (await _getCustomStartNumber('nextPurchaseNumber')).toString();
  }

  static Future<String> peekPaymentReceiptNumber() async {
    return (await _getCustomStartNumber('nextPaymentReceiptNumber')).toString();
  }
}
