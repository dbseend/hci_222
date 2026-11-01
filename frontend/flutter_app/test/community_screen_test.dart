import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trueprice/features/community/data/models/community_post.dart';
import 'package:trueprice/features/community/data/repositories/community_post_repository.dart';
import 'package:trueprice/features/community/presentation/screens/community_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Finder textFieldWithLabel(String label) {
    return find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == label,
      description: 'TextField with label "$label"',
    );
  }

  List<CommunityPost> communityPosts() {
    final now = DateTime.now();
    return [
      CommunityPost(
        id: 'post_5',
        productName: 'Lemons 5 pcs',
        price: 19,
        storeName: 'Ataba Market',
        locationName: 'Downtown Cairo',
        createdAt: now.subtract(const Duration(minutes: 10)),
      ),
      CommunityPost(
        id: 'post_4',
        productName: 'Pomegranate 1 pc',
        price: 44,
        storeName: 'Khan el-Khalili Market',
        locationName: 'Old Cairo',
        createdAt: now.subtract(const Duration(minutes: 30)),
      ),
      CommunityPost(
        id: 'post_3',
        productName: 'Cucumbers 1kg',
        price: 7.2,
        storeName: 'Imbaba Market',
        locationName: 'Imbaba',
        createdAt: now.subtract(const Duration(hours: 1)),
      ),
      CommunityPost(
        id: 'post_2',
        productName: 'Tomatoes 1kg',
        price: 13.5,
        storeName: 'Ataba Market',
        locationName: 'Downtown Cairo',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      CommunityPost(
        id: 'post_1',
        productName: 'Grapes 1kg',
        price: 64,
        storeName: 'Khan el-Khalili Market',
        locationName: 'Old Cairo',
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
    ];
  }

  testWidgets('applies location/item/store filters in community feed', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityScreen(
          repository: _FakeCommunityRepository(communityPosts()),
        ),
      ),
    );
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
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityScreen(
          initialLocationFilter: 'Downtown Cairo',
          initialItemFilter: 'Tomatoes',
          initialStoreFilter: 'Ataba',
          repository: _FakeCommunityRepository(communityPosts()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('1 results'), findsOneWidget);
    expect(find.text('Tomatoes 1kg'), findsOneWidget);
    expect(find.text('Grapes 1kg'), findsNothing);
  });

  testWidgets('shows sample community feed on first launch', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityScreen(
          repository: _FakeCommunityRepository(communityPosts()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('No posts match the selected filters.'), findsNothing);
    expect(find.text('5 results'), findsOneWidget);
    expect(find.text('Lemons 5 pcs'), findsOneWidget);
  });

  testWidgets('shows default images for posts without photos', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityScreen(
          repository: _FakeCommunityRepository(communityPosts()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('community-default-image')), findsWidgets);
  });

  testWidgets('filters a 300-post feed without rendering every row eagerly', (
    tester,
  ) async {
    final now = DateTime.now();
    final posts = List<CommunityPost>.generate(
      300,
      (index) => CommunityPost(
        id: 'bulk_$index',
        productName: 'Product $index',
        price: index.toDouble() + 1,
        storeName: 'Store ${index % 10}',
        locationName: index.isEven ? 'Downtown Cairo' : 'Old Cairo',
        createdAt: now.subtract(Duration(minutes: index)),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CommunityScreen(repository: _FakeCommunityRepository(posts)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('300 results'), findsOneWidget);
    expect(find.text('Product 0'), findsOneWidget);
    expect(find.text('Product 299'), findsNothing);

    await tester.enterText(textFieldWithLabel('Item'), 'Product 299');
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('1 results'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data == 'Product 299' &&
            widget.style?.fontWeight == FontWeight.w700,
      ),
      findsOneWidget,
    );
  });
}

class _FakeCommunityRepository implements CommunityPostRepository {
  final List<CommunityPost> posts;

  _FakeCommunityRepository(this.posts);

  @override
  Future<void> addPurchasePost({
    required String productName,
    required double price,
    String? imagePath,
    String productCode = 'tomato',
    String storeName = 'Traveler Report',
    String locationName = 'Unknown',
  }) async {}

  @override
  Future<List<CommunityPost>> getUserPosts() async => posts;
}
