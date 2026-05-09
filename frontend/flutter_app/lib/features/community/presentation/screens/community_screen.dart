// community_screen.dart
// Displays a community feed of recent price reports submitted by other users.
// Auto-uploaded posts from the Scan purchase-confirm flow are shown at the top.

import 'dart:io';

import 'package:flutter/material.dart';
import '../../../../core/services/supabase_service.dart';
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

  final _repo = CommunityPostRepositoryImpl();
  late Future<List<CommunityPost>> _postsFuture;
  final _locationController = TextEditingController();
  final _productController = TextEditingController();
  final _storeController = TextEditingController();
  String _locationFilter = '';
  String _productFilter = '';
  String _storeFilter = '';
  bool _filtersExpanded = true;
  _SortOption _sortOption = _SortOption.newest;

  @override
  void initState() {
    super.initState();
    _postsFuture = _repo.getUserPosts();
    _locationController.text = widget.initialLocationFilter;
    _productController.text = widget.initialItemFilter;
    _storeController.text = widget.initialStoreFilter;
    _locationFilter = _normalize(widget.initialLocationFilter);
    _productFilter = _normalize(widget.initialItemFilter);
    _storeFilter = _normalize(widget.initialStoreFilter);
    _locationController.addListener(_onFilterChanged);
    _productController.addListener(_onFilterChanged);
    _storeController.addListener(_onFilterChanged);
  }

  @override
  void dispose() {
    _locationController.dispose();
    _productController.dispose();
    _storeController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _postsFuture = _repo.getUserPosts();
    });
  }

  String _timeAgo(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} day ago';
  }

  String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(_multiSpaceRegExp, ' ');
  }

  bool _containsIgnoreCase(String text, String query) {
    if (query.isEmpty) return true;
    return _normalize(text).contains(_normalize(query));
  }

  List<_FeedItem> _applyFilters(List<_FeedItem> feed) {
    return feed.where((item) {
      return _containsIgnoreCase(item.location, _locationFilter) &&
          _containsIgnoreCase(item.productName, _productFilter) &&
          _containsIgnoreCase(item.marketName, _storeFilter);
    }).toList();
  }

  List<_FeedItem> _sortFeed(List<_FeedItem> feed) {
    final sorted = List<_FeedItem>.from(feed);
    switch (_sortOption) {
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

  void _onFilterChanged() {
    final nextLocation = _normalize(_locationController.text);
    final nextProduct = _normalize(_productController.text);
    final nextStore = _normalize(_storeController.text);
    if (nextLocation == _locationFilter &&
        nextProduct == _productFilter &&
        nextStore == _storeFilter) {
      return;
    }

    setState(() {
      _locationFilter = nextLocation;
      _productFilter = nextProduct;
      _storeFilter = nextStore;
    });
  }

  void _resetFilters() {
    _locationController.clear();
    _productController.clear();
    _storeController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Community')),
      body: FutureBuilder<List<CommunityPost>>(
        future: _postsFuture,
        builder: (context, snapshot) {
          final userPosts = snapshot.data ?? const <CommunityPost>[];
          final userFeed = userPosts
              .map(
                (post) => _FeedItem(
                  productName: post.productName,
                  price: post.price,
                  avgPrice: post.price,
                  marketName: post.storeName,
                  location: post.locationName,
                  timeAgo: _timeAgo(post.createdAt),
                  imagePath: post.imagePath,
                ),
              )
              .toList();

          final filtered = _applyFilters(userFeed);
          final feed = _sortFeed(filtered);

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _InlineFilters(
                  locationController: _locationController,
                  itemController: _productController,
                  storeController: _storeController,
                  filtersExpanded: _filtersExpanded,
                  hasActiveFilter: _hasActiveFilter,
                  sortOption: _sortOption,
                  resultCount: feed.length,
                  onToggleExpanded: () {
                    setState(() {
                      _filtersExpanded = !_filtersExpanded;
                    });
                  },
                  onSortChanged: (sort) {
                    setState(() {
                      _sortOption = sort;
                    });
                  },
                  onReset: _resetFilters,
                ),
                const SizedBox(height: 12),
                if (feed.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Text(
                      'No posts match the selected filters.',
                      style: TextStyle(color: AppColors.onSurfaceLight),
                    ),
                  ),
                for (final item in feed) _FeedCard(feed: item),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  final _FeedItem feed;
  const _FeedCard({required this.feed});

  @override
  Widget build(BuildContext context) {
    final status = PriceClassifier.classify(
      observed: feed.price,
      avg: feed.avgPrice,
      stdDev: feed.avgPrice <= 0 ? 1 : feed.avgPrice * 0.25,
    );
    final pct = PriceClassifier.percentDiff(feed.price, feed.avgPrice);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (feed.imagePath != null && feed.imagePath!.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: double.infinity,
                  height: 160,
                  child: _FeedImage(imagePath: feed.imagePath!),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feed.productName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${feed.marketName} · ${feed.location}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.onSurfaceLight,
                        ),
                      ),
                    ],
                  ),
                ),
                PriceBadge(
                  status: status,
                  label: pct >= 0
                      ? '+${pct.toStringAsFixed(0)}%'
                      : '${pct.toStringAsFixed(0)}%',
                ),
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
                        CurrencyDisplay.formatEgpWithKrw(feed.price),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'avg. ${CurrencyDisplay.formatEgpWithKrw(feed.avgPrice)}',
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
                  feed.timeAgo,
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
  final String imagePath;

  const _FeedImage({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    final localFile = File(imagePath);
    if (localFile.existsSync()) {
      return Image.file(localFile, fit: BoxFit.cover);
    }

    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return Image.network(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _brokenImage(),
      );
    }

    if (SupabaseService.isInitialized) {
      try {
        final signedUrl = SupabaseService.client.storage
            .from('community-images')
            .getPublicUrl(imagePath);
        return Image.network(
          signedUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _brokenImage(),
        );
      } catch (_) {
        return _brokenImage();
      }
    }

    return _brokenImage();
  }

  Widget _brokenImage() {
    return Container(
      color: Colors.grey.shade200,
      child: const Icon(Icons.broken_image_outlined),
    );
  }
}

class _FeedItem {
  final String productName;
  final double price;
  final double avgPrice;
  final String marketName;
  final String location;
  final String timeAgo;
  final String? imagePath;

  _FeedItem({
    required this.productName,
    required this.price,
    required this.avgPrice,
    required this.marketName,
    required this.location,
    required this.timeAgo,
    this.imagePath,
  });
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
