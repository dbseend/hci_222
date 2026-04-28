import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _items = [
    _HomeItem(
      title: 'Price Check',
      subtitle: 'Scan products or check camel ride offers',
      route: '/scan',
      icon: Icons.camera_alt,
      color: AppColors.primary,
    ),
    _HomeItem(
      title: 'Market Map',
      subtitle: 'Find nearby markets and local price areas',
      route: '/map',
      icon: Icons.map,
      color: Color(0xFF1565C0),
    ),
    _HomeItem(
      title: 'Phrases',
      subtitle: 'Use quick Arabic phrases for bargaining',
      route: '/language',
      icon: Icons.translate,
      color: Color(0xFFEF6C00),
    ),
    _HomeItem(
      title: 'Community',
      subtitle: 'Check shared traveler price reports',
      route: '/community',
      icon: Icons.people,
      color: Color(0xFF6A1B9A),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          children: [
            const Text(
              'Burası True Price',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose what you want to check before bargaining.',
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: AppColors.onSurfaceLight,
              ),
            ),
            const SizedBox(height: 28),
            ..._items.map((item) => _HomeFeatureCard(item: item)),
          ],
        ),
      ),
    );
  }
}

class _HomeFeatureCard extends StatelessWidget {
  final _HomeItem item;

  const _HomeFeatureCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () => context.go(item.route),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(item.icon, color: item.color, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item.subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: AppColors.onSurfaceLight,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.onSurfaceLight,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeItem {
  final String title;
  final String subtitle;
  final String route;
  final IconData icon;
  final Color color;

  const _HomeItem({
    required this.title,
    required this.subtitle,
    required this.route,
    required this.icon,
    required this.color,
  });
}
