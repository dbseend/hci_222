import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../models/detection_result.dart';
import '../models/scan_history_item.dart';

abstract class ScanHistoryRepository {
  Future<String?> addCapturedImage(File image);
  Future<List<ScanHistoryItem>> getHistory();
  Future<File> resolveImageFile(ScanHistoryItem item);
  Future<void> updateDetection({
    String? historyId,
    String? imagePath,
    required DetectionResult result,
  });
  Future<void> updateQuotedPrice({
    String? historyId,
    String? imagePath,
    required double totalPrice,
    required double quantity,
    required String unit,
    required double unitPrice,
  });
  Future<void> clearHistory();
}

class ScanHistoryRepositoryImpl implements ScanHistoryRepository {
  static const _storageKey = 'scan_history_items';

  final Future<SharedPreferences> Function() _prefsProvider;
  final Future<Directory> Function() _directoryProvider;
  final Dio _dio;
  final void Function(String operation, Object error, StackTrace stackTrace)?
  _onSyncError;
  final Set<String> _uploadsInFlight = <String>{};
  final int maxItems;

  ScanHistoryRepositoryImpl({
    Future<SharedPreferences> Function()? prefsProvider,
    Future<Directory> Function()? directoryProvider,
    Dio? dio,
    void Function(String operation, Object error, StackTrace stackTrace)?
    onSyncError,
    this.maxItems = 50,
  }) : _prefsProvider = prefsProvider ?? SharedPreferences.getInstance,
       _directoryProvider =
           directoryProvider ?? getApplicationDocumentsDirectory,
       _dio = dio ?? DioClient.instance,
       _onSyncError = onSyncError;

  @override
  Future<String?> addCapturedImage(File image) async {
    if (!await image.exists()) return null;

    final historyDir = await _historyDirectory();
    final now = DateTime.now();
    final ext = _fileExtension(image.path);
    final id = 'capture_${now.millisecondsSinceEpoch}';
    final copiedPath = '${historyDir.path}/$id$ext';

    final copied = await image.copy(copiedPath);

    final current = await _getLocalHistory();
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

    _scheduleUpload(localId: id, localImagePath: copied.path, image: copied);

    return copied.path;
  }

  Future<void> _syncUploadedHistoryItem({
    required String localId,
    required String localImagePath,
    required File image,
  }) async {
    try {
      final uploaded = await _uploadHistoryImage(image);
      if (uploaded == null) return;
      final current = await _findHistoryItem(
        historyId: localId,
        imagePath: localImagePath,
      );
      if (current == null) return;

      final synced = uploaded.copyWith(
        imagePath: current.imagePath,
        capturedAt: current.capturedAt,
        detectionResult: current.detectionResult,
        quotedTotalPriceEgp: current.quotedTotalPriceEgp,
        quotedQuantity: current.quotedQuantity,
        quotedUnit: current.quotedUnit,
        quotedUnitPriceEgp: current.quotedUnitPriceEgp,
      );
      await _replaceLocalItem(current, synced);

      final detection = current.detectionResult;
      if (detection != null && synced.id.isNotEmpty) {
        unawaited(updateDetection(historyId: synced.id, result: detection));
      }
      if (current.hasQuotedPrice && synced.id.isNotEmpty) {
        unawaited(
          updateQuotedPrice(
            historyId: synced.id,
            totalPrice: current.quotedTotalPriceEgp!,
            quantity: current.quotedQuantity ?? 1,
            unit: current.quotedUnit ?? 'kg',
            unitPrice: current.quotedUnitPriceEgp!,
          ),
        );
      }
    } catch (error, stackTrace) {
      _reportSyncError('sync_uploaded_history', error, stackTrace);
    }
  }

  void _scheduleUpload({
    required String localId,
    required String localImagePath,
    required File image,
  }) {
    if (!_uploadsInFlight.add(localImagePath)) return;
    unawaited(
      _syncUploadedHistoryItem(
        localId: localId,
        localImagePath: localImagePath,
        image: image,
      ).whenComplete(() => _uploadsInFlight.remove(localImagePath)),
    );
  }

