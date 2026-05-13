import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/location_service.dart';
import '../../data/models/scan_history_item.dart';
import '../../data/repositories/scan_history_repository.dart';
import '../../data/repositories/scan_repository.dart';
import '../models/scan_route_data.dart';

class ScanHistoryScreen extends StatefulWidget {
  const ScanHistoryScreen({super.key});

  @override
  State<ScanHistoryScreen> createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends State<ScanHistoryScreen> {
  final _repo = ScanHistoryRepositoryImpl();
  final _scanRepo = ScanRepositoryImpl();
  final _location = LocationService();
  late Future<List<ScanHistoryItem>> _future;
  String? _detectingId;

  @override
  void initState() {
    super.initState();
    _future = _repo.getHistory();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _repo.getHistory();
    });
  }

  String _format(DateTime dt) {
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$mm/$dd $hh:$min';
  }

  Future<void> _detectFromHistory(ScanHistoryItem item) async {
    if (_detectingId != null) return;

    final cached = item.detectionResult;
    if (cached != null) {
      final routeData = ScanRouteData(
        productName: cached.productName,
        productId: cached.productId,
        detectedPrice: cached.detectedPrice,
        inputPrice: item.quotedUnitPriceEgp ?? 0,
        capturedImagePath: item.imagePath.isNotEmpty ? item.imagePath : null,
        historyId: item.id,
      );
      context.go(
        item.hasQuotedPrice ? '/scan/analysis' : '/scan/stats',
        extra: routeData,
      );
      return;
    }

    setState(() => _detectingId = item.id);
    try {
      final image = await _repo.resolveImageFile(item);
      final pos = await _location.getCurrentLocation();
      final result = await _scanRepo.detectObject(
        image: image,
        lat: pos.lat,
        lon: pos.lon,
      );
      await _repo.updateDetection(historyId: item.id, result: result);
      if (!mounted) return;
      context.go(
        '/scan/stats',
        extra: ScanRouteData(
          productName: result.productName,
          productId: result.productId,
          detectedPrice: result.detectedPrice,
          capturedImagePath: image.path,
          historyId: item.id,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to detect product from history. ($e)'),
          backgroundColor: AppColors.warning,
        ),
      );
    } finally {
      if (mounted) setState(() => _detectingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan History'),
        actions: [
          IconButton(
            onPressed: () async {
              await _repo.clearHistory();
              if (!mounted) return;
              await _reload();
            },
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: FutureBuilder<List<ScanHistoryItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return const Center(
              child: Text(
                'No captured photos yet.',
                style: TextStyle(color: AppColors.onSurfaceLight),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = items[index];
                final isDetecting = _detectingId == item.id;
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(10),
                    onTap: isDetecting ? null : () => _detectFromHistory(item),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: _HistoryImage(item: item),
                      ),
                    ),
                    title: Text(
                      item.detectionResult?.productName ??
                          'Captured from camera',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      item.hasQuotedPrice
                          ? 'Saved price ${item.quotedUnitPriceEgp!.toStringAsFixed(0)} EGP · ${_format(item.capturedAt)}'
                          : 'Saved at ${_format(item.capturedAt)}',
                    ),
                    trailing: isDetecting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_forward_ios, size: 16),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _HistoryImage extends StatelessWidget {
  final ScanHistoryItem item;

  const _HistoryImage({required this.item});

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.imageUrl;
    if (item.imagePath.isNotEmpty) {
      return Image.file(
        File(item.imagePath),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _networkOrFallback(imageUrl),
      );
    }
    return _networkOrFallback(imageUrl);
  }

  Widget _networkOrFallback(String? imageUrl) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      color: Colors.grey.shade200,
      child: const Icon(Icons.broken_image_outlined),
    );
  }
}
