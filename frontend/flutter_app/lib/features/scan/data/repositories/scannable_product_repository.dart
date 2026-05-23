import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/scannable_product.dart';

class ScannableProductRepository {
  static const _assetPath = 'assets/data/scannable_products.json';

  Future<List<ScannableProduct>> loadProducts() async {
    final raw = await rootBundle.loadString(_assetPath);
    final data = jsonDecode(raw) as List<dynamic>;
    return data
        .map((item) => ScannableProduct.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }
}
