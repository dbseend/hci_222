import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/repositories/scan_history_repository.dart';
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
  static const Duration _cameraInitTimeout = Duration(seconds: 8);
  final _picker = ImagePicker();
  final _historyRepo = ScanHistoryRepositoryImpl();
  CameraController? _cameraController;
  bool _isInitializingCamera = false;
  bool _hasCameraPermission = true;
  String? _cameraError;
  bool _flashOn = false;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _currentZoom = 1.0;
  double _zoomAtGestureStart = 1.0;
  String? _latestCapturedImagePath;

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
      await _cameraController?.dispose();
      _cameraController = null;

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
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize().timeout(_cameraInitTimeout);
      await controller.setFlashMode(FlashMode.off);
      final minZoom = await controller.getMinZoomLevel();
      final maxZoom = await controller.getMaxZoomLevel();
      final initialZoom = minZoom.clamp(minZoom, maxZoom).toDouble();
      await controller.setZoomLevel(initialZoom);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _hasCameraPermission = true;
        _isInitializingCamera = false;
        _flashOn = false;
        _minZoom = minZoom;
        _maxZoom = maxZoom;
        _currentZoom = initialZoom;
        _zoomAtGestureStart = initialZoom;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final timedOut = e is TimeoutException;
        _cameraError = timedOut
            ? 'Camera startup timed out. Use Gallery/Manual mode or retry.'
            : 'Failed to start camera. Please try again. ($e)';
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
      try {
        _latestCapturedImagePath = await _historyRepo.addCapturedImage(
          File(image.path),
        );
      } catch (_) {
        // Do not block scan flow if history save fails.
        _latestCapturedImagePath = null;
      }
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

  Future<void> _setZoomLevel(double zoom) async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    final nextZoom = zoom.clamp(_minZoom, _maxZoom).toDouble();
    if ((nextZoom - _currentZoom).abs() < 0.01) return;

    try {
      if (!mounted) return;
      setState(() => _currentZoom = nextZoom);
      await controller.setZoomLevel(nextZoom);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to change zoom. ($e)'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  void _handleZoomScaleStart(ScaleStartDetails details) {
    _zoomAtGestureStart = _currentZoom;
  }

  void _handleZoomScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount < 2 || _maxZoom <= _minZoom) return;

    final nextZoom = calculatePinchZoom(
      baseZoom: _zoomAtGestureStart,
      scale: details.scale,
      minZoom: _minZoom,
      maxZoom: _maxZoom,
    );
    unawaited(_setZoomLevel(nextZoom));
  }

  Future<void> _pickAndScan(ImageSource source) async {
    _latestCapturedImagePath = null;

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
          if (_latestCapturedImagePath != null) {
            unawaited(
              _historyRepo.updateDetection(
                imagePath: _latestCapturedImagePath,
                result: state.result,
              ),
            );
          }
          context.go(
            '/scan/stats',
            extra: ScanRouteData(
              productName: state.result.productName,
              productId: state.result.productId,
              detectedPrice: state.result.detectedPrice,
              capturedImagePath: _latestCapturedImagePath,
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
                            'Detecting product...',
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
                                  onTap: () => context.go('/scan/history'),
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
        actionLabel: null,
        onAction: null,
        bottomActions: [
          _CameraAction(label: 'Retry camera', onPressed: _initCamera),
          _CameraAction(
            label: 'Open gallery',
            onPressed: () => _pickAndScan(ImageSource.gallery),
          ),
          _CameraAction(
            label: 'Enter price manually',
            onPressed: () =>
                context.go('/scan/input', extra: const ScanRouteData()),
          ),
        ],
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

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: _handleZoomScaleStart,
      onScaleUpdate: _handleZoomScaleUpdate,
      child: ClipRect(
        child: Transform.scale(
          scale: scale < 1 ? 1 : scale,
          child: Center(child: CameraPreview(controller)),
        ),
      ),
    );
  }
}

@visibleForTesting
double calculatePinchZoom({
  required double baseZoom,
  required double scale,
  required double minZoom,
  required double maxZoom,
}) {
  final safeMin = minZoom <= maxZoom ? minZoom : maxZoom;
  final safeMax = maxZoom >= minZoom ? maxZoom : minZoom;
  return (baseZoom * scale).clamp(safeMin, safeMax).toDouble();
}

class _CameraMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final List<_CameraAction> bottomActions;

  const _CameraMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.bottomActions = const [],
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
          if (bottomActions.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...bottomActions.map(
              (action) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton(
                  onPressed: action.onPressed,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                  ),
                  child: Text(action.label),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CameraAction {
  final String label;
  final VoidCallback onPressed;

  const _CameraAction({required this.label, required this.onPressed});
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
