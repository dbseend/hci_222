import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:trueprice/core/utils/currency_display.dart';
import 'package:trueprice/core/utils/price_classifier.dart';
import 'package:trueprice/features/market_map/presentation/models/market_location.dart';
import 'package:trueprice/features/market_map/presentation/utils/market_marker_builder.dart';
import 'package:trueprice/features/scan/presentation/screens/price_input_screen.dart';
import 'package:trueprice/features/scan/data/models/price_comparison.dart';
import 'package:trueprice/features/scan/data/models/region_stats.dart';
import 'package:trueprice/features/onboarding/presentation/screens/permission_screen.dart';
import 'package:trueprice/features/scan/presentation/screens/final_price_screen.dart';
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

    test('percentile is around 50 at average', () {
      expect(
        PriceClassifier.percentile(observed: 55, avg: 55, stdDev: 10),
        closeTo(50, 0.5),
      );
    });

    test('percentile increases as observed price increases', () {
      final low = PriceClassifier.percentile(observed: 45, avg: 55, stdDev: 10);
      final high = PriceClassifier.percentile(
        observed: 65,
        avg: 55,
        stdDev: 10,
      );
      expect(low, lessThan(50));
      expect(high, greaterThan(50));
      expect(high, greaterThan(low));
    });

    test('confidence score improves with larger sample size', () {
      final small = PriceClassifier.confidenceScore(
        sampleSize: 10,
        avg: 55,
        stdDev: 10,
      );
      final large = PriceClassifier.confidenceScore(
        sampleSize: 120,
        avg: 55,
        stdDev: 10,
      );

      expect(large, greaterThan(small));
      expect(large, inInclusiveRange(0, 100));
    });

    test('signal bundles percent, percentile, and confidence', () {
      final signal = PriceClassifier.signal(
        observed: 60,
        avg: 55,
        stdDev: 10,
        sampleSize: 80,
      );

      expect(signal.percentDiff, closeTo(9.09, 0.1));
      expect(signal.percentile, greaterThan(50));
      expect(signal.confidenceScore, inInclusiveRange(0, 100));
    });
  });

  group('CurrencyDisplay', () {
    setUp(() {
      CurrencyDisplay.resetRateForTest();
    });

    test('formats EGP with KRW', () {
      expect(CurrencyDisplay.formatEgpWithKrw(65), '65 EGP (₩1,820)');
    });

    test('applies fetched exchange rate', () {
      CurrencyDisplay.setEgpToKrwRate(30);
      expect(CurrencyDisplay.formatEgpWithKrw(10), '10 EGP (₩300)');
    });
  });

  group('RegionStats', () {
    test('grapes mock uses baseline price distribution', () {
      final stats = RegionStats.mock('p001');

      expect(stats.productId, 'p001');
      expect(stats.avgPrice, 55.0);
      expect(stats.distribution, isNotEmpty);
    });

    test('parses backend price stats and builds chart distribution', () {
      final stats = RegionStats.fromJson({
        'product_id': 'tomato',
        'region': 'cairo',
        'currency': 'EGP',
        'avg_price': 20,
        'median_price': 19,
        'min_price': 15,
        'max_price': 28,
        'stddev_price': 4,
        'sample_count': 42,
      });

      expect(stats.productId, 'tomato');
      expect(stats.region, 'cairo');
      expect(stats.currency, 'EGP');
      expect(stats.avgPrice, 20);
      expect(stats.modePrice, 19);
      expect(stats.stdDev, 4);
      expect(stats.sampleCount, 42);
      expect(stats.distribution.fold<int>(0, (sum, b) => sum + b.count), 42);
    });
  });

  group('PriceComparison', () {
    test('parses backend compare response', () {
      final comparison = PriceComparison.fromJson({
        'product_id': 'tomato',
        'display_name': 'Tomato',
        'unit': 'kg',
        'region': 'cairo',
        'currency': 'EGP',
        'user_price': 25,
        'avg_price': 20,
        'median_price': 19,
        'min_price': 15,
        'max_price': 28,
        'stddev_price': 4,
        'sample_count': 42,
        'percent_diff': 25,
        'verdict': 'negotiable',
        'message': 'Slightly above the local average (+25.0%).',
      });

      expect(comparison.productId, 'tomato');
      expect(comparison.verdict, 'negotiable');
      expect(comparison.percentDiff, 25);
      expect(comparison.message, contains('average'));
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

  group('Market marker builder', () {
    test('builds stable markers for each market location', () {
      final markets = [
        const MarketLocation(
          name: 'Khan el-Khalili',
          lat: 30.0478,
          lon: 31.2625,
          desc: 'Traditional market',
          rating: 4.6,
          reviewCount: 128,
        ),
        const MarketLocation(
          name: 'Ataba Market',
          lat: 30.0565,
          lon: 31.2457,
          desc: 'Fruit and spices',
          rating: 4.3,
          reviewCount: 94,
        ),
      ];

      final markers = buildMarketMarkers(markets: markets, onTap: (_) {});
      final markerIds = markers.map((m) => m.markerId.value).toSet();

      expect(markers.length, 2);
      expect(markerIds, {'khan_el-khalili', 'ataba_market'});
      expect(
        markers
            .firstWhere((m) => m.markerId.value == 'khan_el-khalili')
            .position,
        const LatLng(30.0478, 31.2625),
      );
    });
  });

  group('PriceInputScreen units', () {
    testWidgets('does not show bundle/bunch unit option', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PriceInputScreen(productName: 'Tomato')),
      );

      expect(find.text('kg'), findsOneWidget);
      expect(find.text('pcs'), findsOneWidget);
      expect(find.text('bunch'), findsNothing);
      expect(find.text('bundle'), findsNothing);
    });
  });

  group('FinalPriceScreen layout', () {
    testWidgets('renders on small-height screens without overflow', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 520));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: FinalPriceScreen(productName: 'Grapes', finalPrice: 65),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Purchase complete!'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
