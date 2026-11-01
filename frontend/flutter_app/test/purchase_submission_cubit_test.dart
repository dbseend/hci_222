import 'package:flutter_test/flutter_test.dart';
import 'package:trueprice/features/community/data/models/community_post.dart';
import 'package:trueprice/features/community/data/repositories/community_post_repository.dart';
import 'package:trueprice/features/community/presentation/cubit/purchase_submission_cubit.dart';

void main() {
  test('submits purchase through repository and emits success', () async {
    final repository = _RecordingRepository();
    final cubit = PurchaseSubmissionCubit(repository: repository);
    addTearDown(cubit.close);

    await cubit.submit(productName: 'Tomato', productCode: 'tomato', price: 20);

    expect(cubit.state.status, PurchaseSubmissionStatus.success);
    expect(repository.productCode, 'tomato');
    expect(repository.price, 20);
  });
}

class _RecordingRepository implements CommunityPostRepository {
  String? productCode;
  double? price;

  @override
  Future<void> addPurchasePost({
    required String productName,
    required double price,
    String? imagePath,
    String productCode = 'tomato',
    String storeName = 'Traveler Report',
    String locationName = 'Unknown',
  }) async {
    this.productCode = productCode;
    this.price = price;
  }

  @override
  Future<List<CommunityPost>> getUserPosts() async => const [];
}
