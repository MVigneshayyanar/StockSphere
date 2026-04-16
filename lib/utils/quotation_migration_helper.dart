import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:maxbillup/utils/firestore_service.dart';

/// Utility to migrate old quotations that have status='settled' or 'billed'
/// but are missing the billed=true field
class QuotationMigrationHelper {

  /// Run this once to update all existing settled quotations
  static Future<void> migrateSettledQuotations(BuildContext context) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Migrating quotations...'),
            ],
          ),
        ),
      );

      final stream = await FirestoreService().getCollectionStream('quotations');
      int updatedCount = 0;

      // Process first snapshot only
      await for (final snapshot in stream) {
        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'];
          final billed = data['billed'];

          // If status is settled/billed but billed field is missing or false
          if ((status == 'settled' || status == 'billed') && billed != true) {
            try {
              await FirestoreService().updateDocument('quotations', doc.id, {
                'billed': true,
              });
              updatedCount++;
              debugPrint('✅ Updated quotation ${doc.id} to billed=true');
            } catch (e) {
              debugPrint('❌ Error updating quotation ${doc.id}: $e');
            }
          }
        }
        break; // Only process first snapshot
      }

      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Migration complete! Updated $updatedCount quotation(s)'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Migration failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Alternative: Update a single quotation by ID
  static Future<void> migrateQuotationById(String quotationId, BuildContext context) async {
    try {
      await FirestoreService().updateDocument('quotations', quotationId, {
        'billed': true,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quotation updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

