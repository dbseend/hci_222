class ScannableProduct {
  final String productId;
  final String displayName;
  final String nameAr;
  final String unit;
  final List<String> aliases;

  const ScannableProduct({
    required this.productId,
    required this.displayName,
    required this.nameAr,
    required this.unit,
    required this.aliases,
  });

  factory ScannableProduct.fromJson(Map<String, dynamic> json) {
    return ScannableProduct(
      productId: json['product_id'] as String,
      displayName: json['display_name'] as String,
      nameAr: json['name_ar'] as String? ?? '',
      unit: json['unit'] as String? ?? 'kg',
      aliases:
          (json['aliases'] as List<dynamic>?)
              ?.map((value) => value.toString())
              .toList() ??
          const [],
    );
  }

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;

    return productId.toLowerCase().contains(normalized) ||
        displayName.toLowerCase().contains(normalized) ||
        nameAr.toLowerCase().contains(normalized) ||
        aliases.any((alias) => alias.toLowerCase().contains(normalized));
  }
}
