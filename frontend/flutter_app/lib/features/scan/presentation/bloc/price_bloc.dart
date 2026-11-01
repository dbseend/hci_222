import 'package:flutter/foundation.dart';
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
      final userPrice = event.userPrice;
      if (userPrice != null) {
        final comparison = await _repo.comparePrice(
          productId: event.productId,
          price: userPrice,
          region: stats.region,
          currency: stats.currency,
        );
        emit(
          PriceLoaded(
            stats: stats,
            userPrice: userPrice,
            comparison: comparison,
          ),
        );
        return;
      }
      emit(PriceLoaded(stats: stats));
    } catch (error, stackTrace) {
      debugPrint('[PriceBloc] Failed to load price data: $error\n$stackTrace');
      emit(const PriceError('Failed to load price data. Please try again.'));
    }
  }
}
