// 📁 screens/splash_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:recruitswift/config/app_config.dart';
import 'onboarding_screen.dart';
import 'auth_gate.dart';
import 'package:flutter/foundation.dart';

class SplashScreen extends StatefulWidget {
  static const routeName = '/splash';
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  static const String _onboardingCompletedKey = 'recruitSwift_onboardingCompleted_v1';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000), // Increased duration for smoother animation
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeIn);
    _scaleAnimation = CurvedAnimation(parent: _animationController, curve: Curves.elasticOut);
    _animationController.forward();
    _navigateToNextScreen();
  }

  Future<void> _navigateToNextScreen() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool onboardingCompleted = prefs.getBool(_onboardingCompletedKey) ?? false;
      if (mounted) {
        if (onboardingCompleted) {
          Navigator.of(context).pushReplacementNamed(AuthGate.routeName);
        } else {
          Navigator.of(context).pushReplacementNamed(OnboardingScreen.routeName);
        }
      }
    } catch (e) {
      if (kDebugMode) print("Error accessing SharedPreferences in SplashScreen: $e");
      if (mounted) Navigator.of(context).pushReplacementNamed(OnboardingScreen.routeName);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(Icons.hub_rounded, size: 80, color: theme.colorScheme.onPrimary),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                AppConfig.appName,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0, // Increased letter spacing
                ),
              ),
              const SizedBox(height: 12),
               Text(
                "AI Powered Hiring, Simplified.",
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onBackground.withOpacity(0.8),
                  fontStyle: FontStyle.italic,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 50),
              SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  minHeight: 8, // Thicker progress bar
                  borderRadius: BorderRadius.circular(4),
                  backgroundColor: theme.colorScheme.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}