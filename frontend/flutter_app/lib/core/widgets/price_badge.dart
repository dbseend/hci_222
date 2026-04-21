// price_badge.dart
// Purpose: Colored badge widget that displays the price classification status (safe/negotiable/warning).
//          Used on PriceStatsScreen and PriceAnalysisScreen to give a quick visual signal.
// The [label] string (e.g. "Fair Price", "Negotiate", "Overpriced") is provided by the caller
// and is already translated at the call site (see price_classifier.dart statusMessage).
// Dependencies: AppColors, PriceClassifier (PriceStatus enum)

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../utils/price_classifier.dart';

class PriceBadge extends StatelessWidget {
  final PriceStatus status;
  final String label;
  final bool large;

  const PriceBadge({
    super.key,
    required this.status,
    required this.label,
    this.large = false,
  });

  Color get _color {
    switch (status) {
      case PriceStatus.safe:
        return AppColors.safe;
      case PriceStatus.negotiable:
        return AppColors.negotiable;
      case PriceStatus.warning:
        return AppColors.warning;
    }
  }

  IconData get _icon {
    switch (status) {
      case PriceStatus.safe:
        return Icons.check_circle;
      case PriceStatus.negotiable:
        return Icons.info;
      case PriceStatus.warning:
        return Icons.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = large ? 16.0 : 13.0;
    final iconSize = large ? 24.0 : 18.0;
    final padding = large
        ? const EdgeInsets.symmetric(horizontal: 20, vertical: 12)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 6);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(large ? 16 : 20),
        border: Border.all(color: _color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, color: _color, size: iconSize),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: _color,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
