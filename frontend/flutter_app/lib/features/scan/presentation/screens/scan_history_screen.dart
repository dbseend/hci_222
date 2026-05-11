import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/scan_history_item.dart';
import '../../data/repositories/scan_history_repository.dart';

class ScanHistoryScreen extends StatefulWidget {
  const ScanHistoryScreen({super.key});

  @override
  State<ScanHistoryScreen> createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends State<ScanHistoryScreen> {
  final _repo = ScanHistoryRepositoryImpl();
  late Future<List<ScanHistoryItem>> _future;

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
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(10),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: Image.file(
                          File(item.imagePath),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.broken_image_outlined),
                            );
                          },
                        ),
                      ),
                    ),
                    title: const Text(
                      'Captured from camera',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('Saved at ${_format(item.capturedAt)}'),
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
