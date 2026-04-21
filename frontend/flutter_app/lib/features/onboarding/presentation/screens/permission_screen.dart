// permission_screen.dart
// Purpose: Explains the three permissions the app needs (camera, location, mic)
//          and prompts the user to grant them before entering the main app.
// Navigation flow: /permission (from splash) → /intro
//                  "Skip" path: shows a warning dialog then also goes to /intro
// Dependencies: AppColors, go_router, kIsWeb (web skips native permission request)

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';

class PermissionScreen extends StatelessWidget {
  const PermissionScreen({super.key});

  // List of (icon, title, description) tuples for each required permission
  static const _permissions = [
    (Icons.camera_alt, 'Camera', 'Required to scan products and recognize price tags'),
    (Icons.location_on, 'Location', 'Required to search nearby markets and compare local prices'),
    (Icons.mic, 'Microphone', 'Required to play Arabic pronunciation guides'),
  ];

  /// Shows a warning dialog when the user tries to proceed without granting location permission.
  /// Informs the user that region-specific features will be disabled and Cairo defaults will be used.
  void _showLocationWarning(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Continue without location permission?'),
        content: const Text(
          'Without location permission, the following features will be limited:\n\n'
          '• Real-time price comparison by region\n'
          '• Nearby market map\n\n'
          'Default data for Cairo, Egypt will be shown instead.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Go back'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/intro');
            },
            child: const Text(
              'Continue with limited features',
              style: TextStyle(color: AppColors.onSurfaceLight),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const Text(
                'App Permissions',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'The following permissions are required\nfor the best experience',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.onSurfaceLight,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              ...(_permissions.map(
                (p) => _PermissionItem(
                  icon: p.$1,
                  title: p.$2,
                  desc: p.$3,
                ),
              )),
              const Spacer(),
              ElevatedButton(
                onPressed: () => context.go('/intro'),
                // On web, native permission APIs are not available, so skip the request label
                child: Text(kIsWeb ? 'Get Started' : 'Allow permissions & get started'),
              ),
              if (!kIsWeb) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => _showLocationWarning(context),
                  child: const Text(
                    'Set up later',
                    style: TextStyle(color: AppColors.onSurfaceLight),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;

  const _PermissionItem({
    required this.icon,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.onSurfaceLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
