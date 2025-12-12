// 📁 main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:recruitswift/screens/main_screen.dart';
import 'firebase_options.dart';

import 'screens/auth_gate.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/jd_list_screen.dart';
import 'screens/add_edit_jd_screen.dart';
import 'screens/jd_detail_screen.dart';
import 'screens/new_analysis_setup_screen.dart';
import 'screens/analysis_job_list_screen.dart';
import 'screens/analysis_job_detail_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/profile_screen.dart';

import 'models/job_description.dart';
import 'config/app_config.dart';
import 'package:flutter/foundation.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (kDebugMode) {
      print("Firebase Core SDK initialized successfully.");
    }

    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      );
      if (kDebugMode) {
        print("Firebase App Check activated successfully (Provider: ${kDebugMode ? 'Debug' : 'PlayIntegrity'}).");
      }
    } catch (e) {
      if (kDebugMode) {
        print("Firebase App Check initialization failed: $e. If App Check is enforced in Firebase console, Firestore/Storage calls might fail.");
      }
    }

  } catch (e) {
    if (kDebugMode) {
      print("Firebase core initialization failed: $e. Ensure 'firebase_options.dart' is correct and your Firebase project is properly set up (including SHA fingerprints for Android).");
    }
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: AppConfig.appFontFamily,

      colorScheme: const ColorScheme.light(
        primary: AppConfig.primaryColor,
        onPrimary: AppConfig.onPrimaryColor,
        secondary: AppConfig.secondaryColor,
        onSecondary: AppConfig.onSecondaryColor,
        background: AppConfig.backgroundColor,
        onBackground: AppConfig.onBackgroundColor,
        surface: AppConfig.surfaceColor,
        onSurface: AppConfig.onSurfaceColor,
        error: AppConfig.errorColor,
        onError: AppConfig.onPrimaryColor,
        surfaceVariant: Color(0xFFE0E0E0), // Lighter grey for variants
        onSurfaceVariant: Color(0xFF616161), // Darker text on surface variant
        outline: Color(0xFFBDBDBD), // Light grey outline
      ),

      scaffoldBackgroundColor: AppConfig.backgroundColor,

      appBarTheme: AppBarTheme(
        backgroundColor: AppConfig.surfaceColor,
        elevation: 2,
        iconTheme: const IconThemeData(color: AppConfig.primaryColor),
        titleTextStyle: TextStyle(
          color: AppConfig.onBackgroundColor,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          fontFamily: AppConfig.appFontFamily,
        ),
      ),

      cardTheme: CardTheme(
        elevation: 4,
        color: AppConfig.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConfig.cardBorderRadius),
          side: BorderSide(color: AppConfig.outline.withOpacity(0.5), width: 0.5),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),

      textTheme: TextTheme(
        displayLarge: TextStyle(color: AppConfig.onBackgroundColor, fontWeight: FontWeight.bold, fontFamily: AppConfig.appFontFamily),
        displayMedium: TextStyle(color: AppConfig.onBackgroundColor, fontWeight: FontWeight.bold, fontFamily: AppConfig.appFontFamily),
        displaySmall: TextStyle(color: AppConfig.onBackgroundColor, fontWeight: FontWeight.bold, fontFamily: AppConfig.appFontFamily),
        headlineLarge: TextStyle(color: AppConfig.onBackgroundColor, fontWeight: FontWeight.w600, fontFamily: AppConfig.appFontFamily, fontSize: 30),
        headlineMedium: TextStyle(color: AppConfig.onBackgroundColor, fontWeight: FontWeight.w600, fontFamily: AppConfig.appFontFamily, fontSize: 26),
        headlineSmall: TextStyle(color: AppConfig.onBackgroundColor, fontWeight: FontWeight.w600, fontFamily: AppConfig.appFontFamily, fontSize: 22),
        titleLarge: TextStyle(color: AppConfig.onBackgroundColor, fontWeight: FontWeight.w500, fontFamily: AppConfig.appFontFamily, fontSize: 19),
        titleMedium: TextStyle(color: AppConfig.onBackgroundColor, fontWeight: FontWeight.w500, fontFamily: AppConfig.appFontFamily, fontSize: 17),
        titleSmall: TextStyle(color: AppConfig.hintColor, fontWeight: FontWeight.w400, fontFamily: AppConfig.appFontFamily, fontSize: 15),
        bodyLarge: TextStyle(color: AppConfig.onBackgroundColor, height: 1.5, fontFamily: AppConfig.appFontFamily, fontSize: 16),
        bodyMedium: TextStyle(color: AppConfig.onBackgroundColor.withOpacity(0.8), height: 1.4, fontFamily: AppConfig.appFontFamily, fontSize: 14),
        bodySmall: TextStyle(color: AppConfig.onBackgroundColor.withOpacity(0.6), height: 1.3, fontFamily: AppConfig.appFontFamily, fontSize: 12),
        labelLarge: TextStyle(color: AppConfig.onPrimaryColor, fontWeight: FontWeight.bold, fontFamily: AppConfig.appFontFamily, fontSize: 16),
        labelMedium: TextStyle(color: AppConfig.hintColor, fontFamily: AppConfig.appFontFamily),
        labelSmall: TextStyle(color: AppConfig.hintColor, fontFamily: AppConfig.appFontFamily),
      ).apply(fontFamily: AppConfig.appFontFamily),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConfig.primaryColor,
          foregroundColor: AppConfig.onPrimaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: AppConfig.appFontFamily,
            letterSpacing: 0.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConfig.buttonBorderRadius),
          ),
          elevation: 4,
          shadowColor: AppConfig.primaryColor.withOpacity(0.4),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppConfig.primaryColor,
          textStyle: TextStyle(
            fontWeight: FontWeight.w600,
            fontFamily: AppConfig.appFontFamily,
            fontSize: 15,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppConfig.surfaceColor,
        hintStyle: TextStyle(color: AppConfig.hintColor.withOpacity(0.8)),
        labelStyle: TextStyle(color: AppConfig.primaryColor.withOpacity(0.9), fontWeight: FontWeight.w500),
        prefixIconColor: AppConfig.primaryColor.withOpacity(0.8),
        suffixIconColor: AppConfig.primaryColor.withOpacity(0.8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConfig.inputBorderRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConfig.inputBorderRadius),
          borderSide: BorderSide(color: AppConfig.outline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConfig.inputBorderRadius),
          borderSide: const BorderSide(color: AppConfig.primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConfig.inputBorderRadius),
          borderSide: BorderSide(color: AppConfig.errorColor, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConfig.inputBorderRadius),
          borderSide: BorderSide(color: AppConfig.errorColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 16.0),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppConfig.surfaceColor,
        selectedItemColor: AppConfig.primaryColor,
        unselectedItemColor: AppConfig.hintColor,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 11),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppConfig.primaryColor.withOpacity(0.1),
        disabledColor: AppConfig.hintColor.withOpacity(0.3),
        selectedColor: AppConfig.primaryColor,
        secondarySelectedColor: AppConfig.secondaryColor,
        labelStyle: TextStyle(color: AppConfig.onBackgroundColor.withOpacity(0.9), fontWeight: FontWeight.w500, fontSize: 12),
        secondaryLabelStyle: const TextStyle(color: AppConfig.onSecondaryColor, fontWeight: FontWeight.w500, fontSize: 12),
        brightness: Brightness.light,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConfig.chipBorderRadius)),
        side: BorderSide.none,
        iconTheme: IconThemeData(color: AppConfig.primaryColor.withOpacity(0.9), size: 18),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      dialogTheme: DialogTheme(
        backgroundColor: AppConfig.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConfig.dialogBorderRadius)),
        titleTextStyle: TextStyle(color: AppConfig.onBackgroundColor, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: AppConfig.appFontFamily),
        contentTextStyle: TextStyle(color: AppConfig.onSurfaceColor, fontSize: 16, fontFamily: AppConfig.appFontFamily, height: 1.4),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppConfig.primaryColor,
        linearMinHeight: 6,
        circularTrackColor: AppConfig.surfaceColor.withOpacity(0.5),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppConfig.surfaceColor,
        contentTextStyle: TextStyle(color: AppConfig.onBackgroundColor, fontFamily: AppConfig.appFontFamily),
        actionTextColor: AppConfig.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConfig.snackBarBorderRadius)),
        elevation: 6,
      ),
    );

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: lightTheme, // Use the new light theme
      home: const SplashScreen(),
      routes: {
        SplashScreen.routeName: (context) => const SplashScreen(),
        OnboardingScreen.routeName: (context) => const OnboardingScreen(),
        AuthGate.routeName: (context) => const AuthGate(),
        MainScreen.routeName: (context) => const MainScreen(),
        LoginScreen.routeName: (context) => const LoginScreen(),
        SignUpScreen.routeName: (context) => const SignUpScreen(),
        JDListScreen.routeName: (context) => const JDListScreen(),
        AddEditJDScreen.routeName: (context) {
          final JobDescription? jd = ModalRoute.of(context)?.settings.arguments as JobDescription?;
          return AddEditJDScreen(jobDescription: jd);
        },
        JDDetailScreen.routeName: (context) {
          final JobDescription jd = ModalRoute.of(context)!.settings.arguments as JobDescription;
          return JDDetailScreen(jobDescription: jd);
        },
        NewAnalysisSetupScreen.routeName: (context) {
           final JobDescription jd = ModalRoute.of(context)!.settings.arguments as JobDescription;
           return NewAnalysisSetupScreen(selectedJD: jd);
        },
        AnalysisJobListScreen.routeName: (context) => const AnalysisJobListScreen(),
        AnalysisJobDetailScreen.routeName: (context) {
          final String analysisJobId = ModalRoute.of(context)!.settings.arguments as String;
          return AnalysisJobDetailScreen(analysisJobId: analysisJobId);
        },
        ProfileScreen.routeName: (context) => const ProfileScreen(),
      },
    );
  }
}