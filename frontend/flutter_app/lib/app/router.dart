// router.dart
// Purpose: Defines the full navigation graph for the app using go_router.
//
// Route tree:
//   /            → SplashScreen    (auto-redirects to /permission after 2 s)
//   /permission  → PermissionScreen
//   /intro       → IntroScreen
//   ShellRoute (with AppBottomNavBar):
//     /home              → HomeScreen
//     /scan              → ScanMenuScreen
//     /scan/stats        → PriceStatsScreen   (extra: productName, productId, detectedPrice?)
//     /scan/input        → PriceInputScreen   (extra: productName, productId)
//     /scan/analysis     → PriceAnalysisScreen(extra: productName, productId, inputPrice)
//     /scan/final        → FinalPriceScreen   (extra: productName, productId, finalPrice)
//     /map               → MarketMapScreen
//     /language          → PhraseScreen
//     /community         → CommunityScreen
//
// Data passing: route parameters are passed via GoRouter's [extra] map (Map<String, dynamic>).
//               The _ExtraX extension provides null-safe typed getters.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/widgets/bottom_nav_bar.dart';
import '../features/onboarding/presentation/screens/splash_screen.dart';
import '../features/onboarding/presentation/screens/permission_screen.dart';
import '../features/onboarding/presentation/screens/intro_screen.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/scan/presentation/screens/scan_menu_screen.dart';
import '../features/scan/presentation/screens/price_stats_screen.dart';
import '../features/scan/presentation/screens/price_input_screen.dart';
import '../features/scan/presentation/screens/price_analysis_screen.dart';
import '../features/scan/presentation/screens/final_price_screen.dart';
import '../features/scan/presentation/models/scan_route_data.dart';
import '../features/market_map/presentation/screens/market_map_screen.dart';
import '../features/language/presentation/screens/phrase_screen.dart';
import '../features/community/presentation/screens/community_screen.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
    GoRoute(path: '/permission', builder: (_, _) => const PermissionScreen()),
    GoRoute(path: '/intro', builder: (_, _) => const IntroScreen()),
    ShellRoute(
      builder: (context, state, child) => _MainShell(child: child),
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
        GoRoute(
          path: '/scan',
          builder: (_, _) => const ScanMenuScreen(),
          routes: [
            GoRoute(
              path: 'stats',
              builder: (_, s) {
                final e = ScanRouteData.fromExtra(s.extra);
                return PriceStatsScreen(
                  productName: e.productName,
                  productId: e.productId,
                  detectedPrice: e.detectedPrice,
                );
              },
            ),
            GoRoute(
              path: 'input',
              builder: (_, s) {
                final e = ScanRouteData.fromExtra(s.extra);
                return PriceInputScreen(
                  productName: e.productName,
                  productId: e.productId,
                );
              },
            ),
            GoRoute(
              path: 'analysis',
              builder: (_, s) {
                final e = ScanRouteData.fromExtra(s.extra);
                return PriceAnalysisScreen(
                  productName: e.productName,
                  productId: e.productId,
                  inputPrice: e.inputPrice,
                );
              },
            ),
            GoRoute(
              path: 'final',
              builder: (_, s) {
                final e = ScanRouteData.fromExtra(s.extra);
                return FinalPriceScreen(
                  productName: e.productName,
                  productId: e.productId,
                  finalPrice: e.finalPrice,
                );
              },
            ),
          ],
        ),
        GoRoute(path: '/map', builder: (_, _) => const MarketMapScreen()),
        GoRoute(path: '/language', builder: (_, _) => const PhraseScreen()),
        GoRoute(path: '/community', builder: (_, _) => const CommunityScreen()),
      ],
    ),
  ],
);

class _MainShell extends StatelessWidget {
  final Widget child;
  const _MainShell({required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/scan')) return 1;
    if (location.startsWith('/map')) return 2;
    if (location.startsWith('/language')) return 3;
    if (location.startsWith('/community')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentIndex(context),
      ),
    );
  }
}
