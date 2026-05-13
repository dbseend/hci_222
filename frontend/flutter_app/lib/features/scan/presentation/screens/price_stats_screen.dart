import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_display.dart';
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
  final String? capturedImagePath;
  final String? historyId;

  const PriceStatsScreen({
    super.key,
    required this.productName,
    this.productId = 'tomato',
    this.detectedPrice,
    this.capturedImagePath,
    this.historyId,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = productName.isNotEmpty
        ? productName
        : 'Detected product';
    return BlocProvider(
      create: (_) => PriceBloc()
        ..add(
          PriceStatsRequested(
            productId: productId,
            lat: 0, // LocationService fetches the real coordinates internally
            lon: 0,
          ),
        ),
      child: _PriceStatsView(
        displayName: displayName,
        productId: productId,
        detectedPrice: detectedPrice,
        capturedImagePath: capturedImagePath,
        historyId: historyId,
      ),
    );
  }
}

class _PriceStatsView extends StatelessWidget {
  final String displayName;
  final String productId;
  final double? detectedPrice;
  final String? capturedImagePath;
  final String? historyId;

  const _PriceStatsView({
    required this.displayName,
    required this.productId,
    this.detectedPrice,
    this.capturedImagePath,
    this.historyId,
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

          const Text(
            'Price Distribution',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Sample data: $totalCount entries (demo — not real regional data)',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.onSurfaceLight,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _LegendItem(color: AppColors.primary, label: 'Price trend'),
              const SizedBox(width: 16),
              _LegendItem(
                color: AppColors.primaryLight,
                label: 'Regional avg',
                isDash: true,
              ),
              const SizedBox(width: 16),
              if (detectedPrice != null)
                _LegendItem(
                  color: AppColors.warning,
                  label: 'Your price',
                  isDash: true,
                ),
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
                detectedPrice: detectedPrice,
                capturedImagePath: capturedImagePath,
                historyId: historyId,
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
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceLight),
        ),
        const SizedBox(height: 4),
        Text(
          CurrencyDisplay.formatEgpWithKrw(value),
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

  const _LegendItem({
    required this.color,
    required this.label,
    this.isDash = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        isDash
            ? Container(
                width: 16,
                height: 2,
                color: color,
                margin: const EdgeInsets.symmetric(vertical: 5),
              )
            : Container(width: 12, height: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceLight),
        ),
      ],
    );
  }
}

/// Reusable continuous distribution chart with optional vertical-line overlay.
class PriceHistogramWidget extends StatelessWidget {
  final RegionStats stats;
  final double? userPrice;

  const PriceHistogramWidget({super.key, required this.stats, this.userPrice});

  List<FlSpot> _toCurvePoints(List<PriceBucket> buckets) {
    if (buckets.isEmpty) return const [];

    final sorted = [...buckets]..sort((a, b) => a.start.compareTo(b.start));
    final points = <FlSpot>[FlSpot(sorted.first.start, 0)];

    for (final b in sorted) {
      final center = (b.start + b.end) / 2;
      points.add(FlSpot(center, b.count.toDouble()));
    }

    points.add(FlSpot(sorted.last.end, 0));
    return points;
  }

  double _interpolateYAtX(List<FlSpot> points, double x) {
    if (points.isEmpty) return 0;
    if (x <= points.first.x) return points.first.y;
    if (x >= points.last.x) return points.last.y;

    for (int i = 0; i < points.length - 1; i++) {
      final left = points[i];
      final right = points[i + 1];
      if (x >= left.x && x <= right.x) {
        final width = right.x - left.x;
        if (width == 0) return left.y;
        final ratio = (x - left.x) / width;
        return left.y + (right.y - left.y) * ratio;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final buckets = stats.distribution;
    if (buckets.isEmpty) return const SizedBox(height: 180);

    final points = _toCurvePoints(buckets);
    final maxY =
        points.map((e) => e.y).reduce((a, b) => a > b ? a : b).toDouble() *
        1.25;
    final minX = points.first.x;
    final maxX = points.last.x;

    final hasUserPrice =
        userPrice != null && userPrice! >= minX && userPrice! <= maxX;
    final userY = hasUserPrice ? _interpolateYAtX(points, userPrice!) : null;

    final markerSpots = <FlSpot>[
      FlSpot(stats.avgPrice, _interpolateYAtX(points, stats.avgPrice)),
      if (hasUserPrice && userY != null) FlSpot(userPrice!, userY),
    ];

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minX: minX,
          maxX: maxX,
          minY: 0,
          maxY: maxY,
          lineTouchData: const LineTouchData(enabled: false),
          extraLinesData: ExtraLinesData(
            verticalLines: [
              VerticalLine(
                x: stats.avgPrice,
                color: AppColors.primaryLight,
                strokeWidth: 2,
                dashArray: [4, 3],
                label: VerticalLineLabel(
                  show: true,
                  alignment: Alignment.topLeft,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.primaryLight,
                    fontWeight: FontWeight.w700,
                  ),
                  labelResolver: (_) => 'avg',
                ),
              ),
              if (hasUserPrice && userPrice != null)
                VerticalLine(
                  x: userPrice!,
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
                        CurrencyDisplay.formatEgpWithKrw(userPrice!),
                  ),
                ),
            ],
          ),
          lineBarsData: [
            LineChartBarData(
              spots: points,
              isCurved: true,
              barWidth: 3,
              color: AppColors.primary,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary.withValues(alpha: 0.15),
              ),
            ),
            LineChartBarData(
              spots: markerSpots,
              isCurved: false,
              color: Colors.transparent,
              barWidth: 0,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  final isAvg = (spot.x - stats.avgPrice).abs() < 0.001;
                  final color = isAvg
                      ? AppColors.primaryLight
                      : AppColors.warning;
                  return FlDotCirclePainter(
                    radius: isAvg ? 4 : 5,
                    color: color,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  );
                },
              ),
            ),
          ],
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (v, _) {
                  final min = stats.minPrice.round();
                  final avg = stats.avgPrice.round();
                  final max = stats.maxPrice.round();
                  final value = v.round();
                  final show = value == min || value == avg || value == max;

                  return show
                      ? Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '$value',
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.onSurfaceLight,
                            ),
                          ),
                        )
                      : const SizedBox.shrink();
                },
                interval: ((maxX - minX) / 6).clamp(1, double.infinity),
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: (maxY / 3).clamp(1, double.infinity),
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: Color(0xFFEEEEEE), strokeWidth: 1),
            getDrawingVerticalLine: (_) => FlLine(
              color: AppColors.onSurfaceLight.withValues(alpha: 0.10),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(
              color: AppColors.onSurfaceLight.withValues(alpha: 0.15),
            ),
          ),
        ),
      ),
    );
  }
}
