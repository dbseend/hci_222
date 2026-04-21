// price_classifier.dart
// Purpose: Pure utility class for classifying an observed price relative to regional statistics.
//          Uses a z-score approach. Consumed by ScanScreen BLoC and PriceAnalysisScreen.
// Architecture note: no Flutter dependencies — safe to unit-test without a widget tree.

/// Three-tier price status used across the UI (badge color, Arabic phrase selection, etc.)
enum PriceStatus { safe, negotiable, warning }

class PriceClassifier {
  /// Classifies [observed] price using a z-score against [avg] and [stdDev].
  ///
  /// Thresholds:
  ///   z > 1.5  → warning    (Red  — significantly overpriced)
  ///   z > 0.0  → negotiable (Yellow — slightly above average)
  ///   z <= 0.0 → safe       (Green — at or below average)
  static PriceStatus classify({
    required double observed,
    required double avg,
    required double stdDev,
  }) {
    if (stdDev == 0) {
      return observed > avg ? PriceStatus.warning : PriceStatus.safe;
    }
    final z = (observed - avg) / stdDev;
    if (z > 1.5) return PriceStatus.warning;
    if (z > 0.0) return PriceStatus.negotiable;
    return PriceStatus.safe;
  }

  /// Returns how many percent [observed] differs from [avg] (positive = above average).
  static double percentDiff(double observed, double avg) {
    if (avg == 0) return 0;
    return (observed - avg) / avg * 100;
  }

  /// Human-readable status message shown on the analysis screen.
  static String statusMessage(PriceStatus status, double percent) {
    switch (status) {
      case PriceStatus.safe:
        return 'Great price! Below average.';
      case PriceStatus.negotiable:
        return 'Negotiate. ${percent.toStringAsFixed(0)}% above average.';
      case PriceStatus.warning:
        return 'Overpriced! ${percent.toStringAsFixed(0)}% above average.';
    }
  }
}
