import 'package:flutter_test/flutter_test.dart';
import 'package:trueprice/features/scan/data/repositories/price_repository.dart';

const _backendE2e = bool.fromEnvironment('TRUEPRICE_BACKEND_E2E');

void main() {
  group('PriceRepository backend integration', () {
    setUp(PriceRepositoryImpl.clearCache);

    test(
      'loads price stats and compares user price through FastAPI',
      () async {
        final repo = PriceRepositoryImpl();

        final stats = await repo.getStats(productId: 'tomato', lat: 0, lon: 0);
        final comparison = await repo.comparePrice(
          productId: 'tomato',
          price: 25,
        );

        expect(stats.productId, 'tomato');
        expect(stats.avgPrice, 20);
        expect(stats.distribution, isNotEmpty);
        expect(comparison.verdict, 'negotiable');
        expect(comparison.percentDiff, 25);
      },
      skip: _backendE2e
          ? false
          : 'Set TRUEPRICE_BACKEND_E2E=true and run the FastAPI server.',
    );
  });
}
