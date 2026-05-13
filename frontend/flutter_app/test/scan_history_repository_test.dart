import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trueprice/features/scan/data/repositories/scan_history_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScanHistoryRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'stores captured image into app history and returns newest first',
      () async {
        final tempRoot = await Directory.systemTemp.createTemp(
          'scan-history-test',
        );
        addTearDown(() async => tempRoot.delete(recursive: true));

        final sourceA = File('${tempRoot.path}/source-a.jpg')
          ..writeAsBytesSync([1, 2, 3]);
        final sourceB = File('${tempRoot.path}/source-b.jpg')
          ..writeAsBytesSync([4, 5, 6]);

        final prefs = await SharedPreferences.getInstance();
        final repo = ScanHistoryRepositoryImpl(
          prefsProvider: () async => prefs,
          directoryProvider: () async => tempRoot,
          dio: _dioThatCannotConnect(),
          maxItems: 50,
        );

        await repo.addCapturedImage(sourceA);
        await Future<void>.delayed(const Duration(milliseconds: 5));
        await repo.addCapturedImage(sourceB);

        final items = await repo.getHistory();
        expect(items.length, 2);
        expect(items.first.imagePath, contains('scan_history/capture_'));
        expect(await File(items.first.imagePath).exists(), isTrue);
        expect(await File(items.last.imagePath).exists(), isTrue);
        expect(items.first.capturedAt.isAfter(items.last.capturedAt), isTrue);
      },
    );

    test('keeps max history size', () async {
      final tempRoot = await Directory.systemTemp.createTemp(
        'scan-history-limit',
      );
      addTearDown(() async => tempRoot.delete(recursive: true));

      final prefs = await SharedPreferences.getInstance();
      final repo = ScanHistoryRepositoryImpl(
        prefsProvider: () async => prefs,
        directoryProvider: () async => tempRoot,
        dio: _dioThatCannotConnect(),
        maxItems: 2,
      );

      for (var i = 0; i < 3; i++) {
        final source = File('${tempRoot.path}/source-$i.jpg')
          ..writeAsBytesSync([i]);
        await repo.addCapturedImage(source);
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      final items = await repo.getHistory();
      expect(items.length, 2);
    });

    test('loads remote scan history with signed image url', () async {
      final tempRoot = await Directory.systemTemp.createTemp(
        'scan-history-remote',
      );
      addTearDown(() async => tempRoot.delete(recursive: true));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('anonymous_user_id', 'client-1');

      final repo = ScanHistoryRepositoryImpl(
        prefsProvider: () async => prefs,
        directoryProvider: () async => tempRoot,
        dio: _dioWithRemoteHistory(),
      );

      final items = await repo.getHistory();

      expect(items, hasLength(1));
      expect(items.single.remoteImagePath, 'client-1/capture.jpg');
      expect(items.single.imageUrl, 'https://example.test/signed/capture.jpg');
    });

    test('resolves remote history image into a local file', () async {
      final tempRoot = await Directory.systemTemp.createTemp(
        'scan-history-download',
      );
      addTearDown(() async => tempRoot.delete(recursive: true));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('anonymous_user_id', 'client-1');

      final repo = ScanHistoryRepositoryImpl(
        prefsProvider: () async => prefs,
        directoryProvider: () async => tempRoot,
        dio: _dioWithRemoteHistory(),
      );

      final item = (await repo.getHistory()).single;
      final file = await repo.resolveImageFile(item);

      expect(await file.readAsBytes(), [1, 2, 3]);
      expect(file.path, contains('scan_history/history-1_remote.jpg'));
    });
  });
}

Dio _dioThatCannotConnect() {
  return Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8000'))
    ..httpClientAdapter = _ConnectionErrorAdapter();
}

Dio _dioWithRemoteHistory() {
  return Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8000'))
    ..httpClientAdapter = _RemoteHistoryAdapter();
}

class _ConnectionErrorAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'Connection refused',
    );
  }

  @override
  void close({bool force = false}) {}
}

class _RemoteHistoryAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'GET' && options.path == '/scan/history') {
      return ResponseBody.fromString(
        '''
[
  {
    "id": "history-1",
    "image_path": "client-1/capture.jpg",
    "image_url": "https://example.test/signed/capture.jpg",
    "created_at": "2026-05-13T00:00:00Z"
  }
]
''',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    if (options.method == 'GET' &&
        options.path == 'https://example.test/signed/capture.jpg') {
      return ResponseBody.fromBytes(
        [1, 2, 3],
        200,
        headers: {
          Headers.contentTypeHeader: ['image/jpeg'],
        },
      );
    }

    throw DioException.connectionError(
      requestOptions: options,
      reason: 'Unexpected request',
    );
  }

  @override
  void close({bool force = false}) {}
}
