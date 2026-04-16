import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrinterService {
  static const String _selectedPrinterNameKey = 'selected_printer_name';
  static const String _selectedPrinterUrlKey = 'selected_printer_url';

  // --- DISCOVERY & SETTINGS ---

  /// Scans for all available printe(Bluetooth, WiFi, USB)
  /// Note: Bluetooth printemust be paired in Android Settings first.
  static Future<List<Printer>> discoverPrinters() async {
    try {
      return await Printing.listPrinters();
    } catch (e) {
      print('Error discovering printers: $e');
      return [];
    }
  }

  /// Saves the user's preferred printer details
  static Future<void> saveSelectedPrinter(Printer printer) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedPrinterNameKey, printer.name);
    if (printer.url != null) {
      await prefs.setString(_selectedPrinterUrlKey, printer.url!);
    }
  }

  /// Gets the saved printer
  static Future<Printer?> getSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_selectedPrinterNameKey);
    final url = prefs.getString(_selectedPrinterUrlKey);

    if (name == null) return null;

    // We reconstruct a Printer object from saved data
    // The Printer constructor requires non-null url, so we use name as fallback
    return Printer(name: name, url: url ?? name);
  }

  /// Clear saved printer
  static Future<void> clearSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_selectedPrinterNameKey);
    await prefs.remove(_selectedPrinterUrlKey);
  }

  // --- PRINTING LOGIC ---

  /// The main method to call for printing any PDF Document
  static Future<void> printPdf(pw.Document pdf) async {
    final savedPrinterObj = await getSavedPrinter();

    if (savedPrinterObj != null) {
      try {
        // Find the actual printer object from the system list to ensure it's still available
        final printers = await Printing.listPrinters();
        final printer = printers.firstWhere(
              (p) => p.name == savedPrinterObj.name || p.url == savedPrinterObj.url,
          orElse: () => savedPrinterObj, // Fallback to the reconstruction
        );

        await Printing.directPrintPdf(
          printer: printer,
          onLayout: (format) async => pdf.save(),
          format: PdfPageFormat.roll80, // Use thermal format for direct printing
        );
        return;
      } catch (e) {
        print('Failed to print to saved printer: $e');
        // If background printing fails, fall back to the UI dialog
      }
    }

    // Fallback: Show the system print dialog
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }

  // --- INVOICE GENERATION ---

  static Future<void> printInvoice({
    required String invoiceNumber,
    required String customerName,
    required String customerPhone,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discount,
    required double tax,
    required double total,
    required String paymentMode,
    String? businessName,
    String? businessPhone,
    String? businessAddress,
    String? gstin,
    DateTime? timestamp,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80, // Standard Thermal Paper Width
        margin: const pw.EdgeInsets.all(5), // Small margins for thermal
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Business Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      businessName ?? 'Business Name',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (businessPhone != null) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(businessPhone, style: const pw.TextStyle(fontSize: 10)),
                    ],
                    if (businessAddress != null) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        businessAddress,
                        style: const pw.TextStyle(fontSize: 9),
                        textAlign: pw.TextAlign.center,
                      ),
                    ],
                    if (gstin != null) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Tax: $gstin',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    ],
                  ],
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Divider(),
              pw.SizedBox(height: 5),

              // Invoice Details
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Inv: $invoiceNumber',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    timestamp != null
                        ? DateFormat('dd/MM/yy hh:mm a').format(timestamp)
                        : DateFormat('dd/MM/yy hh:mm a').format(DateTime.now()),
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Text('Cust: $customerName', style: const pw.TextStyle(fontSize: 10)),
              if (customerPhone.isNotEmpty)
                pw.Text('Ph: $customerPhone', style: const pw.TextStyle(fontSize: 9)),

              pw.SizedBox(height: 5),
              // Dashed divider using Container
              pw.Container(
                height: 1,
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(
                      color: PdfColors.grey,
                      width: 1,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 5),

              // Items Header
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 4,
                    child: pw.Text(
                      'Item',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text(
                      'Qty',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      'Amount',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 2),

              // Items List
              ...items.map((item) {
                final itemName = item['name'] ?? '';
                final quantity = item['quantity'] ?? 0;
                final price = (item['price'] ?? 0).toDouble();
                final amount = price * quantity;

                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        flex: 4,
                        child: pw.Text(
                          itemName,
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                      pw.Expanded(
                        flex: 1,
                        child: pw.Text(
                          '$quantity',
                          style: const pw.TextStyle(fontSize: 9),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          ' ${amount.toStringAsFixed(2)}',
                          style: const pw.TextStyle(fontSize: 9),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),

              pw.SizedBox(height: 5),
              pw.Divider(),
              pw.SizedBox(height: 3),

              // Subtotal, Discount, Tax breakdown
              if (discount > 0) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Subtotal', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(
                      ' ${subtotal.toStringAsFixed(2)}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Discount', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(
                      '- ${discount.toStringAsFixed(2)}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
                pw.SizedBox(height: 2),
              ],
              if (tax > 0) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Tax', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(
                      ' ${tax.toStringAsFixed(2)}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
                pw.SizedBox(height: 2),
              ],

              pw.Divider(),
              pw.SizedBox(height: 3),

              // Total
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Total',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    ' ${total.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 3),

              // Payment Mode
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Payment', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(
                    paymentMode,
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 10),
              // Dashed divider using Container
              pw.Container(
                height: 1,
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(
                      color: PdfColors.grey,
                      width: 1,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Center(
                child: pw.Text(
                  'Thank You! Visit Again',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 5),
            ],
          );
        },
      ),
    );

    await printPdf(pdf);
  }
}