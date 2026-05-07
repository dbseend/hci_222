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

  testWidgets('applies location/item/store filters in community feed', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CommunityScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Grapes 1kg'), findsOneWidget);
    expect(find.text('Tomatoes 1kg'), findsOneWidget);
    expect(find.text('5 results'), findsOneWidget);

    await tester.enterText(
      textFieldWithLabel('Location'),
      '  downtown   cairo ',
    );
    await tester.enterText(textFieldWithLabel('Item'), '  TOMATOES ');
    await tester.enterText(textFieldWithLabel('Store/Company'), '  ataba ');
    await tester.pump();

    expect(find.text('1 results'), findsOneWidget);
    expect(find.text('Tomatoes 1kg'), findsOneWidget);
    expect(find.text('Grapes 1kg'), findsNothing);
    expect(find.text('Cucumbers 1kg'), findsNothing);
  });

  testWidgets('applies initial filters passed from navigation', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CommunityScreen(
          initialLocationFilter: 'Downtown Cairo',
          initialItemFilter: 'Tomatoes',
          initialStoreFilter: 'Ataba',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 results'), findsOneWidget);
    expect(find.text('Tomatoes 1kg'), findsOneWidget);
    expect(find.text('Grapes 1kg'), findsNothing);
  });
}
