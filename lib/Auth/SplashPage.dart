import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maxbillup/Colors.dart';
import 'package:provider/provider.dart';
import 'LoginPage.dart';
import 'BusinessDetailsPage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/Sales/NewSale.dart';
import 'package:maxbillup/Admin/Home.dart';
import 'package:maxbillup/utils/plan_provider.dart';
import 'package:maxbillup/services/in_app_update_service.dart';
import 'package:maxbillup/services/single_session_service.dart';

// Mobile-only imports - these will be tree-shaken on web
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  StreamSubscription<ForceSignOutReason>? _forceLogoutSub;

  @override
  void initState() {
    super.initState();
    debugPrint('Splash screen started at: ${DateTime.now()}');

    // Listen for forced logout events and redirect to login with a message.
    _forceLogoutSub = ForceSignOutBus.instance.stream.listen((reason) {
      if (!mounted) return;
      final message = reason == ForceSignOutReason.loggedInOnAnotherDevice
          ? 'You were logged out because this account was used to sign in on another device.'
          : 'You have been logged out.';

      // Ensure we land on login.
      Navigator.of(context).pushAndRemoveUntil(
        CupertinoPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );

      // Show confirmation message after navigation.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
    });

    // Check for in-app updates (Android only, skip on web)
    if (!kIsWeb) {
      InAppUpdateService.checkForUpdate();
    }

    // Navigate after 2 seconds (reduced from 5 for better UX on web)
    Timer(Duration(seconds: kIsWeb ? 2 : 5), () {
      debugPrint('Splash screen ended at: ${DateTime.now()}');
      if (!mounted) return;
      _navigateToNextScreen();
    });
  }

  Future<void> _navigateToNextScreen() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // Start single-session enforcement for already logged in users.
      // IMPORTANT: do NOT overwrite active session on splash; only listen.
      // Otherwise opening the app would kick out the current active device.
      await SingleSessionService.instance.startSessionListener(uid: user.uid);

      // Check if the logged-in user is admin
      final userEmail = user.email?.toLowerCase() ?? '';
      if (userEmail == 'maxmybillapp@gmail.com') {
        // Initialize PlanProvider in background (non-blocking)
        final planProvider = Provider.of<PlanProvider>(context, listen: false);
        planProvider.initialize(); // Don't await - let it run in background

        if (!mounted) return;

        // Navigate to Admin Home page
        Navigator.of(context).pushReplacement(
          CupertinoPageRoute(
            builder: (_) => HomePage(
              uid: user.uid,
              userEmail: user.email,
            ),
          ),
        );
        return;
      }

      // Check if user has completed business registration
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (!mounted) return;

        if (!userDoc.exists) {
          // User started registration but didn't complete - redirect to BusinessDetailsPage
          Navigator.of(context).pushReplacement(
            CupertinoPageRoute(
              builder: (_) => BusinessDetailsPage(
                uid: user.uid,
                email: user.email,
                displayName: user.displayName,
              ),
            ),
          );
          return;
        }

        // User has completed registration - proceed normally
        // Initialize PlanProvider in background (non-blocking)
        final planProvider = Provider.of<PlanProvider>(context, listen: false);
        planProvider.initialize(); // Don't await - let it run in background

        if (!mounted) return;

        // Navigate to NewSalePage for regular users
        Navigator.of(context).pushReplacement(
          CupertinoPageRoute(
            builder: (_) => NewSalePage(
              uid: user.uid,
              userEmail: user.email,
            ),
          ),
        );
      } catch (e) {
        debugPrint('Error checking user registration status: $e');
        // On error, navigate to NewSalePage as fallback
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          CupertinoPageRoute(
            builder: (_) => NewSalePage(
              uid: user.uid,
              userEmail: user.email,
            ),
          ),
        );
      }
    } else {
      // User is NOT logged in
      Navigator.of(context).pushReplacement(
        CupertinoPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  @override
  void dispose() {
    _forceLogoutSub?.cancel();
    super.dispose();
  }

  /// Request Bluetooth and location permissions for printer connectivity
  /// This is now a public static method that can be called when needed
  static Future<bool> requestBluetoothPermissions() async {
    // Skip on web - Bluetooth not supported
    if (kIsWeb) {
      debugPrint('⚠️ Bluetooth not supported on web');
      return false;
    }

    try {
      // Request Bluetooth permissions (Android 12+)
      final bluetoothStatus = await Permission.bluetooth.request();
      final scanStatus = await Permission.bluetoothScan.request();
      final connectStatus = await Permission.bluetoothConnect.request();

      // Request location permission (required for Bluetooth scanning on Android)
      final locationStatus = await Permission.location.request();

      // If all permissions granted, enable Bluetooth
      if (bluetoothStatus.isGranted && scanStatus.isGranted && connectStatus.isGranted && locationStatus.isGranted) {
        try {
          await FlutterBluePlus.turnOn();
          debugPrint('✅ Bluetooth enabled successfully');
          return true;
        } catch (e) {
          debugPrint('⚠️ Error enabling Bluetooth: $e');
          return true; // Still return true if permissions granted
        }
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error requesting Bluetooth permissions: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size to determine device type
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final diagonal = sqrt(screenWidth * screenWidth + screenHeight * screenHeight);

    // Determine if device is tablet/iPad (diagonal > 7 inches assuming ~160 dpi)
    // Typically tablets have diagonal > 1100 pixels
    final isTablet = diagonal > 1100 || screenWidth > 600;

    // Choose appropriate splash image with correct file extension
    final splashImage = isTablet ? 'assets/MAX_my_bill_tab.png' : 'assets/MAX_my_bill_mobile.png';

    return Scaffold(
      backgroundColor: Color(0xff4456E0),
      body: SizedBox.expand(
        child: Image.asset(
          splashImage,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
