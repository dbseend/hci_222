// app_colors.dart
// Purpose: Central color palette for the entire app.
//          All color references in widgets/screens should import from here
//          so a future theme change requires editing only this file.

import 'package:flutter/material.dart';

class AppColors {
  // --- Price status colors (used by PriceBadge and histogram) ---
  static const Color safe = Color(0xFF4CAF50);          // Green  — at or below average price
  static const Color negotiable = Color(0xFFFFC107);    // Yellow — slightly above average
  static const Color warning = Color(0xFFF44336);       // Red    — significantly overpriced

  // --- Brand / theme colors ---
  static const Color primary = Color(0xFF1B5E20);       // Dark Green (app primary)
  static const Color primaryLight = Color(0xFF4CAF50);  // Light Green (accent)
  static const Color background = Color(0xFFF5F5F5);    // Off-white page background
  static const Color surface = Colors.white;            // Card / panel surface
  static const Color onSurface = Color(0xFF212121);     // Primary text color
  static const Color onSurfaceLight = Color(0xFF757575);// Secondary / hint text color

  // --- Camera scan overlay colors ---
  static const Color overlay = Color(0x80000000);       // Semi-transparent black overlay
  static const Color scanLine = Color(0xFF4CAF50);      // Animated scan line on camera preview
}
