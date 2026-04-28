import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../models/scan_route_data.dart';
import '../../data/models/region_stats.dart';
import '../bloc/price_bloc.dart';
import '../bloc/price_event.dart';
import '../bloc/price_state.dart';

class PriceStatsScreen extends StatelessWidget {
  final String productName;
  final String productId;
  final double? detectedPrice;

  const PriceStatsScreen({
    super.key,
    required this.productName,
    this.productId = 'p001',
    this.detectedPrice,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = productName.isNotEmpty ? productName : 'Detected product';
    return BlocProvider(
      create: (_) => PriceBloc()
        ..add(PriceStatsRequested(
          productId: productId,
          lat: 0, // LocationService fetches the real coordinates internally
          lon: 0,
        )),
      child: _PriceStatsView(
        displayName: displayName,
        productId: productId,
        detectedPrice: detectedPrice,
      ),
    );
  }
}

class _PriceStatsView extends StatelessWidget {
  final String displayName;
  final String productId;
  final double? detectedPrice;

  const _PriceStatsView({
    required this.displayName,
    required this.productId,
    this.detectedPrice,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(displayName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/scan'),
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
    final totalCount = stats.distribution.fold(0, (s, b) => s + b.count);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            child: Column(
              children: [
                _StatsRow('Average', stats.avgPrice, isPrimary: true),
                const Divider(height: 20),
                Row(
                  children: [
                    Expanded(child: _StatsRow('Min', stats.minPrice)),
                    Expanded(child: _StatsRow('Max', stats.maxPrice)),
                    Expanded(child: _StatsRow('Mode', stats.modePrice)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          const Text('Price Distribution',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Sample data: $totalCount entries (demo — not real regional data)',
              style:
                  const TextStyle(fontSize: 12, color: AppColors.onSurfaceLight)),
          const SizedBox(height: 8),
          Row(
            children: [
              _LegendItem(color: AppColors.primary, label: 'Avg. range'),
              const SizedBox(width: 16),
              if (detectedPrice != null)
                _LegendItem(
                    color: AppColors.warning, label: 'Scanned price', isDash: true),
            ],
          ),
          const SizedBox(height: 8),

          PriceHistogramWidget(stats: stats, userPrice: detectedPrice),

          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go(
              '/scan/input',
              extra: ScanRouteData(
                productName: displayName,
                productId: productId,
              ),
            ),
            child: const Text("Enter Seller's Price"),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final String label;
  final double value;
  final bool isPrimary;

  const _StatsRow(this.label, this.value, {this.isPrimary = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style:
                const TextStyle(fontSize: 12, color: AppColors.onSurfaceLight)),
        const SizedBox(height: 4),
        Text(
          '${value.toStringAsFixed(0)} EGP',
          style: TextStyle(
            fontSize: isPrimary ? 24 : 16,
            fontWeight: isPrimary ? FontWeight.bold : FontWeight.w600,
            color: isPrimary ? AppColors.primary : AppColors.onSurface,
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool isDash;

  const _LegendItem(
      {required this.color, required this.label, this.isDash = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        isDash
            ? Container(
                width: 16, height: 2, color: color,
                margin: const EdgeInsets.symmetric(vertical: 5))
            : Container(width: 12, height: 12, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.onSurfaceLight)),
      ],
    );
  }
}

/// Reusable histogram widget with optional vertical-line overlay for the user's price.
class PriceHistogramWidget extends StatelessWidget {
  final RegionStats stats;
  final double? userPrice;

  const PriceHistogramWidget({
    super.key,
    required this.stats,
    this.userPrice,
  });

  int? _findUserBucketIndex() {
    if (userPrice == null) return null;
    final buckets = stats.distribution;
    for (int i = 0; i < buckets.length; i++) {
      if (userPrice! >= buckets[i].start && userPrice! < buckets[i].end) {
        return i;
      }
    }
    return buckets.isNotEmpty ? buckets.length - 1 : null;
  }

  @override
  Widget build(BuildContext context) {
    final buckets = stats.distribution;
    if (buckets.isEmpty) return const SizedBox(height: 180);

    final maxCount =
        buckets.map((b) => b.count).reduce((a, b) => a > b ? a : b);
    final maxY = maxCount.toDouble() * 1.3;
    final userBucketIndex = _findUserBucketIndex();

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          barGroups: buckets.asMap().entries.map((e) {
            final i = e.key;
            final b = e.value;
            final isAvgBucket =
                stats.avgPrice >= b.start && stats.avgPrice < b.end;
            final isUserBucket = i == userBucketIndex;

            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: b.count.toDouble(),
                  color: isUserBucket
                      ? AppColors.warning
                      : isAvgBucket
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.35),
                  width: 22,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: isUserBucket,
                    toY: maxY,
                    color: AppColors.warning.withValues(alpha: 0.08),
                  ),
                ),
              ],
            );
          }).toList(),
          extraLinesData: userPrice != null && userBucketIndex != null
              ? ExtraLinesData(
                  verticalLines: [
                    VerticalLine(
                      x: userBucketIndex.toDouble(),
                      color: AppColors.warning,
                      strokeWidth: 2,
                      dashArray: [4, 3],
                      label: VerticalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.warning,
                          fontWeight: FontWeight.bold,
                        ),
                        labelResolver: (_) =>
                            '${userPrice!.toStringAsFixed(0)} EGP',
                      ),
                    ),
                  ],
                )
              : null,
          titlesData: FlTitlesData(
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= buckets.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      buckets[i].start.toInt().toString(),
                      style: const TextStyle(
                          fontSize: 9, color: AppColors.onSurfaceLight),
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxCount / 3,
            getDrawingHorizontalLine: (_) => const FlLine(
              color: Color(0xFFEEEEEE),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}
