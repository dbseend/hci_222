import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trueprice/features/community/presentation/screens/community_screen.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Community frame performance on real device', (tester) async {
    await _seedCommunityPosts(postCount: 300);
    await tester.pumpWidget(const MaterialApp(home: CommunityScreen()));
    await tester.pumpAndSettle(const Duration(milliseconds: 700));

    await _pumpUntilFound(tester, find.text('Filters'), timeoutSec: 15);

    await binding.watchPerformance(() async {
      final scrollable = find.byType(Scrollable).first;
      for (int i = 0; i < 4; i++) {
        await tester.fling(scrollable, const Offset(0, -700), 2000);
        await tester.pumpAndSettle(const Duration(milliseconds: 450));
      }
      for (int i = 0; i < 4; i++) {
        await tester.fling(scrollable, const Offset(0, 650), 1800);
        await tester.pumpAndSettle(const Duration(milliseconds: 450));
      }

      await tester.enterText(_textFieldWithLabel('Location'), 'downtown');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.enterText(_textFieldWithLabel('Item'), 'grapes');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.enterText(_textFieldWithLabel('Store/Company'), 'market');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.fling(scrollable, const Offset(0, -500), 1700);
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
    }, reportKey: 'community_watch_performance');

    await binding.traceAction(() async {
      final scrollable = find.byType(Scrollable).first;
      await tester.fling(scrollable, const Offset(0, -900), 2200);
      await tester.pumpAndSettle(const Duration(milliseconds: 600));
      await tester.fling(scrollable, const Offset(0, 900), 2200);
      await tester.pumpAndSettle(const Duration(milliseconds: 600));
    }, reportKey: 'community_scroll_timeline');
  });
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int timeoutSec = 10,
}) async {
  final max = timeoutSec * 10;
  for (int i = 0; i < max; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw StateError('Timed out waiting for finder: $finder');
}

Finder _textFieldWithLabel(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
    description: 'TextField with label "$label"',
  );
}

Future<void> _seedCommunityPosts({required int postCount}) async {
  final now = DateTime.now();
  final rows = List<Map<String, dynamic>>.generate(postCount, (index) {
    final price = 10 + (index % 90) + (index % 5) * 0.4;
    return {
      'id': 'post_$index',
      'product_name': 'Product $index',
      'price': price,
      'store_name': 'Store ${index % 15}',
      'location_name': index % 2 == 0 ? 'Downtown Cairo' : 'Old Cairo',
      'image_path': null,
      'created_at': now.subtract(Duration(minutes: index)).toIso8601String(),
    };
  });

  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('community_user_posts', jsonEncode(rows));

  final projectRoot = Directory.current.path;
  final warmupFile = File('$projectRoot/build/perf_seed_summary.json');
  await warmupFile.parent.create(recursive: true);
  await warmupFile.writeAsString(
    jsonEncode({
      'seed_post_count': postCount,
      'seed_time': DateTime.now().toIso8601String(),
    }),
  );
}
