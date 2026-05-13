import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trueprice/features/community/presentation/screens/community_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Finder textFieldWithLabel(String label) {
    return find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == label,
      description: 'TextField with label "$label"',
    );
  }

  Future<void> seedCommunityPosts() async {
    final now = DateTime.now();
    final rows = [
      {
        'id': 'post_5',
        'product_name': 'Lemons 5 pcs',
        'price': 19.0,
        'store_name': 'Ataba Market',
        'location_name': 'Downtown Cairo',
        'image_path': null,
        'created_at': now
            .subtract(const Duration(minutes: 10))
            .toIso8601String(),
      },
      {
        'id': 'post_4',
        'product_name': 'Pomegranate 1 pc',
        'price': 44.0,
        'store_name': 'Khan el-Khalili Market',
        'location_name': 'Old Cairo',
        'image_path': null,
        'created_at': now
            .subtract(const Duration(minutes: 30))
            .toIso8601String(),
      },
      {
        'id': 'post_3',
        'product_name': 'Cucumbers 1kg',
        'price': 7.2,
        'store_name': 'Imbaba Market',
        'location_name': 'Imbaba',
        'image_path': null,
        'created_at': now.subtract(const Duration(hours: 1)).toIso8601String(),
      },
      {
        'id': 'post_2',
        'product_name': 'Tomatoes 1kg',
        'price': 13.5,
        'store_name': 'Ataba Market',
        'location_name': 'Downtown Cairo',
        'image_path': null,
        'created_at': now.subtract(const Duration(hours: 2)).toIso8601String(),
      },
      {
        'id': 'post_1',
        'product_name': 'Grapes 1kg',
        'price': 64.0,
        'store_name': 'Khan el-Khalili Market',
        'location_name': 'Old Cairo',
        'image_path': null,
        'created_at': now.subtract(const Duration(hours: 3)).toIso8601String(),
      },
    ];

    SharedPreferences.setMockInitialValues({
      'community_user_posts': jsonEncode(rows),
    });
  }

  testWidgets('applies location/item/store filters in community feed', (
    tester,
  ) async {
    await seedCommunityPosts();
    await tester.pumpWidget(const MaterialApp(home: CommunityScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('5 results'), findsOneWidget);

    await tester.enterText(
      textFieldWithLabel('Location'),
      '  downtown   cairo ',
    );
    await tester.enterText(textFieldWithLabel('Item'), '  TOMATOES ');
    await tester.enterText(textFieldWithLabel('Store/Company'), '  ataba ');
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('1 results'), findsOneWidget);
    expect(find.text('Tomatoes 1kg'), findsOneWidget);
    expect(find.text('Cucumbers 1kg'), findsNothing);
  });

  testWidgets('applies initial filters passed from navigation', (tester) async {
    await seedCommunityPosts();
    await tester.pumpWidget(
      const MaterialApp(
        home: CommunityScreen(
          initialLocationFilter: 'Downtown Cairo',
          initialItemFilter: 'Tomatoes',
          initialStoreFilter: 'Ataba',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('1 results'), findsOneWidget);
    expect(find.text('Tomatoes 1kg'), findsOneWidget);
    expect(find.text('Grapes 1kg'), findsNothing);
  });

  testWidgets('shows sample community feed on first launch', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CommunityScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('No posts match the selected filters.'), findsNothing);
    expect(find.text('5 results'), findsOneWidget);
    expect(find.text('Lemons 5 pcs'), findsOneWidget);
  });

  testWidgets('shows default images for posts without photos', (tester) async {
    await seedCommunityPosts();
    await tester.pumpWidget(const MaterialApp(home: CommunityScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('community-default-image')), findsWidgets);
  });
}
