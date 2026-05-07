// community_screen.dart
// Displays a community feed of recent price reports submitted by other users.
// Auto-uploaded posts from the Scan purchase-confirm flow are shown at the top.

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
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final _repo = CommunityPostRepositoryImpl();
  late Future<List<CommunityPost>> _postsFuture;

  // Mock feed data (Cairo, Egypt — prices in EGP)
  static final _mockFeed = [
    _FeedItem(
      productName: 'Grapes 1kg',
      price: 65.0,
      avgPrice: 55.0,
      marketName: 'Khan el-Khalili Market',
      timeAgo: '2 min ago',
    ),
    _FeedItem(
      productName: 'Tomatoes 1kg',
      price: 14.0,
      avgPrice: 10.0,
      marketName: 'Ataba Market',
      timeAgo: '15 min ago',
    ),
    _FeedItem(
      productName: 'Cucumbers 1kg',
      price: 6.0,
      avgPrice: 8.0,
      marketName: 'Imbaba Market',
      timeAgo: '32 min ago',
    ),
    _FeedItem(
      productName: 'Pomegranate 1 pc',
      price: 45.0,
      avgPrice: 30.0,
      marketName: 'Khan el-Khalili Market',
      timeAgo: '1 hr ago',
    ),
    _FeedItem(
      productName: 'Lemons 5 pcs',
      price: 18.0,
      avgPrice: 20.0,
      marketName: 'Ataba Market',
      timeAgo: '2 hr ago',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _postsFuture = _repo.getUserPosts();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
        actions: [
          IconButton(icon: const Icon(Icons.filter_list), onPressed: () {}),
        ],
      ),
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
                  marketName: 'Traveler Report',
                  timeAgo: _timeAgo(post.createdAt),
                  imagePath: post.imagePath,
                ),
              )
              .toList();

          final feed = [...userFeed, ..._mockFeed];

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: feed.length,
              itemBuilder: (_, i) => _FeedCard(feed: feed[i]),
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
                  child: File(feed.imagePath!).existsSync()
                      ? Image.file(File(feed.imagePath!), fit: BoxFit.cover)
                      : Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
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
                        feed.marketName,
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

class _FeedItem {
  final String productName;
  final double price;
  final double avgPrice;
  final String marketName;
  final String timeAgo;
  final String? imagePath;

  _FeedItem({
    required this.productName,
    required this.price,
    required this.avgPrice,
    required this.marketName,
    required this.timeAgo,
    this.imagePath,
  });
}
