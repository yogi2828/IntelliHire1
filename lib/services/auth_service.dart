// 📁 services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:recruitswift/config/app_config.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  User? get currentUser => _firebaseAuth.currentUser;
  String? getCurrentUserId() => _firebaseAuth.currentUser?.uid;
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  void _showAuthSnackbar(BuildContext context, String message, {bool isError = true}) {
     if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Theme.of(context).colorScheme.error : AppConfig.primaryColor.withOpacity(0.8),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<UserCredential?> signUpWithEmailPassword(String email, String password, {BuildContext? context}) async {
    try {
      UserCredential userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (context != null) _showAuthSnackbar(context, 'Sign up successful! Welcome.', isError: false);
      return userCredential;
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Sign up failed: ${e.message ?? "An unknown error occurred."}';
      if (e.code == 'weak-password') errorMessage = 'The password provided is too weak.';
      else if (e.code == 'email-already-in-use') errorMessage = 'An account already exists for that email.';
      else if (e.code == 'invalid-email') errorMessage = 'The email address is not valid.';

      if (context != null) _showAuthSnackbar(context, errorMessage);
      if (kDebugMode) print("AuthService: Sign up error: ${e.code} - ${e.message}");
      return null;
    } catch (e) {
      if (context != null) _showAuthSnackbar(context, 'Sign up failed: An unexpected error occurred.');
      if (kDebugMode) print("AuthService: Unexpected sign up error: $e");
      return null;
    }
  }

  Future<UserCredential?> signInWithEmailPassword(String email, String password, {BuildContext? context}) async {
    try {
      UserCredential userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Sign in failed: ${e.message ?? "An unknown error occurred."}';
      if (e.code == 'user-not-found') errorMessage = 'No user found for that email.';
      else if (e.code == 'wrong-password') errorMessage = 'Wrong password provided for that user.';
      else if (e.code == 'invalid-email') errorMessage = 'The email address is not valid.';
      else if (e.code == 'user-disabled') errorMessage = 'This user account has been disabled.';

      if (context != null) _showAuthSnackbar(context, errorMessage);
      if (kDebugMode) print("AuthService: Sign in error: ${e.code} - ${e.message}");
      return null;
    } catch (e) {
      if (context != null) _showAuthSnackbar(context, 'Sign in failed: An unexpected error occurred.');
      if (kDebugMode) print("AuthService: Unexpected sign in error: $e");
      return null;
    }
  }

  Future<void> signOut({BuildContext? context}) async {
    try {
      await _firebaseAuth.signOut();
    } on FirebaseAuthException catch (e) {
      if (context != null) _showAuthSnackbar(context, 'Sign out failed: ${e.message ?? "Unknown error"}');
      if (kDebugMode) print("AuthService: Sign out error: ${e.code} - ${e.message}");
    } catch (e) {
      if (context != null) _showAuthSnackbar(context, 'Sign out failed: An unexpected error occurred.');
      if (kDebugMode) print("AuthService: Unexpected sign out error: $e");
    }
  }

  Future<bool> sendPasswordResetEmail(String email, {BuildContext? context}) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
      if (context != null) _showAuthSnackbar(context, 'Password reset email sent to $email. Please check your inbox (and spam folder).', isError: false);
      return true;
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Failed to send password reset email: ${e.message ?? "Unknown error."}';
      if (e.code == 'user-not-found') errorMessage = 'No user found for this email address.';
      else if (e.code == 'invalid-email') errorMessage = 'The email address is not valid.';

      if (context != null) _showAuthSnackbar(context, errorMessage);
      if (kDebugMode) print("AuthService: Password reset error: ${e.code} - ${e.message}");
      return false;
    } catch (e) {
      if (context != null) _showAuthSnackbar(context, 'Password reset failed: An unexpected error occurred.');
      if (kDebugMode) print("AuthService: Unexpected password reset error: $e");
      return false;
    }
  }
}