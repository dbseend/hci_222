import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/services/location_service.dart';
import '../../data/repositories/price_repository.dart';
import 'price_event.dart';
import 'price_state.dart';

class PriceBloc extends Bloc<PriceEvent, PriceState> {
  final PriceRepository _repo;
  final LocationService _location;

  PriceBloc({PriceRepository? repo, LocationService? location})
      : _repo = repo ?? PriceRepositoryImpl(),
        _location = location ?? LocationService(),
        super(const PriceInitial()) {
    on<PriceStatsRequested>(_onStatsRequested);
    on<PriceSubmitted>(_onSubmitted);
  }

  Future<void> _onStatsRequested(
    PriceStatsRequested event,
    Emitter<PriceState> emit,
  ) async {
    emit(const PriceLoading());
    try {
      final pos = await _location.getCurrentLocation();
      final stats = await _repo.getStats(
        productId: event.productId,
        lat: pos.lat,
        lon: pos.lon,
      );
      emit(PriceLoaded(stats: stats));
    } catch (e) {
      emit(PriceError('Failed to load price data. Please try again. ($e)'));
    }
  }

  Future<void> _onSubmitted(
    PriceSubmitted event,
    Emitter<PriceState> emit,
  ) async {
    final current = state;
    if (current is! PriceLoaded) return;

    emit(PriceSubmitting(stats: current.stats, userPrice: event.price));
    try {
      final pos = await _location.getCurrentLocation();
      await _repo.submitPrice(
        productId: event.productId,
        price: event.price,
        unit: event.unit,
        lat: pos.lat,
        lon: pos.lon,
        userId: event.userId,
      );
      emit(const PriceSubmitSuccess());
    } catch (e) {
      emit(PriceError('Failed to submit price. Please try again. ($e)'));
    }
  }
}
