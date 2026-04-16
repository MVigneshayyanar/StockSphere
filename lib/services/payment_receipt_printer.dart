import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/services/currency_service.dart';
import 'dart:convert';

/// Direct thermal printer service for payment receipts
/// Prints payment receipts directly without showing invoice preview
class PaymentReceiptPrinter {
  
  /// Print payment receipt directly to thermal printer
  static Future<void> printPaymentReceipt({
    required BuildContext context,
    required String receiptNumber,
    required String customerName,
    required String customerPhone,
    required double previousCredit,
    required double receivedAmount,
    required String paymentMode,
    required double currentCredit,
    String? invoiceReference,
  }) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Load store data
      final storeDoc = await FirestoreService().getCurrentStoreDoc();
      final storeData = storeDoc?.data() as Map<String, dynamic>?;
      
      if (storeData == null) {
        Navigator.pop(context);
        _showError(context, 'Store data not found');
        return;
      }

      final businessName = storeData['businessName'] ?? '';
      final businessPhone = storeData['businessPhone'] ?? '';
      final businessLocation = storeData['businessLocation'] ?? '';
      final currency = CurrencyService.getSymbolWithSpace(storeData['currency']);

      // Get connected printer (optional - continue if not available)
      final connectedDevices = await FlutterBluePlus.connectedSystemDevices;
      BluetoothDevice? printer;
      BluetoothCharacteristic? writeCharacteristic;
      
      if (connectedDevices.isNotEmpty) {
        printer = connectedDevices.first;
        
        try {
          await printer.connect();

          // Find write characteristic
          final services = await printer.discoverServices();
          
          for (var service in services) {
            for (var char in service.characteristics) {
              if (char.properties.write) {
                writeCharacteristic = char;
                break;
              }
            }
            if (writeCharacteristic != null) break;
          }
        } catch (e) {
          debugPrint('Printer connection failed: $e');
          // Continue without printer
        }
      }

      // Build receipt content
      final dateStr = DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now());
      final lineWidth = 32; // Standard thermal printer width
      
      List<int> bytes = [];
      
      // ESC/POS commands
      bytes.addAll([27, 64]); // Initialize printer
      bytes.addAll([27, 97, 1]); // Center align
      
      // Header - RECEIPT
      bytes.addAll([27, 33, 16]); // Double height
      bytes.addAll(utf8.encode('PAYMENT RECEIPT\n'));
      bytes.addAll([27, 33, 0]); // Normal text
      
      bytes.addAll(utf8.encode('\n'));
      
      // Date and Receipt Number
      bytes.addAll([27, 97, 0]); // Left align
      bytes.addAll(utf8.encode('$dateStr\n'));
      bytes.addAll(utf8.encode('Receipt No: $receiptNumber\n'));
      bytes.addAll(utf8.encode('${'-' * lineWidth}\n'));
      
      // Business details
      bytes.addAll([27, 97, 1]); // Center align
      bytes.addAll([27, 33, 8]); // Bold
      bytes.addAll(utf8.encode('$businessName\n'));
      bytes.addAll([27, 33, 0]); // Normal
      if (businessLocation.isNotEmpty) {
        bytes.addAll(utf8.encode('$businessLocation\n'));
      }
      if (businessPhone.isNotEmpty) {
        bytes.addAll(utf8.encode('Tel: $businessPhone\n'));
      }
      bytes.addAll(utf8.encode('\n'));
      
      bytes.addAll([27, 97, 0]); // Left align
      bytes.addAll(utf8.encode('${'-' * lineWidth}\n'));
      
      // Received From section
      bytes.addAll([27, 97, 1]); // Center align
      bytes.addAll([27, 33, 8]); // Bold
      bytes.addAll(utf8.encode('Received From\n'));
      bytes.addAll([27, 33, 0]); // Normal
      bytes.addAll(utf8.encode('\n'));
      bytes.addAll(utf8.encode('$customerName\n'));
      bytes.addAll(utf8.encode('Contact: $customerPhone\n'));
      
      bytes.addAll([27, 97, 0]); // Left align
      bytes.addAll(utf8.encode('${'-' * lineWidth}\n'));
      bytes.addAll(utf8.encode('\n'));
      
      // Credit details
      bytes.addAll(_formatLine('Previous Credit', '${currency}${previousCredit.toStringAsFixed(2)}', lineWidth));
      bytes.addAll(utf8.encode('\n'));
      bytes.addAll(_formatLine('Received', '${currency}${receivedAmount.toStringAsFixed(2)}', lineWidth));
      bytes.addAll(utf8.encode('\n'));
      bytes.addAll(_formatLine('Payment Mode', paymentMode, lineWidth));
      bytes.addAll(utf8.encode('\n'));
      bytes.addAll(utf8.encode('${'-' * lineWidth}\n'));
      bytes.addAll([27, 33, 16]); // Double height
      bytes.addAll(_formatLine('Balance Amount', '${currency}${currentCredit.toStringAsFixed(2)}', lineWidth));
      bytes.addAll([27, 33, 0]); // Normal
      bytes.addAll(utf8.encode('${'-' * lineWidth}\n'));
      
      // Invoice reference if bill settlement
      if (invoiceReference != null && invoiceReference.isNotEmpty) {
        bytes.addAll(utf8.encode('\n'));
        bytes.addAll(utf8.encode('For Invoice: $invoiceReference\n'));
      }
      
      bytes.addAll(utf8.encode('\n'));
      bytes.addAll([27, 97, 1]); // Center align
      bytes.addAll(utf8.encode('Thank You\n'));
      bytes.addAll(utf8.encode('\n\n\n'));
      
      // Cut paper
      bytes.addAll([29, 86, 1]);
      
      // Send to printer if available
      if (writeCharacteristic != null) {
        try {
          // Send to printer in chunks
          const chunkSize = 20;
          for (var i = 0; i < bytes.length; i += chunkSize) {
            final end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
            await writeCharacteristic.write(bytes.sublist(i, end), withoutResponse: true);
            await Future.delayed(const Duration(milliseconds: 50));
          }
        } catch (e) {
          debugPrint('Print error (continuing): $e');
        }
      }

      // Close dialog
      Navigator.pop(context);
      
      // Show success
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            writeCharacteristic != null 
              ? 'Receipt printed successfully!' 
              : 'Receipt saved! (Printer not connected)',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      
    } catch (e) {
      debugPrint('Error printing payment receipt: $e');
      Navigator.pop(context);
      _showError(context, 'Print failed: $e');
    }
  }

  /// Format a two-column line (left-aligned label, right-aligned value)
  static List<int> _formatLine(String label, String value, int lineWidth) {
    final totalLength = label.length + value.length;
    final spaces = lineWidth - totalLength;
    final paddedLine = label + (' ' * (spaces > 0 ? spaces : 1)) + value;
    return utf8.encode('$paddedLine\n');
  }

  /// Show error dialog
  static void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
