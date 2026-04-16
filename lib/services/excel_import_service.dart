import 'dart:io';

import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/utils/firestore_service.dart';

class ExcelImportService {
  /// Download Customer Template
  static Future<String?> downloadCustomerTemplate() async {
    try {
      // Request storage permission
      if (Platform.isAndroid) {
        var status = await Permission.storage.request();
        if (!status.isGranted) {
          status = await Permission.manageExternalStorage.request();
          if (!status.isGranted) {
            return 'Error: Storage permission denied';
          }
        }
      }

      // Load template from assets
      final ByteData data = await rootBundle.load('excel/Customer Templete.xlsx');
      final List<int> bytes = data.buffer.asUint8List();

      // Get downloads directory
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download/MAXmybill');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // For desktop platforms, use downloads folder
        final downloadsPath = Platform.isWindows
            ? '${Platform.environment['Userprofile']}\\Downloads\\MAXmybill'
            : '${Platform.environment['Home']}/Downloads/MAXmybill';
        directory = Directory(downloadsPath);
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      // Save file
      final String fileName = 'Customer_Template_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final File file = File('${directory.path}${Platform.pathSeparator}$fileName');
      await file.writeAsBytes(bytes, flush: true);

      // Verify file was created
      if (await file.exists()) {
        return file.path;
      } else {
        return 'Error: Failed to save file';
      }
    } catch (e) {
      return 'Error: ${e.toString()}';
    }
  }

  /// Download Product Template
  static Future<String?> downloadProductTemplate() async {
    try {
      // Request storage permission
      if (Platform.isAndroid) {
        var status = await Permission.storage.request();
        if (!status.isGranted) {
          status = await Permission.manageExternalStorage.request();
          if (!status.isGranted) {
            return 'Error: Storage permission denied';
          }
        }
      }

      // Load template from assets
      final ByteData data = await rootBundle.load('excel/Product Templete.xlsx');
      final List<int> bytes = data.buffer.asUint8List();

      // Get downloads directory
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download/MAXmybill');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // For desktop platforms, use downloads folder
        final downloadsPath = Platform.isWindows
            ? '${Platform.environment['Userprofile']}\\Downloads\\MAXmybill'
            : '${Platform.environment['Home']}/Downloads/MAXmybill';
        directory = Directory(downloadsPath);
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      // Save file
      final String fileName = 'Product_Template_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final File file = File('${directory.path}${Platform.pathSeparator}$fileName');
      await file.writeAsBytes(bytes, flush: true);

      // Verify file was created
      if (await file.exists()) {
        return file.path;
      } else {
        return 'Error: Failed to save file';
      }
    } catch (e) {
      return 'Error: ${e.toString()}';
    }
  }

