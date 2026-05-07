import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_display.dart';
import '../../../../core/utils/price_classifier.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/price_badge.dart';
import '../../../community/data/repositories/community_post_repository.dart';
import '../../data/models/region_stats.dart';
import '../models/scan_route_data.dart';
import '../bloc/price_bloc.dart';
import '../bloc/price_event.dart';
import '../bloc/price_state.dart';
import 'price_stats_screen.dart' show PriceHistogramWidget;

class PriceAnalysisScreen extends StatelessWidget {
  final String productName;
  final String productId;
  final double inputPrice;
  final double? detectedPrice;
  final String? capturedImagePath;

  const PriceAnalysisScreen({
    super.key,
    required this.productName,
    required this.inputPrice,
    this.productId = 'p001',
    this.detectedPrice,
    this.capturedImagePath,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          PriceBloc()
            ..add(PriceStatsRequested(productId: productId, lat: 0, lon: 0)),
      child: _PriceAnalysisView(
        productName: productName,
        productId: productId,
        inputPrice: inputPrice,
        detectedPrice: detectedPrice,
        capturedImagePath: capturedImagePath,
      ),
    );
  }
}

class _PriceAnalysisView extends StatelessWidget {
  final String productName;
  final String productId;
  final double inputPrice;
  final double? detectedPrice;
  final String? capturedImagePath;

  const _PriceAnalysisView({
    required this.productName,
    required this.productId,
    required this.inputPrice,
    this.detectedPrice,
    this.capturedImagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Price Analysis'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(
            '/scan/input',
            extra: ScanRouteData(
              productName: productName,
              productId: productId,
              detectedPrice: detectedPrice,
              inputPrice: inputPrice,
              capturedImagePath: capturedImagePath,
            ),
          ),
        ),
      ),
      body: BlocBuilder<PriceBloc, PriceState>(
        builder: (context, state) {
          if (state is PriceLoading || state is PriceInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is PriceError) {
            return AppErrorWidget(
              message: state.message,
              onRetry: () => context.read<PriceBloc>().add(
                PriceStatsRequested(productId: productId, lat: 0, lon: 0),
              ),
            );
          }
          if (state is PriceLoaded) {
            return _buildContent(context, state.stats);
          }
          return const SizedBox();
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, RegionStats stats) {
    final status = PriceClassifier.classify(
      observed: inputPrice,
      avg: stats.avgPrice,
      stdDev: stats.stdDev,
    );
    final pct = PriceClassifier.percentDiff(inputPrice, stats.avgPrice);
    final message = PriceClassifier.statusMessage(status, pct);

    final statusColor = switch (status) {
      PriceStatus.safe => AppColors.safe,
      PriceStatus.negotiable => AppColors.negotiable,
      PriceStatus.warning => AppColors.warning,
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Main result card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: statusColor.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                PriceBadge(status: status, label: message, large: true),
                const SizedBox(height: 24),
                Text(
                  CurrencyDisplay.formatEgp(inputPrice),
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  CurrencyDisplay.formatKrw(inputPrice),
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.onSurfaceLight,
                  ),
                ),
                Text(
                  productName,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.onSurfaceLight,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Histogram (with vertical line)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Price Distribution',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 12),
                PriceHistogramWidget(stats: stats, userPrice: inputPrice),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Comparison figures
          AppCard(
            child: _CompareContent(inputPrice: inputPrice, stats: stats),
          ),

          const SizedBox(height: 20),

          // Negotiation guide
          if (status != PriceStatus.safe)
            AppCard(
              child: _NegotiationContent(status: status, avg: stats.avgPrice),
            ),

          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: () async {
              final repo = CommunityPostRepositoryImpl();
              await repo.addPurchasePost(
                productName: productName,
                price: inputPrice,
                imagePath: capturedImagePath,
              );
              if (!context.mounted) return;
              context.go(
                '/scan/final',
                extra: ScanRouteData(
                  productName: productName,
                  productId: productId,
                  detectedPrice: detectedPrice,
                  finalPrice: inputPrice,
                  capturedImagePath: capturedImagePath,
                ),
              );
            },
            child: const Text('I bought at this price'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => context.go(
              '/scan/input',
              extra: ScanRouteData(
                productName: productName,
                productId: productId,
                detectedPrice: detectedPrice,
                inputPrice: inputPrice,
                capturedImagePath: capturedImagePath,
              ),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Re-analyze with a different price'),
          ),
        ],
      ),
    );
  }
}

class _CompareContent extends StatelessWidget {
  final double inputPrice;
  final RegionStats stats;

  const _CompareContent({required this.inputPrice, required this.stats});

  @override
  Widget build(BuildContext context) {
    final diff = inputPrice - stats.avgPrice;
    final isHigher = diff > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'vs. Regional Average',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatItem('Offered Price', inputPrice, bold: true),
            Column(
              children: [
                Icon(
                  isHigher ? Icons.arrow_upward : Icons.arrow_downward,
                  color: isHigher ? AppColors.warning : AppColors.safe,
                  size: 28,
                ),
                Text(
                  CurrencyDisplay.formatEgp(diff.abs()),
                  style: TextStyle(
                    color: isHigher ? AppColors.warning : AppColors.safe,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  CurrencyDisplay.formatKrw(diff.abs()),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.onSurfaceLight,
                  ),
                ),
              ],
            ),
            _StatItem('Regional Avg.', stats.avgPrice),
          ],
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final double value;
  final bool bold;

  const _StatItem(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceLight),
        ),
        const SizedBox(height: 4),
        Text(
          CurrencyDisplay.formatEgp(value),
          style: TextStyle(
            fontSize: bold ? 20 : 18,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          CurrencyDisplay.formatKrw(value),
          style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceLight),
        ),
      ],
    );
  }
}

class _NegotiationContent extends StatelessWidget {
  final PriceStatus status;
  final double avg;

  const _NegotiationContent({required this.status, required this.avg});

  @override
  Widget build(BuildContext context) {
    final targetPrice = avg * 1.05;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.handshake, color: AppColors.primary, size: 20),
            SizedBox(width: 8),
            Text(
              'Negotiation Guide',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Target: negotiate below ${CurrencyDisplay.formatEgpWithKrw(targetPrice)}',
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 12),
        const Text(
          'Useful phrases',
          style: TextStyle(fontSize: 12, color: AppColors.onSurfaceLight),
        ),
        const SizedBox(height: 8),
        _PhraseChip('Too expensive', 'هذا غالي جداً'),
        const SizedBox(height: 6),
        _PhraseChip('Please give a discount', 'خفّض السعر من فضلك'),
      ],
    );
  }
}

class _PhraseChip extends StatelessWidget {
  final String kr;
  final String ar;

  const _PhraseChip(this.kr, this.ar);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(kr, style: const TextStyle(fontSize: 13)),
          const Spacer(),
          Text(
            ar,
            style: const TextStyle(fontSize: 15, fontFamily: 'NotoSansArabic'),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(width: 8),
          const Icon(Icons.volume_up, size: 16, color: AppColors.primary),
        ],
      ),
    );
  }
}
