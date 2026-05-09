import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/supabase_service.dart';
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
    if (SupabaseService.isInitialized) {
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
        // Fallback to local cache if remote write fails.
      }
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
    if (SupabaseService.isInitialized) {
      try {
        return await _getUserPostsRemote().timeout(_remoteTimeout);
      } catch (_) {
        // Fallback to local cache if remote read fails.
      }
    }

    return _getUserPostsLocal();
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
    final client = SupabaseService.client;
    final clientUserId = await UserIdService.getOrCreate();
    final authUserId = client.auth.currentUser?.id;

    final productId = await _ensureProductId(
      client: client,
      productCode: productCode,
      productName: productName,
    );

    final purchaseInsert = <String, dynamic>{
      'auth_user_id': authUserId,
      'client_user_id': clientUserId,
      'product_id': productId,
      'product_name_override': productName,
      'store_name_override': storeName,
      'location_override': locationName,
      'unit': 'kg',
      'quantity': 1,
      'final_price_egp': price,
    };

    final purchaseRows = await client
        .from('purchases')
        .insert(purchaseInsert)
        .select('id')
        .limit(1);

    final purchaseRow = (purchaseRows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .first;
    final purchaseId = purchaseRow['id'] as String;

    final uploadedPath = await _uploadImageIfNeeded(
      client: client,
      clientUserId: clientUserId,
      purchaseId: purchaseId,
      localImagePath: imagePath,
    );

    if (uploadedPath != null) {
      await client
          .from('purchases')
          .update({'image_path': uploadedPath})
          .eq('id', purchaseId);
    }
  }

  Future<String> _ensureProductId({
    required SupabaseClient client,
    required String productCode,
    required String productName,
  }) async {
    final rows = await client
        .from('products')
        .select('id')
        .eq('code', productCode)
        .limit(1);

    final list = (rows as List<dynamic>).cast<Map<String, dynamic>>();
    if (list.isNotEmpty) {
      return list.first['id'] as String;
    }

    final inserted = await client
        .from('products')
        .insert({
          'code': productCode,
          'name': productName,
          'default_unit': 'kg',
        })
        .select('id')
        .limit(1);

    return (inserted as List<dynamic>).cast<Map<String, dynamic>>().first['id']
        as String;
  }

  Future<String?> _uploadImageIfNeeded({
    required SupabaseClient client,
    required String clientUserId,
    required String purchaseId,
    required String? localImagePath,
  }) async {
    if (localImagePath == null || localImagePath.isEmpty) return null;

    final file = File(localImagePath);
    if (!await file.exists()) return null;

    final ext = _fileExtension(localImagePath);
    final objectPath = '$clientUserId/$purchaseId$ext';
    await client.storage
        .from('community-images')
        .upload(objectPath, file, fileOptions: const FileOptions(upsert: true));
    return objectPath;
  }

  Future<List<CommunityPost>> _getUserPostsRemote() async {
    final rows = await SupabaseService.client
        .from('community_feed_v1')
        .select(
          'id, product_name, store_name, location_name, price_egp, image_path, created_at',
        )
        .order('created_at', ascending: false);

    final mapped = (rows as List<dynamic>).cast<Map<String, dynamic>>().map((
      row,
    ) {
      return CommunityPost(
        id: row['id'] as String? ?? '',
        productName: row['product_name'] as String? ?? '',
        price: (row['price_egp'] as num?)?.toDouble() ?? 0,
        storeName: row['store_name'] as String? ?? 'Traveler Report',
        locationName: row['location_name'] as String? ?? 'Unknown',
        imagePath: row['image_path'] as String?,
        createdAt:
            DateTime.tryParse(row['created_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
    }).toList();

    return mapped;
  }

  String _fileExtension(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot == path.length - 1) return '.jpg';
    return path.substring(dot);
  }
}
