import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../main.dart';
import 'detection/smart_scanner_page.dart';
import 'history/equipment_timeline_page.dart';
import 'analytics/farm_intelligence_dashboard.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    SmartScannerPage(),
    EquipmentTimelinePage(),
    FarmIntelligenceDashboard(),
  ];

  final List<String> _titles = const [
    'Smart Scanner',
    'Timeline',
    'Intelligence',
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = MyApp.isDarkMode(context);
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0.5,
        title: Text(
          _titles[_currentIndex],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => MyApp.toggleTheme(context),
            tooltip: isDark ? 'Light Mode' : 'Dark Mode',
          ),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.camera_enhance_outlined),
            selectedIcon: Icon(Icons.camera_enhance),
            label: 'Scanner',
          ),
          NavigationDestination(
            icon: Icon(Icons.timeline_outlined),
            selectedIcon: Icon(Icons.timeline),
            label: 'Timeline',
          ),
          NavigationDestination(
            icon: Icon(Icons.lightbulb_outlined),
            selectedIcon: Icon(Icons.lightbulb),
            label: 'Intelligence',
          ),
        ],
      ),
    );
  }
}
