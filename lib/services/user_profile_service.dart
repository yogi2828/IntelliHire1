// 📁 services/user_profile_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_config.dart';
import 'package:flutter/foundation.dart';

class UserProfileService {
  static const String _displayNameKey = 'recruitSwift_userDisplayName';
  static const String _selectedAvatarKey = 'recruitSwift_userSelectedAvatar';
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> saveDisplayName(String displayName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_displayNameKey, displayName);
    User? currentUser = _auth.currentUser;
    if (currentUser != null && currentUser.displayName != displayName) {
      try {
        await currentUser.updateDisplayName(displayName);
        if (kDebugMode) print("UserProfileService: Firebase display name updated.");
      } catch (e) {
        if (kDebugMode) print("UserProfileService: Error updating Firebase display name: $e");
      }
    }
  }

  Future<String> getDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    String? localName = prefs.getString(_displayNameKey);
    if (localName != null && localName.isNotEmpty) return localName;

    User? currentUser = _auth.currentUser;
    if (currentUser?.displayName != null && currentUser!.displayName!.isNotEmpty) {
      await prefs.setString(_displayNameKey, currentUser.displayName!);
      return currentUser.displayName!;
    }
    if (currentUser?.email != null && currentUser!.email!.isNotEmpty) {
      final emailName = currentUser.email!.split('@').first;
      final formattedEmailName = emailName.isNotEmpty ? emailName[0].toUpperCase() + emailName.substring(1) : AppConfig.defaultUserDisplayName;
      await prefs.setString(_displayNameKey, formattedEmailName);
      return formattedEmailName;
    }
    return AppConfig.defaultUserDisplayName;
  }

  Future<void> saveSelectedAvatar(String avatarIdentifier) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedAvatarKey, avatarIdentifier);
  }

  Future<String> getSelectedAvatarIdentifier() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedAvatarKey) ?? AppConfig.defaultAvatarAssetName;
  }

  String? getCurrentUserEmail() => _auth.currentUser?.email;
  User? getCurrentUser() => _auth.currentUser;
}