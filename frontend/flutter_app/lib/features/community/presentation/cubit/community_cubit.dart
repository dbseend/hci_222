import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/community_post.dart';
import '../../data/repositories/community_post_repository.dart';

enum CommunityLoadStatus { initial, loading, loaded, failure }

enum CommunitySortOption { newest, priceLowToHigh, priceHighToLow }

class CommunityState extends Equatable {
  final CommunityLoadStatus status;
  final List<CommunityPost> visiblePosts;
  final String locationFilter;
  final String productFilter;
  final String storeFilter;
  final CommunitySortOption sortOption;

  const CommunityState({
    this.status = CommunityLoadStatus.initial,
    this.visiblePosts = const [],
    this.locationFilter = '',
    this.productFilter = '',
    this.storeFilter = '',
    this.sortOption = CommunitySortOption.newest,
  });

  bool get hasActiveFilter =>
      locationFilter.isNotEmpty ||
      productFilter.isNotEmpty ||
      storeFilter.isNotEmpty;

  CommunityState copyWith({
    CommunityLoadStatus? status,
    List<CommunityPost>? visiblePosts,
    String? locationFilter,
    String? productFilter,
    String? storeFilter,
    CommunitySortOption? sortOption,
  }) {
    return CommunityState(
      status: status ?? this.status,
      visiblePosts: visiblePosts ?? this.visiblePosts,
      locationFilter: locationFilter ?? this.locationFilter,
      productFilter: productFilter ?? this.productFilter,
      storeFilter: storeFilter ?? this.storeFilter,
      sortOption: sortOption ?? this.sortOption,
    );
  }

  @override
  List<Object?> get props => [
    status,
    visiblePosts,
    locationFilter,
    productFilter,
    storeFilter,
    sortOption,
  ];
}

class CommunityCubit extends Cubit<CommunityState> {
  static final RegExp _multiSpaceRegExp = RegExp(r'\s+');

  final CommunityPostRepository _repository;
  List<CommunityPost> _allPosts = const [];

  CommunityCubit({
    required CommunityPostRepository repository,
    String initialLocationFilter = '',
    String initialProductFilter = '',
    String initialStoreFilter = '',
  }) : _repository = repository,
       super(
         CommunityState(
           locationFilter: _normalize(initialLocationFilter),
           productFilter: _normalize(initialProductFilter),
           storeFilter: _normalize(initialStoreFilter),
         ),
       );

  Future<void> load() async {
    emit(state.copyWith(status: CommunityLoadStatus.loading));
    try {
      _allPosts = await _repository.getUserPosts();
      _emitFiltered(status: CommunityLoadStatus.loaded);
    } catch (error) {
      debugPrint('[CommunityCubit] Failed to load feed: $error');
      emit(state.copyWith(status: CommunityLoadStatus.failure));
    }
  }

  void setFilters({
    required String location,
    required String product,
    String? store,
  }) {
    final next = state.copyWith(
      locationFilter: _normalize(location),
      productFilter: _normalize(product),
      storeFilter: _normalize(store ?? state.storeFilter),
    );
    if (next == state) return;
    emit(next);
    _emitFiltered();
  }

  void setSort(CommunitySortOption sortOption) {
    if (sortOption == state.sortOption) return;
    emit(state.copyWith(sortOption: sortOption));
    _emitFiltered();
  }

  void _emitFiltered({CommunityLoadStatus? status}) {
    final filtered = _allPosts
        .where((post) {
          return (state.locationFilter.isEmpty ||
                  _normalize(
                    post.locationName,
                  ).contains(state.locationFilter)) &&
              (state.productFilter.isEmpty ||
                  _normalize(post.productName).contains(state.productFilter)) &&
              (state.storeFilter.isEmpty ||
                  _normalize(post.storeName).contains(state.storeFilter));
        })
        .toList(growable: false);

    final sorted = List<CommunityPost>.of(filtered);
    switch (state.sortOption) {
      case CommunitySortOption.newest:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case CommunitySortOption.priceLowToHigh:
        sorted.sort((a, b) => a.price.compareTo(b.price));
      case CommunitySortOption.priceHighToLow:
        sorted.sort((a, b) => b.price.compareTo(a.price));
    }
    emit(state.copyWith(status: status ?? state.status, visiblePosts: sorted));
  }

  static String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(_multiSpaceRegExp, ' ');
  }
}
