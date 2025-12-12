// 📁 screens/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:recruitswift/config/app_config.dart';
import 'auth_gate.dart';
import 'onboarding_content.dart';
import 'package:flutter/foundation.dart';

class OnboardingScreen extends StatefulWidget {
  static const routeName = '/onboarding';
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const String _onboardingCompletedKey = 'recruitSwift_onboardingCompleted_v1';

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingCompletedKey, true);
      if (mounted) Navigator.of(context).pushReplacementNamed(AuthGate.routeName);
    } catch (e) {
        if (kDebugMode) print("Error saving onboarding status: $e");
        if (mounted) Navigator.of(context).pushReplacementNamed(AuthGate.routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: PageView.builder(
                controller: _pageController,
                itemCount: onboardingPages.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final page = onboardingPages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 600), // Increased duration
                          transitionBuilder: (Widget child, Animation<double> animation) => FadeTransition(opacity: animation, child: child),
                          child: OnboardingVisual(key: ValueKey<String>(page.imagePath), iconData: page.icon),
                        ),
                        const SizedBox(height: 48),
                        Text(page.title, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                        const SizedBox(height: 16),
                        Text(page.description, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onBackground.withOpacity(0.8), height: 1.6)),
                      ],
                    ),
                  );
                },
              ),
            ),
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    SmoothPageIndicator(
                      controller: _pageController,
                      count: onboardingPages.length,
                      effect: ExpandingDotsEffect(
                        activeDotColor: theme.colorScheme.primary,
                        dotColor: theme.colorScheme.primary.withOpacity(0.4), // More visible inactive dots
                        dotHeight: 10, dotWidth: 10, spacing: 8,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _currentPage != onboardingPages.length - 1
                            ? TextButton(onPressed: _completeOnboarding, child: Text('SKIP', style: TextStyle(color: theme.colorScheme.primary.withOpacity(0.8))))
                            : const SizedBox(width: 70),
                        ElevatedButton(
                          onPressed: () {
                            if (_currentPage == onboardingPages.length - 1) _completeOnboarding();
                            else _pageController.nextPage(duration: const Duration(milliseconds: 500), curve: Curves.easeInOutCubic); // Smoother transition
                          },
                          style: theme.elevatedButtonTheme.style?.copyWith(
                             padding: MaterialStateProperty.all(const EdgeInsets.symmetric(horizontal: 28, vertical: 14)),
                             elevation: MaterialStateProperty.all(6), // Added elevation
                             shadowColor: MaterialStateProperty.all(theme.colorScheme.primary.withOpacity(0.5)), // Added shadow
                          ),
                          child: Text(_currentPage == onboardingPages.length - 1 ? 'GET STARTED' : 'NEXT'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}