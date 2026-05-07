import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/market_location.dart';

Set<Marker> buildMarketMarkers({
  required List<MarketLocation> markets,
  required void Function(MarketLocation market) onTap,
}) {
  return markets
      .map(
        (market) => Marker(
          markerId: MarkerId(_toMarkerId(market.name)),
          position: LatLng(market.lat, market.lon),
          consumeTapEvents: true,
          infoWindow: InfoWindow(title: market.name, snippet: market.desc),
          onTap: () => onTap(market),
        ),
      )
      .toSet();
}

String _toMarkerId(String name) =>
    name.trim().toLowerCase().replaceAll(' ', '_');
