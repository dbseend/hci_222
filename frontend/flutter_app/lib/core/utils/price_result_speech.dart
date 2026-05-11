import 'currency_display.dart';
import 'price_classifier.dart';

class PriceResultSpeech {
  static String build({
    required String productName,
    required double offeredPrice,
    required double averagePrice,
    required PriceStatus status,
    required double percentDiff,
  }) {
    final name = productName.trim().isEmpty ? 'this item' : productName.trim();
    final verdict = PriceClassifier.statusMessage(status, percentDiff);
    final delta = PriceClassifier.priceDeltaLabel(percentDiff);

    return '$name is offered at ${CurrencyDisplay.formatEgp(offeredPrice)}. '
        '$verdict $delta. '
        'The regional average is ${CurrencyDisplay.formatEgp(averagePrice)}.';
  }
}
