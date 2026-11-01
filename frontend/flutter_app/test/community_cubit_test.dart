import 'package:flutter_test/flutter_test.dart';
import 'package:trueprice/features/community/data/models/community_post.dart';
import 'package:trueprice/features/community/data/repositories/community_post_repository.dart';
import 'package:trueprice/features/community/presentation/cubit/community_cubit.dart';

void main() {
  test(
    'loads, filters, and sorts community posts outside the widget',
    () async {
      final cubit = CommunityCubit(
        repository: _FakeCommunityRepository([
          CommunityPost(
            id: '1',
            productName: 'Tomato',
            price: 20,
            storeName: 'Ataba Market',
            locationName: 'Downtown Cairo',
            createdAt: DateTime(2026, 1, 1),
          ),
          CommunityPost(
            id: '2',
            productName: 'Apple',
            price: 10,
            storeName: 'Old Market',
            locationName: 'Giza',
            createdAt: DateTime(2026, 1, 2),
          ),
        ]),
      );
      addTearDown(cubit.close);

      await cubit.load();
      cubit.setFilters(location: ' downtown  cairo ', product: 'TOMATO');

      expect(cubit.state.status, CommunityLoadStatus.loaded);
      expect(cubit.state.visiblePosts.single.productName, 'Tomato');

      cubit.setFilters(location: '', product: '');
      cubit.setSort(CommunitySortOption.priceLowToHigh);

      expect(cubit.state.visiblePosts.first.productName, 'Apple');
    },
  );
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
