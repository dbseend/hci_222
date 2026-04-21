import 'package:flutter_test/flutter_test.dart';
import 'package:trueprice/core/utils/price_classifier.dart';

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
}
