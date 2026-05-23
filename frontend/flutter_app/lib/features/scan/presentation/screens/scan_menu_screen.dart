import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../models/scan_route_data.dart';

class ScanMenuScreen extends StatelessWidget {
  const ScanMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Price Check')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            _ScanModeTile(
              icon: Icons.camera_alt,
              title: 'Camera scan',
              subtitle: 'Recognize a supported product from the camera.',
              color: AppColors.primary,
              onTap: () => context.go('/scan/camera'),
            ),
            const SizedBox(height: 12),
            _ScanModeTile(
              icon: Icons.search,
              title: 'Product search',
              subtitle:
                  'Search supported products with Cairo reference prices.',
              color: const Color(0xFF1565C0),
              onTap: () => context.go('/scan/search'),
            ),
            const SizedBox(height: 12),
            _ScanModeTile(
              icon: Icons.edit,
              title: 'Manual price input',
              subtitle: 'Enter a quote directly when no product is selected.',
              color: const Color(0xFF6A1B9A),
              onTap: () =>
                  context.go('/scan/input', extra: const ScanRouteData()),
            ),
            const SizedBox(height: 12),
            _ScanModeTile(
              icon: Icons.history,
              title: 'Scan history',
              subtitle: 'Review recent detected products and entered prices.',
              color: const Color(0xFF455A64),
              onTap: () => context.go('/scan/history'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanModeTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ScanModeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: AppColors.onSurfaceLight,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.onSurfaceLight),
            ],
          ),
        ),
      ),
    );
  }
}
