import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:trueprice/core/utils/currency_display.dart';
import 'package:trueprice/core/utils/price_classifier.dart';
import 'package:trueprice/features/market_map/presentation/models/market_location.dart';
import 'package:trueprice/features/market_map/presentation/utils/market_marker_builder.dart';
import 'package:trueprice/features/scan/presentation/screens/price_input_screen.dart';
import 'package:trueprice/features/scan/presentation/screens/scan_menu_screen.dart';
import 'package:trueprice/features/scan/presentation/screens/scan_screen.dart';
import 'package:trueprice/features/scan/data/models/price_comparison.dart';
import 'package:trueprice/features/scan/data/models/region_stats.dart';
import 'package:trueprice/features/scan/data/models/scannable_product.dart';
import 'package:trueprice/features/onboarding/presentation/screens/permission_screen.dart';
import 'package:trueprice/features/scan/presentation/screens/final_price_screen.dart';
import 'package:trueprice/features/scan/presentation/widgets/product_search_sheet.dart';
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
    test('local fallback uses product-specific Cairo reference prices', () {
      final tomato = RegionStats.mock('tomato');
      final mango = RegionStats.mock('mango');

      expect(tomato.productId, 'tomato');
      expect(tomato.avgPrice, 18.4);
      expect(mango.avgPrice, 61.8);
      expect(tomato.avgPrice, isNot(mango.avgPrice));
      expect(tomato.distribution, isNotEmpty);
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

    test('estimated chart distribution peaks near the market center', () {
      final stats = RegionStats.fromJson({
        'product_id': 'tomato',
        'region': 'cairo',
        'currency': 'EGP',
        'avg_price': 18.4,
        'median_price': 15,
        'min_price': 13,
        'max_price': 30,
        'stddev_price': 6.1,
        'sample_count': 18,
      });

      final peak = stats.distribution.reduce(
        (a, b) => a.count >= b.count ? a : b,
      );
      final peakCenter = (peak.start + peak.end) / 2;

      expect(stats.distribution.length, 8);
      expect(stats.distribution.fold<int>(0, (sum, b) => sum + b.count), 18);
      expect(peakCenter, inInclusiveRange(13, 22));
      expect(stats.distribution.every((b) => b.count >= 0), isTrue);
    });

    test('parses price trust metadata from backend stats', () {
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
        'window_days': 14,
        'stat_date': '2026-05-28',
        'data_source': 'Talabat + traveler reports',
      });

      expect(stats.windowDays, 14);
      expect(stats.lastUpdated, DateTime(2026, 5, 28));
      expect(stats.dataSource, 'Talabat + traveler reports');
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
        'message':
            'Slightly above the Cairo reference (+25.0%). Try negotiating.',
      });

      expect(comparison.productId, 'tomato');
      expect(comparison.verdict, 'negotiable');
      expect(comparison.percentDiff, 25);
      expect(comparison.message, contains('reference'));
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

  group('Camera pinch zoom', () {
    test('calculates pinch zoom within device bounds', () {
      expect(
        calculatePinchZoom(
          baseZoom: 2.0,
          scale: 1.5,
          minZoom: 1.0,
          maxZoom: 4.0,
        ),
        3.0,
      );
      expect(
        calculatePinchZoom(
          baseZoom: 2.0,
          scale: 0.25,
          minZoom: 1.0,
          maxZoom: 4.0,
        ),
        1.0,
      );
      expect(
        calculatePinchZoom(
          baseZoom: 3.0,
          scale: 2.0,
          minZoom: 1.0,
          maxZoom: 4.0,
        ),
        4.0,
      );
    });
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

  group('ProductSearchSheet', () {
    testWidgets('scan menu separates camera scan and product search', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: ScanMenuScreen()));

      expect(find.text('Camera scan'), findsOneWidget);
      expect(find.text('Product search'), findsOneWidget);
      expect(find.text('Manual price input'), findsOneWidget);
      expect(find.text('Scan history'), findsOneWidget);
    });

    testWidgets('filters supported scan products and returns selection', (
      tester,
    ) async {
      ScannableProduct? selected;
      const products = [
        ScannableProduct(
          productId: 'tomato',
          displayName: 'Tomato',
          nameAr: 'طماطم',
          unit: 'kg',
          aliases: ['tomatoes', 'balady tomato'],
        ),
        ScannableProduct(
          productId: 'mango',
          displayName: 'Mango',
          nameAr: 'مانجو',
          unit: 'kg',
          aliases: ['mangoes'],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductSearchSheet(
              products: products,
              onSelected: (product) => selected = product,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'tom');
      await tester.pump();

      expect(find.text('Tomato'), findsOneWidget);
      expect(find.text('Mango'), findsNothing);

      await tester.tap(find.text('Tomato'));
      await tester.pump();

      expect(selected?.productId, 'tomato');
    });
  });

  group('ScanRecoveryActions', () {
    testWidgets('offers retry, search, and manual input actions', (
      tester,
    ) async {
      var retried = false;
      var searched = false;
      var manual = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScanRecoveryActions(
              message: 'Failed to detect product.',
              onRetry: () => retried = true,
              onSearch: () => searched = true,
              onManualInput: () => manual = true,
            ),
          ),
        ),
      );

      expect(find.text('Product not recognized'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Search product'), findsOneWidget);
      expect(find.text('Enter manually'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.tap(find.text('Search product'));
      await tester.tap(find.text('Enter manually'));

      expect(retried, isTrue);
      expect(searched, isTrue);
      expect(manual, isTrue);
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
