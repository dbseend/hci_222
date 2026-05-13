// community_screen.dart
// Displays a community feed of recent price reports submitted by other users.
// Auto-uploaded posts from the Scan purchase-confirm flow are shown at the top.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_display.dart';
import '../../../../core/utils/price_classifier.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/price_badge.dart';
import '../../data/models/community_post.dart';
import '../../data/repositories/community_post_repository.dart';

class CommunityScreen extends StatefulWidget {
  final String initialLocationFilter;
  final String initialItemFilter;
  final String initialStoreFilter;

  const CommunityScreen({
    super.key,
    this.initialLocationFilter = '',
    this.initialItemFilter = '',
    this.initialStoreFilter = '',
  });

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  static final RegExp _multiSpaceRegExp = RegExp(r'\s+');
  static const Duration _filterDebounce = Duration(milliseconds: 180);
  static const int _precomputeThreshold = 80;

  final _repo = CommunityPostRepositoryImpl();
  final _locationController = TextEditingController();
  final _productController = TextEditingController();
  final _storeController = TextEditingController();
  Timer? _filterDebounceTimer;
  List<_FeedItem> _allFeed = const [];
  List<_FeedItem> _visibleFeed = const [];
  List<_FeedCardData>? _precomputedVisibleCards;
  bool _isLoading = true;
  String? _loadError;
  String _locationFilter = '';
  String _productFilter = '';
  String _storeFilter = '';
  bool _filtersExpanded = true;
  _SortOption _sortOption = _SortOption.newest;

  @override
  void initState() {
    super.initState();
    _locationController.text = widget.initialLocationFilter;
    _productController.text = widget.initialItemFilter;
    _storeController.text = widget.initialStoreFilter;
    _locationFilter = _normalize(widget.initialLocationFilter);
    _productFilter = _normalize(widget.initialItemFilter);
    _storeFilter = _normalize(widget.initialStoreFilter);
    _locationController.addListener(_onFilterChanged);
    _productController.addListener(_onFilterChanged);
    _storeController.addListener(_onFilterChanged);
    _loadPosts();
  }

  @override
  void dispose() {
    _filterDebounceTimer?.cancel();
    _locationController.dispose();
    _productController.dispose();
    _storeController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }
    try {
      final userPosts = await _repo.getUserPosts();
      final nextFeed = userPosts
          .map((post) => _FeedItem.fromPost(post, normalizer: _normalize))
          .toList();
      if (!mounted) return;
      setState(() {
        _allFeed = nextFeed;
        _isLoading = false;
      });
      _applyFilterAndSort(
        locationFilter: _locationFilter,
        productFilter: _productFilter,
        storeFilter: _storeFilter,
        sortOption: _sortOption,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = '$e';
      });
    }
  }

  Future<void> _reload() async {
    await _loadPosts();
  }

  static String _timeAgo(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} day ago';
  }

  String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(_multiSpaceRegExp, ' ');
  }

  List<_FeedItem> _applyFilters(
    List<_FeedItem> feed, {
    required String locationFilter,
    required String productFilter,
    required String storeFilter,
  }) {
    return feed.where((item) {
      return (locationFilter.isEmpty ||
              item.locationNormalized.contains(locationFilter)) &&
          (productFilter.isEmpty ||
              item.productNameNormalized.contains(productFilter)) &&
          (storeFilter.isEmpty ||
              item.marketNameNormalized.contains(storeFilter));
    }).toList();
  }

  List<_FeedItem> _sortFeed(List<_FeedItem> feed, _SortOption sortOption) {
    final sorted = List<_FeedItem>.from(feed);
    switch (sortOption) {
      case _SortOption.newest:
        return sorted;
      case _SortOption.priceLowToHigh:
        sorted.sort((a, b) => a.price.compareTo(b.price));
        return sorted;
      case _SortOption.priceHighToLow:
        sorted.sort((a, b) => b.price.compareTo(a.price));
        return sorted;
    }
  }

  bool get _hasActiveFilter =>
      _locationFilter.isNotEmpty ||
      _productFilter.isNotEmpty ||
      _storeFilter.isNotEmpty;

  void _applyFilterAndSort({
    required String locationFilter,
    required String productFilter,
    required String storeFilter,
    required _SortOption sortOption,
  }) {
    final filtered = _applyFilters(
      _allFeed,
      locationFilter: locationFilter,
      productFilter: productFilter,
      storeFilter: storeFilter,
    );
    final sorted = _sortFeed(filtered, sortOption);
    final precomputed = sorted.length > _precomputeThreshold
        ? sorted.map(_FeedCardData.fromItem).toList(growable: false)
        : null;

    if (!mounted) return;
    setState(() {
      _locationFilter = locationFilter;
      _productFilter = productFilter;
      _storeFilter = storeFilter;
      _sortOption = sortOption;
      _visibleFeed = sorted;
      _precomputedVisibleCards = precomputed;
    });
  }

  void _onFilterChanged() {
    _filterDebounceTimer?.cancel();
    _filterDebounceTimer = Timer(_filterDebounce, () {
      if (!mounted) return;
      final nextLocation = _normalize(_locationController.text);
      final nextProduct = _normalize(_productController.text);
      final nextStore = _normalize(_storeController.text);
      if (nextLocation == _locationFilter &&
          nextProduct == _productFilter &&
          nextStore == _storeFilter) {
        return;
      }
      _applyFilterAndSort(
        locationFilter: nextLocation,
        productFilter: nextProduct,
        storeFilter: nextStore,
        sortOption: _sortOption,
      );
    });
  }

  void _onSortChanged(_SortOption sort) {
    if (_sortOption == sort) return;
    _applyFilterAndSort(
      locationFilter: _locationFilter,
      productFilter: _productFilter,
      storeFilter: _storeFilter,
      sortOption: sort,
    );
  }

  void _resetFilters() {
    _filterDebounceTimer?.cancel();
    _locationController.clear();
    _productController.clear();
    _storeController.clear();
    _applyFilterAndSort(
      locationFilter: '',
      productFilter: '',
      storeFilter: '',
      sortOption: _sortOption,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Community')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
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
                const SizedBox(height: 8),
                Text(
                  _loadError!,
                  style: const TextStyle(color: AppColors.onSurfaceLight),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _loadPosts,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Community')),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _visibleFeed.isEmpty ? 3 : _visibleFeed.length + 2,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _InlineFilters(
                locationController: _locationController,
                itemController: _productController,
                storeController: _storeController,
                filtersExpanded: _filtersExpanded,
                hasActiveFilter: _hasActiveFilter,
                sortOption: _sortOption,
                resultCount: _visibleFeed.length,
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
            if (_visibleFeed.isEmpty) {
              return const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Text(
                  'No posts match the selected filters.',
                  style: TextStyle(color: AppColors.onSurfaceLight),
                ),
              );
            }

            final item = _visibleFeed[index - 2];
            final precomputedCards = _precomputedVisibleCards;
            if (precomputedCards != null &&
                precomputedCards.length == _visibleFeed.length) {
              return _FeedCard(card: precomputedCards[index - 2]);
            }
            return _FeedCard(card: _FeedCardData.fromItem(item));
          },
        ),
      ),
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
                PriceBadge(status: card.status, label: card.badgeLabel),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.priceText,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'avg. ${card.avgPriceText}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.onSurfaceLight,
                        ),
                      ),
                    ],
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

