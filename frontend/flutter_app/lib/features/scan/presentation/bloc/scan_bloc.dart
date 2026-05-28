import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/services/location_service.dart';
import '../../data/models/detection_result.dart';
import '../../data/repositories/scan_repository.dart';
import 'scan_event.dart';
import 'scan_state.dart';

class ScanBloc extends Bloc<ScanEvent, ScanState> {
  final ScanRepository _repo;

  ScanBloc({ScanRepository? repo})
    : _repo = repo ?? ScanRepositoryImpl(),
      super(const ScanInitial()) {
    on<ScanImageCaptured>(_onImageCaptured);
    on<ScanImageBytesCaptured>(_onImageBytesCaptured);
    on<ScanWebMockRequested>(_onWebMock);
    on<ScanReset>(_onReset);
  }

  Future<void> _onImageCaptured(
    ScanImageCaptured event,
    Emitter<ScanState> emit,
  ) async {
    emit(const ScanProcessing());
    try {
      const pos = LatLon.defaultLocation;
      final result = await _repo.detectObject(
        image: event.image,
        lat: pos.lat,
        lon: pos.lon,
      );
      emit(ScanDetected(result));
    } catch (e) {
      emit(ScanError(_scanErrorMessage(e)));
    }
  }

  Future<void> _onImageBytesCaptured(
    ScanImageBytesCaptured event,
    Emitter<ScanState> emit,
  ) async {
    emit(const ScanProcessing());
    try {
      const pos = LatLon.defaultLocation;
      final result = await _repo.detectObjectBytes(
        imageBytes: event.bytes,
        filename: event.filename,
        lat: pos.lat,
        lon: pos.lon,
      );
      emit(ScanDetected(result));
    } catch (e) {
      emit(ScanError(_scanErrorMessage(e)));
    }
  }

  /// On web where File access is unavailable — skips detection and emits a mock result directly.
  Future<void> _onWebMock(
    ScanWebMockRequested event,
    Emitter<ScanState> emit,
  ) async {
    emit(const ScanProcessing());
    await Future.delayed(const Duration(seconds: 1));
    emit(ScanDetected(DetectionResult.mock()));
  }

  void _onReset(ScanReset event, Emitter<ScanState> emit) {
    emit(const ScanInitial());
  }

  String _scanErrorMessage(Object error) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 404) {
        return 'No supported product was detected. Try a clearer photo or choose the product manually.';
      }
      if (statusCode == 503) {
        return 'Detection server is not ready. Check the local backend and try again.';
      }
      if (statusCode != null) {
        return 'Detection request failed with status $statusCode. Please try again.';
      }
      return 'Could not reach the detection server. Check the backend URL and network.';
    }

    return 'Failed to detect product. Please try again.';
  }
}
