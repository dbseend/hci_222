import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/scan_history_item.dart';

abstract class ScanHistoryRepository {
  Future<String?> addCapturedImage(File image);
  Future<List<ScanHistoryItem>> getHistory();
  Future<void> clearHistory();
}

class ScanHistoryRepositoryImpl implements ScanHistoryRepository {
  static const _storageKey = 'scan_history_items';

  final Future<SharedPreferences> Function() _prefsProvider;
  final Future<Directory> Function() _directoryProvider;
  final int maxItems;

  ScanHistoryRepositoryImpl({
    Future<SharedPreferences> Function()? prefsProvider,
    Future<Directory> Function()? directoryProvider,
    this.maxItems = 50,
  }) : _prefsProvider = prefsProvider ?? SharedPreferences.getInstance,
       _directoryProvider =
           directoryProvider ?? getApplicationDocumentsDirectory;

  @override
  Future<String?> addCapturedImage(File image) async {
    if (!await image.exists()) return null;

    final historyDir = await _historyDirectory();
    final now = DateTime.now();
    final ext = _fileExtension(image.path);
    final id = 'capture_${now.millisecondsSinceEpoch}';
    final copiedPath = '${historyDir.path}/$id$ext';

    final copied = await image.copy(copiedPath);

    final current = await getHistory();
    final next = [
      ScanHistoryItem(id: id, imagePath: copied.path, capturedAt: now),
      ...current,
    ];

    final trimmed = next.take(maxItems).toList();
    final overflow = next.skip(maxItems);
    for (final item in overflow) {
      final file = File(item.imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    }

    await _save(trimmed);
    return copied.path;
  }

  @override
  Future<List<ScanHistoryItem>> getHistory() async {
    final prefs = await _prefsProvider();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final items =
          decoded
              .map((e) => ScanHistoryItem.fromJson(e as Map<String, dynamic>))
              .where((item) => item.imagePath.isNotEmpty)
              .toList()
            ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
      return items;
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> clearHistory() async {
    final items = await getHistory();
    for (final item in items) {
      final file = File(item.imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    final prefs = await _prefsProvider();
    await prefs.remove(_storageKey);
  }

  Future<Directory> _historyDirectory() async {
    final root = await _directoryProvider();
    final dir = Directory('${root.path}/scan_history');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<void> _save(List<ScanHistoryItem> items) async {
    final prefs = await _prefsProvider();
    final raw = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, raw);
  }

  String _fileExtension(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot == path.length - 1) return '.jpg';
    return path.substring(dot);
  }
}
