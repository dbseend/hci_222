// community_screen.dart
// Displays a community feed of recent price reports submitted by other users.
// Auto-uploaded posts from the Scan purchase-confirm flow are shown at the top.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_display.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/models/community_post.dart';
import '../../data/repositories/community_post_repository.dart';
import '../cubit/community_cubit.dart';

class CommunityScreen extends StatelessWidget {
  final String initialLocationFilter;
  final String initialItemFilter;
  final String initialStoreFilter;
  final CommunityPostRepository? repository;

  const CommunityScreen({
    super.key,
    this.initialLocationFilter = '',
    this.initialItemFilter = '',
    this.initialStoreFilter = '',
    this.repository,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CommunityCubit(
        repository: repository ?? CommunityPostRepositoryImpl(),
        initialLocationFilter: initialLocationFilter,
        initialProductFilter: initialItemFilter,
        initialStoreFilter: initialStoreFilter,
      )..load(),
      child: const _CommunityView(),
    );
  }
}

class _CommunityView extends StatefulWidget {
  const _CommunityView();

  @override
  State<_CommunityView> createState() => _CommunityViewState();
}

class _CommunityViewState extends State<_CommunityView> {
  static const Duration _filterDebounce = Duration(milliseconds: 180);

  final _locationController = TextEditingController();
  final _productController = TextEditingController();
  final _storeController = TextEditingController();
  Timer? _filterDebounceTimer;
  bool _filtersExpanded = true;

  @override
  void initState() {
    super.initState();
    final state = context.read<CommunityCubit>().state;
    _locationController.text = state.locationFilter;
    _productController.text = state.productFilter;
    _storeController.text = state.storeFilter;
    _locationController.addListener(_onFilterChanged);
    _productController.addListener(_onFilterChanged);
    _storeController.addListener(_onFilterChanged);
  }

  @override
  void dispose() {
    _filterDebounceTimer?.cancel();
    _locationController.dispose();
    _productController.dispose();
    _storeController.dispose();
    super.dispose();
  }

  void _onFilterChanged() {
    _filterDebounceTimer?.cancel();
    _filterDebounceTimer = Timer(_filterDebounce, () {
      if (!mounted) return;
      context.read<CommunityCubit>().setFilters(
        location: _locationController.text,
        product: _productController.text,
        store: _storeController.text,
      );
    });
  }

  void _onSortChanged(CommunitySortOption sort) {
    context.read<CommunityCubit>().setSort(sort);
  }

