// location_service.dart
// Purpose: Singleton service that retrieves the device's GPS coordinates.
//          On failure (permission denied, service off, timeout) it falls back to a
//          hardcoded Cairo default so the rest of the app always has a valid location.
// Architecture: consumed by PriceRepository (lat/lon for price API) and MarketMapScreen.
// TODO(next-dev): Wire the real Geolocator permission request to the PermissionScreen flow
//                 so the system dialog fires at the right moment instead of lazily.

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

// Default coordinates: near Khan el-Khalili Market, Cairo, Egypt
const _kDefaultLat = 30.0444;
const _kDefaultLon = 31.2357;

class LatLon {
  final double lat;
  final double lon;
  /// true = using Cairo default instead of real GPS — UI can show an info banner when this is set
  final bool isFallback;

  const LatLon(this.lat, this.lon, {this.isFallback = false});

  static const defaultLocation = LatLon(_kDefaultLat, _kDefaultLon, isFallback: true);
}

class LocationService {
  static final LocationService _instance = LocationService._();
  factory LocationService() => _instance;
  LocationService._();

  LatLon? _cached;

  /// Returns the current device location, or the Cairo fallback if unavailable.
  /// When [isFallback] is true the caller (e.g. ScanScreen) can display a banner:
  /// "Could not get your location — showing Cairo default data."
  Future<LatLon> getCurrentLocation() async {
    if (_cached != null) return _cached!;

    // On web, browser geolocation is supported by geolocator but may be
    // disabled on non-HTTPS origins (e.g. localhost dev server).
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LocationService] Location service disabled → using Cairo default');
        return LatLon.defaultLocation; // isFallback = true
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[LocationService] Location permission denied → using Cairo default');
          return LatLon.defaultLocation; // isFallback = true
        }
      }
      if (permission == LocationPermission.deniedForever) {
        debugPrint('[LocationService] Location permission permanently denied → using Cairo default');
        return LatLon.defaultLocation; // isFallback = true
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low, // low accuracy to preserve battery
        timeLimit: const Duration(seconds: 5),
      );
      _cached = LatLon(pos.latitude, pos.longitude); // isFallback = false (real GPS)
      return _cached!;
    } catch (e) {
      debugPrint('[LocationService] Failed to get location: $e → using Cairo default');
      return LatLon.defaultLocation; // isFallback = true
    }
  }

  void clearCache() => _cached = null;
}
