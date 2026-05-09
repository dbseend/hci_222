// price_classifier.dart
// Purpose: Pure utility class for classifying an observed price relative to regional statistics.
//          Uses a z-score approach. Consumed by ScanScreen BLoC and PriceAnalysisScreen.
// Architecture note: no Flutter dependencies — safe to unit-test without a widget tree.
import 'dart:math' as math;

/// Three-tier price status used across the UI (badge color, Arabic phrase selection, etc.)
enum PriceStatus { safe, negotiable, warning }

enum ConfidenceLevel { low, medium, high }

class PriceSignal {
  final double percentDiff;
  final double percentile; // 0..100
  final double confidenceScore; // 0..100
  final ConfidenceLevel confidenceLevel;

  const PriceSignal({
    required this.percentDiff,
    required this.percentile,
    required this.confidenceScore,
    required this.confidenceLevel,
  });
}

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

  /// Estimated percentile (0..100) from normal approximation using [avg]/[stdDev].
  static double percentile({
    required double observed,
    required double avg,
    required double stdDev,
  }) {
    if (stdDev <= 0) {
      if (observed < avg) return 25;
      if (observed > avg) return 75;
      return 50;
    }

    final z = (observed - avg) / stdDev;
    return _normalCdf(z) * 100;
  }

  /// Confidence score for how trustworthy the estimate is.
  /// Uses sample size + variability (coefficient of variation) heuristics.
  static double confidenceScore({
    required int sampleSize,
    required double avg,
    required double stdDev,
  }) {
    if (sampleSize <= 0 || avg <= 0) return 0;

    final sizeScore = ((sampleSize / 80) * 100).clamp(0, 100).toDouble();
    final cv = (stdDev / avg).abs();
    final variancePenalty = ((cv - 0.10) / 0.60 * 100).clamp(0, 100).toDouble();
    final spreadScore = (100 - variancePenalty).clamp(0, 100).toDouble();

    return (sizeScore * 0.65 + spreadScore * 0.35).clamp(0, 100).toDouble();
  }

  static ConfidenceLevel confidenceLevel(double confidenceScore) {
    if (confidenceScore >= 75) return ConfidenceLevel.high;
    if (confidenceScore >= 45) return ConfidenceLevel.medium;
    return ConfidenceLevel.low;
  }

  static PriceSignal signal({
    required double observed,
    required double avg,
    required double stdDev,
    required int sampleSize,
  }) {
    final pct = percentDiff(observed, avg);
    final pctl = percentile(observed: observed, avg: avg, stdDev: stdDev);
    final confScore = confidenceScore(
      sampleSize: sampleSize,
      avg: avg,
      stdDev: stdDev,
    );
    return PriceSignal(
      percentDiff: pct,
      percentile: pctl,
      confidenceScore: confScore,
      confidenceLevel: confidenceLevel(confScore),
    );
  }

  static String percentileLabel(double percentile) {
    final rounded = percentile.round().clamp(1, 99);
    final suffix = switch (rounded % 100) {
      11 || 12 || 13 => 'th',
      _ => switch (rounded % 10) {
        1 => 'st',
        2 => 'nd',
        3 => 'rd',
        _ => 'th',
      },
    };
    return '$rounded$suffix percentile';
  }

  static String confidenceLabel(ConfidenceLevel level, double score) {
    final pct = score.round();
    return switch (level) {
      ConfidenceLevel.high => 'High confidence ($pct/100)',
      ConfidenceLevel.medium => 'Medium confidence ($pct/100)',
      ConfidenceLevel.low => 'Low confidence ($pct/100)',
    };
  }

  static String priceDeltaLabel(double percent) {
    if (percent.abs() < 0.05) return 'At regional average';
    final sign = percent > 0 ? '+' : '';
    return '$sign${percent.toStringAsFixed(1)}% vs regional average';
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

  // Abramowitz and Stegun approximation for normal CDF.
  static double _normalCdf(double z) {
    final t = 1 / (1 + 0.2316419 * z.abs());
    final d = 0.3989423 * _exp(-z * z / 2);
    final poly =
        (((((1.330274429 * t - 1.821255978) * t + 1.781477937) * t -
                    0.356563782) *
                t) +
            0.319381530) *
        t;
    final cdf = 1 - d * poly;
    return z >= 0 ? cdf : 1 - cdf;
  }

  static double _exp(double x) {
    return math.exp(x);
  }
}
