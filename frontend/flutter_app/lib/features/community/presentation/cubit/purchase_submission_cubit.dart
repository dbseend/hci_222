import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/community_post_repository.dart';

enum PurchaseSubmissionStatus { initial, submitting, success, failure }

class PurchaseSubmissionState extends Equatable {
  final PurchaseSubmissionStatus status;

  const PurchaseSubmissionState({
    this.status = PurchaseSubmissionStatus.initial,
  });

  @override
  List<Object?> get props => [status];
}

class PurchaseSubmissionCubit extends Cubit<PurchaseSubmissionState> {
  final CommunityPostRepository _repository;

  PurchaseSubmissionCubit({required CommunityPostRepository repository})
    : _repository = repository,
      super(const PurchaseSubmissionState());

  Future<void> submit({
    required String productName,
    required String productCode,
    required double price,
    String? imagePath,
    String storeName = 'Traveler Report',
    String locationName = 'Unknown',
  }) async {
    if (state.status == PurchaseSubmissionStatus.submitting) return;
    emit(
      const PurchaseSubmissionState(
        status: PurchaseSubmissionStatus.submitting,
      ),
    );
    try {
      await _repository.addPurchasePost(
        productName: productName,
        productCode: productCode,
        price: price,
        imagePath: imagePath,
        storeName: storeName,
        locationName: locationName,
      );
      emit(
        const PurchaseSubmissionState(status: PurchaseSubmissionStatus.success),
      );
    } catch (error) {
      debugPrint('[PurchaseSubmissionCubit] Submission failed: $error');
      emit(
        const PurchaseSubmissionState(status: PurchaseSubmissionStatus.failure),
      );
    }
  }
}
