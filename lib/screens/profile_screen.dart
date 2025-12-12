// 📁 screens/profile_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:recruitswift/config/app_config.dart';
import '../services/auth_service.dart';
import '../services/user_profile_service.dart';
import 'auth_gate.dart';

class ProfileScreen extends StatefulWidget {
  static const routeName = '/profile';
  final VoidCallback? onProfileUpdated;

  const ProfileScreen({super.key, this.onProfileUpdated});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with AutomaticKeepAliveClientMixin {
  final AuthService _authService = AuthService();
  final UserProfileService _profileService = UserProfileService();
  final TextEditingController _nameController = TextEditingController();

  String? _displayName;
  String? _email;
  String _selectedAvatarIdentifier = AppConfig.defaultAvatarAssetName;
  bool _isLoading = true;
  bool _isSaving = false;

  final List<String> _availableAvatarIdentifiers = [
    // Example SVG identifiers (assuming you have a way to render these)
    'svg_avatar_default',
    'svg_avatar_1',
    'svg_avatar_2',
    'svg_avatar_3',
    'svg_avatar_4',
    'svg_avatar_5',
    // Add more identifiers as needed
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    _email = _profileService.getCurrentUserEmail();
    _displayName = await _profileService.getDisplayName();
    _selectedAvatarIdentifier = await _profileService.getSelectedAvatarIdentifier();
    _nameController.text = _displayName ?? '';
    if(mounted) setState(() => _isLoading = false);
  }

  Future<void> _updateProfile() async {
    FocusScope.of(context).unfocus();
    if (_nameController.text.trim().isEmpty) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
            content: const Text('Display name cannot be empty.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }
    if(mounted) setState(() => _isSaving = true);

    await _profileService.saveDisplayName(_nameController.text.trim());
    await _profileService.saveSelectedAvatar(_selectedAvatarIdentifier);

    await _loadUserProfile();
    widget.onProfileUpdated?.call();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green),
      );
      setState(() => _isSaving = false);
    }
  }

  // Placeholder for rendering SVG avatars - replace with actual SVG rendering logic
  Widget _buildAvatarWidget(String identifier, double size) {
    // In a real app, you would use an SVG rendering library like flutter_svg
    // Example: SvgPicture.asset('assets/avatars/$identifier.svg', height: size, width: size);
    // For now, we'll use a placeholder icon
    final theme = Theme.of(context);
    return CircleAvatar(
       radius: size / 2,
       backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
       child: Icon(Icons.person_rounded, size: size * 0.7, color: theme.colorScheme.primary),
    );
  }


  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: constraints.maxWidth > 600 ? (constraints.maxWidth - 550) / 2 : 24.0,
                    vertical: 24.0
                  ),
                  child: Center(
                    child: ConstrainedBox(
                       constraints: const BoxConstraints(maxWidth: 500),
                       child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20),
                          GestureDetector(
                            onTap: _showAvatarSelectionDialog,
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient( // Gradient border
                                      colors: [theme.colorScheme.primary, theme.colorScheme.secondary.withOpacity(0.8)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                     boxShadow: [
                                      BoxShadow(
                                        color: theme.colorScheme.primary.withOpacity(0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0,4)
                                      )
                                    ]
                                  ),
                                  child: _buildAvatarWidget(_selectedAvatarIdentifier, 120), // Use the placeholder
                                ),
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: theme.colorScheme.surface,
                                  child: Icon(Icons.edit_rounded, size: 26, color: theme.colorScheme.primary),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            _displayName ?? "User",
                            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _email ?? 'No email found',
                            style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onBackground.withOpacity(0.75)),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Display Name',
                              hintText: 'Enter your preferred display name',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                            style: theme.textTheme.titleMedium,
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: 30),
                          _isSaving
                            ? const Center(child: CircularProgressIndicator())
                            : ElevatedButton.icon(
                                icon: const Icon(Icons.save_as_outlined),
                                label: const Text('Save Profile Changes'),
                                onPressed: _updateProfile,
                                style: theme.elevatedButtonTheme.style?.copyWith(
                                  minimumSize: MaterialStateProperty.all(const Size(double.infinity, 50)),
                                )
                              ),
                          const SizedBox(height: 24),
                          OutlinedButton.icon(
                            icon: Icon(Icons.logout_rounded, color: theme.colorScheme.error),
                            label: Text('Sign Out', style: TextStyle(color: theme.colorScheme.error)),
                            onPressed: () async {
                              await _authService.signOut(context: context);
                              if (mounted) {
                                Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                                  MaterialPageRoute(builder: (context) => const AuthGate()),
                                  (Route<dynamic> route) => false,
                                );
                              }
                            },
                             style: OutlinedButton.styleFrom(
                               side: BorderSide(color: theme.colorScheme.error.withOpacity(0.5)),
                               padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConfig.buttonBorderRadius))
                             )
                          ),
                           const SizedBox(height: 40),
                        ],
                       ),
                    ),
                  ),
                );
              }
            ),
    );
  }

  void _showAvatarSelectionDialog() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Your Avatar'),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _availableAvatarIdentifiers.length,
              itemBuilder: (context, index) {
                final avatarIdentifier = _availableAvatarIdentifiers[index];
                final bool isSelected = avatarIdentifier == _selectedAvatarIdentifier;
                return GestureDetector(
                  onTap: () {
                    if(mounted) {
                      setState(() {
                        _selectedAvatarIdentifier = avatarIdentifier;
                      });
                    }
                    Navigator.of(context).pop();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: theme.colorScheme.primary, width: 3.5)
                          : Border.all(color: theme.colorScheme.outline.withOpacity(0.5), width: 1.5),
                       boxShadow: isSelected ? [
                         BoxShadow(
                           color: theme.colorScheme.primary.withOpacity(0.4),
                           blurRadius: 10,
                           spreadRadius: 2
                         )
                       ] : [
                         BoxShadow(
                           color: theme.shadowColor.withOpacity(0.1),
                           blurRadius: 5,
                         )
                       ],
                    ),
                    child: _buildAvatarWidget(avatarIdentifier, 60), // Use placeholder in dialog
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            )
          ],
        );
      },
    );
  }
}