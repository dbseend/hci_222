import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../models/detection_result.dart';

abstract class ScanRepository {
  Future<DetectionResult> detectObject({
    required File image,
    required double lat,
    required double lon,
  });

  Future<DetectionResult> detectObjectBytes({
    required Uint8List imageBytes,
    required String filename,
    required double lat,
    required double lon,
  });
}

class ScanRepositoryImpl implements ScanRepository {
  @override
  Future<DetectionResult> detectObject({
    required File image,
    required double lat,
    required double lon,
  }) async {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(
        image.path,
        filename: image.uri.pathSegments.isNotEmpty
            ? image.uri.pathSegments.last
            : 'scan.jpg',
      ),
      'lat': lat,
      'lon': lon,
    });

    final response = await DioClient.instance.post<Map<String, dynamic>>(
      ApiEndpoints.detectObject,
      data: formData,
    );

    final data = response.data;
    if (data == null) {
      throw const FormatException('Detection API returned an empty response.');
    }
    return DetectionResult.fromJson(data);
  }

  @override
  Future<DetectionResult> detectObjectBytes({
    required Uint8List imageBytes,
    required String filename,
    required double lat,
    required double lon,
  }) async {
    final formData = FormData.fromMap({
      'image': MultipartFile.fromBytes(
        imageBytes,
        filename: filename.isNotEmpty ? filename : 'scan.jpg',
      ),
      'lat': lat,
      'lon': lon,
    });

    final response = await DioClient.instance.post<Map<String, dynamic>>(
      ApiEndpoints.detectObject,
      data: formData,
    );

    final data = response.data;
    if (data == null) {
      throw const FormatException('Detection API returned an empty response.');
    }
    return DetectionResult.fromJson(data);
  }
}
