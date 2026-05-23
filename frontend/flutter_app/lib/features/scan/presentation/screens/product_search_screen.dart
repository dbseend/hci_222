import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/scannable_product.dart';
import '../../data/repositories/scannable_product_repository.dart';
import '../models/scan_route_data.dart';
import '../widgets/product_search_sheet.dart';

class ProductSearchScreen extends StatefulWidget {
  const ProductSearchScreen({super.key});

  @override
  State<ProductSearchScreen> createState() => _ProductSearchScreenState();
}

class _ProductSearchScreenState extends State<ProductSearchScreen> {
  final _repo = ScannableProductRepository();
  late Future<List<ScannableProduct>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _productsFuture = _repo.loadProducts();
  }

  void _reload() {
    setState(() => _productsFuture = _repo.loadProducts());
  }

  void _openStats(ScannableProduct product) {
    context.go(
      '/scan/stats',
      extra: ScanRouteData(
        productName: product.displayName,
        productId: product.productId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Product Search')),
      body: FutureBuilder<List<ScannableProduct>>(
        future: _productsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (snapshot.hasError) {
            return _SearchLoadError(onRetry: _reload);
          }

          final products = snapshot.data ?? const <ScannableProduct>[];
          return ProductSearchSheet(
            products: products,
            showHandle: false,
            autofocus: false,
            onSelected: _openStats,
          );
        },
      ),
    );
  }
}

class _SearchLoadError extends StatelessWidget {
  final VoidCallback onRetry;

  const _SearchLoadError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off,
              size: 56,
              color: AppColors.onSurfaceLight,
            ),
            const SizedBox(height: 14),
            const Text(
              'Could not load searchable products.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
