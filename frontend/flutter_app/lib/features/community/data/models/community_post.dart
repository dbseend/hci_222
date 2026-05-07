class CommunityPost {
  final String id;
  final String productName;
  final double price;
  final String? imagePath;
  final DateTime createdAt;

  const CommunityPost({
    required this.id,
    required this.productName,
    required this.price,
    required this.createdAt,
    this.imagePath,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'product_name': productName,
    'price': price,
    'image_path': imagePath,
    'created_at': createdAt.toIso8601String(),
  };

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    return CommunityPost(
      id: json['id'] as String? ?? '',
      productName: json['product_name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      imagePath: json['image_path'] as String?,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
