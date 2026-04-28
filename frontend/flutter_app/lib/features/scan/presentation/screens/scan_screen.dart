import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/constants/app_colors.dart';
import '../models/scan_route_data.dart';
import '../bloc/scan_bloc.dart';
import '../bloc/scan_event.dart';
import '../bloc/scan_state.dart';

class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(create: (_) => ScanBloc(), child: const _ScanView());
  }
}

class _ScanView extends StatefulWidget {
  const _ScanView();

  @override
  State<_ScanView> createState() => _ScanViewState();
}

class _ScanViewState extends State<_ScanView> {
  final _picker = ImagePicker();
  CameraController? _cameraController;
  bool _isInitializingCamera = false;
  bool _hasCameraPermission = true;
  String? _cameraError;
  bool _flashOn = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    if (kIsWeb) return;

    setState(() {
      _isInitializingCamera = true;
      _cameraError = null;
    });

    final status = await Permission.camera.status;
    if (!status.isGranted) {
      if (!mounted) return;
      setState(() {
        _hasCameraPermission = false;
        _isInitializingCamera = false;
      });
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('no_camera', 'No camera found on this device.');
      }

      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _hasCameraPermission = true;
        _isInitializingCamera = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraError = 'Failed to start camera. Please try again. ($e)';
        _isInitializingCamera = false;
      });
    }
  }

  Future<void> _captureAndScan() async {
    final controller = _cameraController;
    if (kIsWeb) {
      context.read<ScanBloc>().add(const ScanWebMockRequested());
      return;
    }
    if (controller == null || !controller.value.isInitialized) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Camera is not ready yet.')));
      return;
    }
    if (controller.value.isTakingPicture) return;

    try {
      final image = await controller.takePicture();
      if (!mounted) return;
      context.read<ScanBloc>().add(ScanImageCaptured(File(image.path)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to capture image. ($e)'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  Future<void> _toggleFlash() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    final next = !_flashOn;
    await controller.setFlashMode(next ? FlashMode.torch : FlashMode.off);
    if (!mounted) return;
    setState(() => _flashOn = next);
  }

  Future<void> _pickAndScan(ImageSource source) async {
    // Camera not supported on web — fall back to gallery
    final effectiveSource = (kIsWeb && source == ImageSource.camera)
        ? ImageSource.gallery
        : source;

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
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
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
                onPressed: () =>
                    context.read<ScanBloc>().add(const ScanReset()),
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
                _buildCameraLayer(context),

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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
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
                            icon: Icon(
                              _flashOn ? Icons.flash_on : Icons.flash_off,
                              color: Colors.white,
                            ),
                            onPressed: _toggleFlash,
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
                                  onTap: () =>
                                      _pickAndScan(ImageSource.gallery),
                                  small: true,
                                ),
                                _ScanButton(
                                  icon: Icons.camera_alt,
                                  label: 'Scan',
                                  onTap: _captureAndScan,
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
            top: top
                ? const BorderSide(color: AppColors.scanLine, width: 3)
                : BorderSide.none,
            bottom: !top
                ? const BorderSide(color: AppColors.scanLine, width: 3)
                : BorderSide.none,
            left: left
                ? const BorderSide(color: AppColors.scanLine, width: 3)
                : BorderSide.none,
            right: !left
                ? const BorderSide(color: AppColors.scanLine, width: 3)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildCameraLayer(BuildContext context) {
    final controller = _cameraController;

    if (kIsWeb) {
      return _CameraMessage(
        icon: Icons.photo_library,
        title: 'Camera preview is not available on web',
        message: 'Use Gallery to load a demo image.',
        actionLabel: null,
        onAction: null,
      );
    }

    if (!_hasCameraPermission) {
      return _CameraMessage(
        icon: Icons.lock_outline,
        title: 'Camera permission required',
        message: 'Allow camera access in Settings to scan products here.',
        actionLabel: 'Open Settings',
        onAction: openAppSettings,
      );
    }

    if (_isInitializingCamera) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.scanLine),
        ),
      );
    }

    if (_cameraError != null) {
      return _CameraMessage(
        icon: Icons.error_outline,
        title: 'Camera unavailable',
        message: _cameraError!,
        actionLabel: 'Retry',
        onAction: _initCamera,
      );
    }

    if (controller == null || !controller.value.isInitialized) {
      return _CameraMessage(
        icon: Icons.camera_alt,
        title: 'Preparing camera',
        message: 'Hold on while the camera starts.',
        actionLabel: 'Retry',
        onAction: _initCamera,
      );
    }

    final size = MediaQuery.sizeOf(context);
    final scale = 1 / (controller.value.aspectRatio * size.aspectRatio);

    return ClipRect(
      child: Transform.scale(
        scale: scale < 1 ? 1 : scale,
        child: Center(child: CameraPreview(controller)),
      ),
    );
  }
}

class _CameraMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _CameraMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 72, color: Colors.white.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: Colors.white70, height: 1.4),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
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
              color: small
                  ? Colors.white.withValues(alpha: 0.15)
                  : AppColors.scanLine,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white30, width: 1),
            ),
            child: Icon(icon, color: Colors.white, size: small ? 24 : 32),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
