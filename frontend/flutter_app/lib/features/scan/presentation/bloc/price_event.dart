// price_event.dart
// Events dispatched to PriceBloc.
// PriceStatsRequested — fetch regional price statistics for a product.

import 'package:equatable/equatable.dart';

abstract class PriceEvent extends Equatable {
  const PriceEvent();
  @override
  List<Object?> get props => [];
}

class PriceStatsRequested extends PriceEvent {
  final String productId;
  final double lat;
  final double lon;
  final double? userPrice;
  const PriceStatsRequested({
    required this.productId,
    required this.lat,
    required this.lon,
    this.userPrice,
  });
  @override
  List<Object?> get props => [productId, lat, lon, userPrice];
}
