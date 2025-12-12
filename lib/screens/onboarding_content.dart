// 📁 screens/onboarding_content.dart
import 'package:flutter/material.dart';
import 'package:recruitswift/config/app_config.dart';

class OnboardingPageContent {
  final String imagePath; final IconData icon; final String title; final String description;
  OnboardingPageContent({required this.imagePath, required this.icon, required this.title, required this.description});
}

List<OnboardingPageContent> onboardingPages = [
  OnboardingPageContent(imagePath: 'onboarding_welcome', icon: Icons.auto_awesome_mosaic_outlined, title: 'Welcome to ${AppConfig.appName}!', description: 'Revolutionize your hiring process with intelligent CV analysis, streamlined job management, and automated candidate communication.'),
  OnboardingPageContent(imagePath: 'onboarding_cv_parse', icon: Icons.document_scanner_rounded, title: 'Smart CV Parsing & Matching', description: 'Our AI instantly extracts vital candidate data and precisely matches profiles to your job descriptions, saving you countless hours.'),
  OnboardingPageContent(imagePath: 'onboarding_workflow', icon: Icons.lan_outlined, title: 'Automated & Organized Workflow', description: 'Effortlessly manage job postings, track candidate progress through analysis stages, and send personalized emails in bulk.'),
  OnboardingPageContent(imagePath: 'onboarding_boost', icon: Icons.rocket_launch_rounded, title: 'Elevate Your Recruitment Game', description: 'Sign up or log in to transform your hiring strategy, identify top talent faster, and build your dream team with ease.'),
];

class OnboardingVisual extends StatelessWidget {
  final IconData iconData;
  const OnboardingVisual({super.key, required this.iconData});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 220, // Slightly larger
      width: 220, // Slightly larger
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary.withOpacity(0.3), theme.colorScheme.secondary.withOpacity(0.1)], // Gradient colors
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.5), width: 3.0), // Thicker border
         boxShadow: [ // Added shadow
           BoxShadow(
             color: theme.colorScheme.primary.withOpacity(0.3),
             blurRadius: 15,
             spreadRadius: 3
           )
         ]
      ),
      child: Center(child: Icon(iconData, size: 100, color: theme.colorScheme.primary, shadows: [Shadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(3, 3))])), // Larger icon, more prominent shadow
    );
  }
}