class _FeedItem {
  final String productName;
  final double price;
  final double avgPrice;
  final String marketName;
  final String location;
  final String productNameNormalized;
  final String marketNameNormalized;
  final String locationNormalized;
  final String timeAgo;
  final String priceText;
  final String avgPriceText;
  final PriceStatus status;
  final String badgeLabel;
  final String? imagePath;

  _FeedItem({
    required this.productName,
    required this.price,
    required this.avgPrice,
    required this.marketName,
    required this.location,
    required this.productNameNormalized,
    required this.marketNameNormalized,
    required this.locationNormalized,
    required this.timeAgo,
    required this.priceText,
    required this.avgPriceText,
    required this.status,
    required this.badgeLabel,
    this.imagePath,
  });

  factory _FeedItem.fromPost(
    CommunityPost post, {
    required String Function(String value) normalizer,
  }) {
    final avgPrice = post.price;
    final status = PriceClassifier.classify(
      observed: post.price,
      avg: avgPrice,
      stdDev: avgPrice <= 0 ? 1 : avgPrice * 0.25,
    );
    final pct = PriceClassifier.percentDiff(post.price, avgPrice);
    final badgeLabel = pct >= 0
        ? '+${pct.toStringAsFixed(0)}%'
        : '${pct.toStringAsFixed(0)}%';

    return _FeedItem(
      productName: post.productName,
      price: post.price,
      avgPrice: avgPrice,
      marketName: post.storeName,
      location: post.locationName,
      productNameNormalized: normalizer(post.productName),
      marketNameNormalized: normalizer(post.storeName),
      locationNormalized: normalizer(post.locationName),
      timeAgo: _CommunityScreenState._timeAgo(post.createdAt),
      priceText: CurrencyDisplay.formatEgpWithKrw(post.price),
      avgPriceText: CurrencyDisplay.formatEgpWithKrw(avgPrice),
      status: status,
      badgeLabel: badgeLabel,
      imagePath: post.imagePath,
    );
  }
}

class _FeedCardData {
  final String productName;
  final String marketName;
  final String location;
  final String priceText;
  final String avgPriceText;
  final String timeAgo;
  final PriceStatus status;
  final String badgeLabel;
  final String? imagePath;

  const _FeedCardData({
    required this.productName,
    required this.marketName,
    required this.location,
    required this.priceText,
    required this.avgPriceText,
    required this.timeAgo,
    required this.status,
    required this.badgeLabel,
    this.imagePath,
  });

  factory _FeedCardData.fromItem(_FeedItem item) {
    return _FeedCardData(
      productName: item.productName,
      marketName: item.marketName,
      location: item.location,
      priceText: item.priceText,
      avgPriceText: item.avgPriceText,
      timeAgo: item.timeAgo,
      status: item.status,
      badgeLabel: item.badgeLabel,
      imagePath: item.imagePath,
    );
  }
}

class _InlineFilters extends StatelessWidget {
  final TextEditingController locationController;
  final TextEditingController itemController;
  final TextEditingController storeController;
  final bool filtersExpanded;
  final bool hasActiveFilter;
  final _SortOption sortOption;
  final int resultCount;
  final VoidCallback onToggleExpanded;
  final ValueChanged<_SortOption> onSortChanged;
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
          DropdownButtonFormField<_SortOption>(
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
                value: _SortOption.newest,
                child: Text('Newest'),
              ),
              DropdownMenuItem(
                value: _SortOption.priceLowToHigh,
                child: Text('Price: Low to High'),
              ),
              DropdownMenuItem(
                value: _SortOption.priceHighToLow,
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

enum _SortOption { newest, priceLowToHigh, priceHighToLow }
