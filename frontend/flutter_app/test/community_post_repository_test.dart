import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trueprice/features/community/data/repositories/community_post_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CommunityPostRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('adds purchase post and returns newest first', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = CommunityPostRepositoryImpl(
        prefsProvider: () async => prefs,
      );

      await repo.addPurchasePost(
        productName: 'Grapes',
        price: 61,
        imagePath: '/tmp/grapes.jpg',
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repo.addPurchasePost(
        productName: 'Tomato',
        price: 14,
        imagePath: '/tmp/tomato.jpg',
      );

      final posts = await repo.getUserPosts();
      expect(posts.length, 2);
      expect(posts.first.productName, 'Tomato');
      expect(posts.first.price, 14);
      expect(posts.first.imagePath, '/tmp/tomato.jpg');
      expect(posts.first.createdAt.isAfter(posts.last.createdAt), isTrue);
    });

    test('returns sample feed when no community posts exist yet', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = CommunityPostRepositoryImpl(
        prefsProvider: () async => prefs,
      );

      final posts = await repo.getUserPosts();

      expect(posts, isNotEmpty);
      expect(posts.map((post) => post.productName), contains('Tomatoes 1kg'));
      expect(posts.map((post) => post.storeName), contains('Ataba Market'));
    });
  });
}