  /// Pick Excel file - returns file bytes or null if cancelled
  static Future<Uint8List?> pickExcelFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        allowedExtensions: null,
        withData: true,
        dialogTitle: 'Select Excel File (.xlsx, .xls)',
      );

      if (result == null || result.files.isEmpty) {
        print('📂 File picker cancelled or no file selected');
        return null;
      }

      final file = result.files.first;
      print('📂 File selected: ${file.name}, Size: ${file.size} bytes');

      // Try to get bytes directly first (works on web and some platforms)
      if (file.bytes != null) {
        print('📂 Got bytes directly from file picker');
        return file.bytes;
      }

      // Fall back to reading from path (desktop platforms)
      if (file.path != null) {
        print('📂 Reading bytes from path: ${file.path}');
        final bytes = await File(file.path!).readAsBytes();
        print('📂 Read ${bytes.length} bytes from file');
        return bytes;
      }

      print('❌ No bytes or path available for file');
      return null;
    } catch (e) {
      print('❌ Error picking file: $e');
      return null;
    }
  }

  /// Process Customer Excel bytes - call this after picking the file
  static Future<Map<String, dynamic>> processCustomersExcel(Uint8List bytes, String uid) async {
    try {
      print('🔵 Starting Excel processing...');
      final excel = Excel.decodeBytes(bytes);
      print('🔵 Excel decoded successfully');

      int successCount = 0;
      int failCount = 0;
      List<String> errors = [];

      // Get the first sheet
      final sheet = excel.tables.keys.first;
      final table = excel.tables[sheet];
      print('🔵 Sheet: $sheet, Rows: ${table?.rows.length ?? 0}');

      if (table == null) {
        return {'success': false, 'message': 'Empty Excel file'};
      }

      // Skip header row, start from row 1 (index 1)
      // Template columns (0-indexed):
      // 0: Phone Number*, 1: Name*, 2: Tax No, 3: Address, 4: Default Discount %,
      // 5: Last Due, 6: Date of Birth (dd-MM-yyyy), 7: Customer Rating (out of 5)
      // * = Required field
      for (int rowIndex = 1; rowIndex < table.rows.length; rowIndex++) {
        try {
          final row = table.rows[rowIndex];

          // Skip empty rows
          if (row.isEmpty || row.every((cell) => cell == null || cell.value == null)) {
            continue;
          }

          // Extract data based on template columns:
          // A: Phone Number, B: Name, C: Tax No, D: Address, E: Default Discount %,
          // F: Last Due, G: Date of Birth, H: Customer Rating
          final phone = row.length > 0 ? row[0]?.value?.toString().trim() ?? '' : '';
          final name = row.length > 1 ? row[1]?.value?.toString().trim() ?? '' : '';
          print('🔵 Processing row ${rowIndex + 1}: $name - $phone');
          final gstin = row.length > 2 ? row[2]?.value?.toString().trim() ?? '' : '';
          final address = row.length > 3 ? row[3]?.value?.toString().trim() ?? '' : '';
          final discountStr = row.length > 4 ? row[4]?.value?.toString().trim() ?? '0' : '0';
          final lastDueStr = row.length > 5 ? row[5]?.value?.toString().trim() ?? '0' : '0';
          final dobStr = row.length > 6 ? row[6]?.value?.toString().trim() ?? '' : '';
          final ratingStr = row.length > 7 ? row[7]?.value?.toString().trim() ?? '0' : '0';

          // Validate required fields
          if (name.isEmpty || phone.isEmpty) {
            errors.add('Row ${rowIndex + 1}: Name and Phone are required');
            failCount++;
            continue;
          }

          // Parse numeric values
          final defaultDiscount = double.tryParse(discountStr) ?? 0.0;
          final lastDue = double.tryParse(lastDueStr) ?? 0.0;
          final rating = int.tryParse(ratingStr) ?? 0;

          // Parse date of birth - Support multiple formats: dd-MM-yyyy, dd/MM/yyyy, yyyy-MM-dd, ISO 8601
          DateTime? dob;
          if (dobStr.isNotEmpty) {
            try {
              final cleanDateStr = dobStr.trim();

              // Check for ISO 8601 format (e.g., 2000-02-12T00:00:00.000Z)
              if (cleanDateStr.contains('T')) {
                dob = DateTime.parse(cleanDateStr);
              } else if (cleanDateStr.contains('-') || cleanDateStr.contains('/')) {
                final separator = cleanDateStr.contains('-') ? '-' : '/';
                final parts = cleanDateStr.split(separator);
                if (parts.length == 3) {
                  final firstNum = int.tryParse(parts[0]);
                  if (firstNum != null && firstNum <= 31) {
                    // dd-MM-yyyy format
                    dob = DateTime(
                      int.parse(parts[2]), // year
                      int.parse(parts[1]), // month
                      int.parse(parts[0]), // day
                    );
                  } else {
                    // yyyy-MM-dd format
                    dob = DateTime(
                      int.parse(parts[0]), // year
                      int.parse(parts[1]), // month
                      int.parse(parts[2]), // day
                    );
                  }
                }
              } else {
                // Try parsing as Excel date serial number
                final serialNumber = int.tryParse(cleanDateStr);
                if (serialNumber != null) {
                  dob = DateTime(1899, 12, 30).add(Duration(days: serialNumber));
                }
              }
            } catch (e) {
              // Silently skip invalid dates - customer will be imported without DOB
              print('⚠️ Could not parse date: $dobStr - customer will be imported without DOB');
            }
          }

          // Check if customer already exists
          final existingCustomer = await FirestoreService().getDocument('customers', phone);

          if (existingCustomer.exists) {
            errors.add('Row ${rowIndex + 1}: Customer with phone $phone already exists');
            failCount++;
            continue;
          }

          // Prepare customer data
          final customerData = {
            'name': name,
            'phone': phone,
            'gstin': gstin.isEmpty ? null : gstin,
            'gst': gstin.isEmpty ? null : gstin,
            'address': address.isEmpty ? null : address,
            'defaultDiscount': defaultDiscount,
            'rating': rating.clamp(0, 5), // Ensure rating is between 0-5
            'balance': lastDue,
            'totalSales': 0,
            'createdAt': FieldValue.serverTimestamp(),
            'uid': uid,
            'isActive': true,
          };

          // Add DOB if provided
          if (dob != null) {
            customerData['dob'] = Timestamp.fromDate(dob);
          }

          // Add customer to Firestore
          print('📝 Saving customer: $name with phone: $phone');
          try {
            await FirestoreService().setDocument('customers', phone, customerData);
            print('✅ Customer saved successfully: $name');
          } catch (saveError) {
            print('❌ Error saving customer $name: $saveError');
            errors.add('Row ${rowIndex + 1}: Failed to save - ${saveError.toString()}');
            failCount++;
            continue;
          }

          // If there's a last due amount, create credit entry
          if (lastDue > 0) {
            final creditsCollection = await FirestoreService().getStoreCollection('credits');
            await creditsCollection.add({
              'customerName': name,
              'customerPhone': phone,
              'amount': lastDue,
              'previousDue': 0,
              'totalDue': lastDue,
              'date': FieldValue.serverTimestamp(),
              'note': 'Opening balance from Excel import',
              'uid': uid,
              'type': 'credit',
            });
            print('✅ Credit entry added for $name: $lastDue');
          }

          successCount++;
        } catch (e) {
          print('❌ Error on row ${rowIndex + 1}: $e');
          errors.add('Row ${rowIndex + 1}: ${e.toString()}');
          failCount++;
        }
      }

      print('🎉 Import complete: $successCount success, $failCount failed');
      return {
        'success': true,
        'successCount': successCount,
        'failCount': failCount,
        'errors': errors,
        'message': '$successCount customers imported successfully${failCount > 0 ? ', $failCount failed' : ''}',
      };
    } catch (e) {
      print('💥 Fatal error: $e');
      return {'success': false, 'message': 'Error processing Excel: ${e.toString()}'};
    }
  }

  /// Import Customers from Excel (legacy method - picks file and processes)
  static Future<Map<String, dynamic>> importCustomers(String uid) async {
    try {
      // Pick Excel file - Allow all file types to ensure .xlsx files are visible
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        allowedExtensions: null,
        withData: true,
        dialogTitle: 'Select Excel File (.xlsx, .xls)',
      );

      if (result == null) {
        return {'success': false, 'message': 'No file selected'};
      }

      // Read Excel file
      final bytes = result.files.first.bytes ?? await File(result.files.first.path!).readAsBytes();

      // Use the new processing method
      return await processCustomersExcel(bytes, uid);
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  /// Process Product Excel bytes - call this after picking the file
  static Future<Map<String, dynamic>> processProductsExcel(Uint8List bytes, String uid) async {
    try {
      final excel = Excel.decodeBytes(bytes);

      int successCount = 0;
      int failCount = 0;
      List<String> errors = [];

      // Get the first sheet
      final sheet = excel.tables.keys.first;
      final table = excel.tables[sheet];

      if (table == null) {
        return {'success': false, 'message': 'Empty Excel file'};
      }

      // Skip header row, start from row 1 (index 1)
      // Template columns (0-indexed):
      // 0: Category, 1: Item Name*, 2: Product code, 3: Price, 4: Initial Stock,
      // 5: Low Stock Alert, 6: Measuring Unit, 7: Total Cost Price, 8: MRP,
      // 9: Tax Type, 10: Tax %, 11: Item Location, 12: Expiry Date
      // * = Required field (Only Item Name is required)
      for (int rowIndex = 1; rowIndex < table.rows.length; rowIndex++) {
        try {
          final row = table.rows[rowIndex];

          // Skip empty rows
          if (row.isEmpty || row.every((cell) => cell == null || cell.value == null)) {
            continue;
          }

          // Extract data based on actual template columns
          final category = row.length > 0 ? row[0]?.value?.toString().trim() ?? '' : '';
          final name = row.length > 1 ? row[1]?.value?.toString().trim() ?? '' : '';
          String barcode = row.length > 2 ? row[2]?.value?.toString().trim() ?? '' : '';
          final priceStr = row.length > 3 ? row[3]?.value?.toString().trim() ?? '0' : '0';
          final quantityStr = row.length > 4 ? row[4]?.value?.toString().trim() ?? '0' : '0';
          final lowStockAlertStr = row.length > 5 ? row[5]?.value?.toString().trim() ?? '0' : '0';
          final unit = row.length > 6 ? row[6]?.value?.toString().trim() ?? 'Piece' : 'Piece';
          final costPriceStr = row.length > 7 ? row[7]?.value?.toString().trim() ?? '0' : '0';
          final mrpStr = row.length > 8 ? row[8]?.value?.toString().trim() ?? '0' : '0';
          // Column 9 is "Tax Type" but it's actually the TAX NAME (VAT, GST, etc.)
          final taxNameFromExcel = row.length > 9 ? row[9]?.value?.toString().trim() ?? '' : '';
          final gstStr = row.length > 10 ? row[10]?.value?.toString().trim() ?? '0' : '0';
          final location = row.length > 11 ? row[11]?.value?.toString().trim() ?? '' : '';
          final expiryDateStr = row.length > 12 ? row[12]?.value?.toString().trim() ?? '' : '';

          // Validate required fields - ONLY Item Name is required
          if (name.isEmpty) {
            errors.add('Row ${rowIndex + 1}: Item Name is required');
            failCount++;
            continue;
          }

          // Generate barcode if not provided (using timestamp + row index for uniqueness)
          if (barcode.isEmpty) {
            barcode = 'PRD${DateTime.now().millisecondsSinceEpoch}${rowIndex}';
          }

          // Parse numeric values (all can be 0 or empty)
          final price = double.tryParse(priceStr) ?? 0.0;
          final costPrice = double.tryParse(costPriceStr) ?? 0.0;
          final mrp = double.tryParse(mrpStr) ?? 0.0;
          final quantity = double.tryParse(quantityStr) ?? 0.0;
          final lowStockAlert = double.tryParse(lowStockAlertStr) ?? 0.0;
          final gst = double.tryParse(gstStr) ?? 0.0;

          // Parse expiry date if provided
          DateTime? expiryDate;
          if (expiryDateStr.isNotEmpty) {
            try {
              // Check for ISO 8601 format
              if (expiryDateStr.contains('T')) {
                expiryDate = DateTime.parse(expiryDateStr);
              } else if (expiryDateStr.contains('-') || expiryDateStr.contains('/')) {
                final separator = expiryDateStr.contains('-') ? '-' : '/';
                final parts = expiryDateStr.split(separator);
                if (parts.length == 3) {
                  final firstNum = int.tryParse(parts[0]);
                  if (firstNum != null && firstNum <= 31) {
                    // dd-MM-yyyy format
                    expiryDate = DateTime(
                      int.parse(parts[2]),
                      int.parse(parts[1]),
                      int.parse(parts[0]),
                    );
                  } else {
                    // yyyy-MM-dd format
                    expiryDate = DateTime(
                      int.parse(parts[0]),
                      int.parse(parts[1]),
                      int.parse(parts[2]),
                    );
                  }
                }
              }
            } catch (e) {
              print('⚠️ Could not parse expiry date: $expiryDateStr');
            }
          }

          // Check if product already exists
          final existingProduct = await FirestoreService().getDocument('Products', barcode);

          if (existingProduct.exists) {
            errors.add('Row ${rowIndex + 1}: Product with barcode $barcode already exists');
            failCount++;
            continue;
          }

          // Determine tax name from Excel column 9 (Tax Type column is actually tax name like VAT, GST)
          // Valid tax names: 'VAT', 'GST', 'CGST', 'SGST', 'IGST', 'Excise Tax', 'Zero Rated', 'Exempt'
          String? taxName;
          if (taxNameFromExcel.isNotEmpty) {
            // Use the tax name from Excel (VAT, GST, etc.)
            taxName = taxNameFromExcel.toUpperCase();
            // Normalize common variations
            if (taxName == 'Value Added Tax') taxName = 'VAT';
            if (taxName == 'Goods And Services Tax') taxName = 'GST';
          } else if (gst > 0) {
            // Default to GST if tax percentage is provided but no name
            taxName = 'GST';
          }

          // Determine tax type/treatment - default to 'Add Tax at Billing' for taxable products
          String? taxType;
          if (gst > 0) {
            taxType = 'Add Tax at Billing'; // Default for products with tax
          } else if (taxName != null && (taxName.contains('Exempt') || taxName.contains('Zero'))) {
            taxType = 'Exempt from Tax';
          }

          // Prepare product data - field names must match manual product creation
          final productData = {
            'itemName': name,
            'barcode': barcode,
            'productCode': barcode,
            'mrp': mrp,
            'price': price,
            'salePrice': price,
            'costPrice': costPrice,
            'purchasePrice': costPrice,
            'currentStock': quantity,
            'quantity': quantity,
            'stockEnabled': quantity > 0,
            'unit': unit.toUpperCase(),
            'stockUnit': unit.isEmpty ? 'Piece' : unit,
            'category': category.isEmpty ? 'General' : category,
            'gst': gst,
            'taxId': null, // No linked tax ID for imported products
            'taxPercentage': gst,
            'taxName': taxName,
            'taxType': taxType,
            'hsn': '',
            'hsnCode': null,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'uid': uid,
            'isFavorite': false,
            'isActive': true,
            'lowStockAlert': lowStockAlert,
            'lowStockAlertType': 'Count', // Valid values: 'Count' or 'Percentage'
            'location': location,
            'expiryDate': expiryDate?.toIso8601String(),
          };

          // Add product to Firestore
          print('📝 Saving product: $name with barcode: $barcode');
          try {
            await FirestoreService().setDocument('Products', barcode, productData);
            print('✅ Product saved successfully: $name');
            successCount++;
          } catch (saveError) {
            print('❌ Error saving product $name: $saveError');
            errors.add('Row ${rowIndex + 1}: Failed to save - ${saveError.toString()}');
            failCount++;
          }
        } catch (e) {
          print('❌ Error processing row ${rowIndex + 1}: $e');
          errors.add('Row ${rowIndex + 1}: ${e.toString()}');
          failCount++;
        }
      }

      print('🎉 Product import complete: $successCount success, $failCount failed');
      return {
        'success': true,
        'successCount': successCount,
        'failCount': failCount,
        'errors': errors,
        'message': '$successCount products imported successfully${failCount > 0 ? ', $failCount failed' : ''}',
      };
    } catch (e) {
      print('💥 Fatal error in product import: $e');
      return {'success': false, 'message': 'Error processing Excel: ${e.toString()}'};
    }
  }

  /// Import Products from Excel (legacy method - picks file and processes)
  static Future<Map<String, dynamic>> importProducts(String uid) async {
    try {
      // Pick Excel file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        allowedExtensions: null,
        withData: true,
        dialogTitle: 'Select Excel File (.xlsx, .xls)',
      );

      if (result == null) {
        return {'success': false, 'message': 'No file selected'};
      }

      // Read Excel file
      final bytes = result.files.first.bytes ?? await File(result.files.first.path!).readAsBytes();

      // Use the new processing method
      return await processProductsExcel(bytes, uid);
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }
}