  void _resetFilters() {
    _filterDebounceTimer?.cancel();
    _locationController.clear();
    _productController.clear();
    _storeController.clear();
    context.read<CommunityCubit>().setFilters(
      location: '',
      product: '',
      store: '',
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CommunityCubit, CommunityState>(
      builder: (context, state) {
        if (state.status == CommunityLoadStatus.loading ||
            state.status == CommunityLoadStatus.initial) {
          return Scaffold(
            appBar: AppBar(title: const Text('Community')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (state.status == CommunityLoadStatus.failure) {
          return Scaffold(
            appBar: AppBar(title: const Text('Community')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Failed to load community posts.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: context.read<CommunityCubit>().load,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final posts = state.visiblePosts;
        return Scaffold(
          appBar: AppBar(title: const Text('Community')),
          body: RefreshIndicator(
            onRefresh: context.read<CommunityCubit>().load,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: posts.isEmpty ? 3 : posts.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _InlineFilters(
                    locationController: _locationController,
                    itemController: _productController,
                    storeController: _storeController,
                    filtersExpanded: _filtersExpanded,
                    hasActiveFilter: state.hasActiveFilter,
                    sortOption: state.sortOption,
                    resultCount: posts.length,
                    onToggleExpanded: () {
                      setState(() {
                        _filtersExpanded = !_filtersExpanded;
                      });
                    },
                    onSortChanged: _onSortChanged,
                    onReset: _resetFilters,
                  );
                }
                if (index == 1) return const SizedBox(height: 12);
                if (posts.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Text(
                      'No posts match the selected filters.',
                      style: TextStyle(color: AppColors.onSurfaceLight),
                    ),
                  );
                }
                return _FeedCard(
                  card: _FeedCardData.fromPost(posts[index - 2]),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _FeedCard extends StatelessWidget {
  final _FeedCardData card;
  const _FeedCard({required this.card});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: double.infinity,
                height: 160,
                child: _FeedImage(
                  imagePath: card.imagePath,
                  productName: card.productName,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.productName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${card.marketName} · ${card.location}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.onSurfaceLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    card.priceText,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  card.timeAgo,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.onSurfaceLight,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedImage extends StatelessWidget {
  final String? imagePath;
  final String productName;

  const _FeedImage({required this.imagePath, required this.productName});

  @override
  Widget build(BuildContext context) {
    final path = imagePath?.trim();
    if (path == null || path.isEmpty) {
      return _defaultImage();
    }

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _defaultImage(),
      );
    }

    if (path.startsWith('/')) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _defaultImage(),
      );
    }

    return _defaultImage();
  }

  Widget _defaultImage() {
    return Container(
      key: const ValueKey('community-default-image'),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3EE),
        border: Border.all(color: const Color(0xFFD7E7DC)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -20,
            top: -24,
            child: Icon(
              Icons.shopping_basket_outlined,
              size: 112,
              color: AppColors.primary.withValues(alpha: 0.12),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.image_outlined,
                  size: 36,
                  color: AppColors.primary.withValues(alpha: 0.74),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Text(
                    'Purchase photo',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedCardData {
  final String productName;
  final String marketName;
  final String location;
  final String priceText;
  final String timeAgo;
  final String? imagePath;

  const _FeedCardData({
    required this.productName,
    required this.marketName,
    required this.location,
    required this.priceText,
    required this.timeAgo,
    this.imagePath,
  });

  factory _FeedCardData.fromPost(CommunityPost post) {
    return _FeedCardData(
      productName: post.productName,
      marketName: post.storeName,
      location: post.locationName,
      priceText: CurrencyDisplay.formatEgpWithKrw(post.price),
      timeAgo: _timeAgo(post.createdAt),
      imagePath: post.imagePath,
    );
  }
}

String _timeAgo(DateTime createdAt) {
  final diff = DateTime.now().difference(createdAt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hr ago';
  return '${diff.inDays} day ago';
}

class _InlineFilters extends StatelessWidget {
  final TextEditingController locationController;
  final TextEditingController itemController;
  final TextEditingController storeController;
  final bool filtersExpanded;
  final bool hasActiveFilter;
  final CommunitySortOption sortOption;
  final int resultCount;
  final VoidCallback onToggleExpanded;
  final ValueChanged<CommunitySortOption> onSortChanged;
  final VoidCallback onReset;

  const _InlineFilters({
    required this.locationController,
    required this.itemController,
    required this.storeController,
    required this.filtersExpanded,
    required this.hasActiveFilter,
    required this.sortOption,
    required this.resultCount,
    required this.onToggleExpanded,
    required this.onSortChanged,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Filters',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const Spacer(),
              Text(
                '$resultCount results',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.onSurfaceLight,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: hasActiveFilter ? onReset : null,
                child: const Text('Reset'),
              ),
              const SizedBox(width: 8),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onToggleExpanded,
                icon: Icon(
                  filtersExpanded ? Icons.expand_less : Icons.expand_more,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<CommunitySortOption>(
            initialValue: sortOption,
            isDense: true,
            decoration: const InputDecoration(
              labelText: 'Sort',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              if (value == null) return;
              onSortChanged(value);
            },
            items: const [
              DropdownMenuItem(
                value: CommunitySortOption.newest,
                child: Text('Newest'),
              ),
              DropdownMenuItem(
                value: CommunitySortOption.priceLowToHigh,
                child: Text('Price: Low to High'),
              ),
              DropdownMenuItem(
                value: CommunitySortOption.priceHighToLow,
                child: Text('Price: High to Low'),
              ),
            ],
          ),
          if (filtersExpanded) ...[
            const SizedBox(height: 10),
            TextField(
              controller: locationController,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Location',
                hintText: 'e.g. Downtown Cairo',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: itemController,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Item',
                hintText: 'e.g. Tomatoes',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: storeController,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Store/Company',
                hintText: 'e.g. Ataba Market',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
