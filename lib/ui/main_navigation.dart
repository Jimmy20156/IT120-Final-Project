import 'package:flutter/material.dart';
import '../app_theme.dart';
import 'landing/farm_command_center.dart';
import 'analytics/dashboard_page.dart';
import 'camera/ar_camera_detection_page.dart';
import 'history/equipment_timeline_page.dart';
import 'settings/settings_page.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const FarmEquipmentDetector(),
    const DashboardPage(),
    const ARCameraDetectionPage(
      confidenceThreshold: 0.5,
      isARMode: true,
    ),
    const EquipmentTimelinePage(),
    const SettingsPage(),
  ];

  final List<BottomNavigationBarItem> _bottomNavItems = [
    const BottomNavigationBarItem(
      icon: Icon(Icons.home),
      label: 'Home',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.analytics),
      label: 'Analytics',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.camera_alt),
      label: 'Camera',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.history),
      label: 'History',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.settings),
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
            
            // Force refresh when switching to data-dependent tabs
            if (index == 0 || index == 1 || index == 3) {
              // Home, Analytics, or History tabs
              _refreshCurrentPage();
            }
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          selectedItemColor: AppColors.primaryBlue,
          unselectedItemColor: AppColors.textSecondary,
          selectedFontSize: 12,
          unselectedFontSize: 11,
          iconSize: 24,
          items: _bottomNavItems,
        ),
      ),
    );
  }

  void _refreshCurrentPage() {
    // Trigger a rebuild of the current page to refresh data
    if (mounted) {
      setState(() {});
    }
  }
}
