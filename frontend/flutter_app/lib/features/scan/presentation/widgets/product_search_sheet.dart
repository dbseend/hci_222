import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/scannable_product.dart';

class ProductSearchSheet extends StatefulWidget {
  final List<ScannableProduct> products;
  final ValueChanged<ScannableProduct> onSelected;
  final bool showHandle;
  final bool autofocus;

  const ProductSearchSheet({
    super.key,
    required this.products,
    required this.onSelected,
    this.showHandle = true,
    this.autofocus = true,
  });

  @override
  State<ProductSearchSheet> createState() => _ProductSearchSheetState();
}

class _ProductSearchSheetState extends State<ProductSearchSheet> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.products
        .where((product) => product.matches(_query))
        .toList(growable: false);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: widget.showHandle ? MainAxisSize.min : MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showHandle) ...[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],
            const Text(
              'Search scannable product',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Only products with current Cairo reference prices are searchable.',
              style: TextStyle(fontSize: 13, color: AppColors.onSurfaceLight),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: widget.autofocus,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Tomato, mango, camel doll...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: filtered.isEmpty
                  ? const _EmptyProductSearch()
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final product = filtered[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withValues(
                              alpha: 0.12,
                            ),
                            child: const Icon(
                              Icons.shopping_basket_outlined,
                              color: AppColors.primary,
                            ),
                          ),
                          title: Text(
                            product.displayName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            [
                              if (product.nameAr.isNotEmpty) product.nameAr,
                              product.unit,
                            ].join(' · '),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => widget.onSelected(product),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyProductSearch extends StatelessWidget {
  const _EmptyProductSearch();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          'No supported product found.',
          style: TextStyle(color: AppColors.onSurfaceLight),
        ),
      ),
    );
  }
}
