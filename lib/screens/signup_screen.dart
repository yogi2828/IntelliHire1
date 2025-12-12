// 📁 screens/signup_screen.dart
import 'package:flutter/material.dart';
import 'package:recruitswift/config/app_config.dart';
import '../services/auth_service.dart';
import '../services/user_profile_service.dart';
import 'login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class SignUpScreen extends StatefulWidget {
  static const routeName = '/signup';
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _authService = AuthService();
  final _userProfileService = UserProfileService();
  bool _isLoading = false; bool _passwordVisible = false; bool _confirmPasswordVisible = false;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeIn));
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose(); _passwordController.dispose(); _confirmPasswordController.dispose(); _displayNameController.dispose(); _animationController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState!.validate()) {
      if (_passwordController.text != _confirmPasswordController.text) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Passwords do not match!'), backgroundColor: Theme.of(context).colorScheme.error));
        return;
      }
      if(mounted) setState(() => _isLoading = true);
      UserCredential? userCredential = await _authService.signUpWithEmailPassword(_emailController.text, _passwordController.text, context: context);
      if (userCredential != null && userCredential.user != null) {
        String displayName = _displayNameController.text.trim();
        if (displayName.isEmpty) {
          displayName = _emailController.text.split('@').first;
          displayName = displayName.isNotEmpty ? displayName[0].toUpperCase() + displayName.substring(1) : AppConfig.defaultUserDisplayName;
        }
        await _userProfileService.saveDisplayName(displayName);
        await _userProfileService.saveSelectedAvatar(AppConfig.defaultAvatarAssetName);
      }
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Icon(Icons.person_add_alt_1_rounded, size: 72, color: theme.colorScheme.primary),
                      const SizedBox(height: 24),
                      Text('Create Your Account', textAlign: TextAlign.center, style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Join ${AppConfig.appName} to streamline your hiring', textAlign: TextAlign.center, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onBackground.withOpacity(0.75))),
                      const SizedBox(height: 40),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(controller: _displayNameController, decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline_rounded), hintText: 'e.g., Alex Smith'), keyboardType: TextInputType.name, textCapitalization: TextCapitalization.words, autofillHints: const [AutofillHints.name], validator: (v) => (v == null || v.trim().isEmpty) ? 'Name required' : (v.trim().length < 3) ? 'Name too short' : null),
                            const SizedBox(height: 16),
                            TextFormField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_outlined), hintText: 'you@example.com'), keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email], validator: (v) => (v == null || v.trim().isEmpty) ? 'Email required' : (!RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$").hasMatch(v.trim())) ? 'Valid email required' : null),
                            const SizedBox(height: 16),
                            TextFormField(controller: _passwordController, decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline_rounded), hintText: 'Create a strong password', suffixIcon: IconButton(icon: Icon(_passwordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => _passwordVisible = !_passwordVisible))), obscureText: !_passwordVisible, autofillHints: const [AutofillHints.newPassword], validator: (v) => (v == null || v.isEmpty) ? 'Password required' : (v.length < 8) ? 'Min 8 characters' : null),
                            const SizedBox(height: 16),
                            TextFormField(controller: _confirmPasswordController, decoration: InputDecoration(labelText: 'Confirm Password', prefixIcon: const Icon(Icons.lock_reset_outlined), hintText: 'Re-enter your password', suffixIcon: IconButton(icon: Icon(_confirmPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => _confirmPasswordVisible = !_confirmPasswordVisible))), obscureText: !_confirmPasswordVisible, validator: (v) => (v == null || v.isEmpty) ? 'Confirm password' : (v != _passwordController.text) ? 'Passwords do not match' : null),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      _isLoading ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)) : ElevatedButton.icon(icon: const Icon(Icons.person_add_alt_1_rounded), onPressed: _signup, label: const Text('SIGN UP'), style: theme.elevatedButtonTheme.style?.copyWith(minimumSize: MaterialStateProperty.all(const Size(double.infinity, 52)))),
                      const SizedBox(height: 24),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [ Text("Already have an account?", style: theme.textTheme.bodyMedium), TextButton(onPressed: _isLoading ? null : () => Navigator.of(context).pushReplacementNamed(LoginScreen.routeName), child: Text('Log In', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)))]),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}