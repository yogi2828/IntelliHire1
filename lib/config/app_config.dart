// 📁 config/app_config.dart
import 'package:flutter/material.dart';

class AppConfig {
  static const String appName = "IntelliHire";
  static const String companyName = "IntelliHire AI Solutions";
  static const String companyCareersUrl = "https://IntelliHire.com/careers";

  static const String appFontFamily = 'Inter';

  static const Color primaryColor = Color(0xFF007BFF); // A vibrant blue
  static const Color secondaryColor = Color(0xFF00CFFF); // A lighter, energetic blue
  static const Color accentColor = Color(0xFF4CAF50); // Green for success/shortlisted
  static const Color errorColor = Color(0xFFF44336); // Standard error red
  static const Color warningColor = Color(0xFFFF9800); // Orange for warnings/processing errors
  static const Color outline = Color.fromARGB(255, 0, 0, 0);
  // White theme colors
  static const Color backgroundColor = Color(0xFFFFFFFF); 
  static const Color surfaceColor = Color(0xFFF5F5F5); 
  static const Color onPrimaryColor = Color(0xFFFFFFFF); // White text on primary
  static const Color onSecondaryColor = Color(0xFF000000); // Black text on secondary
  static const Color onBackgroundColor = Color(0xFF212121); // Dark text on background
  static const Color onSurfaceColor = Color(0xFF424242); // Medium dark text on surface
  static const Color hintColor = Color(0xFF757575); // Grey hint text

  static const double cardBorderRadius = 16.0;
  static const double buttonBorderRadius = 30.0;
  static const double inputBorderRadius = 12.0;
  static const double dialogBorderRadius = 20.0;
  static const double chipBorderRadius = 24.0;
  static const double snackBarBorderRadius = 8.0;

  static const String defaultUserDisplayName = "Recruiter";
  static const String defaultAvatarAssetName = "svg_avatar_default";

  static const double defaultShortlistingThreshold = 0.70;

  static const List<String> geminiApiKeys = [
    'api key',
    'api key',
  ];

  static bool isGeminiApiKeyConfigured() {
    if (geminiApiKeys.isEmpty) return false;
    final firstKey = geminiApiKeys.first;
    return firstKey.isNotEmpty &&
           !firstKey.startsWith('YOUR_GEMINI_API_KEY') &&
           !firstKey.endsWith('_REPLACE_ME');
  }
}
