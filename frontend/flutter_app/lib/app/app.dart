// app.dart
// Purpose: Root MaterialApp.router widget. Configures the global theme (colors, button styles,
//          app bar style) and wires in the go_router configuration from router.dart.
// Entry point: instantiated in main.dart → runApp(TruePriceApp()).
// Dependencies: AppColors, router (GoRouter instance)

import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import 'router.dart';

class TruePriceApp extends StatelessWidget {
  const TruePriceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Burası True Price',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          surface: AppColors.surface,
        ),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        useMaterial3: true,
      ),
    );
  }
}
