// bottom_nav_bar.dart
// Purpose: Shared bottom navigation bar used by the main ShellRoute (_MainShell in router.dart).
//          Highlights the active tab based on the current route and navigates via go_router.
// Tabs (index → route): 0=/scan, 1=/map, 2=/language, 3=/community
// Dependencies: AppColors, go_router

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';

class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;

  const AppBottomNavBar({super.key, required this.currentIndex});

  static const _routes = ['/scan', '/map', '/language', '/community'];

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.onSurfaceLight,
      backgroundColor: AppColors.surface,
      elevation: 8,
      onTap: (i) => context.go(_routes[i]),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.camera_alt_outlined),
          activeIcon: Icon(Icons.camera_alt),
          label: 'Scan',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.map_outlined),
          activeIcon: Icon(Icons.map),
          label: 'Map',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.translate_outlined),
          activeIcon: Icon(Icons.translate),
          label: 'Phrases',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.people_outline),
          activeIcon: Icon(Icons.people),
          label: 'Community',
        ),
      ],
    );
  }
}
