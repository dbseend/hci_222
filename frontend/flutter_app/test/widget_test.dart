import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:trueprice/core/utils/price_classifier.dart';
import 'package:trueprice/features/scan/data/models/region_stats.dart';
import 'package:trueprice/features/onboarding/presentation/screens/permission_screen.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  group('PriceClassifier', () {
    test('safe when z <= 0', () {
      expect(
        PriceClassifier.classify(observed: 30, avg: 38, stdDev: 9.5),
        PriceStatus.safe,
      );
    });

    test('negotiable when 0 < z <= 1.5', () {
      expect(
        PriceClassifier.classify(observed: 45, avg: 38, stdDev: 9.5),
        PriceStatus.negotiable,
      );
    });

    test('warning when z > 1.5', () {
      expect(
        PriceClassifier.classify(observed: 60, avg: 38, stdDev: 9.5),
        PriceStatus.warning,
      );
    });

    test('percentDiff is correct', () {
      expect(PriceClassifier.percentDiff(45, 38), closeTo(18.4, 0.1));
    });
  });

  group('RegionStats', () {
    test('camel ride mock uses per-minute price baseline', () {
      final stats = RegionStats.mock('camel_ride');

      expect(stats.productId, 'camel_ride');
      expect(stats.avgPrice, 10.0);
      expect(stats.distribution, isNotEmpty);
    });
  });

  group('PermissionScreen', () {
    testWidgets(
      'shows camera required dialog when camera permission is denied',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: PermissionScreen(
              permissionRequester: () async => {
                Permission.camera: PermissionStatus.denied,
                Permission.locationWhenInUse: PermissionStatus.granted,
              },
            ),
          ),
        );

        await tester.tap(find.byType(ElevatedButton));
        await tester.pumpAndSettle();

        expect(find.text('Camera permission required'), findsOneWidget);
      },
    );
  });
}
