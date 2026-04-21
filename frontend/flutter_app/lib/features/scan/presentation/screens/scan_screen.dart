import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../models/scan_route_data.dart';
import '../bloc/scan_bloc.dart';
import '../bloc/scan_event.dart';
import '../bloc/scan_state.dart';

class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ScanBloc(),
      child: const _ScanView(),
    );
  }
}

class _ScanView extends StatefulWidget {
  const _ScanView();

  @override
  State<_ScanView> createState() => _ScanViewState();
}

class _ScanViewState extends State<_ScanView> {
  final _picker = ImagePicker();

  Future<void> _pickAndScan(ImageSource source) async {
    // Camera not supported on web — fall back to gallery
    final effectiveSource =
        (kIsWeb && source == ImageSource.camera) ? ImageSource.gallery : source;

    if (kIsWeb && source == ImageSource.camera) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('On web, please select an image from the gallery.'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    final picked = await _picker.pickImage(source: effectiveSource);
    if (picked == null || !mounted) return;

    // Web: XFile.path is a blob URL — File() cannot be used; handle via bytes
    if (kIsWeb) {
      // On web, skip passing a File to ScanBloc and go straight to a mock result
      context.read<ScanBloc>().add(const ScanWebMockRequested());
    } else {
      context.read<ScanBloc>().add(ScanImageCaptured(File(picked.path)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ScanBloc, ScanState>(
      listener: (context, state) {
        if (state is ScanDetected) {
          context.read<ScanBloc>().add(const ScanReset());
          context.go(
            '/scan/stats',
            extra: ScanRouteData(
              productName: state.result.productName,
              productId: state.result.productId,
              detectedPrice: state.result.detectedPrice,
            ),
          );
        } else if (state is ScanError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.warning,
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () => context.read<ScanBloc>().add(const ScanReset()),
              ),
            ),
          );
        }
      },
      child: BlocBuilder<ScanBloc, ScanState>(
        builder: (context, state) {
          final isProcessing = state is ScanProcessing;

          return Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              fit: StackFit.expand,
              children: [
                // Camera viewfinder (demo mode — real camera not connected)
                // TODO: replace with CameraPreview widget from the camera package
                Container(
                  color: Colors.black87,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_alt,
                          size: 80,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Center the product in the frame',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Demo mode — select a gallery image to get sample results',
                            style:
                                TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Scan overlay frame
                Center(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.scanLine, width: 2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Stack(
                      children: [
                        _corner(Alignment.topLeft, true, true),
                        _corner(Alignment.topRight, true, false),
                        _corner(Alignment.bottomLeft, false, true),
                        _corner(Alignment.bottomRight, false, false),
                      ],
                    ),
                  ),
                ),

                // Top AppBar
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          const Text(
                            'Burası True Price',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.flash_off, color: Colors.white),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Processing indicator
                if (isProcessing)
                  Container(
                    color: AppColors.overlay,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: AppColors.scanLine),
                          SizedBox(height: 16),
                          Text(
                            '[DEMO] Loading sample price data...',
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Bottom buttons
                if (!isProcessing)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        child: Column(
                          children: [
                            TextButton(
                              onPressed: () => context.go(
                                '/scan/input',
                                extra: const ScanRouteData(),
                              ),
                              child: const Text(
                                'Enter price manually',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _ScanButton(
                                  icon: Icons.photo_library,
                                  label: 'Gallery',
                                  onTap: () => _pickAndScan(ImageSource.gallery),
                                  small: true,
                                ),
                                _ScanButton(
                                  icon: Icons.camera_alt,
                                  label: 'Scan',
                                  onTap: () => _pickAndScan(ImageSource.camera),
                                  small: false,
                                ),
                                _ScanButton(
                                  icon: Icons.history,
                                  label: 'History',
                                  onTap: () {},
                                  small: true,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _corner(Alignment align, bool top, bool left) {
    return Align(
      alignment: align,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          border: Border(
            top: top ? const BorderSide(color: AppColors.scanLine, width: 3) : BorderSide.none,
            bottom: !top ? const BorderSide(color: AppColors.scanLine, width: 3) : BorderSide.none,
            left: left ? const BorderSide(color: AppColors.scanLine, width: 3) : BorderSide.none,
            right: !left ? const BorderSide(color: AppColors.scanLine, width: 3) : BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _ScanButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool small;

  const _ScanButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.small,
  });

  @override
  Widget build(BuildContext context) {
    final size = small ? 56.0 : 72.0;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: small ? Colors.white.withOpacity(0.15) : AppColors.scanLine,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white30, width: 1),
            ),
            child: Icon(icon, color: Colors.white, size: small ? 24 : 32),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}