  @override
  Future<List<ScanHistoryItem>> getHistory() async {
    final localItems = await _getLocalHistory();
    for (final item in localItems) {
      if (item.remoteImagePath?.isNotEmpty ?? false) continue;
      if (item.imagePath.isEmpty) continue;
      final image = File(item.imagePath);
      if (await image.exists()) {
        _scheduleUpload(
          localId: item.id,
          localImagePath: item.imagePath,
          image: image,
        );
      }
    }
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
  Future<void> updateDetection({
    String? historyId,
    String? imagePath,
    required DetectionResult result,
  }) async {
    final item = await _findHistoryItem(
      historyId: historyId,
      imagePath: imagePath,
    );
    final remoteId =
        historyId ??
        ((item?.remoteImagePath?.isNotEmpty ?? false) ? item?.id : null);
    if (item == null && (remoteId == null || remoteId.isEmpty)) return;

    ScanHistoryItem? updated;
    if (item != null) {
      updated = item.copyWith(detectionResult: result);
      await _replaceLocalItem(item, updated);
    }

    if (remoteId == null || remoteId.isEmpty) return;
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        ApiEndpoints.scanHistoryDetection(remoteId),
        data: result.toJson(),
      );
      final data = response.data;
      if (data != null && item != null && updated != null) {
        await _replaceLocalItem(
          updated,
          ScanHistoryItem.fromApiJson(
            data,
          ).copyWith(imagePath: updated.imagePath),
        );
      }
    } catch (error, stackTrace) {
      _reportSyncError('update_detection', error, stackTrace);
    }
  }

  @override
  Future<void> updateQuotedPrice({
    String? historyId,
    String? imagePath,
    required double totalPrice,
    required double quantity,
    required String unit,
    required double unitPrice,
  }) async {
    final item = await _findHistoryItem(
      historyId: historyId,
      imagePath: imagePath,
    );
    final remoteId =
        historyId ??
        ((item?.remoteImagePath?.isNotEmpty ?? false) ? item?.id : null);
    if (item == null && (remoteId == null || remoteId.isEmpty)) return;

    ScanHistoryItem? updated;
    if (item != null) {
      updated = item.copyWith(
        quotedTotalPriceEgp: totalPrice,
        quotedQuantity: quantity,
        quotedUnit: unit,
        quotedUnitPriceEgp: unitPrice,
      );
      await _replaceLocalItem(item, updated);
    }

    if (remoteId == null || remoteId.isEmpty) return;
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        ApiEndpoints.scanHistoryPrice(remoteId),
        data: {
          'quoted_total_price_egp': totalPrice,
          'quoted_quantity': quantity,
          'quoted_unit': unit,
          'quoted_unit_price_egp': unitPrice,
        },
      );
      final data = response.data;
      if (data != null && item != null && updated != null) {
        await _replaceLocalItem(
          updated,
          ScanHistoryItem.fromApiJson(
            data,
          ).copyWith(imagePath: updated.imagePath),
        );
      }
    } catch (error, stackTrace) {
      _reportSyncError('update_quoted_price', error, stackTrace);
    }
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
    } catch (error, stackTrace) {
      _reportSyncError('read_local_history', error, stackTrace);
      final prefs = await _prefsProvider();
      await prefs.remove(_storageKey);
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

  Future<ScanHistoryItem?> _findHistoryItem({
    String? historyId,
    String? imagePath,
  }) async {
    final items = await _getLocalHistory();
    for (final item in items) {
      if (historyId != null && historyId.isNotEmpty && item.id == historyId) {
        return item;
      }
      if (imagePath != null &&
          imagePath.isNotEmpty &&
          item.imagePath == imagePath) {
        return item;
      }
    }
    return null;
  }

  Future<void> _replaceLocalItem(
    ScanHistoryItem original,
    ScanHistoryItem updated,
  ) async {
    final items = await _getLocalHistory();
    final next =
        items
            .map(
              (item) =>
                  item.id == original.id || item.imagePath == original.imagePath
                  ? updated
                  : item,
            )
            .toList()
          ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    await _save(next);
  }

  Future<ScanHistoryItem?> _uploadHistoryImage(File image) async {
    try {
      final formData = FormData.fromMap({
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
    } catch (error, stackTrace) {
      _reportSyncError('upload_history_image', error, stackTrace);
      return null;
    }
  }

  Future<List<ScanHistoryItem>> _fetchRemoteHistory() async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiEndpoints.scanHistory,
        queryParameters: {'limit': maxItems},
      );
      final data = response.data ?? const [];
      return data
          .map((e) => ScanHistoryItem.fromApiJson(e as Map<String, dynamic>))
          .where((item) => item.canDisplay)
          .toList();
    } catch (error, stackTrace) {
      _reportSyncError('fetch_remote_history', error, stackTrace);
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

  void _reportSyncError(String operation, Object error, StackTrace stackTrace) {
    debugPrint('[ScanHistoryRepository] $operation failed: $error');
    _onSyncError?.call(operation, error, stackTrace);
  }
}
