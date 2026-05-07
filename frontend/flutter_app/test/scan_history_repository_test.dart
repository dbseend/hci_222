import 'dart:io';

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
  });
}
