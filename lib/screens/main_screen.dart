// 📁 screens/main_screen.dart
import 'package:flutter/material.dart';
import 'package:recruitswift/config/app_config.dart';
import 'package:recruitswift/screens/add_edit_jd_screen.dart';
import '../services/user_profile_service.dart';
import 'jd_list_screen.dart';
import 'analysis_job_list_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  static const routeName = '/main';
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  final UserProfileService _profileService = UserProfileService();
  String? _userDisplayName;

  late final List<Widget> _widgetOptions;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabScaleAnimation;

  final List<String> _appBarTitles = [
    'Job Descriptions',
    'Analysis Jobs',
    'My Profile',
  ];

  final List<IconData> _navBarIcons = [
    Icons.list_alt_outlined,
    Icons.history_edu_outlined,
    Icons.person_outline_rounded,
  ];
   final List<IconData> _navBarSelectedIcons = [
    Icons.list_alt_rounded,
    Icons.history_edu_rounded,
    Icons.person_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _widgetOptions = <Widget>[
      const JDListScreen(),
      const AnalysisJobListScreen(),
      ProfileScreen(onProfileUpdated: _handleProfileUpdate),
    ];

    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _fabScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeOutBack),
    );

    if (_selectedIndex == 0) {
      _fabAnimationController.forward();
    }
  }

  Future<void> _loadUserData() async {
    final displayName = await _profileService.getDisplayName();
    if (mounted) {
      setState(() {
        _userDisplayName = displayName;
      });
    }
  }

  void _handleProfileUpdate() {
    _loadUserData();
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;

    setState(() {
      _selectedIndex = index;
    });
    if (_selectedIndex == 0) {
      _fabAnimationController.forward();
    } else {
      _fabAnimationController.reverse();
    }
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitles[_selectedIndex]),
        leadingWidth: 70,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
        ),
        actions: [
          if (_userDisplayName != null)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Text(
                  _userDisplayName!.split(" ").first,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: List.generate(_appBarTitles.length, (i) {
          return BottomNavigationBarItem(
            icon: Icon(_selectedIndex == i ? _navBarSelectedIcons[i] : _navBarIcons[i]),
            label: _appBarTitles[i].split(" ").first,
          );
        }),
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
       floatingActionButton: _selectedIndex == 0
          ? ScaleTransition(
              scale: _fabScaleAnimation,
              child: FloatingActionButton.extended(
                onPressed: () {
                  Navigator.pushNamed(context, AddEditJDScreen.routeName);
                },
                label: const Text('Add JD'),
                icon: const Icon(Icons.add_comment_outlined),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}