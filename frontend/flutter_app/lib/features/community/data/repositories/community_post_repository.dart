import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/services/user_id_service.dart';
import '../models/community_post.dart';

abstract class CommunityPostRepository {
  Future<void> addPurchasePost({
    required String productName,
    required double price,
    String? imagePath,
    String productCode = 'p001',
    String storeName = 'Traveler Report',
    String locationName = 'Unknown',
  });

  Future<List<CommunityPost>> getUserPosts();
}

class CommunityPostRepositoryImpl implements CommunityPostRepository {
  static const _storageKey = 'community_user_posts';
  static const _remoteTimeout = Duration(seconds: 5);

  final Future<SharedPreferences> Function() _prefsProvider;

  CommunityPostRepositoryImpl({
    Future<SharedPreferences> Function()? prefsProvider,
  }) : _prefsProvider = prefsProvider ?? SharedPreferences.getInstance;

  @override
  Future<void> addPurchasePost({
    required String productName,
    required double price,
    String? imagePath,
    String productCode = 'p001',
    String storeName = 'Traveler Report',
    String locationName = 'Unknown',
  }) async {
    try {
      await _addPurchasePostRemote(
        productName: productName,
        price: price,
        imagePath: imagePath,
        productCode: productCode,
        storeName: storeName,
        locationName: locationName,
      ).timeout(_remoteTimeout);
      return;
    } catch (_) {
      // Fallback to local cache if backend write fails.
    }

    await _addPurchasePostLocal(
      productName: productName,
      price: price,
      imagePath: imagePath,
      storeName: storeName,
      locationName: locationName,
    );
  }

  Future<void> _addPurchasePostLocal({
    required String productName,
    required double price,
    String? imagePath,
    String storeName = 'Traveler Report',
    String locationName = 'Unknown',
  }) async {
    final now = DateTime.now();
    final post = CommunityPost(
      id: 'post_${now.millisecondsSinceEpoch}',
      productName: productName,
      price: price,
      storeName: storeName,
      locationName: locationName,
      imagePath: imagePath,
      createdAt: now,
    );

    final current = await _getUserPostsLocal();
    final updated = [post, ...current];

    final prefs = await _prefsProvider();
    await prefs.setString(
      _storageKey,
      jsonEncode(updated.map((e) => e.toJson()).toList()),
    );
  }

  @override
  Future<List<CommunityPost>> getUserPosts() async {
    try {
      final remotePosts = await _getUserPostsRemote().timeout(_remoteTimeout);
      return remotePosts.isEmpty ? _samplePosts() : remotePosts;
    } catch (_) {
      // Fallback to local cache if backend read fails.
    }

    final localPosts = await _getUserPostsLocal();
    return localPosts.isEmpty ? _samplePosts() : localPosts;
  }

  Future<List<CommunityPost>> _getUserPostsLocal() async {
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

  Future<void> _addPurchasePostRemote({
    required String productName,
    required double price,
    String? imagePath,
    required String productCode,
    required String storeName,
    required String locationName,
  }) async {
    final clientUserId = await UserIdService.getOrCreate();
    final payload = {
      'product_name': productName,
      'price': price,
      'product_code': productCode,
      'store_name': storeName,
      'location_name': locationName,
      'client_user_id': clientUserId,
    };
    final formData = FormData.fromMap({'payload': jsonEncode(payload)});
    if (imagePath != null && imagePath.isNotEmpty) {
      final file = File(imagePath);
      if (await file.exists()) {
        formData.files.add(
          MapEntry(
            'image',
            await MultipartFile.fromFile(
              imagePath,
              filename: imagePath.split('/').last,
            ),
          ),
        );
      }
    }

    await DioClient.instance.post(ApiEndpoints.communityPosts, data: formData);
  }

  Future<List<CommunityPost>> _getUserPostsRemote() async {
    final res = await DioClient.instance.get<List<dynamic>>(
      ApiEndpoints.communityFeed,
    );
    final rows = res.data ?? const [];
    return rows.cast<Map<String, dynamic>>().map((row) {
      return CommunityPost(
        id: row['id'] as String? ?? '',
        productName: row['product_name'] as String? ?? '',
        price: (row['price'] as num?)?.toDouble() ?? 0,
        storeName: row['store_name'] as String? ?? 'Traveler Report',
        locationName: row['location_name'] as String? ?? 'Unknown',
        imagePath: row['image_path'] as String?,
        createdAt:
            DateTime.tryParse(row['created_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
    }).toList();
  }

  List<CommunityPost> _samplePosts() {
    final now = DateTime.now();
    return [
      CommunityPost(
        id: 'sample_5',
        productName: 'Lemons 5 pcs',
        price: 19.0,
        storeName: 'Ataba Market',
        locationName: 'Downtown Cairo',
        createdAt: now.subtract(const Duration(minutes: 10)),
      ),
      CommunityPost(
        id: 'sample_4',
        productName: 'Pomegranate 1 pc',
        price: 44.0,
        storeName: 'Khan el-Khalili Market',
        locationName: 'Old Cairo',
        createdAt: now.subtract(const Duration(minutes: 30)),
      ),
      CommunityPost(
        id: 'sample_3',
        productName: 'Cucumbers 1kg',
        price: 7.2,
        storeName: 'Imbaba Market',
        locationName: 'Imbaba',
        createdAt: now.subtract(const Duration(hours: 1)),
      ),
      CommunityPost(
        id: 'sample_2',
        productName: 'Tomatoes 1kg',
        price: 13.5,
        storeName: 'Ataba Market',
        locationName: 'Downtown Cairo',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      CommunityPost(
        id: 'sample_1',
        productName: 'Grapes 1kg',
        price: 64.0,
        storeName: 'Khan el-Khalili Market',
        locationName: 'Old Cairo',
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
    ];
  }
}
