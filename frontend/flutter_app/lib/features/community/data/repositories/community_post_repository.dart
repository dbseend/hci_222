import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/community_post.dart';

abstract class CommunityPostRepository {
  Future<void> addPurchasePost({
    required String productName,
    required double price,
    String? imagePath,
  });

  Future<List<CommunityPost>> getUserPosts();
}

class CommunityPostRepositoryImpl implements CommunityPostRepository {
  static const _storageKey = 'community_user_posts';

  final Future<SharedPreferences> Function() _prefsProvider;

  CommunityPostRepositoryImpl({
    Future<SharedPreferences> Function()? prefsProvider,
  }) : _prefsProvider = prefsProvider ?? SharedPreferences.getInstance;

  @override
  Future<void> addPurchasePost({
    required String productName,
    required double price,
    String? imagePath,
  }) async {
    final now = DateTime.now();
    final post = CommunityPost(
      id: 'post_${now.millisecondsSinceEpoch}',
      productName: productName,
      price: price,
      imagePath: imagePath,
      createdAt: now,
    );

    final current = await getUserPosts();
    final updated = [post, ...current];

    final prefs = await _prefsProvider();
    await prefs.setString(
      _storageKey,
      jsonEncode(updated.map((e) => e.toJson()).toList()),
    );
  }

  @override
  Future<List<CommunityPost>> getUserPosts() async {
    final prefs = await _prefsProvider();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final posts =
          decoded
              .map((e) => CommunityPost.fromJson(e as Map<String, dynamic>))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return posts;
    } catch (_) {
      return const [];
    }
  }
}
