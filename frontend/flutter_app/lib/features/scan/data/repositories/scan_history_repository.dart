import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/services/user_id_service.dart';
import '../models/scan_history_item.dart';

abstract class ScanHistoryRepository {
  Future<String?> addCapturedImage(File image);
  Future<List<ScanHistoryItem>> getHistory();
  Future<File> resolveImageFile(ScanHistoryItem item);
  Future<void> clearHistory();
}

class ScanHistoryRepositoryImpl implements ScanHistoryRepository {
  static const _storageKey = 'scan_history_items';

  final Future<SharedPreferences> Function() _prefsProvider;
  final Future<Directory> Function() _directoryProvider;
  final Dio _dio;
  final int maxItems;

  ScanHistoryRepositoryImpl({
    Future<SharedPreferences> Function()? prefsProvider,
    Future<Directory> Function()? directoryProvider,
    Dio? dio,
    this.maxItems = 50,
  }) : _prefsProvider = prefsProvider ?? SharedPreferences.getInstance,
       _directoryProvider =
           directoryProvider ?? getApplicationDocumentsDirectory,
       _dio = dio ?? DioClient.instance;

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
    final localItem = ScanHistoryItem(
      id: id,
      imagePath: copied.path,
      capturedAt: now,
    );
    final next = [localItem, ...current];

    final trimmed = next.take(maxItems).toList();
    final overflow = next.skip(maxItems);
    for (final item in overflow) {
      if (item.imagePath.isEmpty) continue;
      final file = File(item.imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    }

    await _save(trimmed);

    final uploaded = await _uploadHistoryImage(copied);
    if (uploaded != null) {
      final synced = trimmed
          .map(
            (item) => item.id == id
                ? item.copyWith(
                    id: uploaded.id.isNotEmpty ? uploaded.id : item.id,
                    remoteImagePath: uploaded.remoteImagePath,
                    imageUrl: uploaded.imageUrl,
                  )
                : item,
          )
          .toList();
      await _save(synced);
    }

    return copied.path;
  }

  @override
  Future<List<ScanHistoryItem>> getHistory() async {
    final localItems = await _getLocalHistory();
    final remoteItems = await _fetchRemoteHistory();
    if (remoteItems.isEmpty) return localItems;
    return _mergeHistory(localItems, remoteItems);
  }

  @override
  Future<File> resolveImageFile(ScanHistoryItem item) async {
    if (item.imagePath.isNotEmpty) {
      final local = File(item.imagePath);
      if (await local.exists()) return local;
    }

    final imageUrl = item.imageUrl;
    if (imageUrl == null || imageUrl.isEmpty) {
      throw StateError('History image is not available locally or remotely.');
    }

    final dir = await _historyDirectory();
    final ext = _fileExtension(item.remoteImagePath ?? imageUrl);
    final target = File('${dir.path}/${item.id}_remote$ext');
    if (await target.exists()) return target;

    final response = await _dio.get<List<int>>(
      imageUrl,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Downloaded history image is empty.');
    }
    return target.writeAsBytes(bytes);
  }

  @override
  Future<void> clearHistory() async {
    final items = await _getLocalHistory();
    for (final item in items) {
      if (item.imagePath.isEmpty) continue;
      final file = File(item.imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    final prefs = await _prefsProvider();
    await prefs.remove(_storageKey);
  }

  Future<List<ScanHistoryItem>> _getLocalHistory() async {
    final prefs = await _prefsProvider();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final items =
          decoded
              .map((e) => ScanHistoryItem.fromJson(e as Map<String, dynamic>))
              .where((item) => item.canDisplay)
              .toList()
            ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
      return items;
    } catch (_) {
      return const [];
    }
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

  Future<ScanHistoryItem?> _uploadHistoryImage(File image) async {
    try {
      final clientUserId = await UserIdService.getOrCreate();
      final formData = FormData.fromMap({
        'client_user_id': clientUserId,
        'image': await MultipartFile.fromFile(
          image.path,
          filename: image.uri.pathSegments.isNotEmpty
              ? image.uri.pathSegments.last
              : 'scan.jpg',
        ),
      });
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.scanHistory,
        data: formData,
      );
      final data = response.data;
      if (data == null) return null;
      return ScanHistoryItem.fromApiJson(data);
    } catch (_) {
      // Keep local history even if remote history sync is unavailable.
      return null;
    }
  }

  Future<List<ScanHistoryItem>> _fetchRemoteHistory() async {
    try {
      final clientUserId = await UserIdService.getOrCreate();
      final response = await _dio.get<List<dynamic>>(
        ApiEndpoints.scanHistory,
        queryParameters: {'client_user_id': clientUserId, 'limit': maxItems},
      );
      final data = response.data ?? const [];
      return data
          .map((e) => ScanHistoryItem.fromApiJson(e as Map<String, dynamic>))
          .where((item) => item.canDisplay)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  List<ScanHistoryItem> _mergeHistory(
    List<ScanHistoryItem> localItems,
    List<ScanHistoryItem> remoteItems,
  ) {
    final localByRemotePath = {
      for (final item in localItems)
        if (item.remoteImagePath?.isNotEmpty ?? false)
          item.remoteImagePath!: item,
    };
    final merged = <ScanHistoryItem>[
      for (final remote in remoteItems)
        localByRemotePath[remote.remoteImagePath]?.copyWith(
              id: remote.id,
              imageUrl: remote.imageUrl,
              capturedAt: remote.capturedAt,
            ) ??
            remote,
      for (final local in localItems)
        if (!(local.remoteImagePath?.isNotEmpty ?? false) ||
            !remoteItems.any(
              (remote) => remote.remoteImagePath == local.remoteImagePath,
            ))
          local,
    ]..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));

    return merged.take(maxItems).toList();
  }

  String _fileExtension(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot == path.length - 1) return '.jpg';
    return path.substring(dot);
  }
}
