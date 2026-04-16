import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'Auth/SplashPage.dart';
import 'firebase_options.dart';
import 'utils/theme_notifier.dart';
import 'utils/language_provider.dart';
import 'utils/plan_provider.dart';
import 'utils/keyboard_helper.dart';
import 'models/sale.dart';
import 'services/sale_sync_service.dart';
import 'services/local_stock_service.dart';
import 'services/direct_notification_service.dart';
import 'services/cart_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


void main() async {
  await dotenv.load(fileName: ".env");
  WidgetsFlutterBinding.ensureInitialized();

  // Configure keyboard optimizations early (skip on web)
  if (!kIsWeb) {
    KeyboardHelper.configureKeyboardOptimizations();
  }

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Hive for offline storage
  if (kIsWeb) {
    // For web, initialize Hive without path
    await Hive.initFlutter();
  } else {
    // For mobile/desktop, use application documents directory
    final appDocumentDir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(appDocumentDir.path);
  }
  Hive.registerAdapter(SaleAdapter());

  // Initialize SaleSyncService for offline sales syncing
  final saleSyncService = SaleSyncService();
  await saleSyncService.init();

  // Initialize LocalStockService for offline stock management
  final localStockService = LocalStockService();
  await localStockService.init();

  // Initialize LanguageProvider and load saved preference
  final languageProvider = LanguageProvider();
  await languageProvider.loadLanguagePreference();

  // Initialize PlanProvider for real-time plan updates
  final planProvider = PlanProvider();
  // Note: planProvider.initialize() will be called after user login to start real-time listener

  // Initialize CartService for cart persistence across navigation
  final cartService = CartService();

  // DirectNotificationService will be initialized lazily when needed
  // Permissions will be requested only when user interacts with notification features

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier()),
        ChangeNotifierProvider<LanguageProvider>.value(value: languageProvider),
        ChangeNotifierProvider<PlanProvider>.value(value: planProvider),
        Provider<SaleSyncService>.value(value: saleSyncService),
        ChangeNotifierProvider<LocalStockService>.value(value: localStockService),
        ChangeNotifierProvider<CartService>.value(value: cartService),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    // Set keyboard animation duration to improve responsiveness
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MAXmybill',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F7CF6)),
        useMaterial3: true,
        fontFamily: 'MiSans',
        scaffoldBackgroundColor: Colors.white,
        // Improve text field performance
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Color(0xFF2F7CF6),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8F9FA), // kGreyBg equivalent
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          labelStyle: const TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w600),
          floatingLabelStyle: const TextStyle(color: Color(0xFF2F7CF6), fontSize: 11, fontWeight: FontWeight.w900),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFEEEEEE), width: 1.0), // kGrey200 equivalent
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF2F7CF6), width: 2.0),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.red, width: 1.0),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.red, width: 2.0),
          ),
        ),
        // Reduce animations for better keyboard performance
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F7CF6), brightness: Brightness.dark),
        useMaterial3: true,
        fontFamily: 'NotoSans',
        scaffoldBackgroundColor: Colors.black,
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Color(0xFF2F7CF6),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      themeMode: themeNotifier.themeMode,
      home: const SplashPage(), // Use custom splash page directly
      builder: (context, child) {
        // Lock screen orientation to portrait
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            // Disable text scaling to improve performance
            textScaler: const TextScaler.linear(1.0),
          ),
          child: OrientationBuilder(
            builder: (context, orientation) {
              if (orientation != Orientation.portrait) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  SystemChrome.setPreferredOrientations([
                    DeviceOrientation.portraitUp,
                    DeviceOrientation.portraitDown,
                  ]);
                });
              }
              return child!;
            },
          ),
        );
      },
    );
  }
}

