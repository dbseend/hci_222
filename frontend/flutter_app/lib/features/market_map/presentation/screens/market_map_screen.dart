// market_map_screen.dart
// Displays Google Maps with markers for nearby Cairo markets.
// Tapping a marker opens a bottom sheet with market details and a directions button.
// Mock data is used for the three hardcoded markets; replace with GET /markets/nearby
// when the backend is ready.

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../models/market_location.dart';
import '../utils/market_marker_builder.dart';

class MarketMapScreen extends StatefulWidget {
  const MarketMapScreen({super.key});

  @override
  State<MarketMapScreen> createState() => _MarketMapScreenState();
}

class _MarketMapScreenState extends State<MarketMapScreen> {
  static const _initialPosition = CameraPosition(
    target: LatLng(30.0478, 31.2625), // Cairo — Khan el-Khalili
    zoom: 13,
  );

  final _mockMarkets = kDefaultMarketLocations;
  GoogleMapController? _mapController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Markets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _moveToDefaultMarket,
          ),
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: _initialPosition,
        myLocationButtonEnabled: false,
        mapToolbarEnabled: false,
        zoomControlsEnabled: false,
        onMapCreated: (controller) => _mapController = controller,
        markers: buildMarketMarkers(
          markets: _mockMarkets,
          onTap: (market) => _showMarketSheet(context, market),
        ),
      ),
    );
  }

  Future<void> _moveToDefaultMarket() async {
    if (_mapController == null) return;
    await _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(_initialPosition),
    );
  }

  void _showMarketSheet(BuildContext context, MarketLocation market) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.storefront, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        market.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        market.desc,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.onSurfaceLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.directions),
              label: const Text('Get Directions'),
            ),
          ],
        ),
      ),
    );
  }
}
