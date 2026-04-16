import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:maxbillup/Sales/components/common_widgets.dart';
import 'package:maxbillup/Sales/NewSale.dart';
import 'package:maxbillup/services/cart_service.dart';
import 'package:maxbillup/services/currency_service.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/amount_formatter.dart';
import 'package:maxbillup/components/app_mini_switch.dart';
import 'package:maxbillup/Settings/Profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/utils/plan_permission_helper.dart';
import 'package:maxbillup/Colors.dart';
import 'package:heroicons/heroicons.dart';

// Invoice Template Types
enum InvoiceTemplate {
  classic,    // Black & White Professional
  modern,     // Blue Accent Modern
  minimal,    // Clean Minimal
  colorful,   // Colorful Creative
}

// Template Colors - Classic (Black & White)
const Color _bwPrimary = Colors.black;
const Color _bwBg = Colors.white;
const Color _textMain = Colors.black;
const Color _textSub = Color(0xFF424242);
const Color _headerBg = Color(0xFFF5F5F5);

// Template Colors - Modern (Blue)
const Color _modernPrimary = Color(0xFF2F7CF6);
const Color _modernBg = Colors.white;
const Color _modernHeaderBg = Color(0xFFE3F2FD);

// Template Colors - Minimal (Gray)
const Color _minimalPrimary = Color(0xFF37474F);
const Color _minimalBg = Colors.white;
const Color _minimalAccent = Color(0xFF78909C);
const Color _minimalHeaderBg = Color(0xFFF5F5F5);

// Template Colors - Colorful (Multi-color)
const Color _colorfulPrimary = Color(0xFF6A1B9A);
const Color _colorfulBg = Colors.white;
const Color _colorfulAccent = Color(0xFFFF6F00);
const Color _colorfulHeaderBg = Color(0xFFF3E5F5);

class InvoicePage extends StatefulWidget {
  final String uid;
  final String? userEmail;
  final String businessName;
  final String businessLocation;
  final String businessPhone;
  final String? businessGSTIN;
  final String invoiceNumber;
  final DateTime dateTime;
  final List<Map<String, dynamic>> items;
  final double subtotal;
  final double discount;
  final List<Map<String, dynamic>>? taxes;
  final double total;
  final String paymentMode;
  final double cashReceived;
  final String? customerName;
  final String? customerPhone;
  final String? customerGSTIN;
  final String? customNote;
  final String? deliveryAddress;
  final double deliveryCharge;
  final bool isQuotation;
  final bool isPaymentReceipt;
  final double? cashReceived_split;
  final double? onlineReceived_split;
  final double? creditIssued_split;
  final double? cashReceived_partial;
  final double? creditIssued_partial;
  final bool showCelebration;

  const InvoicePage({
    super.key,
    required this.uid,
    this.userEmail,
    required this.businessName,
    required this.businessLocation,
    required this.businessPhone,
    this.businessGSTIN,
    required this.invoiceNumber,
    required this.dateTime,
    required this.items,
    required this.subtotal,
    required this.discount,
    this.taxes,
    required this.total,
    required this.paymentMode,
    required this.cashReceived,
    this.customerName,
    this.customerPhone,
    this.customerGSTIN,
    this.customNote,
    this.deliveryAddress,
    this.deliveryCharge = 0.0,
    this.isQuotation = false,
    this.isPaymentReceipt = false,
    this.cashReceived_split,
    this.onlineReceived_split,
    this.creditIssued_split,
    this.cashReceived_partial,
    this.creditIssued_partial,
    this.showCelebration = true,
  });

  @override
  State<InvoicePage> createState() => _InvoicePageState();
}

class _InvoicePageState extends State<InvoicePage> with TickerProviderStateMixin {
  bool _isLoading = true;
  String? _storeId;

  // Celebration animation
  late AnimationController _celebrationController;
  bool _showCelebration = false;
  final List<_Confetti> _confettiParticles = [];

  late String businessName;
  late String businessLocation;
  late String businessPhone;
  String? businessGSTIN;
  String? businessTaxTypeName; // Tax type name like "GSTIN", "PAN", "VAT", etc.
  String? businessEmail;
  String? businessLogoUrl;
  String? businessLicenseNumber;
  String? businessLicenseTypeName; // License type name like "FSSAI", "Drug License", etc.
  String _currencySymbol = ''; // Will be loaded from store data

  // Header Info Settings (shared for display)
  String _receiptHeader = 'Invoice';
  bool _showLogo = true;
  bool _showEmail = true;
  bool _showPhone = true;
  bool _showGST = true;
  bool _showLicenseNumber = false;
  bool _showLocation = true;

  // Item Table Settings (shared for display)
  bool _showCustomerDetails = true;
  bool _showMeasuringUnit = true;
  bool _showMRP = false;
  bool _showPaymentMode = true;
  bool _showTotalItems = true;
  bool _showTotalQty = false;
  bool _showSaveAmountMessage = true;

  // Invoice Footer Settings (shared for display)
  String _footerDescription = 'Thank you for your business!';
  String? _footerImageUrl;

  // Quotation Footer Settings
  String _quotationFooterDescription = 'Thank You';

  // ==========================================
  // THERMAL PRINTER SPECIFIC SETTINGS
  // ==========================================
  bool _thermalShowHeader = true;
  bool _thermalShowLogo = true;
  bool _thermalShowCustomerInfo = true;
  bool _thermalShowItemTable = true;
  bool _thermalShowTotalItemQuantity = true;
  bool _thermalShowTaxDetails = true;
  bool _thermalShowYouSaved = true;
  bool _thermalShowDescription = false;
  bool _thermalShowDelivery = false;
  bool _thermalShowLicense = true;
  String _thermalSaleInvoiceText = 'Thank you for your purchase!';
  bool _thermalShowTaxColumn = false; // Tax column hidden by default for thermal

  // ==========================================
  // A4 / PDF PRINTER SPECIFIC SETTINGS
  // ==========================================
  bool _a4ShowHeader = true;
  bool _a4ShowLogo = true;
  bool _a4ShowCustomerInfo = true;
  bool _a4ShowItemTable = true;
  bool _a4ShowTotalItemQuantity = true;
  bool _a4ShowTaxDetails = true;
  bool _a4ShowYouSaved = true;
  bool _a4ShowDescription = false;
  bool _a4ShowDelivery = false;
  bool _a4ShowLicense = true;
  String _a4SaleInvoiceText = 'Thank you for your purchase!';
  bool _a4ShowTaxColumn = true; // Tax column shown by default for A4
  bool _a4ShowSignature = false;
  String _a4ColorTheme = 'blue'; // Color theme for A4: blue, black, green, purple, red

  // Preview mode TabController
  late TabController _previewTabController;

  // Template selection
  InvoiceTemplate _selectedTemplate = InvoiceTemplate.classic;

  // PDF Fonts for currency symbol support
  pw.Font? _pdfFontRegular;
  pw.Font? _pdfFontBold;

  // Stream subscription for store data changes
  StreamSubscription<Map<String, dynamic>>? _storeDataSubscription;

  // Customer rating
  bool _ratingDialogShown = false;

  // Plan gate - watermark shown for free users
  bool _isPaidPlan = true; // default true to avoid flash of watermark on paid users

