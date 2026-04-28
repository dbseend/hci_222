// permission_screen.dart
// Purpose: Explains the core iPhone permissions the app needs (camera, photos, location)
//          and prompts the user to grant them before entering the main app.
// Navigation flow: /permission (from splash) → /intro
//                  "Skip" path: shows a warning dialog then also goes to /intro
// Dependencies: AppColors, go_router, permission_handler, kIsWeb (web skips native permission request)

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/constants/app_colors.dart';

typedef OnboardingPermissionRequester =
    Future<Map<Permission, PermissionStatus>> Function();

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key, this.permissionRequester});

  final OnboardingPermissionRequester? permissionRequester;

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  bool _isRequesting = false;
  Map<Permission, PermissionStatus> _statuses = const {};

  // List of (icon, title, description) tuples for each requested iPhone permission.
  static const _permissions = [
    (
      Icons.camera_alt,
      'Camera',
      'Required to scan products and recognize price tags',
    ),
    (
      Icons.location_on,
      'Location',
      'Required to search nearby markets and compare local prices',
    ),
    (
      Icons.photo_library,
      'Photos',
      'Required to choose saved product photos when camera scanning is not available',
    ),
  ];

  Future<Map<Permission, PermissionStatus>> _requestDevicePermissions() {
    if (widget.permissionRequester != null) {
      return widget.permissionRequester!();
    }

    return [
      Permission.camera,
      Permission.locationWhenInUse,
      Permission.photos,
    ].request();
  }

  Future<void> _handleAllowPressed() async {
    if (kIsWeb) {
      context.go('/intro');
      return;
    }

    setState(() => _isRequesting = true);

    final statuses = await _requestDevicePermissions();
    if (!mounted) return;

    setState(() {
      _statuses = statuses;
      _isRequesting = false;
    });

    final cameraStatus = statuses[Permission.camera];
    final locationStatus = statuses[Permission.locationWhenInUse];
    final photosStatus = statuses[Permission.photos];
    final hasBlockedPermission = [
      cameraStatus,
      locationStatus,
      photosStatus,
    ].any((status) => status?.isPermanentlyDenied ?? false);

    if (hasBlockedPermission) {
      _showSettingsDialog(context);
      return;
    }

    if (cameraStatus?.isGranted ?? false) {
      context.go('/intro');
      return;
    }

    _showCameraRequiredDialog(context);
  }

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

  void _showCameraRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Camera permission required'),
        content: const Text(
          'Camera permission is required to scan products. Please allow camera access to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Permission blocked'),
        content: const Text(
          'One or more permissions are blocked. Open app settings and allow permissions to use all features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open settings'),
          ),
        ],
      ),
    );
  }

  PermissionStatus? _statusForTitle(String title) {
    return switch (title) {
      'Camera' => _statuses[Permission.camera],
      'Location' => _statuses[Permission.locationWhenInUse],
      'Photos' => _statuses[Permission.photos],
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ListView(
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
                'The following iPhone permissions are needed\nfor the best experience',
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
                  status: _statusForTitle(p.$2),
                ),
              )),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isRequesting ? null : _handleAllowPressed,
                // On web, native permission APIs are not available, so skip the request label
                child: _isRequesting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        kIsWeb
                            ? 'Get Started'
                            : 'Allow permissions & get started',
                      ),
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
  final PermissionStatus? status;

  const _PermissionItem({
    required this.icon,
    required this.title,
    required this.desc,
    this.status,
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
            color: Colors.black.withValues(alpha: 0.05),
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
              color: AppColors.primary.withValues(alpha: 0.1),
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
          if (status != null) ...[
            const SizedBox(width: 12),
            Icon(
              status!.isGranted ? Icons.check_circle : Icons.error_outline,
              color: status!.isGranted ? AppColors.primary : Colors.orange,
              size: 22,
            ),
          ],
        ],
      ),
    );
  }
}
