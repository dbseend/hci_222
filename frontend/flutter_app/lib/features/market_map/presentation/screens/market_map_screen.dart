// market_map_screen.dart
// Displays an interactive OpenStreetMap with markers for nearby Cairo markets.
// Tapping a marker opens a bottom sheet with market details and a directions button.
// Mock data is used for the three hardcoded markets; replace with GET /markets/nearby
// when the backend is ready.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_colors.dart';

class MarketMapScreen extends StatefulWidget {
  const MarketMapScreen({super.key});

  @override
  State<MarketMapScreen> createState() => _MarketMapScreenState();
}

class _MarketMapScreenState extends State<MarketMapScreen> {
  // Mock market data (Cairo, Egypt)
  // TODO: Replace with GET /markets/nearby?lat=&lon= when backend is ready
  final _mockMarkets = [
    _MockMarket('Khan el-Khalili', 30.0478, 31.2625, "Cairo's largest traditional market & souq"),
    _MockMarket('Ataba Market', 30.0565, 31.2457, 'Specializes in fruit, vegetables & spices'),
    _MockMarket('Imbaba Market', 30.0720, 31.2130, 'Focused on fresh fruit & vegetables'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Markets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: const LatLng(30.0478, 31.2625), // Cairo — Khan el-Khalili
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.trueprice.app',
              ),
              MarkerLayer(
                markers: _mockMarkets
                    .map(
                      (m) => Marker(
                        point: LatLng(m.lat, m.lon),
                        width: 40,
                        height: 40,
                        child: GestureDetector(
                          onTap: () => _showMarketSheet(context, m),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.storefront,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showMarketSheet(BuildContext context, _MockMarket market) {
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

class _MockMarket {
  final String name;
  final double lat;
  final double lon;
  final String desc;
  _MockMarket(this.name, this.lat, this.lon, this.desc);
}