  @override
  void initState() {
    super.initState();
    businessName = widget.businessName;
    businessLocation = widget.businessLocation;
    businessPhone = widget.businessPhone;
    businessGSTIN = widget.businessGSTIN;
    _loadStoreData();
    _loadReceiptSettings();
    _loadTemplatePreference();
    _loadPdfFonts();
    _loadPlanStatus();

    // Initialize preview tab controller
    _previewTabController = TabController(length: 2, vsync: this);

    // Initialize celebration animation
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    // Generate confetti particles
    _generateConfetti();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CartService>().clearCart();
        // Start celebration effects only when coming from a new sale
        if (widget.showCelebration) {
          setState(() => _showCelebration = true);
          _startCelebration();
        }
        // Check if we should show rating dialog for first-time customer
        _checkAndShowRatingDialog();
      }
    });

    _storeDataSubscription = FirestoreService().storeDataStream.listen((storeData) {
      if (mounted) {
        setState(() {
          businessLogoUrl = storeData['logoUrl'];
          businessName = storeData['businessName'] ?? businessName;
          businessPhone = storeData['businessPhone'] ?? businessPhone;
          businessLocation = storeData['businessLocation'] ?? businessLocation;

          // Parse taxType - stored as "Type Number" format
          final taxType = storeData['taxType'] ?? storeData['gstin'] ?? '';
          if (taxType.isNotEmpty) {
            final taxParts = taxType.toString().split(' ');
            if (taxParts.length > 1) {
              businessTaxTypeName = taxParts[0];
              businessGSTIN = taxParts.sublist(1).join(' ');
            } else {
              businessTaxTypeName = 'GSTIN';
              businessGSTIN = taxType;
            }
          }

          // Email can be stored as 'email' or 'ownerEmail'
          businessEmail = storeData['email'] ?? storeData['ownerEmail'];

          // Parse licenseNumber - stored as "Type Number" format (e.g. "FSSAI 123456")
          final licenseNumber = storeData['licenseNumber'] ?? '';
          if (licenseNumber.isNotEmpty) {
            final licenseParts = licenseNumber.toString().trim().split(' ');
            if (licenseParts.length > 1) {
              businessLicenseTypeName = licenseParts[0];
              businessLicenseNumber = licenseParts.sublist(1).join(' ');
            } else {
              // Only one token — treat it as the number, use 'License' as label
              businessLicenseTypeName = 'License';
              businessLicenseNumber = licenseParts[0];
            }
          }
        });
        debugPrint('Invoice: Store data updated via stream - logo=$businessLogoUrl, email=$businessEmail, taxType=$businessTaxTypeName $businessGSTIN');
      }
    });
  }

  @override
  void dispose() {
    _storeDataSubscription?.cancel();
    _celebrationController.dispose();
    _previewTabController.dispose();
    super.dispose();
  }

  /// Check if this is the customer's first purchase and show rating dialog
  Future<void> _checkAndShowRatingDialog() async {
    // Only show for customers with phone number (identified customers)
    if (widget.customerPhone == null || widget.customerPhone!.isEmpty) {
      debugPrint('❌ Rating dialog: No customer phone');
      return;
    }
    if (_ratingDialogShown) {
      debugPrint('❌ Rating dialog: Already shown');
      return;
    }

    try {
      // Add a delay to ensure purchaseCount has been updated
      await Future.delayed(const Duration(milliseconds: 1000));

      final customersCollection = await FirestoreService().getStoreCollection('customers');
      final customerDoc = await customersCollection.doc(widget.customerPhone).get();

      debugPrint('📊 Checking rating for customer: ${widget.customerPhone}');

      if (customerDoc.exists) {
        final data = customerDoc.data() as Map<String, dynamic>?;
        final purchaseCount = data?['purchaseCount'] ?? 0;
        final hasRating = data?['rating'] != null;

        debugPrint('   Purchase Count: $purchaseCount');
        debugPrint('   Has Rating: $hasRating');

        // Show rating dialog for first-time purchase (purchaseCount 0 or 1) and no existing rating
        // Note: purchaseCount may be 0 if sale hasn't synced yet, or 1 if sync completed
        if (purchaseCount <= 1 && !hasRating) {
          debugPrint('✅ Showing rating dialog for first-time customer');
          // Wait for celebration to finish before showing rating dialog
          await Future.delayed(const Duration(milliseconds: 2500));
          if (mounted && !_ratingDialogShown) {
            _ratingDialogShown = true;
            _showRatingDialog();
          }
        } else {
          debugPrint('❌ Rating dialog: purchaseCount=$purchaseCount, hasRating=$hasRating');
        }
      } else {
        debugPrint('❌ Rating dialog: Customer document does not exist - might be new customer');
        // For brand new customers that don't have a document yet, show rating dialog
        debugPrint('✅ Showing rating dialog for brand new customer');
        await Future.delayed(const Duration(milliseconds: 2500));
        if (mounted && !_ratingDialogShown) {
          _ratingDialogShown = true;
          _showRatingDialog();
        }
      }
    } catch (e) {
      debugPrint('Error checking customer rating: $e');
    }
  }

  /// Show the 5-star rating dialog
  void _showRatingDialog() {
    int selectedRating = 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Customer avatar
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      (widget.customerName ?? 'C')[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: kPrimaryColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                const Text(
                  'Rate this Customer',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: kBlack87,
                  ),
                ),
                const SizedBox(height: 8),

                // Customer name
                Text(
                  widget.customerName ?? 'Customer',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kBlack54,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.customerPhone ?? '',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: kBlack54,
                  ),
                ),
                const SizedBox(height: 24),

                // 5-star rating
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return GestureDetector(
                      onTap: () {
                        setDialogState(() {
                          selectedRating = index + 1;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: HeroIcon(
                          HeroIcons.star,
                          style: index < selectedRating ? HeroIconStyle.solid : HeroIconStyle.outline,
                          size: 40,
                          color: index < selectedRating ? kOrange : kGrey300,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),

                // Rating text
                Text(
                  selectedRating == 0
                      ? 'Tap to rate'
                      : selectedRating == 1
                      ? 'Poor'
                      : selectedRating == 2
                      ? 'Fair'
                      : selectedRating == 3
                      ? 'Good'
                      : selectedRating == 4
                      ? 'Very Good'
                      : 'Excellent!',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: selectedRating > 0 ? kPrimaryColor : kBlack54,
                  ),
                ),
                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    // Skip button
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: kGrey300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Skip',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: kBlack54,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Submit button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: selectedRating > 0
                            ? () {
                          _submitCustomerRating(selectedRating);
                          Navigator.pop(context);
                        }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryColor,
                          disabledBackgroundColor: kGrey200,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Submit',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Submit customer rating to Firestore
  Future<void> _submitCustomerRating(int rating) async {
    if (widget.customerPhone == null || widget.customerPhone!.isEmpty) return;

    try {
      final customersCollection = await FirestoreService().getStoreCollection('customers');
      await customersCollection.doc(widget.customerPhone).set({
        'rating': rating,
        'ratedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const HeroIcon(HeroIcons.star, style: HeroIconStyle.solid, color: kOrange, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Customer rated $rating star${rating > 1 ? 's' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            backgroundColor: kGoogleGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error submitting customer rating: $e');
    }
  }

  void _generateConfetti() {
    final random = Random();
    for (int i = 0; i < 50; i++) {
      _confettiParticles.add(_Confetti(
        x: random.nextDouble(),
        y: random.nextDouble() * -1, // Start above screen
        color: [kPrimaryColor, kOrange, kGoogleGreen, Colors.purple, Colors.pink, Colors.amber][random.nextInt(6)],
        size: random.nextDouble() * 8 + 4,
        speed: random.nextDouble() * 0.5 + 0.3,
        rotation: random.nextDouble() * 360,
      ));
    }
  }

  Future<void> _startCelebration() async {
    // Vibration feedback - short burst pattern
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 300));
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 300));
    await HapticFeedback.heavyImpact();

    // Play success sound using system sound
    await SystemSound.play(SystemSoundType.click);

    // Start confetti animation
    _celebrationController.forward();

    // Hide celebration after animation completes
    await Future.delayed(const Duration(milliseconds: 3000));
    if (mounted) {
      setState(() => _showCelebration = false);
    }
  }

  Future<void> _loadTemplatePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final templateIndex = prefs.getInt('invoice_template') ?? 0;
      setState(() {
        _selectedTemplate = InvoiceTemplate.values[templateIndex];
      });
    } catch (e) {
      debugPrint('Error loading template preference: $e');
    }
  }

  Future<void> _loadPdfFonts() async {
    try {
      final fontRegular = await rootBundle.load('fonts/NotoSans-Regular.ttf');
      final fontBold = await rootBundle.load('fonts/NotoSans-Bold.ttf');
      _pdfFontRegular = pw.Font.ttf(fontRegular);
      _pdfFontBold = pw.Font.ttf(fontBold);
    } catch (e) {
      debugPrint('Error loading PDF fonts: $e');
    }
  }

  Future<void> _loadPlanStatus() async {
    final canRemove = await PlanPermissionHelper.canRemoveWatermark();
    if (mounted) setState(() => _isPaidPlan = canRemove);
  }

  Future<void> _loadReceiptSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        // Header Info (general)
        _receiptHeader = widget.isPaymentReceipt ? 'Payment Receipt' : (prefs.getString('receipt_header') ?? 'Invoice');
        _showLogo = prefs.getBool('receipt_show_logo') ?? true;
        _showEmail = prefs.getBool('receipt_show_email') ?? true;
        _showPhone = prefs.getBool('receipt_show_phone') ?? true;
        _showGST = prefs.getBool('receipt_show_gst') ?? true;
        _showLicenseNumber = prefs.getBool('receipt_show_license') ?? false;
        _showLocation = prefs.getBool('receipt_show_location') ?? true;

        // Item Table (general)
        _showCustomerDetails = prefs.getBool('receipt_show_customer_details') ?? true;
        _showMeasuringUnit = prefs.getBool('receipt_show_measuring_unit') ?? true;
        _showMRP = prefs.getBool('receipt_show_mrp') ?? false;
        _showPaymentMode = prefs.getBool('receipt_show_payment_mode') ?? true;
        _showTotalItems = prefs.getBool('receipt_show_total_items') ?? true;
        _showTotalQty = prefs.getBool('receipt_show_total_qty') ?? false;
        _showSaveAmountMessage = prefs.getBool('receipt_show_save_amount') ?? true;

        // Invoice Footer (general)
        _footerDescription = prefs.getString('receipt_footer_description') ?? 'Thank you for your business!';
        _footerImageUrl = prefs.getString('receipt_footer_image');

        // Quotation Footer
        _quotationFooterDescription = prefs.getString('quotation_footer_description') ?? 'Thank You';

        // ==========================================
        // THERMAL PRINTER SPECIFIC SETTINGS
        // ==========================================
        _thermalShowHeader = prefs.getBool('thermal_show_header') ?? true;
        _thermalShowLogo = prefs.getBool('thermal_show_logo') ?? true;
        _thermalShowCustomerInfo = prefs.getBool('thermal_show_customer_info') ?? true;
        _thermalShowItemTable = prefs.getBool('thermal_show_item_table') ?? true;
        _thermalShowTotalItemQuantity = prefs.getBool('thermal_show_total_item_quantity') ?? true;
        _thermalShowTaxDetails = prefs.getBool('thermal_show_tax_details') ?? true;
        _thermalShowYouSaved = prefs.getBool('thermal_show_you_saved') ?? true;
        _thermalShowDescription = prefs.getBool('thermal_show_description') ?? false;
        _thermalShowDelivery = prefs.getBool('thermal_show_delivery') ?? false;
        _thermalShowLicense = prefs.getBool('thermal_show_license') ?? true;
        _thermalSaleInvoiceText = prefs.getString('thermal_sale_invoice_text') ?? 'Thank you for your purchase!';
        _thermalShowTaxColumn = prefs.getBool('thermal_show_tax_column') ?? false;

        // ==========================================
        // A4 / PDF PRINTER SPECIFIC SETTINGS
        // ==========================================
        _a4ShowHeader = prefs.getBool('a4_show_header') ?? true;
        _a4ShowLogo = prefs.getBool('a4_show_logo') ?? true;
        _a4ShowCustomerInfo = prefs.getBool('a4_show_customer_info') ?? true;
        _a4ShowItemTable = prefs.getBool('a4_show_item_table') ?? true;
        _a4ShowTotalItemQuantity = prefs.getBool('a4_show_total_item_quantity') ?? true;
        _a4ShowTaxDetails = prefs.getBool('a4_show_tax_details') ?? true;
        _a4ShowYouSaved = prefs.getBool('a4_show_you_saved') ?? true;
        _a4ShowDescription = prefs.getBool('a4_show_description') ?? false;
        _a4ShowDelivery = prefs.getBool('a4_show_delivery') ?? false;
        _a4ShowLicense = prefs.getBool('a4_show_license') ?? true;
        _a4SaleInvoiceText = prefs.getString('a4_sale_invoice_text') ?? 'Thank you for your purchase!';
        _a4ShowTaxColumn = prefs.getBool('a4_show_tax_column') ?? true;
        _a4ShowSignature = prefs.getBool('a4_show_signature') ?? false;
        _a4ColorTheme = prefs.getString('a4_color_theme') ?? 'blue';
      });
    } catch (e) {
      debugPrint('Error loading receipt settings: $e');
    }
  }

  Future<void> _loadStoreData() async {
    try {
      // Use the same method as Profile.dart - FirestoreService().getCurrentStoreDoc()
      final store = await FirestoreService().getCurrentStoreDoc();
      if (store != null && store.exists) {
        final data = store.data() as Map<String, dynamic>;
        _storeId = store.id;
        setState(() {
          businessName = data['businessName'] ?? widget.businessName;
          businessPhone = data['businessPhone'] ?? widget.businessPhone;
          businessLocation = data['businessLocation'] ?? widget.businessLocation;

          // Parse taxType - stored as "Type Number" format (e.g., "GSTIN 27AAFCV2449G1Z7")
          final taxType = data['taxType'] ?? data['gstin'] ?? '';
          if (taxType.isNotEmpty) {
            final taxParts = taxType.toString().split(' ');
            if (taxParts.length > 1) {
              businessTaxTypeName = taxParts[0]; // e.g., "GSTIN"
              businessGSTIN = taxParts.sublist(1).join(' '); // e.g., "27AAFCV2449G1Z7"
            } else {
              businessTaxTypeName = 'GSTIN'; // Default name
              businessGSTIN = taxType;
            }
          } else {
            businessGSTIN = widget.businessGSTIN;
            businessTaxTypeName = 'GSTIN';
          }

          // Email can be stored as 'email' or 'ownerEmail'
          businessEmail = data['email'] ?? data['ownerEmail'];
          businessLogoUrl = data['logoUrl'];

          // Parse licenseNumber - stored as "Type Number" format (e.g., "FSSAI 123456789")
          final licenseNumber = data['licenseNumber'] ?? '';
          if (licenseNumber.isNotEmpty) {
            final licenseParts = licenseNumber.toString().trim().split(' ');
            if (licenseParts.length > 1) {
              businessLicenseTypeName = licenseParts[0]; // e.g., "FSSAI"
              businessLicenseNumber = licenseParts.sublist(1).join(' '); // e.g., "123456789"
            } else {
              // Only one token — treat it as the number, use 'License' as label
              businessLicenseTypeName = 'License';
              businessLicenseNumber = licenseParts[0];
            }
          }

          // Load currency and convert to symbol
          final currencyCode = data['currency'] as String?;
          _currencySymbol = CurrencyService.getSymbolWithSpace(currencyCode);
          _isLoading = false;
        });
        debugPrint('Invoice: Store data loaded - name=$businessName, logo=$businessLogoUrl, email=$businessEmail, gstin=$businessGSTIN, license=$businessLicenseNumber, location=$businessLocation, currency=$_currencySymbol');
        return;
      }
      setState(() { _isLoading = false; });
    } catch (e) {
      debugPrint('Error loading store data: $e');
      setState(() { _isLoading = false; });
    }
  }



  @override
  Widget build(BuildContext context) {
    final templateColors = _getTemplateColors(_selectedTemplate);

    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.isPaymentReceipt ? 'Payment Receipt' : (widget.isQuotation ? 'Quotation Details' : 'Invoice Details'),
          style: const TextStyle(
            color: kWhite,
            fontWeight: FontWeight.w700,
            fontSize: 16,
            fontFamily: 'NotoSans',
          ),
        ),
        leading: IconButton(
          icon: const HeroIcon(HeroIcons.xMark, color: kWhite, size: 18),
          onPressed: () => Navigator.pushAndRemoveUntil(
            context,
            CupertinoPageRoute(builder: (context) => NewSalePage(uid: widget.uid, userEmail: widget.userEmail)),
                (route) => false,
          ),
        ),
        actions: [
          IconButton(
            icon: const HeroIcon(HeroIcons.printer, color: kWhite, size: 20),
            tooltip: 'Printer Setup',
            onPressed: () => Navigator.push(
              context,
              CupertinoPageRoute(builder: (_) => PrinterSetupPage(onBack: () => Navigator.pop(context))),
            ),
          ),
          IconButton(
            icon: const HeroIcon(HeroIcons.cog6Tooth, color: kWhite, size: 20),
            onPressed: _showInvoiceSettings,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Container(
            decoration: const BoxDecoration(
              color: kPrimaryColor,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              height: 48,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: kGreyBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kGrey200),
              ),
              child: TabBar(
                controller: _previewTabController,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: kPrimaryColor,
                ),
                dividerColor: Colors.transparent,
                labelColor: kWhite,
                unselectedLabelColor: kBlack54,
                labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5),
                tabs: const [
                  Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.print_rounded, size: 16), SizedBox(width: 8), Text('Thermal')])),
                  Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.picture_as_pdf_rounded, size: 16), SizedBox(width: 8), Text('A4 / PDF')])),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
              : TabBarView(
            controller: _previewTabController,
            children: [
              // Thermal Preview Tab
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                child: _buildThermalPreview(),
              ),
              // A4/PDF Preview Tab
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                child: _buildA4Preview(templateColors),
              ),
            ],
          ),
          // Celebration confetti overlay
          if (_showCelebration)
            AnimatedBuilder(
              animation: _celebrationController,
              builder: (context, child) {
                return IgnorePointer(
                  child: CustomPaint(
                    size: MediaQuery.of(context).size,
                    painter: _ConfettiPainter(
                      particles: _confettiParticles,
                      progress: _celebrationController.value,
                    ),
                  ),
                );
              },
            ),
          // Success checkmark animation in center
          if (_showCelebration)
            AnimatedBuilder(
              animation: _celebrationController,
              builder: (context, child) {
                // Scale animation: grow from 0 to 1 in first 30% of animation
                final scaleProgress = (_celebrationController.value / 0.3).clamp(0.0, 1.0);
                final scale = Curves.elasticOut.transform(scaleProgress);

                // Fade out in last 20% of animation
                final fadeProgress = ((_celebrationController.value - 0.8) / 0.2).clamp(0.0, 1.0);
                final opacity = 1.0 - fadeProgress;

                return IgnorePointer(
                  child: Center(
                    child: Opacity(
                      opacity: opacity,
                      child: Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: kGoogleGreen,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: kGoogleGreen.withOpacity(0.4),
                                blurRadius: 30,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 70,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

        ],
      ),
      bottomNavigationBar: _buildBottomActionBar(),
    );
  }

  Map<String, Color> _getTemplateColors(InvoiceTemplate template) {
    switch (template) {
      case InvoiceTemplate.classic:
        return {
          'primary': _bwPrimary,
          'bg': _bwBg,
          'text': _textMain,
          'textSub': _textSub,
          'headerBg': _headerBg,
        };
      case InvoiceTemplate.modern:
        return {
          'primary': _modernPrimary,
          'bg': _modernBg,
          'text': _modernPrimary,
          'textSub': kBlack54,
          'headerBg': _modernHeaderBg,
        };
      case InvoiceTemplate.minimal:
        return {
          'primary': _minimalPrimary,
          'bg': _minimalBg,
          'text': _minimalPrimary,
          'textSub': _minimalAccent,
          'headerBg': _minimalHeaderBg,
        };
      case InvoiceTemplate.colorful:
        return {
          'primary': _colorfulPrimary,
          'bg': _colorfulBg,
          'text': _colorfulPrimary,
          'textSub': _colorfulAccent,
          'headerBg': _colorfulHeaderBg,
        };
    }
  }

  void _showInvoiceSettings() {
    // Navigate to Bill & Print Settings page
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => BillPrintSettingsPage(
          onBack: () {
            Navigator.pop(context);
          },
        ),
      ),
    ).then((_) {
      // Reload settings when returning from Bill & Print Settings
      _loadReceiptSettings();
    });
  }


  Widget _buildExpandableSection({
    required String title,
    required bool isExpanded,
    required VoidCallback onTap,
    required StateSetter setModalState,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGrey200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: kBlack87)),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: _getTemplateColors(_selectedTemplate)['primary'],
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1, color: kGrey200),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextFieldInModal(TextEditingController controller, String label, Function(String) onChanged) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextField(
          controller: controller,
          onChanged: onChanged,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          decoration: InputDecoration(
            labelText: label,
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
    );
  }

  Widget _buildMultilineTextFieldInModal(TextEditingController controller, String hint, Function(String) onChanged) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextField(
          controller: controller,
          onChanged: onChanged,
          maxLines: 3,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: kGrey400, fontWeight: FontWeight.w400),
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
    );
  }

  Widget _buildSectionLabel(String text) => Padding(padding: const EdgeInsets.only(bottom: 12, left: 4), child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 1.0)));

  List<Widget> _buildTemplateOptions(StateSetter setModalState) {
    final templates = [
      {'index': 0, 'title': 'Classic Professional', 'icon': Icons.article_rounded, 'color': Colors.black},
      {'index': 1, 'title': 'Modern Business', 'icon': Icons.receipt_long_rounded, 'color': const Color(0xFF2F7CF6)},
      {'index': 2, 'title': 'Compact Receipt', 'icon': Icons.description_rounded, 'color': const Color(0xFF37474F)},
      {'index': 3, 'title': 'Detailed Creative', 'icon': Icons.summarize_rounded, 'color': const Color(0xFF6A1B9A)},
    ];

    return templates.map((template) {
      final isSelected = _selectedTemplate.index == template['index'];
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          onTap: () {
            setState(() => _selectedTemplate = InvoiceTemplate.values[template['index'] as int]);
            setModalState(() => _selectedTemplate = InvoiceTemplate.values[template['index'] as int]);
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kWhite,
              border: Border.all(
                color: isSelected ? template['color'] as Color : kGrey200,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(template['icon'] as IconData, color: isSelected ? template['color'] as Color : kBlack54, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    template['title'] as String,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? template['color'] as Color : kBlack87,
                    ),
                  ),
                ),
                if (isSelected) Icon(Icons.check_circle_rounded, color: template['color'] as Color, size: 20),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildSettingTile(String title, bool value, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: kGreyBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGrey200),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kBlack87)),
        trailing: AppMiniSwitch(value: value, onChanged: onChanged),
      ),
    );
  }

  Future<void> _saveInvoiceSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Template
      await prefs.setInt('invoice_template', _selectedTemplate.index);

      // Header Info
      await prefs.setString('receipt_header', _receiptHeader);
      await prefs.setBool('receipt_show_logo', _showLogo);
      await prefs.setBool('receipt_show_email', _showEmail);
      await prefs.setBool('receipt_show_phone', _showPhone);
      await prefs.setBool('receipt_show_gst', _showGST);
      await prefs.setBool('receipt_show_license', _showLicenseNumber);
      await prefs.setBool('receipt_show_location', _showLocation);

      // Item Table Settings
      await prefs.setBool('receipt_show_customer_details', _showCustomerDetails);
      await prefs.setBool('receipt_show_measuring_unit', _showMeasuringUnit);
      await prefs.setBool('receipt_show_mrp', _showMRP);
      await prefs.setBool('receipt_show_payment_mode', _showPaymentMode);
      await prefs.setBool('receipt_show_total_items', _showTotalItems);
      await prefs.setBool('receipt_show_total_qty', _showTotalQty);
      await prefs.setBool('receipt_show_save_amount', _showSaveAmountMessage);

      // Footer Settings
      await prefs.setString('receipt_footer_description', _footerDescription);
      await prefs.setString('quotation_footer_description', _quotationFooterDescription);
      if (_footerImageUrl != null) {
        await prefs.setString('receipt_footer_image', _footerImageUrl!);
      }

      // Also save to Firestore for sync across devices
      try {
        final storeId = await FirestoreService().getCurrentStoreId();
        if (storeId != null) {
          await FirebaseFirestore.instance.collection('store').doc(storeId).update({
            'invoiceSettings': {
              'template': _selectedTemplate.index,
              'header': _receiptHeader,
              'showLogo': _showLogo,
              'showEmail': _showEmail,
              'showPhone': _showPhone,
              'showGST': _showGST,
              'showLicense': _showLicenseNumber,
              'showLocation': _showLocation,
              'showCustomerDetails': _showCustomerDetails,
              'showMeasuringUnit': _showMeasuringUnit,
              'showMRP': _showMRP,
              'showPaymentMode': _showPaymentMode,
              'showTotalItems': _showTotalItems,
              'showTotalQty': _showTotalQty,
              'showSaveAmount': _showSaveAmountMessage,
              'footerDescription': _footerDescription,
              'footerImageUrl': _footerImageUrl,
              'quotationFooter': _quotationFooterDescription,
            }
          });
        }
      } catch (e) {
        debugPrint('Error saving to Firestore: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receipt settings updated'), backgroundColor: kGoogleGreen, behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  Widget _buildInvoiceByTemplate(InvoiceTemplate template, Map<String, Color> colors) {
    switch (template) {
      case InvoiceTemplate.classic:
        return _buildClassicLayout(colors);
      case InvoiceTemplate.modern:
        return _buildModernLayout(colors);
      case InvoiceTemplate.minimal:
        return _buildCompactLayout(colors);
      case InvoiceTemplate.colorful:
        return _buildDetailedLayout(colors);
    }
  }

  // ==========================================
  // A4 COLOR THEMES
  // ==========================================
  Map<String, Color> _getA4ThemeColors() {
    switch (_a4ColorTheme) {
      case 'gold':
        return {'primary': const Color(0xFFC9A441), 'accent': const Color(0xFFD4B856), 'light': const Color(0xFFFDF8E8)};
      case 'lavender':
        return {'primary': const Color(0xFF9A96D8), 'accent': const Color(0xFFB0ACE5), 'light': const Color(0xFFF3F2FC)};
      case 'green':
        return {'primary': const Color(0xFF1CB466), 'accent': const Color(0xFF2ECC7A), 'light': const Color(0xFFE6F9EF)};
      case 'brown':
        return {'primary': const Color(0xFFAF4700), 'accent': const Color(0xFFC55A15), 'light': const Color(0xFFFEF3E8)};
      case 'blue':
        return {'primary': const Color(0xFF6488E0), 'accent': const Color(0xFF7A9AEB), 'light': const Color(0xFFEEF3FC)};
      case 'peach':
        return {'primary': const Color(0xFFFAA774), 'accent': const Color(0xFFFBB88A), 'light': const Color(0xFFFFF5EE)};
      case 'red':
        return {'primary': const Color(0xFFDB4747), 'accent': const Color(0xFFE56060), 'light': const Color(0xFFFDECEC)};
      case 'purple':
        return {'primary': const Color(0xFF7A1FA2), 'accent': const Color(0xFF9333B5), 'light': const Color(0xFFF5E8F9)};
      case 'orange':
        return {'primary': const Color(0xFFF45715), 'accent': const Color(0xFFF76E35), 'light': const Color(0xFFFEEDE6)};
      case 'pink':
        return {'primary': const Color(0xFFE2A9F1), 'accent': const Color(0xFFEBBCF6), 'light': const Color(0xFFFCF3FE)};
      case 'copper':
        return {'primary': const Color(0xFFB36A22), 'accent': const Color(0xFFC47F3A), 'light': const Color(0xFFFBF2E8)};
      case 'black':
        return {'primary': const Color(0xFF000000), 'accent': const Color(0xFF333333), 'light': const Color(0xFFF5F5F5)};
      case 'olive':
        return {'primary': const Color(0xFF9B9B6E), 'accent': const Color(0xFFADAD85), 'light': const Color(0xFFF6F6F0)};
      case 'navy':
        return {'primary': const Color(0xFF2F6798), 'accent': const Color(0xFF4279AA), 'light': const Color(0xFFEAF1F7)};
      case 'grey':
        return {'primary': const Color(0xFF737373), 'accent': const Color(0xFF8A8A8A), 'light': const Color(0xFFF2F2F2)};
      case 'forest':
        return {'primary': const Color(0xFF4F6F1F), 'accent': const Color(0xFF628535), 'light': const Color(0xFFEFF3E7)};
      default:
        return {'primary': const Color(0xFF6488E0), 'accent': const Color(0xFF7A9AEB), 'light': const Color(0xFFEEF3FC)};
    }
  }

  // ==========================================
  // A4 PREVIEW WRAPPER - Full Size Preview (matches PDF output)
  // ==========================================
  Widget _buildA4Preview(Map<String, Color> templateColors) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availW = constraints.maxWidth.isFinite ? constraints.maxWidth : MediaQuery.of(context).size.width - 32;
        // Scale factor: designed for 460px, shrinks on smaller screens
        final scale = (availW / 460).clamp(0.6, 1.0);
        return _buildA4PreviewContent(scale);
      },
    );
  }

  Widget _buildA4PreviewContent(double scale) {
    final a4Colors = _getA4ThemeColors();
    final themeColor = a4Colors['primary']!;
    final currency = _currencySymbol;
    final dateStr = DateFormat('dd/MM/yyyy').format(widget.dateTime);
    final timeStr = DateFormat('hh:mm a').format(widget.dateTime);

    // Scaled helpers
    double fs(double size) => size * scale;
    double sp(double size) => size * scale;
    EdgeInsets hp(double h, double v) => EdgeInsets.symmetric(horizontal: sp(h), vertical: sp(v));

    return Center(
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 500),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(25),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top accent strip — always visible at very top
              Container(
                width: double.infinity,
                height: 4,
                color: themeColor,
              ),

              // Header — white bsg, bottom divider, dark text
              if (_a4ShowHeader)
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                    ),
                  ),
                  padding: hp(20, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Logo
                      if (_a4ShowLogo)
                        Container(
                          width: sp(46), height: sp(46),
                          margin: EdgeInsets.only(right: sp(12)),
                          decoration: BoxDecoration(
                            color: themeColor.withAlpha(18),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: themeColor.withAlpha(60)),
                          ),
                          child: businessLogoUrl != null && businessLogoUrl!.isNotEmpty
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(businessLogoUrl!, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(child: Text(businessName.isNotEmpty ? businessName[0].toUpperCase() : 'B', style: TextStyle(fontSize: fs(20), fontWeight: FontWeight.w900, color: themeColor))),
                            ),
                          )
                              : Center(child: Text(businessName.isNotEmpty ? businessName[0].toUpperCase() : 'B', style: TextStyle(fontSize: fs(20), fontWeight: FontWeight.w900, color: themeColor))),
                        ),
                      // Business Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(businessName, style: TextStyle(fontSize: fs(15), fontWeight: FontWeight.w900, color: kBlack87), maxLines: 1, overflow: TextOverflow.ellipsis),
                            if (_showLocation && businessLocation.isNotEmpty)
                              Text(businessLocation, style: TextStyle(fontSize: fs(10), color: kBlack54), maxLines: 1, overflow: TextOverflow.ellipsis),
                            if (_showPhone && businessPhone.isNotEmpty)
                              Text('Tel: $businessPhone', style: TextStyle(fontSize: fs(10), color: kBlack54)),
                            if (_showEmail && businessEmail != null && businessEmail!.isNotEmpty)
                              Text('Email: $businessEmail', style: TextStyle(fontSize: fs(10), color: kBlack54), maxLines: 1, overflow: TextOverflow.ellipsis),
                            if (_showGST && businessGSTIN != null && businessGSTIN!.isNotEmpty)
                              Text('${businessTaxTypeName ?? 'GSTIN'}: $businessGSTIN', style: TextStyle(fontSize: fs(10), fontWeight: FontWeight.w700, color: kBlack87)),
                            if (_a4ShowLicense && businessLicenseNumber != null && businessLicenseNumber!.isNotEmpty)
                              Text('${businessLicenseTypeName ?? 'License'}: $businessLicenseNumber', style: TextStyle(fontSize: fs(10), fontWeight: FontWeight.w700, color: kBlack87)),
                          ],
                        ),
                      ),
                      SizedBox(width: sp(8)),
                      // Invoice Info badge — small coloured tag
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: hp(8, 4),
                            decoration: BoxDecoration(color: themeColor, borderRadius: BorderRadius.circular(4)),
                            child: Text(widget.isQuotation ? 'Quotation' : 'Tax Invoice', style: TextStyle(color: Colors.white, fontSize: fs(9), fontWeight: FontWeight.w900)),
                          ),
                          SizedBox(height: sp(4)),
                          Text('#${widget.invoiceNumber}', style: TextStyle(fontSize: fs(12), fontWeight: FontWeight.w700, color: kBlack87)),
                          Text(dateStr, style: TextStyle(fontSize: fs(10), color: kBlack54)),
                          Text(timeStr, style: TextStyle(fontSize: fs(10), color: kBlack54)),
                        ],
                      ),
                    ],
                  ),
                ),

              // Content area
              Padding(
                padding: EdgeInsets.all(sp(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Customer Section — plain grey box, theme colour only for label
                    if (_a4ShowCustomerInfo && widget.customerName != null) ...[
                      Container(
                        padding: hp(12, 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F8FA),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Row(
                          children: [
                            Text('Customer: ', style: TextStyle(fontSize: fs(12), fontWeight: FontWeight.w700, color: themeColor)),
                            Expanded(child: Text(widget.customerName!, style: TextStyle(fontSize: fs(12), color: kBlack87), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            if (widget.customerPhone != null)
                              Text(' | Contact: ${widget.customerPhone}', style: TextStyle(fontSize: fs(11), color: kBlack54)),
                          ],
                        ),
                      ),
                      SizedBox(height: sp(14)),
                    ],

                    // Items Table — keep as-is (table header uses themeColor — perfect)
                    if (_a4ShowItemTable) ...[
                      // Table Header
                      Container(
                        decoration: BoxDecoration(
                          color: themeColor,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          border: Border.all(color: themeColor),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: Padding(
                                padding: hp(6, 8),
                                child: Text('Item Description', style: TextStyle(fontSize: fs(10), fontWeight: FontWeight.w800, color: Colors.white)),
                              ),
                            ),
                            SizedBox(
                              width: sp(34),
                              child: Padding(
                                padding: hp(2, 8),
                                child: Text('QTY.', style: TextStyle(fontSize: fs(10), fontWeight: FontWeight.w800, color: Colors.white), textAlign: TextAlign.center),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Padding(
                                padding: hp(4, 8),
                                child: Text('Price', style: TextStyle(fontSize: fs(10), fontWeight: FontWeight.w800, color: Colors.white), textAlign: TextAlign.right),
                              ),
                            ),
                            if (_a4ShowTaxColumn)
                              Expanded(
                                flex: 2,
                                child: Padding(
                                  padding: hp(4, 8),
                                  child: Text('Tax', style: TextStyle(fontSize: fs(10), fontWeight: FontWeight.w800, color: Colors.white), textAlign: TextAlign.right),
                                ),
                              ),
                            Expanded(
                              flex: 2,
                              child: Padding(
                                padding: hp(6, 8),
                                child: Text('Amount', style: TextStyle(fontSize: fs(10), fontWeight: FontWeight.w800, color: Colors.white), textAlign: TextAlign.right),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Table Body — alternating white / very-light-grey (no theme tint)
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
                        ),
                        child: Column(
                          children: widget.items.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final item = entry.value;
                            final name = (item['name'] ?? 'Item') as String;
                            final qty = item['quantity'] ?? 1;
                            final rate = (item['price'] ?? item['rate'] ?? 0.0).toDouble();
                            final taxPerc = (item['taxPercentage'] ?? 0).toDouble();
                            final taxName = (item['taxName'] ?? '') as String;
                            final taxAmt = (item['taxAmount'] ?? 0.0).toDouble();
                            final taxType = item['taxType'] as String?;
                            final baseTotal = rate * (qty is num ? qty.toDouble() : 1.0);
                            // Compute amount respecting tax type
                            final double amount;
                            if (taxType == 'Tax Included in Price' || taxType == 'Price includes Tax') {
                              amount = baseTotal; // price already has tax
                            } else if (taxType != null) {
                              amount = baseTotal + taxAmt; // add tax for 'Add Tax at Billing' etc.
                            } else {
                              amount = (item['total'] ?? baseTotal).toDouble(); // fresh sale: total is already totalWithTax
                            }
                            // Subtle alternating: white vs very-light-grey (no theme tint)
                            final rowBg = idx.isEven ? Colors.white : const Color(0xFFF9FAFB);
                            return Container(
                              color: rowBg,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: Padding(
                                      padding: hp(6, 8),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(name, style: TextStyle(fontSize: fs(11), fontWeight: FontWeight.w700, color: kBlack87), maxLines: 3, overflow: TextOverflow.ellipsis),
                                          if (taxName.isNotEmpty && taxPerc > 0)
                                            Text('$taxName ${taxPerc.toStringAsFixed(0)}%', style: TextStyle(fontSize: fs(9), color: kBlack54)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: sp(34),
                                    child: Padding(
                                      padding: hp(2, 8),
                                      child: Text(
                                        qty is double && qty % 1 != 0 ? qty.toStringAsFixed(2) : '$qty',
                                        style: TextStyle(fontSize: fs(11), color: kBlack87),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Padding(
                                      padding: hp(4, 8),
                                      child: Text(rate.toStringAsFixed(2), style: TextStyle(fontSize: fs(11), color: kBlack87), textAlign: TextAlign.right),
                                    ),
                                  ),
                                  if (_a4ShowTaxColumn)
                                    Expanded(
                                      flex: 2,
                                      child: Padding(
                                        padding: hp(4, 8),
                                        child: taxPerc > 0
                                            ? Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(taxAmt.toStringAsFixed(2), style: TextStyle(fontSize: fs(11), color: kBlack87), textAlign: TextAlign.right),
                                                  Text('(${taxPerc.toStringAsFixed(0)}%)', style: TextStyle(fontSize: fs(8), color: kBlack54), textAlign: TextAlign.right),
                                                ],
                                              )
                                            : Text('-', style: TextStyle(fontSize: fs(11), color: kBlack54), textAlign: TextAlign.right),
                                      ),
                                    ),
                                  Expanded(
                                    flex: 2,
                                    child: Padding(
                                      padding: hp(6, 8),
                                      // Keep theme colour on total amount — matches reference image
                                      child: Text(amount.toStringAsFixed(2), style: TextStyle(fontSize: fs(11), fontWeight: FontWeight.w800, color: themeColor), textAlign: TextAlign.right),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      SizedBox(height: sp(14)),
                    ],

                    // Totals Section
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // You Saved / Item count
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_a4ShowYouSaved && widget.discount > 0)
                                Container(
                                  padding: EdgeInsets.all(sp(8)),
                                  margin: EdgeInsets.only(bottom: sp(6)),
                                  decoration: BoxDecoration(color: kGoogleGreen.withAlpha(20), borderRadius: BorderRadius.circular(6), border: Border.all(color: kGoogleGreen.withAlpha(60))),
                                  child: Text('🎉 You Saved $currency${widget.discount.toStringAsFixed(2)}!', style: TextStyle(fontSize: fs(11), fontWeight: FontWeight.w700, color: kGoogleGreen)),
                                ),
                              if (_a4ShowTotalItemQuantity)
                                Text(
                                  'Items: ${widget.items.length} | Qty: ${widget.items.fold<num>(0, (s, i) => s + ((i['quantity'] ?? 1) is int ? i['quantity'] : (i['quantity'] as num).toInt()))}',
                                  style: TextStyle(fontSize: fs(11), color: kBlack54),
                                ),
                            ],
                          ),
                        ),
                        SizedBox(width: sp(8)),
                        // Totals Box — grey border, white bg, theme colour only on total row text
                        Container(
                          width: sp(180),
                          padding: EdgeInsets.all(sp(10)),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Column(
                            children: [
                              _buildScaledTotalRow('Subtotal', '$currency${widget.subtotal.toStringAsFixed(2)}', fs),
                              if (widget.discount > 0)
                                _buildScaledTotalRow('Discount', '-$currency${widget.discount.toStringAsFixed(2)}', fs, isGreen: true),
                              if (_a4ShowTaxDetails && widget.taxes != null)
                                ...widget.taxes!.map((tax) => _buildScaledTotalRow(tax['name'] ?? 'Tax', '$currency${(tax['amount'] ?? 0.0).toStringAsFixed(2)}', fs)),
                              if (widget.deliveryCharge > 0)
                                _buildScaledTotalRow('Delivery', '+$currency${widget.deliveryCharge.toStringAsFixed(2)}', fs),
                              Divider(height: sp(14), color: const Color(0xFFE5E7EB)),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Total', style: TextStyle(fontSize: fs(13), fontWeight: FontWeight.w900, color: themeColor)),
                                  Text('$currency${widget.total.toStringAsFixed(2)}', style: TextStyle(fontSize: fs(14), fontWeight: FontWeight.w900, color: themeColor)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: sp(12)),

                    // Payment Mode — plain grey
                    Container(
                      padding: hp(10, 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.payment_rounded, size: fs(13), color: kBlack54),
                          SizedBox(width: sp(6)),
                          Text(
                            widget.paymentMode != "quotation" ? widget.paymentMode : 'Paid via ${widget.paymentMode}',
                            style: TextStyle(fontSize: fs(11), fontWeight: FontWeight.w700, color: kBlack87),
                          ),
                        ],
                      ),
                    ),

                    // Bill Notes — plain grey
                    if (widget.customNote != null && widget.customNote!.isNotEmpty) ...[
                      SizedBox(height: sp(10)),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(sp(10)),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F8FA),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Note:', style: TextStyle(fontSize: fs(11), fontWeight: FontWeight.bold, color: kBlack54)),
                            SizedBox(height: sp(3)),
                            Text(widget.customNote!, style: TextStyle(fontSize: fs(11), color: kBlack87)),
                          ],
                        ),
                      ),
                    ],

                    // Delivery Address — plain grey
                    if (widget.deliveryAddress != null && widget.deliveryAddress!.isNotEmpty) ...[
                      SizedBox(height: sp(8)),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(sp(10)),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F8FA),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Delivery Address:', style: TextStyle(fontSize: fs(11), fontWeight: FontWeight.bold, color: kBlack54)),
                            SizedBox(height: sp(3)),
                            Text(widget.deliveryAddress!, style: TextStyle(fontSize: fs(11), color: kBlack87)),
                          ],
                        ),
                      ),
                    ],

                    SizedBox(height: sp(20)),

                    // Footer — light grey bg, dark text, small theme accent
                    Container(
                      width: double.infinity,
                      padding: hp(16, 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(6),
                        border: Border(left: BorderSide(color: themeColor, width: 4)),
                      ),
                      child: Center(
                        child: Text(
                          _a4SaleInvoiceText.isNotEmpty ? _a4SaleInvoiceText : 'Thank you for your business!',
                          style: TextStyle(fontSize: fs(13), fontWeight: FontWeight.w700, color: kBlack87),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ));
  }

  /// Scaled total row for preview
  Widget _buildScaledTotalRow(String label, String value, double Function(double) fs, {bool isGreen = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: fs(11), color: kBlack54, fontWeight: FontWeight.w600)),
          Text(value, style: TextStyle(fontSize: fs(11), fontWeight: FontWeight.w800, color: isGreen ? kGoogleGreen : kBlack87)),
        ],
      ),
    );
  }

  // ==========================================
  // THERMAL RECEIPT PREVIEW
  // ==========================================
  Widget _buildThermalPreview() {
    final currency = _currencySymbol;
    final dateStr = DateFormat('dd - MMM - yyyy').format(widget.dateTime);
    final timeStr = DateFormat('hh:mm a').format(widget.dateTime);

    // Calculate total quantity
    final totalQty = widget.items.fold<num>(0, (sum, item) => sum + ((item['quantity'] ?? 1) is int ? item['quantity'] : (item['quantity'] as num).toInt()));

    // Helper: thermal text style with NotoSans for best clarity
    TextStyle tStyle({double size = 9, FontWeight weight = FontWeight.normal, Color color = kBlack87}) =>
        TextStyle(fontSize: size, fontWeight: weight, color: color, fontFamily: 'NotoSans');

    return Center(
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: kBlack87, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ========== HEADER SECTION ==========
            // Logo - Always show if available
            if (_thermalShowLogo) ...[
              if (businessLogoUrl != null && businessLogoUrl!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      businessLogoUrl!,
                      height: 60,
                      width: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 60,
                        width: 60,
                        decoration: BoxDecoration(
                          color: kGrey200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.store, color: kBlack54, size: 30),
                      ),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    height: 60,
                    width: 60,
                    decoration: BoxDecoration(
                      color: kGrey200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        businessName.isNotEmpty ? businessName[0].toUpperCase() : 'B',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: kBlack87),
                      ),
                    ),
                  ),
                ),
            ],

            // Business Name (Bold, Large)
            if (_thermalShowHeader) ...[
              Text(
                businessName,
                style: tStyle(size: 14, weight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
              if (_showLocation && businessLocation.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(businessLocation, style: tStyle(size: 9), textAlign: TextAlign.center),
                ),
              if (_showPhone && businessPhone.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('PHONE: $businessPhone', style: tStyle(size: 9), textAlign: TextAlign.center),
                ),
              if (_showGST && businessGSTIN != null && businessGSTIN!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('${businessTaxTypeName ?? 'GSTIN'}: $businessGSTIN',
                      style: tStyle(size: 9, weight: FontWeight.w600), textAlign: TextAlign.center),
                ),
              if (_thermalShowLicense && businessLicenseNumber != null && businessLicenseNumber!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('${businessLicenseTypeName ?? 'License'}: $businessLicenseNumber',
                      style: tStyle(size: 9, weight: FontWeight.w600), textAlign: TextAlign.center),
                ),
            ],

            const SizedBox(height: 12),

            // ========== BILL NO & DATE ROW ==========
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Bill No: ${widget.invoiceNumber}', style: tStyle(size: 9, weight: FontWeight.w600)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Date: $dateStr', style: tStyle(size: 9, weight: FontWeight.w600)),
                    Text('Time: $timeStr', style: tStyle(size: 9, weight: FontWeight.w600)),
                  ],
                ),
              ],
            ),

            // ========== CUSTOMER INFO ==========
            if (_thermalShowCustomerInfo && widget.customerName != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: kBlack54, width: 1),
                    bottom: BorderSide(color: kBlack54, width: 1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Customer: ${widget.customerName}', style: tStyle(size: 9, weight: FontWeight.w600)),
                    if (widget.customerPhone != null)
                      Text('Contact: ${widget.customerPhone}', style: tStyle(size: 9, color: kBlack54)),
                    if (widget.customerGSTIN != null && widget.customerGSTIN!.isNotEmpty)
                      Text('Tax: ${widget.customerGSTIN}', style: tStyle(size: 9, color: kBlack54)),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 8),

            // ========== ITEMS TABLE ==========
            if (_thermalShowItemTable) ...[
              // Items Table Header
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: kBlack87, width: 1.5),
                    bottom: BorderSide(color: kBlack87, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(flex: 5, child: Text('Item', style: tStyle(size: 9, weight: FontWeight.w800))),
                    SizedBox(width: 32, child: Text('Qty', style: tStyle(size: 9, weight: FontWeight.w800), textAlign: TextAlign.center)),
                    Expanded(flex: 2, child: Text('Price', style: tStyle(size: 9, weight: FontWeight.w800), textAlign: TextAlign.right)),
                    Expanded(flex: 2, child: Text('Amt', style: tStyle(size: 9, weight: FontWeight.w800), textAlign: TextAlign.right)),
                  ],
                ),
              ),
              // Items List
              ...widget.items.asMap().entries.map((entry) {
                final item = entry.value;
                final name = item['name'] ?? 'Item';
                final qty = item['quantity'] ?? 1;
                final price = (item['price'] ?? 0.0).toDouble();
                final taxAmt = (item['taxAmount'] ?? 0.0).toDouble();
                final taxType = item['taxType'] as String?;
                final baseTotal = price * (qty is num ? qty.toDouble() : 1.0);
                // Compute amount respecting tax type
                final double amount;
                if (taxType == 'Tax Included in Price' || taxType == 'Price includes Tax') {
                  amount = baseTotal; // price already has tax
                } else if (taxType != null) {
                  amount = baseTotal + taxAmt; // add tax for 'Add Tax at Billing' etc.
                } else {
                  amount = (item['total'] ?? baseTotal).toDouble(); // fresh sale: total is already totalWithTax
                }
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kGrey300, width: 0.5))),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: tStyle(size: 9), softWrap: true),
                          ],
                        ),
                      ),
                      SizedBox(width: 32, child: Text('$qty', style: tStyle(size: 9), textAlign: TextAlign.center)),
                      Expanded(flex: 2, child: Text(price.toStringAsFixed(2), style: tStyle(size: 9), textAlign: TextAlign.right)),
                      Expanded(flex: 2, child: Text(amount.toStringAsFixed(2), style: tStyle(size: 9), textAlign: TextAlign.right)),
                    ],
                  ),
                );
              }),
            ],

            // ========== SUBTOTAL ROW ==========
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: kBlack87, width: 1))),
              child: Row(
                children: [
                  Expanded(flex: 5, child: Text('Subtotal', style: tStyle(size: 10, weight: FontWeight.w600))),
                  SizedBox(
                    width: 32,
                    child: _thermalShowTotalItemQuantity
                        ? Text('${totalQty.toInt()}', style: tStyle(size: 10, weight: FontWeight.w600), textAlign: TextAlign.center)
                        : const SizedBox.shrink(),
                  ),
                  Expanded(flex: 2, child: const SizedBox.shrink()),
                  Expanded(flex: 2, child: Text(widget.subtotal.toStringAsFixed(2), style: tStyle(size: 10, weight: FontWeight.w600), textAlign: TextAlign.right)),
                ],
              ),
            ),

            // ========== TAX BREAKDOWN (Only show if taxes passed from previous page) ==========
            if (_thermalShowTaxDetails && widget.taxes != null && widget.taxes!.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: kBlack54, width: 1))),
                child: Column(
                  children: [
                    // Show only real taxes from widget.taxes (passed from previous page)
                    ...widget.taxes!.map((tax) => _buildTaxRow(
                      tax['name'] ?? 'Tax',
                      (tax['amount'] ?? 0.0).toDouble(),
                    )),
                  ],
                ),
              ),

            // ========== DISCOUNT ==========
            if (widget.discount > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Discount', style: tStyle(size: 9, color: kBlack54)),
                    Text('-${widget.discount.toStringAsFixed(2)}', style: tStyle(size: 9, weight: FontWeight.w600)),
                  ],
                ),
              ),
            // ========== DELIVERY CHARGE ==========
            if (widget.deliveryCharge > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Delivery Charge', style: tStyle(size: 9, color: kBlack54)),
                    Text('+${widget.deliveryCharge.toStringAsFixed(2)}', style: tStyle(size: 9, weight: FontWeight.w600)),
                  ],
                ),
              ),

            // ========== GRAND TOTAL ==========
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: kBlack87, width: 1.5))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total', style: tStyle(size: 12, weight: FontWeight.w900)),
                  Text('$currency ${widget.total.toStringAsFixed(2)}', style: tStyle(size: 12, weight: FontWeight.w900)),
                ],
              ),
            ),

            // ========== PAYMENT MODE ==========
            if (_showPaymentMode)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Payment:', style: tStyle(size: 9, color: kBlack54)),
                    Text(widget.paymentMode, style: tStyle(size: 9, weight: FontWeight.w700)),
                  ],
                ),
              ),

            // ========== YOU SAVED ==========
            if (_thermalShowYouSaved && widget.discount > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                decoration: BoxDecoration(color: kGrey200, borderRadius: BorderRadius.circular(6), border: Border.all(color: kBlack54)),
                child: Text('🎉 You Saved $currency${widget.discount.toStringAsFixed(2)}!', style: tStyle(size: 9, weight: FontWeight.w700)),
              ),
            ],

            // ========== TOTAL ITEMS/QTY ==========
            if (_thermalShowTotalItemQuantity) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Items: ${widget.items.length}', style: tStyle(size: 8, color: kBlack54)),
                  Text(' | ', style: tStyle(size: 8, color: kBlack54)),
                  Text('Qty: ${totalQty.toInt()}', style: tStyle(size: 8, color: kBlack54)),
                ],
              ),
            ],

            // ========== DELIVERY ADDRESS ==========
            if (widget.deliveryAddress != null && widget.deliveryAddress!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: kGrey200, borderRadius: BorderRadius.circular(6), border: Border.all(color: kGrey300)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Customer Notes:', style: tStyle(size: 8, weight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(widget.deliveryAddress!, style: tStyle(size: 8)),
                  ],
                ),
              ),
            ],

            // ========== FOOTER ==========
            const SizedBox(height: 12),
            Text(
              _thermalSaleInvoiceText.isNotEmpty ? _thermalSaleInvoiceText : 'Thank You',
              style: tStyle(size: 10, weight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaxRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, color: kBlack54)),
          const SizedBox(width: 16),
          SizedBox(
            width: 60,
            child: Text(
              amount.toStringAsFixed(2),
              style: const TextStyle(fontSize: 9),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }



  // Template Layouts
  Widget _buildClassicLayout(Map<String, Color> colors) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: colors['primary']!, width: 1.5), color: Colors.white, borderRadius: BorderRadius.circular(4)),
      child: const Center(child: Text('Classic Layout', style: TextStyle(fontSize: 14))),
    );
  }

  Widget _buildModernLayout(Map<String, Color> colors) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: colors['primary']!, width: 1.5), color: Colors.white, borderRadius: BorderRadius.circular(4)),
      child: const Center(child: Text('Modern Layout', style: TextStyle(fontSize: 14))),
    );
  }

  Widget _buildCompactLayout(Map<String, Color> colors) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: colors['primary']!, width: 1.5), color: Colors.white, borderRadius: BorderRadius.circular(4)),
      child: const Center(child: Text('Compact Layout', style: TextStyle(fontSize: 14))),
    );
  }

  Widget _buildDetailedLayout(Map<String, Color> colors) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: colors['primary']!, width: 1.5), color: Colors.white, borderRadius: BorderRadius.circular(4)),
      child: const Center(child: Text('Detailed Layout', style: TextStyle(fontSize: 14))),
    );
  }

  // Bottom Action Bar
  Widget _buildBottomActionBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: Row(
          children: [
            _buildBtn(Icons.print_rounded, "Print", () => _handlePrint(context), true),
            const SizedBox(width: 12),
            _buildBtn(Icons.share_rounded, "Share", () => _handleShare(context), true),
            const SizedBox(width: 12),
            _buildBtn(Icons.add_rounded, "New Sale", () {
              Navigator.pushAndRemoveUntil(
                context,
                CupertinoPageRoute(builder: (context) => NewSalePage(uid: widget.uid, userEmail: widget.userEmail)),
                    (route) => false,
              );
            }, false),
          ],
        ),
      ),
    );
  }

  Widget _buildBtn(IconData icon, String label, VoidCallback onTap, bool isSec) {
    return Expanded(
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: isSec ? kWhite : kPrimaryColor,
          foregroundColor: isSec ? kPrimaryColor : kWhite,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isSec ? const BorderSide(color: kPrimaryColor, width: 1.5) : BorderSide.none,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  // Print Handler
  Future<void> _handlePrint(BuildContext context) async {
    try {
      BluetoothAdapterState adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState == BluetoothAdapterState.off) {
        if (Platform.isAndroid) {
          try {
            await FlutterBluePlus.turnOn();
            await Future.delayed(const Duration(seconds: 1));
            adapterState = await FlutterBluePlus.adapterState.first;
          } catch (e) {
            debugPrint('Bluetooth turnOn error: $e');
          }
        }
      }

      if (adapterState != BluetoothAdapterState.on) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: kWhite,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text('Bluetooth Required', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: kBlack87)),
              content: const Text('Bluetooth is currently disabled. Please enable it in settings to connect with your printer.', style: TextStyle(color: kBlack54, fontWeight: FontWeight.w500)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w800, color: kPrimaryColor))),
              ],
            ),
          );
        }
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            color: _bwBg,
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: kPrimaryColor),
                  SizedBox(height: 16),
                  Text('PRINTING...', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: kPrimaryColor)),
                ],
              ),
            ),
          ),
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      final selectedPrinterId = prefs.getString('selected_printer_id');

      // Get number of copies from Firestore (backend)
      int numberOfCopies = 1;
      try {
        final storeDoc = await FirestoreService().getCurrentStoreDoc();
        if (storeDoc != null && storeDoc.exists) {
          final data = storeDoc.data() as Map<String, dynamic>?;
          numberOfCopies = data?['thermalNumberOfCopies'] ?? 1;

          // Freshly parse license for print (don't rely on stale state)
          final rawLicense = data?['licenseNumber']?.toString().trim() ?? '';
          if (rawLicense.isNotEmpty) {
            final parts = rawLicense.split(' ');
            if (parts.length > 1) {
              businessLicenseTypeName = parts[0];
              businessLicenseNumber = parts.sublist(1).join(' ');
            } else {
              businessLicenseTypeName = 'License';
              businessLicenseNumber = parts[0];
            }
          }
        }
      } catch (e) {
        debugPrint('Error loading thermal copies from Firestore: $e');
      }

      final printerWidth = prefs.getString('printer_width') ?? '58mm';
      // 80mm → Font A, 48 chars/line
      // 58mm → Font B (smaller), 42 chars/line — matches 80mm density
      final int lineWidth = printerWidth == '80mm' ? 48 : 42;
      final String dividerLine = '=' * lineWidth;
      final String thinDivider = '-' * lineWidth;

      if (selectedPrinterId == null) {
        Navigator.pop(context); // dismiss loading dialog
        if (context.mounted) {
          final result = await Navigator.push(
            context,
            CupertinoPageRoute(builder: (_) => PrinterSetupPage(onBack: () => Navigator.pop(context))),
          );
          // If user came back after setting up a printer, retry print
          if (result == true && context.mounted) {
            _handlePrint(context);
          }
        }
        return;
      }

      final devices = await FlutterBluePlus.bondedDevices;
      BluetoothDevice device;
      try {
        device = devices.firstWhere((d) => d.remoteId.toString() == selectedPrinterId);
      } catch (_) {
        // Printer saved but no longer bonded — go to setup
        Navigator.pop(context);
        if (context.mounted) {
          CommonWidgets.showSnackBar(context, "Printer not found. Please set up again.", bgColor: kOrange);
          await Navigator.push(
            context,
            CupertinoPageRoute(builder: (_) => PrinterSetupPage(onBack: () => Navigator.pop(context))),
          );
        }
        return;
      }


      if (device.isConnected == false) {
        await device.connect(timeout: const Duration(seconds: 10));
        await Future.delayed(const Duration(milliseconds: 500));
      }

      List<int> bytes = [];
      const esc = 0x1B;
      const gs = 0x1D;
      const lf = 0x0A;

      // Init Printer
      bytes.addAll([esc, 0x40]);
      // Font A for 80mm (large, clear), Font B for 58mm (smaller, more chars fit)
      bytes.addAll([esc, 0x4D, printerWidth == '80mm' ? 0x00 : 0x01]);
      // For 58mm: set character size to 1x1 (smallest) using GS ! command
      if (printerWidth != '80mm') {
        bytes.addAll([gs, 0x21, 0x00]); // GS ! 0x00 = 1x width, 1x height (minimum size)
      }

      // ── Helper: encode string safely for thermal printer ──
      List<int> enc(String s) => utf8.encode(_toThermalSafe(s));
      // Thermal-safe currency prefix (e.g. "Rs." for ₹)
      final tCur = _toThermalSafe(_currencySymbol).trim();

      // Print Logo if available
      if (_thermalShowLogo && businessLogoUrl != null && businessLogoUrl!.isNotEmpty) {
        try {
          // Download image and convert to bitmap for thermal printer
          final response = await HttpClient().getUrl(Uri.parse(businessLogoUrl!));
          final httpResponse = await response.close();
          final imageBytes = await consolidateHttpClientResponseBytes(httpResponse);

          // Decode image
          final codec = await ui.instantiateImageCodec(Uint8List.fromList(imageBytes));
          final frame = await codec.getNextFrame();
          final image = frame.image;

          // Resize to appropriate size for thermal printer (max 200px width)
          final targetWidth = printerWidth == '80mm' ? 200 : 160;
          final scale = targetWidth / image.width;
          final targetHeight = (image.height * scale).toInt();

          // Convert to bitmap bytes for ESC/POS
          final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
          if (byteData != null) {
            // Convert RGBA to monochrome bitmap
            final List<int> bitmapBytes = _convertToMonochromeBitmap(byteData.buffer.asUint8List(), image.width, image.height, targetWidth);

            // Center align for logo
            bytes.addAll([esc, 0x61, 0x01]);

            // Print bitmap using GS v 0 command
            final widthBytes = (targetWidth + 7) ~/ 8;
            bytes.addAll([gs, 0x76, 0x30, 0x00]); // GS v 0 - raster bit image
            bytes.addAll([widthBytes & 0xFF, (widthBytes >> 8) & 0xFF]); // xL, xH
            bytes.addAll([targetHeight & 0xFF, (targetHeight >> 8) & 0xFF]); // yL, yH
            bytes.addAll(bitmapBytes);

            bytes.add(lf);
          }
        } catch (e) {
          debugPrint('Error printing logo: $e');
          // Continue without logo if there's an error
        }
      }

      // Header
      bytes.addAll([esc, 0x61, 0x01]); // Center align
      // 80mm: double-height+width (0x30) | 58mm: just bold (0x08) — smaller, fits paper
      bytes.addAll([esc, 0x21, printerWidth == '80mm' ? 0x30 : 0x08]);
      bytes.addAll(enc(_truncateText(businessName, lineWidth ~/ (printerWidth == '80mm' ? 2 : 1))));
      bytes.add(lf);
      bytes.addAll([esc, 0x21, 0x00]); // Reset to normal

      if (_showLocation && businessLocation.isNotEmpty) {
        for (final line in _wrapText(businessLocation, lineWidth)) {
          bytes.addAll(enc(line));
          bytes.add(lf);
        }
      }
      if (_showPhone && businessPhone.isNotEmpty) {
        bytes.addAll(enc(_truncateText('PHONE: $businessPhone', lineWidth)));
        bytes.add(lf);
      }
      if (_showGST && businessGSTIN != null && businessGSTIN!.isNotEmpty) {
        bytes.addAll([esc, 0x21, 0x08]);
        bytes.addAll(enc(_truncateText('${businessTaxTypeName ?? 'Tax'}: $businessGSTIN', lineWidth)));
        bytes.addAll([esc, 0x21, 0x00]);
        bytes.add(lf);
      }
      if (_thermalShowLicense && businessLicenseNumber != null && businessLicenseNumber!.isNotEmpty) {
        bytes.addAll([esc, 0x21, 0x08]);
        bytes.addAll(enc(_truncateText('${businessLicenseTypeName ?? 'License'}: $businessLicenseNumber', lineWidth)));
        bytes.addAll([esc, 0x21, 0x00]);
        bytes.add(lf);
      }

      bytes.add(lf);

      // Bill No & Date
      bytes.addAll([esc, 0x61, 0x00]); // Left align
      final dateStr = DateFormat('dd-MMM-yyyy').format(widget.dateTime);
      final timeStr = DateFormat('hh:mm a').format(widget.dateTime);
      bytes.addAll(enc(_formatTwoColumns('Bill No: ${widget.invoiceNumber}', 'Date: $dateStr', lineWidth)));
      bytes.add(lf);
      bytes.addAll(enc(_formatTwoColumns('', 'Time: $timeStr', lineWidth)));
      bytes.add(lf);

      // Customer Info
      if (_thermalShowCustomerInfo && widget.customerName != null) {
        bytes.addAll(enc(thinDivider));
        bytes.add(lf);
        bytes.addAll([esc, 0x61, 0x00]);
        bytes.addAll([esc, 0x21, 0x08]);
        bytes.addAll(enc(_truncateText('Customer: ${widget.customerName!}', lineWidth)));
        bytes.addAll([esc, 0x21, 0x00]);
        bytes.add(lf);
        if (widget.customerPhone != null) {
          bytes.addAll(enc(_truncateText('Contact: ${widget.customerPhone}', lineWidth)));
          bytes.add(lf);
        }
      }

      // Items header
      bytes.addAll(enc(dividerLine));
      bytes.add(lf);
      bytes.addAll([esc, 0x21, 0x08]); // Bold
      bytes.addAll(enc(_formatTableRow('Item', 'Qty', 'Price', 'Amt', lineWidth)));
      bytes.addAll([esc, 0x21, 0x00]);
      bytes.add(lf);
      bytes.addAll(enc(thinDivider));
      bytes.add(lf);

      // Items
      int totalQty = 0;
      for (int i = 0; i < widget.items.length; i++) {
        final item = widget.items[i];
        final name = (item['name'] ?? 'Item') as String;
        final qty = item['quantity'] ?? 1;
        final price = (item['price'] ?? 0.0).toDouble();
        final taxAmt = (item['taxAmount'] ?? 0.0).toDouble();
        final taxType = item['taxType'] as String?;
        final baseTotal = price * (qty is num ? qty.toDouble() : 1.0);
        // Compute amount respecting tax type
        final double amount;
        if (taxType == 'Tax Included in Price' || taxType == 'Price includes Tax') {
          amount = baseTotal; // price already has tax
        } else if (taxType != null) {
          amount = baseTotal + taxAmt; // add tax for 'Add Tax at Billing' etc.
        } else {
          amount = (item['total'] ?? baseTotal).toDouble(); // fresh sale: total is already totalWithTax
        }

        totalQty += (qty is int ? qty : (qty as num).toInt());

        // No currency in table columns; no tax sub-line
        List<String> itemLines = _formatTableRowMultiLine(name, '$qty', price.toStringAsFixed(2), amount.toStringAsFixed(2), lineWidth);
        for (String line in itemLines) {
          bytes.addAll(enc(line));
          bytes.add(lf);
        }
        // Add spacing between items
        bytes.add(lf);
      }

      // Subtotal — align qty under the Qty column, amount under Amt column
      bytes.addAll(enc(dividerLine));
      bytes.add(lf);
      bytes.addAll([esc, 0x21, 0x08]);
      bytes.addAll(enc(_formatTableRow('Subtotal', '$totalQty', '', widget.subtotal.toStringAsFixed(2), lineWidth)));
      bytes.addAll([esc, 0x21, 0x00]);
      bytes.add(lf);

      // Tax breakdown
      if (_thermalShowTaxDetails && widget.taxes != null && widget.taxes!.isNotEmpty) {
        bytes.addAll(enc(thinDivider));
        bytes.add(lf);
        for (var tax in widget.taxes!) {
          final taxName = tax['name'] ?? 'Tax';
          final taxAmount = (tax['amount'] ?? 0.0).toDouble();
          bytes.addAll(enc(_formatTwoColumns(_toThermalSafe(taxName), taxAmount.toStringAsFixed(2), lineWidth)));
          bytes.add(lf);
        }
      }

      // Discount
      if (widget.discount > 0) {
        bytes.addAll(enc(_formatTwoColumns('Discount', '-${widget.discount.toStringAsFixed(2)}', lineWidth)));
        bytes.add(lf);
      }

      // Delivery Charge
      if (widget.deliveryCharge > 0) {
        bytes.addAll(enc(_formatTwoColumns('Delivery Charge', '+${widget.deliveryCharge.toStringAsFixed(2)}', lineWidth)));
        bytes.add(lf);
      }

      // Total
      bytes.addAll(enc(dividerLine));
      bytes.add(lf);
      // 80mm: bold + double-height (0x18) | 58mm: just bold (0x08)
      bytes.addAll([esc, 0x21, printerWidth == '80mm' ? 0x18 : 0x08]);
      bytes.addAll(enc(_formatTwoColumns('Total', '$tCur${widget.total.toStringAsFixed(2)}', lineWidth)));
      bytes.addAll([esc, 0x21, 0x00]);
      bytes.add(lf);
      bytes.addAll(enc(dividerLine));
      bytes.add(lf);

      // Payment Mode
      if (_showPaymentMode) {
        bytes.addAll(enc(_formatTwoColumns('Payment:', widget.paymentMode, lineWidth)));
        bytes.add(lf);
      }

      // You Saved
      if (_thermalShowYouSaved && widget.discount > 0) {
        bytes.addAll(enc(_truncateText('** You Saved $tCur${widget.discount.toStringAsFixed(2)}! **', lineWidth)));
        bytes.add(lf);
      }

      // Items/Qty count
      if (_thermalShowTotalItemQuantity) {
        bytes.addAll([esc, 0x61, 0x01]);
        bytes.addAll(enc('Items: ${widget.items.length} | Qty: $totalQty'));
        bytes.add(lf);
        bytes.addAll([esc, 0x61, 0x00]);
      }

      // Bill Notes (if provided)
      if (widget.customNote != null && widget.customNote!.isNotEmpty) {
        bytes.addAll([esc, 0x61, 0x00]); // Left align
        for (final line in _wrapText('Note: ${widget.customNote}', lineWidth)) {
          bytes.addAll(enc(line));
          bytes.add(lf);
        }
      }

      // Delivery Address (if provided)
      if (widget.deliveryAddress != null && widget.deliveryAddress!.isNotEmpty) {
        bytes.addAll([esc, 0x61, 0x00]); // Left align
        for (final line in _wrapText('Delivery: ${widget.deliveryAddress}', lineWidth)) {
          bytes.addAll(enc(line));
          bytes.add(lf);
        }
      }

      // Footer
      bytes.addAll([esc, 0x61, 0x01]); // Center
      bytes.add(lf);
      bytes.addAll([esc, 0x21, 0x08]);
      final footerStr = _thermalSaleInvoiceText.isNotEmpty ? _thermalSaleInvoiceText : 'Thank You';
      for (final line in _wrapText(footerStr, lineWidth)) {
        bytes.addAll(enc(line));
        bytes.add(lf);
      }
      bytes.addAll([esc, 0x21, 0x00]);
      // Watermark for free plan users
      if (!_isPaidPlan) {
        bytes.add(lf);
        bytes.addAll([esc, 0x21, 0x00]);
        const wmLine1 = 'Generated by StockSphere';
        const wmLine2 = 'www.stocksphere.com';
        bytes.addAll(enc(wmLine1.padLeft((lineWidth + wmLine1.length) ~/ 2)));
        bytes.add(lf);
        bytes.addAll(enc(wmLine2.padLeft((lineWidth + wmLine2.length) ~/ 2)));
        bytes.add(lf);
      }
      bytes.add(lf);
      bytes.add(lf);
      bytes.add(lf);
      bytes.addAll([gs, 0x56, 0x00]); // Cut

      final services = await device.discoverServices();
      BluetoothCharacteristic? writeChar;
      for (var s in services) {
        for (var c in s.characteristics) {
          if (c.properties.write) { writeChar = c; break; }
        }
      }
      if (writeChar != null) {
        for (int copy = 0; copy < numberOfCopies; copy++) {
          const chunk = 20;
          for (int i = 0; i < bytes.length; i += chunk) {
            final end = (i + chunk < bytes.length) ? i + chunk : bytes.length;
            await writeChar.write(bytes.sublist(i, end), withoutResponse: true);
            await Future.delayed(const Duration(milliseconds: 20));
          }
          if (copy < numberOfCopies - 1) {
            await Future.delayed(const Duration(milliseconds: 500));
          }
        }
      }
      Navigator.pop(context);
      CommonWidgets.showSnackBar(context, numberOfCopies > 1 ? '$numberOfCopies copies printed successfully' : 'Receipt printed successfully', bgColor: kGoogleGreen);
    } catch (e) {
      Navigator.pop(context);
      CommonWidgets.showSnackBar(context, 'Printing failed: $e', bgColor: kErrorColor);
    }
  }

  String _truncateText(String text, int maxWidth) {
    if (text.length <= maxWidth) return text;
    return '${text.substring(0, maxWidth - 1)}.';
  }

  /// Prints left text left-aligned and right text right-aligned on the same line.
  /// Always right-aligns [right]; [left] is truncated if needed to make room.
  String _formatTwoColumns(String left, String right, int lineWidth) {
    // Clamp right to lineWidth
    final safeRight = right.length > lineWidth ? right.substring(0, lineWidth) : right;
    final availLeft = lineWidth - safeRight.length - 1; // at least 1 space separator

    if (availLeft <= 0) {
      // Right side alone fills the line — just print right flush-right
      return safeRight.padLeft(lineWidth);
    }

    final safeLeft = left.length > availLeft
        ? '${left.substring(0, availLeft - 1)}.'
        : left.padRight(availLeft);

    final spaces = lineWidth - safeLeft.length - safeRight.length;
    return '$safeLeft${' ' * spaces}$safeRight';
  }

  /// Convert a string to thermal-printer-safe ASCII.
  /// Replaces Unicode currency symbols and other multi-byte chars with
  /// their ASCII fallbacks so ESC/POS printers render them correctly.
  String _toThermalSafe(String text) {
    return text
        .replaceAll('₹', 'Rs.')  // Indian Rupee
        .replaceAll('€', 'EUR')  // Euro
        .replaceAll('£', 'GBP')  // Pound
        .replaceAll('¥', 'JPY')  // Yen/Yuan
        .replaceAll('₩', 'KRW')  // Korean Won
        .replaceAll('₪', 'ILS')  // Shekel
        .replaceAll('₺', 'TRY')  // Turkish Lira
        .replaceAll('₴', 'UAH')  // Hryvnia
        .replaceAll('₸', 'KZT')  // Tenge
        .replaceAll('₮', 'MNT')  // Tugrik
        .replaceAll('₭', 'LAK')  // Kip
        .replaceAll('₱', 'PHP')  // Philippine Peso
        .replaceAll('₦', 'NGN')  // Naira
        .replaceAll('₡', 'CRC')  // Colon
        .replaceAll('₲', 'PYG')  // Guarani
        .replaceAll('₼', 'AZN')  // Manat
        .replaceAll('₾', 'GEL')  // Lari
        .replaceAll('₽', 'RUB')  // Ruble
        .replaceAll('฿', 'THB')  // Baht
        .replaceAll('﷼', 'SAR')  // Riyal
        .replaceAll('₨', 'Rs.')  // Rupee sign
        .replaceAll('৳', 'BDT')  // Taka
        .replaceAll('₫', 'VND')  // Dong
        .replaceAll('₢', 'Cr.')  // Cruzeiro
        .replaceAll('₵', 'GHS')  // Cedi
        .replaceAll('🎉', '')    // Emoji — not printable
        .replaceAll('✓', 'OK')
    // Strip any remaining non-ASCII chars (codepoint > 127)
        .replaceAll(RegExp(r'[^\x00-\x7F]'), '?');
  }

  // ── Column-width helpers (shared by header + item rows) ────────────────────
  // 58mm paper → lineWidth = 42 chars total (Font B)
  //   item=22  qty=4  price=8  amt=8   (22+4+8+8 = 42)
  // 80mm paper → lineWidth = 48 chars total (Font A)
  //   item=24  qty=4  price=10  amt=10  (24+4+10+10 = 48)
  int _qtyW(int lw)   => 4;
  int _priceW(int lw) => lw <= 42 ? 8 : 10;
  int _amtW(int lw)   => lw <= 42 ? 8 : 10;
  int _itemW(int lw)  => lw - _qtyW(lw) - _priceW(lw) - _amtW(lw);

  String _formatTableRow(String item, String qty, String price, String amt, int lineWidth) {
    final itemW  = _itemW(lineWidth);
    final qtyW   = _qtyW(lineWidth);
    final priceW = _priceW(lineWidth);
    final amtW   = _amtW(lineWidth);

    String itemStr = item.length > itemW ? '${item.substring(0, itemW - 1)}.' : item.padRight(itemW);

    return '$itemStr'
        '${qty.padLeft(qtyW)}'
        '${price.padLeft(priceW)}'
        '${amt.padLeft(amtW)}';
  }

  /// Format table row with full item name support (wraps to multiple lines).
  /// Layout:
  ///   • If name fits on one line  → single row: [NAME_____][QTY][PRICE][AMT]
  ///   • If name is too long       → name wraps across rows inside the item column
  ///                                  first line  : [name chunk 1               ]
  ///                                  middle lines: [name chunk n               ]
  ///                                  last values : [                 ][QTY][PRICE][AMT]
  List<String> _formatTableRowMultiLine(String item, String qty, String price, String amt, int lineWidth) {
    final itemW  = _itemW(lineWidth);
    final qtyW   = _qtyW(lineWidth);
    final priceW = _priceW(lineWidth);
    final amtW   = _amtW(lineWidth);

    List<String> lines = [];

    if (item.length <= itemW) {
      // ── Single line ──────────────────────────────────────────────────────────
      lines.add(
        '${item.padRight(itemW)}'
            '${qty.padLeft(qtyW)}'
            '${price.padLeft(priceW)}'
            '${amt.padLeft(amtW)}',
      );
    } else {
      // ── Multi-line item name ─────────────────────────────────────────────────
      final itemChunks = _wrapText(item, itemW);

      // First line: first name chunk (padded to fill line)
      lines.add('${itemChunks[0].padRight(lineWidth)}');

      // Continuation name lines
      for (int i = 1; i < itemChunks.length; i++) {
        lines.add('${itemChunks[i].padRight(lineWidth)}');
      }

      // Values line: blank item col, then numeric columns right-aligned
      lines.add(
        '${' ' * itemW}'
            '${qty.padLeft(qtyW)}'
            '${price.padLeft(priceW)}'
            '${amt.padLeft(amtW)}',
      );
    }

    return lines;
  }

  /// Wrap text into lines of maxWidth characters, breaking at word boundaries
  List<String> _wrapText(String text, int maxWidth) {
    if (maxWidth <= 0) return [text];
    if (text.length <= maxWidth) return [text];

    List<String> lines = [];
    List<String> words = text.split(' ');
    String currentLine = '';

    for (String word in words) {
      if (currentLine.isEmpty) {
        if (word.length > maxWidth) {
          // Force-break a very long word
          int start = 0;
          while (start < word.length) {
            int end = (start + maxWidth < word.length) ? start + maxWidth : word.length;
            lines.add(word.substring(start, end));
            start = end;
          }
        } else {
          currentLine = word;
        }
      } else if (currentLine.length + 1 + word.length <= maxWidth) {
        currentLine += ' $word';
      } else {
        lines.add(currentLine);
        if (word.length > maxWidth) {
          int start = 0;
          while (start < word.length) {
            int end = (start + maxWidth < word.length) ? start + maxWidth : word.length;
            lines.add(word.substring(start, end));
            start = end;
          }
          currentLine = '';
        } else {
          currentLine = word;
        }
      }
    }

    if (currentLine.isNotEmpty) {
      lines.add(currentLine);
    }

    return lines;
  }

  /// Convert RGBA image bytes to monochrome bitmap for thermal printer
  List<int> _convertToMonochromeBitmap(Uint8List rgba, int width, int height, int targetWidth) {
    final scale = targetWidth / width;
    final targetHeight = (height * scale).toInt();
    final widthBytes = (targetWidth + 7) ~/ 8;
    final List<int> bitmap = List.filled(widthBytes * targetHeight, 0);

    for (int y = 0; y < targetHeight; y++) {
      final srcY = (y / scale).floor();
      for (int x = 0; x < targetWidth; x++) {
        final srcX = (x / scale).floor();
        final srcIndex = (srcY * width + srcX) * 4;

        if (srcIndex + 2 < rgba.length) {
          final r = rgba[srcIndex];
          final g = rgba[srcIndex + 1];
          final b = rgba[srcIndex + 2];
          // Convert to grayscale and threshold
          final gray = (0.299 * r + 0.587 * g + 0.114 * b).round();
          if (gray < 128) {
            // Set bit for black pixel
            final byteIndex = y * widthBytes + (x ~/ 8);
            final bitIndex = 7 - (x % 8);
            bitmap[byteIndex] |= (1 << bitIndex);
          }
        }
      }
    }

    return bitmap;
  }

  // Share Handler
  Future<void> _handleShare(BuildContext context) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: kPrimaryColor),
                  SizedBox(height: 16),
                  Text('Generating PDF...', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      );

      final pdf = await _generatePdf();
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/invoice_${widget.invoiceNumber}.pdf');
      await file.writeAsBytes(await pdf.save());

      Navigator.pop(context);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Invoice #${widget.invoiceNumber}',
      );
    } catch (e) {
      Navigator.pop(context);
      CommonWidgets.showSnackBar(context, 'Error sharing: $e', bgColor: kErrorColor);
    }
  }

  Future<pw.Document> _generatePdf() async {
    final fontData = await rootBundle.load("fonts/NotoSans-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);
    final fontBoldData = await rootBundle.load("fonts/NotoSans-Bold.ttf");
    final ttfBold = pw.Font.ttf(fontBoldData);

    final pdf = pw.Document();
    final a4Colors = _getA4ThemeColors();
    final currency = _currencySymbol;
    final dateStr = DateFormat('dd/MM/yyyy').format(widget.dateTime);
    final timeStr = DateFormat('hh:mm a').format(widget.dateTime);

    // Try to load logo image for PDF
    pw.ImageProvider? logoImage;
    if (_a4ShowLogo && businessLogoUrl != null && businessLogoUrl!.isNotEmpty) {
      try {
        final response = await HttpClient().getUrl(Uri.parse(businessLogoUrl!));
        final httpResponse = await response.close();
        final imageBytes = await consolidateHttpClientResponseBytes(httpResponse);
        logoImage = pw.MemoryImage(Uint8List.fromList(imageBytes));
      } catch (e) {
        debugPrint('Error loading logo for PDF: $e');
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),

        // ── HEADER — first page only ─────────────────────────────────────
        header: (pw.Context context) {
          if (context.pageNumber > 1) return pw.SizedBox.shrink();
          final themeColor = PdfColor.fromInt(a4Colors['primary']!.toARGB32());
          return pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 24),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              border: pw.Border(
                top: pw.BorderSide(color: themeColor, width: 5),
                bottom: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
              ),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Logo
                if (_a4ShowLogo && logoImage != null)
                  pw.Container(
                    width: 52, height: 52,
                    margin: const pw.EdgeInsets.only(right: 16),
                    child: pw.Image(logoImage, fit: pw.BoxFit.cover),
                  )
                else if (_a4ShowLogo)
                  pw.Container(
                    width: 52, height: 52,
                    margin: const pw.EdgeInsets.only(right: 16),
                    decoration: pw.BoxDecoration(
                      color: PdfColor(themeColor.red, themeColor.green, themeColor.blue, 0.08),
                      border: pw.Border.all(color: PdfColor(themeColor.red, themeColor.green, themeColor.blue, 0.3)),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        businessName.isNotEmpty ? businessName[0].toUpperCase() : 'B',
                        style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: themeColor),
                      ),
                    ),
                  ),
                // Business Info
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(businessName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                      if (_showLocation && businessLocation.isNotEmpty) ...[
                        pw.SizedBox(height: 3),
                        pw.Text(businessLocation, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      ],
                      if (_showPhone && businessPhone.isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        pw.Text('Tel: $businessPhone', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      ],
                      if (_showEmail && businessEmail != null && businessEmail!.isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        pw.Text('Email: $businessEmail', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      ],
                      if (_showGST && businessGSTIN != null) ...[
                        pw.SizedBox(height: 2),
                        pw.Text('${businessTaxTypeName ?? 'GSTIN'}: $businessGSTIN', style: pw.TextStyle(fontSize: 10, color: PdfColors.black, fontWeight: pw.FontWeight.bold)),
                      ],
                      if (_a4ShowLicense && businessLicenseNumber != null && businessLicenseNumber!.isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        pw.Text('${businessLicenseTypeName ?? 'License'}: $businessLicenseNumber', style: pw.TextStyle(fontSize: 10, color: PdfColors.black, fontWeight: pw.FontWeight.bold)),
                      ],
                    ],
                  ),
                ),
                // Invoice badge — small coloured tag only
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: themeColor,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        widget.isPaymentReceipt ? 'Payment Receipt' : (widget.isQuotation ? 'Quotation' : 'Tax Invoice'),
                        style: pw.TextStyle(color: PdfColors.white, fontSize: 11, fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text('#${widget.invoiceNumber}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                    pw.SizedBox(height: 2),
                    pw.Text(dateStr, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    pw.Text(timeStr, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  ],
                ),
              ],
            ),
          );
        },

        // ── FOOTER — last page only ───────────────────────────────────────
        footer: (pw.Context context) {
          if (context.pageNumber < context.pagesCount) return pw.SizedBox.shrink();
          final themeColor = PdfColor.fromInt(a4Colors['primary']!.toARGB32());
          return pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFFF7F8FA),
              border: pw.Border(
                top: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                left: pw.BorderSide(color: themeColor, width: 5),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    _a4SaleInvoiceText.isNotEmpty ? _a4SaleInvoiceText : 'Thank you for your business!',
                    style: pw.TextStyle(font: ttfBold, fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.Row(
                  children: [
                    if (!_isPaidPlan)
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('Generated by StockSphere', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                          pw.Text('www.maxmybill.com', style: pw.TextStyle(font: ttfBold, fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                        ],
                      ),
                    pw.SizedBox(width: 8),
                    pw.Text(
                      'Page ${context.pageNumber} of ${context.pagesCount}',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ],
            ),
          );
        },

        // ── BODY — flows across pages automatically ───────────────────────
        build: (pw.Context context) {
          final themeColor = PdfColor.fromInt(a4Colors['primary']!.toARGB32());
          return [
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(40, 20, 40, 0),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Customer block
                  if (widget.customerName != null) ...[
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.all(14),
                      decoration: pw.BoxDecoration(
                        color: const PdfColor.fromInt(0xFFF7F8FA),
                        border: pw.Border.all(color: PdfColors.grey300),
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Customer', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: themeColor, letterSpacing: 1.2)),
                          pw.SizedBox(height: 4),
                          pw.Text(widget.customerName!, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                          if (widget.customerPhone != null)
                            pw.Text('Contact: ${widget.customerPhone!}', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                          if (widget.customerGSTIN != null && widget.customerGSTIN!.isNotEmpty)
                            pw.Text('GSTIN: ${widget.customerGSTIN}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 20),
                  ],

                  // ── ITEMS TABLE ──
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                    columnWidths: _a4ShowTaxColumn ? {
                      0: const pw.FlexColumnWidth(4.5),
                      1: const pw.FixedColumnWidth(36),
                      2: const pw.FlexColumnWidth(1.6),
                      3: const pw.FlexColumnWidth(1.4),
                      4: const pw.FlexColumnWidth(1.6),
                    } : {
                      0: const pw.FlexColumnWidth(5),
                      1: const pw.FixedColumnWidth(36),
                      2: const pw.FlexColumnWidth(1.8),
                      3: const pw.FlexColumnWidth(1.8),
                    },
                    children: [
                      // Header row
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: themeColor),
                        children: [
                          _pdfCell('Item / Description', ttfBold, isHeader: true),
                          _pdfCell('Qty', ttfBold, isHeader: true, align: pw.TextAlign.center),
                          _pdfCell('Rate', ttfBold, isHeader: true, align: pw.TextAlign.right),
                          if (_a4ShowTaxColumn)
                            _pdfCell('Tax', ttfBold, isHeader: true, align: pw.TextAlign.right),
                          _pdfCell('Amount', ttfBold, isHeader: true, align: pw.TextAlign.right),
                        ],
                      ),
                      // ALL item rows — MultiPage handles page breaks automatically
                      ...widget.items.asMap().entries.map((e) {
                        final idx = e.key;
                        final item = e.value;
                        final name = (item['name'] ?? 'Item') as String;
                        final qty = item['quantity'] ?? 1;
                        final price = (item['price'] ?? 0.0).toDouble();
                        final taxPerc = (item['taxPercentage'] ?? 0).toDouble();
                        final taxName = (item['taxName'] ?? '') as String;
                        final taxAmt = (item['taxAmount'] ?? 0.0).toDouble();
                        final taxType = item['taxType'] as String?;
                        final baseTotal = price * (qty is num ? qty.toDouble() : 1.0);
                        // Compute amount respecting tax type
                        final double amount;
                        if (taxType == 'Tax Included in Price' || taxType == 'Price includes Tax') {
                          amount = baseTotal; // price already has tax
                        } else if (taxType != null) {
                          amount = baseTotal + taxAmt; // add tax for 'Add Tax at Billing' etc.
                        } else {
                          amount = (item['total'] ?? baseTotal).toDouble(); // fresh sale: total is already totalWithTax
                        }
                        final isEven = idx.isEven;
                        final rowBg = isEven ? PdfColors.white : const PdfColor.fromInt(0xFFF9FAFB);
                        return pw.TableRow(
                          decoration: pw.BoxDecoration(color: rowBg),
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(name, style: pw.TextStyle(font: ttfBold, fontSize: 10)),
                                  if (taxName.isNotEmpty && taxPerc > 0)
                                    pw.Text('$taxName ${taxPerc.toStringAsFixed(0)}%', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                                ],
                              ),
                            ),
                            _pdfCell(
                              qty is double && qty % 1 != 0 ? qty.toStringAsFixed(2) : '$qty',
                              ttf, align: pw.TextAlign.center, isEven: isEven,
                            ),
                            _pdfCell(price.toStringAsFixed(2), ttf, align: pw.TextAlign.right, isEven: isEven),
                            if (_a4ShowTaxColumn)
                              pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                                child: taxPerc > 0
                                    ? pw.Column(
                                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                                        children: [
                                          pw.Text(taxAmt.toStringAsFixed(2), style: pw.TextStyle(font: ttf, fontSize: 10)),
                                          pw.Text('(${taxPerc.toStringAsFixed(0)}%)', style: pw.TextStyle(font: ttf, fontSize: 7, color: PdfColors.grey600)),
                                        ],
                                      )
                                    : pw.Text('-', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.grey600)),
                              ),
                            _pdfCell(amount.toStringAsFixed(2), ttfBold, align: pw.TextAlign.right, isEven: isEven, bold: true, color: themeColor),
                          ],
                        );
                      }),
                    ],
                  ),
                  pw.SizedBox(height: 16),

                  // Totals box
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Container(
                      width: 220,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Column(
                        children: [
                          _invoicePdfTotalRow('Subtotal', '$currency${widget.subtotal.toStringAsFixed(2)}', ttf, ttfBold),
                          if (widget.discount > 0)
                            _invoicePdfTotalRow('Discount', '-$currency${widget.discount.toStringAsFixed(2)}', ttf, ttfBold, isDiscount: true),
                          if (widget.taxes != null && widget.taxes!.isNotEmpty)
                            ...widget.taxes!.map((tax) => _invoicePdfTotalRow(
                              tax['name'] ?? 'Tax',
                              '$currency${(tax['amount'] ?? 0.0).toStringAsFixed(2)}',
                              ttf, ttfBold,
                            )),
                          if (widget.deliveryCharge > 0)
                            _invoicePdfTotalRow('Delivery', '+$currency${widget.deliveryCharge.toStringAsFixed(2)}', ttf, ttfBold),
                          pw.Container(height: 1, color: PdfColors.grey300),
                          pw.Container(
                            color: PdfColors.white,
                            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text('Total', style: pw.TextStyle(font: ttfBold, fontSize: 13, fontWeight: pw.FontWeight.bold, color: themeColor)),
                                pw.Text('$currency${widget.total.toStringAsFixed(2)}', style: pw.TextStyle(font: ttfBold, fontSize: 14, fontWeight: pw.FontWeight.bold, color: themeColor)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bill Notes
                  if (widget.customNote != null && widget.customNote!.isNotEmpty) ...[
                    pw.SizedBox(height: 14),
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: const PdfColor.fromInt(0xFFF7F8FA),
                        border: pw.Border.all(color: PdfColors.grey300),
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Note:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                          pw.SizedBox(height: 4),
                          pw.Text(widget.customNote!, style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                  ],

                  // Delivery Address
                  if (widget.deliveryAddress != null && widget.deliveryAddress!.isNotEmpty) ...[
                    pw.SizedBox(height: 10),
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: const PdfColor.fromInt(0xFFF7F8FA),
                        border: pw.Border.all(color: PdfColors.grey300),
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Delivery Address:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                          pw.SizedBox(height: 4),
                          pw.Text(widget.deliveryAddress!, style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                  ],

                  pw.SizedBox(height: 16),
                ],
              ),
            ),
          ];
        },
      ),
    );
    return pdf;
  }

  pw.Widget _invoicePdfTotalRow(String label, String value, pw.Font ttf, pw.Font ttfBold, {bool isDiscount = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: ttf, fontSize: 10, color: isDiscount ? PdfColors.green700 : PdfColors.grey800)),
          pw.Text(value, style: pw.TextStyle(font: ttfBold, fontSize: 10, color: isDiscount ? PdfColors.green700 : PdfColors.black)),
        ],
      ),
    );
  }

  /// Reusable PDF table cell
  pw.Widget _pdfCell(
      String text,
      pw.Font font, {
        bool isHeader = false,
        bool bold = false,
        bool isEven = true,
        pw.TextAlign align = pw.TextAlign.left,
        PdfColor? color,
      }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          font: font,
          fontSize: isHeader ? 9 : 10,
          fontWeight: (isHeader || bold) ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader
              ? PdfColors.white
              : (color ?? PdfColors.black),
        ),
      ),
    );
  }
}

// Confetti particle class
class _Confetti {
  double x;
  double y;
  Color color;
  double size;
  double speed;
  double rotation;

  _Confetti({
    required this.x,
    required this.y,
    required this.color,
    required this.size,
    required this.speed,
    required this.rotation,
  });
}

// Confetti painter
class _ConfettiPainter extends CustomPainter {
  final List<_Confetti> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      final paint = Paint()..color = particle.color.withAlpha((255 * (1 - progress)).toInt());
      final x = particle.x * size.width;
      final y = (particle.y + progress * particle.speed * 3) * size.height;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(particle.rotation + progress * 10);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: particle.size, height: particle.size * 0.6), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
