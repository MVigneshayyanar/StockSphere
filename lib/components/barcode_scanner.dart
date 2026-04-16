import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for HapticFeedback and Keyboard events
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/utils/responsive_helper.dart';
import 'package:maxbillup/Colors.dart'; // Using your theme colors
import 'dart:math' as math;

class BarcodeScannerPage extends StatefulWidget {
  final Function(String) onBarcodeScanned;

  const BarcodeScannerPage({
    super.key,
    required this.onBarcodeScanned,
  });

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> with SingleTickerProviderStateMixin {
  // Controller for phone camera scanner
  late MobileScannerController cameraController;

  bool _isScanning = true;
  String _lastScannedCode = '';
  bool _isFlashOn = false;

  // External Scanner logic
  bool _isExternalScannerConnected = false;
  final StringBuffer _externalScannerBuffer = StringBuffer();
  final FocusNode _externalScannerFocusNode = FocusNode();

  // Animation for the scanning line
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // Initialize controller for camera scanning
    cameraController = MobileScannerController(
      formats: [BarcodeFormat.all],
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    // Setup scanning line animation
    _animationController = AnimationController(
      duration: const Duration(seconds: 1, milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Listen for hardware scanner/keyboard events
    HardwareKeyboard.instance.addHandler(_handleHardwareKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    cameraController.dispose();
    _animationController.dispose();
    _externalScannerFocusNode.dispose();
    super.dispose();
  }

  // Handles input from the external hardware scanner (HID Device)
  bool _handleHardwareKey(KeyEvent event) {
    // If we receive any hardware key event, we know a device is active
    if (!_isExternalScannerConnected) {
      setState(() {
        _isExternalScannerConnected = true;
      });
    }

    if (event is KeyDownEvent) {
      final String? character = event.character;

      // Hardware scannetypically act as keyboards and send an 'Enter' key at the end
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (_externalScannerBuffer.isNotEmpty) {
          _handleBarcodeScan(_externalScannerBuffer.toString());
          _externalScannerBuffer.clear();
        }
      } else if (character != null) {
        // Buffer the charactesent by the scanner
        _externalScannerBuffer.write(character);
      }
    }
    return false; // Allow event to propagate if necessary
  }

  void _handleBarcodeScan(String barcode) {
    if (!_isScanning || barcode == _lastScannedCode) return;

    // Vibrate when product is added (from either camera or hardware scanner)
    HapticFeedback.vibrate();

    setState(() {
      _lastScannedCode = barcode;
    });

    widget.onBarcodeScanned(barcode);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${context.tr('product_added_scanned')}: $barcode',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: R.sp(context, 13)),
              ),
            ),
          ],
        ),
        backgroundColor: kPrimaryColor,
        duration: const Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: R.radius(context, 12)),
        margin: EdgeInsets.only(bottom: R.sp(context, 110), left: R.sp(context, 24), right: R.sp(context, 24)),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _lastScannedCode = '';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double appBarHeight = AppBar().preferredSize.height;
    final double availableHeight = screenHeight - statusBarHeight - appBarHeight;

    final scanAreaSize = screenWidth * 0.72;
    final laserWidth = math.max(0.0, scanAreaSize - 40);

    final Rect scanWindow = Rect.fromCenter(
      center: Offset(screenWidth / 2, availableHeight / 2 + statusBarHeight + appBarHeight),
      width: scanAreaSize,
      height: scanAreaSize,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        title: Text(
            context.tr('scanbarcode'),
            style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: R.sp(context, 18))
        ),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isFlashOn ? Icons.flashlight_on : Icons.flashlight_off,
              color: Colors.white,
              size: 22,
            ),
            onPressed: () {
              cameraController.toggleTorch();
              setState(() {
                _isFlashOn = !_isFlashOn;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch_outlined, color: Colors.white, size: 22),
            onPressed: () => cameraController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Camera View
          MobileScanner(
            controller: cameraController,
            scanWindow: scanWindow,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _handleBarcodeScan(barcode.rawValue!);
                  break;
                }
              }
            },
          ),

          // 2. Overlay
          CustomPaint(
            painter: ScannerOverlay(
              scanAreaSize: scanAreaSize,
            ),
            child: const SizedBox.expand(),
          ),

          // 3. Animated "Laser"
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              final double scanAreaTop = (availableHeight - scanAreaSize) / 2;
              final double laserTop = scanAreaTop + (scanAreaSize * _animation.value);

              return Positioned(
                top: laserTop,
                left: (screenWidth - laserWidth) / 2,
                child: Container(
                  width: laserWidth,
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.redAccent.withOpacity(0.1),
                        Colors.redAccent,
                        Colors.redAccent.withOpacity(0.1),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.redAccent.withOpacity(0.6),
                        blurRadius: 12,
                        spreadRadius: 1,
                      )
                    ],
                  ),
                ),
              );
            },
          ),

          // 4. Scanner Connection Status Indicator
          Positioned(
            top: R.sp(context, 20),
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: EdgeInsets.symmetric(horizontal: R.sp(context, 16), vertical: R.sp(context, 8)),
                decoration: BoxDecoration(
                  color: _isExternalScannerConnected ? Colors.green.withOpacity(0.9) : Colors.orange.withOpacity(0.9),
                  borderRadius: R.radius(context, 20),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isExternalScannerConnected ? Icons.usb : Icons.usb_off,
                      color: Colors.white,
                      size: R.sp(context, 18),
                    ),
                    SizedBox(width: R.sp(context, 8)),
                    Text(
                      _isExternalScannerConnected
                          ? context.tr('External Scanner Ready')
                          : context.tr('Connect External Scanner'),
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: R.sp(context, 12)),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 5. Instructions HUD
          Positioned(
            bottom: screenHeight * 0.08,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: EdgeInsets.symmetric(horizontal: R.sp(context, 30)),
                  padding: EdgeInsets.symmetric(horizontal: R.sp(context, 20), vertical: R.sp(context, 16)),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: R.radius(context, 20),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        context.tr('scan_multiple_products'),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: R.sp(context, 14),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: R.sp(context, 6)),
                      Text(
                        "You can also connect the external scanner and scan through it",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: R.sp(context, 11),
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: R.sp(context, 12)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.barcode_reader, color: Colors.white54, size: R.sp(context, 16)),
                          SizedBox(width: R.sp(context, 12)),
                          Icon(Icons.qr_code_2, color: Colors.white54, size: R.sp(context, 16)),
                          SizedBox(width: R.sp(context, 12)),
                          Icon(Icons.keyboard, color: Colors.white54, size: R.sp(context, 16)),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ScannerOverlay extends CustomPainter {
  final double scanAreaSize;

  ScannerOverlay({required this.scanAreaSize});

  @override
  void paint(Canvas canvas, Size size) {
    final double scanAreaLeft = (size.width - scanAreaSize) / 2;
    final double scanAreaTop = (size.height - scanAreaSize) / 2;
    final Rect scanArea = Rect.fromLTWH(scanAreaLeft, scanAreaTop, scanAreaSize, scanAreaSize);

    final Paint backgroundPaint = Paint()
      ..color = Colors.black.withOpacity(0.65)
      ..style = PaintingStyle.fill;

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()
          ..addRRect(RRect.fromRectAndRadius(scanArea, const Radius.circular(24)))
          ..close(),
      ),
      backgroundPaint,
    );

    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const double cornerLength = 36;
    const double offset = 2;

    canvas.drawLine(Offset(scanAreaLeft - offset, scanAreaTop + cornerLength), Offset(scanAreaLeft - offset, scanAreaTop - offset), borderPaint);
    canvas.drawLine(Offset(scanAreaLeft - offset, scanAreaTop - offset), Offset(scanAreaLeft + cornerLength, scanAreaTop - offset), borderPaint);

    canvas.drawLine(Offset(scanAreaLeft + scanAreaSize + offset, scanAreaTop + cornerLength), Offset(scanAreaLeft + scanAreaSize + offset, scanAreaTop - offset), borderPaint);
    canvas.drawLine(Offset(scanAreaLeft + scanAreaSize + offset, scanAreaTop - offset), Offset(scanAreaLeft + scanAreaSize - cornerLength, scanAreaTop - offset), borderPaint);

    canvas.drawLine(Offset(scanAreaLeft - offset, scanAreaTop + scanAreaSize - cornerLength), Offset(scanAreaLeft - offset, scanAreaTop + scanAreaSize + offset), borderPaint);
    canvas.drawLine(Offset(scanAreaLeft - offset, scanAreaTop + scanAreaSize + offset), Offset(scanAreaLeft + cornerLength, scanAreaTop + scanAreaSize + offset), borderPaint);

    canvas.drawLine(Offset(scanAreaLeft + scanAreaSize + offset, scanAreaTop + scanAreaSize - cornerLength), Offset(scanAreaLeft + scanAreaSize + offset, scanAreaTop + scanAreaSize + offset), borderPaint);
    canvas.drawLine(Offset(scanAreaLeft + scanAreaSize + offset, scanAreaTop + scanAreaSize + offset), Offset(scanAreaLeft + scanAreaSize - cornerLength, scanAreaTop + scanAreaSize + offset), borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}