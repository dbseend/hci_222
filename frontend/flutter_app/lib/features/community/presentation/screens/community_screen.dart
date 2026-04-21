// community_screen.dart
// Displays a community feed of recent price reports submitted by other users.
// Each card shows the product name, market, reported price, average price,
// a percentage badge (fair / high / low), and how long ago it was submitted.
// All data is currently mocked; replace _mockFeed with a live API call when
// the backend is available.

import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/price_classifier.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/price_badge.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  // Mock feed data (Cairo, Egypt — prices in EGP)
  // Price reference: Grapes 40–80 EGP, Tomatoes 5–15 EGP, Cucumbers 5–10 EGP
  static final _mockFeed = [
    _MockFeed('Grapes 1kg', 65.0, 55.0, 'Khan el-Khalili Market', '2 min ago'),
    _MockFeed('Tomatoes 1kg', 14.0, 10.0, 'Ataba Market', '15 min ago'),
    _MockFeed('Cucumbers 1kg', 6.0, 8.0, 'Imbaba Market', '32 min ago'),
    _MockFeed(
      'Pomegranate 1 pc',
      45.0,
      30.0,
      'Khan el-Khalili Market',
      '1 hr ago',
    ),
    _MockFeed('Lemons 5 pcs', 18.0, 20.0, 'Ataba Market', '2 hr ago'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
        actions: [
          IconButton(icon: const Icon(Icons.filter_list), onPressed: () {}),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _mockFeed.length,
        itemBuilder: (_, i) => _FeedCard(feed: _mockFeed[i]),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Share Price', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  final _MockFeed feed;
  const _FeedCard({required this.feed});

  @override
  Widget build(BuildContext context) {
    final status = PriceClassifier.classify(
      observed: feed.price,
      avg: feed.avgPrice,
      stdDev: feed.avgPrice * 0.25,
    );
    final pct = PriceClassifier.percentDiff(feed.price, feed.avgPrice);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
              children: [
                Text(
                  '${feed.price.toStringAsFixed(0)} EGP',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(avg. ${feed.avgPrice.toStringAsFixed(0)} EGP)',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.onSurfaceLight,
                  ),
                ),
                const Spacer(),
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

class _MockFeed {
  final String productName;
  final double price;
  final double avgPrice;
  final String marketName;
  final String timeAgo;
  _MockFeed(
    this.productName,
    this.price,
    this.avgPrice,
    this.marketName,
    this.timeAgo,
  );
}
