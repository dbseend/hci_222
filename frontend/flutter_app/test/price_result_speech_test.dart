import 'package:flutter_test/flutter_test.dart';
import 'package:trueprice/core/utils/price_classifier.dart';
import 'package:trueprice/core/utils/price_result_speech.dart';

void main() {
  group('PriceResultSpeech', () {
    test('builds a concise safe price result message', () {
      final message = PriceResultSpeech.build(
        productName: 'Tomato',
        offeredPrice: 18,
        averagePrice: 20,
        status: PriceStatus.safe,
        percentDiff: -10,
      );

      expect(message, contains('Tomato'));
      expect(message, contains('18 EGP'));
      expect(message, contains('Good reference price'));
      expect(message, contains('-10.0%'));
    });

    test('builds a concise negotiation result message', () {
      final message = PriceResultSpeech.build(
        productName: 'Tomato',
        offeredPrice: 25,
        averagePrice: 20,
        status: PriceStatus.negotiable,
        percentDiff: 25,
      );

      expect(message, contains('Tomato'));
      expect(message, contains('25 EGP'));
      expect(message, contains('Negotiate'));
      expect(message, contains('+25.0%'));
    });
  });
}
