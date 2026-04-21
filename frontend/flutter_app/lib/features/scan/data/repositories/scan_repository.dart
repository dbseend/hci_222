import 'dart:io';
import '../models/detection_result.dart';

abstract class ScanRepository {
  Future<DetectionResult> detectObject({
    required File image,
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
    // ──────────────────────────────────────────────────────────────
    // [YOLO BACKEND INTEGRATION GUIDE] — to be implemented by another developer
    //
    // The backend (Python/FastAPI) runs a YOLOv8 model and returns
    // the detected object class (class_name) and the price extracted via OCR.
    //
    // 1. Enable the dio package dependency in pubspec.yaml:
    //    lib/core/network/dio_client.dart  →  DioClient.instance
    //    lib/core/constants/api_endpoints.dart  →  ApiEndpoints.detectObject
    //
    // 2. Backend endpoint: POST /scan/detect-object
    //    Request (multipart/form-data):
    //      - image: File (JPEG/PNG)
    //      - lat: double  (current latitude)
    //      - lon: double  (current longitude)
    //    Response (JSON):
    //      {
    //        "product_id": "p001",
    //        "name_kr": "포도 (Grapes)",
    //        "name_ar": "عنب",
    //        "confidence": 0.92,
    //        "detected_price": 65.0   // price read from tag via OCR (null if not found)
    //      }
    //
    // 3. Integration code (add dio and MultipartFile imports):
    //    final formData = FormData.fromMap({
    //      'image': await MultipartFile.fromFile(image.path),
    //      'lat': lat,
    //      'lon': lon,
    //    });
    //    final res = await DioClient.instance.post(ApiEndpoints.detectObject, data: formData);
    //    return DetectionResult.fromJson(res.data as Map<String, dynamic>);
    //
    // 4. When using ar_flutter_plugin (mentioned in proposal):
    //    AR overlay can display price in real time above the bounding box.
    //    Recommended to implement this feature in a dedicated AR screen.
    // ──────────────────────────────────────────────────────────────

    // [DEMO] Mock: return grapes result after a 2-second delay
    await Future.delayed(const Duration(seconds: 2));
    return DetectionResult.mock();
  }
}
