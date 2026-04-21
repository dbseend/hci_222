# True Price — Market Price Guide for Egypt Travelers

## Overview

True Price is a Flutter mobile application designed to help travelers navigate open-air markets in Cairo, Egypt. The app lets users scan produce with their camera to instantly compare the quoted price against crowdsourced regional averages, and provides Arabic market phrases with text-to-speech pronunciation to help with negotiation. The goal is to level the information asymmetry that tourists face at traditional markets such as Khan el-Khalili.

## Team

**HCI 02 Team 2 | Handong Global University**

| Name | Role |
|---|---|
| Kim Yeeun | Project lead, Flutter UI, BLoC state management |
| Kim Seohyeon | UX research, community screen |
| Na Sarang | Arabic phrases feature, TTS integration |
| Yoon Seong Hyeon | Map feature, location services |
| Seo Yeonwoo | Scan flow, price analysis screen |

---

## Current Status (Demo Mode)

The app currently runs entirely on **mock data** with no live backend. All API calls are stubbed with `Future.delayed` and hardcoded responses. The primary development platform is **Chrome** (`flutter run -d chrome`) because no physical iOS/Android device is available in the team's current environment.

What this means in practice:

- The camera scan always returns "Grapes" at 65 EGP regardless of what is pointed at.
- Price statistics are generated from a mock `RegionStats.mock()` call.
- The community feed shows five hardcoded entries.
- The map shows three hardcoded Cairo market markers.
- Permissions (camera, location) are requested on mobile but silently fall back on web.

---

## Features

1. **Camera Scan + Price Analysis** — Point the camera at a price tag. The app sends the image to a YOLO object-detection backend, identifies the product, reads the displayed price via OCR, and classifies it as Fair / Negotiate / Overpriced using a z-score against regional averages.
2. **Price Distribution Histogram** — A `fl_chart` bar chart displays the regional price distribution with a vertical line marking the observed price, giving users visual context for their negotiation.
3. **Arabic Phrase Guide** — Categorized phrase cards (Greeting, Ask Price, Negotiate, Discount, Purchase) display the Arabic script, romanized pronunciation, and an English label. Each card has a TTS button powered by `flutter_tts`.
4. **Nearby Market Map** — An OpenStreetMap tile layer (`flutter_map`) shows Cairo market locations as tappable pins. No API key required.
5. **Community Price Feed** — A scrollable list of recent price reports from other users, each showing the product, market, reported price, average price, and a percentage difference badge.

---

## Tech Stack

| Package | Version | Purpose |
|---|---|---|
| `flutter_bloc` | ^8.1.6 | BLoC state management for scan and price flows |
| `equatable` | ^2.0.5 | Value equality for BLoC events and states |
| `go_router` | ^14.0.0 | Declarative navigation with ShellRoute and `extra` data passing |
| `dio` | ^5.4.3 | HTTP client (currently imported but calls are stubbed) |
| `camera` | ^0.10.5+9 | Native camera preview in the scan screen |
| `image_picker` | ^1.1.2 | Gallery fallback for image selection |
| `google_mlkit_text_recognition` | ^0.13.0 | On-device OCR for reading price tags |
| `geolocator` | ^12.0.0 | GPS coordinates for location-aware price queries |
| `permission_handler` | ^11.3.0 | Runtime camera and location permission requests |
| `flutter_map` | ^7.0.0 | OpenStreetMap tile rendering (no API key needed) |
| `latlong2` | ^0.9.0 | Coordinate type used by `flutter_map` |
| `fl_chart` | ^0.68.0 | Price distribution histogram / bar chart |
| `flutter_tts` | ^4.0.2 | Text-to-speech for Arabic phrase pronunciation |
| `shared_preferences` | ^2.2.3 | Persistent local storage (anonymous user ID, onboarding flag) |
| `cached_network_image` | ^3.3.1 | Image caching for product thumbnails |
| `uuid` | ^4.3.3 | Generates an anonymous UUID to identify the user without login |
| `cupertino_icons` | ^1.0.8 | iOS-style icons |
| `flutter_lints` | ^6.0.0 | Lint rules (dev) |
| `bloc_test` | ^9.1.7 | BLoC unit testing utilities (dev) |
| `mocktail` | ^1.0.4 | Mocking framework for repository tests (dev) |

---

## Architecture

The project follows **Clean Architecture** organized by feature, not by layer.

```
Presentation  ->  BLoC  ->  Repository (abstract)  ->  Repository (impl)  ->  Network / Mock
```

- **BLoC pattern**: Each major flow (`ScanBloc`, `PriceBloc`) holds a state machine. Events are dispatched by the UI; states drive rebuilds via `BlocBuilder`.
- **Repository abstraction**: `ScanRepository` and `PriceRepository` are abstract classes. The `*Impl` classes contain either mock stubs or (when uncommented) live `DioClient` calls. Swapping mock for real requires only changing the DI site — no UI code changes needed.
- **Feature-first layout**: Each feature owns its own `presentation/`, `data/models/`, and `data/repositories/` folders, making it straightforward to hand off individual features to different developers.
- **GoRouter with ShellRoute**: The bottom navigation bar is rendered by a single `_MainShell` shell that wraps all main routes. Sub-routes within the scan flow (`/scan/stats`, `/scan/input`, `/scan/analysis`, `/scan/final`) are nested under `/scan`.

---

## Project Structure

```
lib/
├── main.dart                              # App entry point
├── app/
│   ├── app.dart                           # MaterialApp + theme setup
│   └── router.dart                        # Full GoRouter navigation graph
│
├── core/
│   ├── constants/
│   │   ├── api_endpoints.dart             # All API URL constants (base URL + paths)
│   │   └── app_colors.dart                # Global color palette
│   ├── network/
│   │   └── dio_client.dart                # Dio singleton with base URL and interceptors
│   ├── services/
│   │   ├── location_service.dart          # Geolocator wrapper — returns current LatLng
│   │   ├── tts_service.dart               # flutter_tts wrapper for Arabic TTS
│   │   └── user_id_service.dart           # Generates/retrieves anonymous UUID from SharedPreferences
│   ├── utils/
│   │   └── price_classifier.dart          # Pure z-score classifier -> PriceStatus enum
│   └── widgets/
│       ├── app_card.dart                  # Shared card container with rounded corners + shadow
│       ├── bottom_nav_bar.dart            # AppBottomNavBar used by the ShellRoute
│       └── price_badge.dart               # Color-coded badge (green/yellow/red) for price status
│
└── features/
    ├── onboarding/
    │   └── presentation/screens/
    │       ├── splash_screen.dart          # 2-second logo splash -> /permission
    │       ├── permission_screen.dart      # Camera + location permission request
    │       └── intro_screen.dart           # Brief onboarding explanation slides
    │
    ├── scan/
    │   ├── data/
    │   │   ├── models/
    │   │   │   ├── detection_result.dart   # Product ID, name (EN/AR), confidence, detected price
    │   │   │   └── region_stats.dart       # avg, stdDev, histogram buckets for a product/region
    │   │   └── repositories/
    │   │       ├── scan_repository.dart    # Abstract + mock impl for POST /scan/detect-object
    │   │       └── price_repository.dart   # Abstract + mock impl for GET /prices/stats, POST /prices/submit
    │   └── presentation/
    │       ├── bloc/
    │       │   ├── scan_bloc.dart          # ScanBloc: idle -> scanning -> detected states
    │       │   ├── scan_event.dart         # ScanStarted, ScanReset
    │       │   ├── scan_state.dart         # ScanInitial, ScanLoading, ScanSuccess, ScanFailure
    │       │   ├── price_bloc.dart         # PriceBloc: loads stats, submits price
    │       │   ├── price_event.dart        # PriceStatsRequested, PriceSubmitted
    │       │   └── price_state.dart        # PriceInitial, PriceLoading, PriceLoaded, PriceError
    │       └── screens/
    │           ├── scan_screen.dart        # Camera preview + scan trigger button
    │           ├── price_stats_screen.dart # Histogram + detected price vertical line
    │           ├── price_input_screen.dart # Manual price entry + unit selector chips
    │           ├── price_analysis_screen.dart  # Z-score result card + Arabic phrase suggestion
    │           └── final_price_screen.dart     # Submit confirmed price to community
    │
    ├── market_map/
    │   └── presentation/screens/
    │       └── market_map_screen.dart      # OSM map with Cairo market markers + bottom sheet
    │
    ├── language/
    │   └── presentation/screens/
    │       └── phrase_screen.dart          # Phrase list with category chips + TTS per card
    │
    └── community/
        └── presentation/screens/
            └── community_screen.dart       # Price report feed with percentage badges

assets/
├── data/
│   └── phrases.json                        # Arabic phrase data (phrase_id, category, text_kr, text_ar, romanized)
└── fonts/
    └── NotoSansArabic-Regular.ttf          # Arabic script font
```

---

## How to Run

### Chrome (recommended during development)

```bash
flutter pub get
flutter run -d chrome
```

### Mobile (Android / iOS physical device or emulator)

```bash
flutter pub get
flutter run
```

> On mobile, the camera permission dialog will appear on first launch. The scan flow currently returns mock data regardless of what is captured.

### Requirements

- Flutter SDK `^3.11.4` (Dart `^3.x`)
- No backend server needed to run in demo mode

---

## Mock vs. Real: What Still Needs Backend

| Feature | Current State | What Is Needed |
|---|---|---|
| Object detection (camera scan) | Returns hardcoded "Grapes" result after 2 s delay | Python/FastAPI server running YOLOv8 at `POST /scan/detect-object` |
| Price statistics | `RegionStats.mock()` generates synthetic histogram data | Database of crowdsourced price reports; `GET /prices/stats` |
| Price submission | `Future.delayed(300 ms)` — data is discarded | `POST /prices/submit` writing to a database |
| Community feed | 5 hardcoded `_MockFeed` entries | `GET /community/feed` returning paginated reports |
| Nearby markets | 3 hardcoded Cairo coordinates | `GET /markets/nearby?lat=&lon=` with a markets database |
| Arabic phrases | Loaded from bundled `assets/data/phrases.json` | Can stay as a local asset or migrate to `GET /phrases` |
| Anonymous user ID | Generated locally via `uuid` + `shared_preferences` | Stays local; pass `user_id` in all write API calls |

---

## Backend API Contracts

All endpoints are relative to `ApiEndpoints.baseUrl` (`https://api.trueprice.app` — confirm with backend team before deploying).

### POST /scan/detect-object

Identifies a product from a camera image and optionally reads a price tag via OCR.

**Request** (`multipart/form-data`):

| Field | Type | Description |
|---|---|---|
| `image` | File (JPEG/PNG) | Camera frame |
| `lat` | double | Current latitude |
| `lon` | double | Current longitude |

**Response** (`application/json`):

```json
{
  "product_id": "p001",
  "name_kr": "Grapes",
  "name_ar": "عنب",
  "confidence": 0.92,
  "detected_price": 65.0
}
```

`detected_price` is `null` if no price tag was legible. Map response to `DetectionResult.fromJson()`.

---

### GET /prices/stats

Returns the regional price distribution for a product, used to render the histogram and compute the z-score.

**Query parameters**:

| Param | Type | Description |
|---|---|---|
| `product_id` | string | e.g. `"p001"` |
| `lat` | double | User latitude |
| `lon` | double | User longitude |

**Response** (`application/json`):

```json
{
  "product_id": "p001",
  "product_name": "Grapes",
  "avg": 55.0,
  "std_dev": 12.0,
  "min": 30.0,
  "max": 90.0,
  "sample_count": 142,
  "histogram": [
    { "range_start": 30.0, "range_end": 40.0, "count": 8 },
    { "range_start": 40.0, "range_end": 50.0, "count": 34 }
  ],
  "is_fallback": false
}
```

`is_fallback: true` signals that the server used a city-wide fallback because there were fewer than 10 nearby samples. The UI should display a disclaimer in this case.

---

### POST /prices/submit

Records a user-confirmed price observation for crowdsourcing.

**Request** (`application/json`):

```json
{
  "product_id": "p001",
  "price": 65.0,
  "unit": "kg",
  "lat": 30.0478,
  "lon": 31.2625,
  "user_id": "uuid-v4-anonymous"
}
```

**Response**: `200 OK` (empty body on success).

After a successful submit, the client invalidates its in-memory cache for `product_id` so the next `getStats()` call fetches fresh data.

---

### GET /markets/nearby

Returns a list of markets within a radius of the user's location.

**Query parameters**:

| Param | Type | Description |
|---|---|---|
| `lat` | double | User latitude |
| `lon` | double | User longitude |
| `radius_km` | double | Search radius (suggested default: 5.0) |

**Response** (`application/json`):

```json
[
  {
    "market_id": "m001",
    "name": "Khan el-Khalili",
    "lat": 30.0478,
    "lon": 31.2625,
    "description": "Cairo's largest traditional market & souq"
  }
]
```

Map each entry to a market model and render as a `flutter_map` `Marker`. Replace the hardcoded `_mockMarkets` list in `market_map_screen.dart`.

---

## For the Next Developer

### Immediate Priority: Connect YOLO Backend (Week 5-6)

1. Stand up the Python/FastAPI server with a YOLOv8 model trained on Egyptian produce classes.
2. In `lib/core/constants/api_endpoints.dart`, update `baseUrl` to the deployed server address.
3. In `ScanRepositoryImpl.detectObject()`, uncomment the `DioClient` block and delete the `await Future.delayed` stub and `DetectionResult.mock()` call.
4. Test with a real device (camera permission required — Chrome does not grant camera on all platforms).
5. Add the `unit` field to `DetectionResult` and `DetectionResult.fromJson()` so `PriceInputScreen` can pre-select the correct unit chip.

### Week 7-8: Polish & Real Permissions

1. In `PriceRepositoryImpl.getStats()` and `submitPrice()`, uncomment the `DioClient` blocks and delete the `Future.delayed` stubs.
2. Wire up `GET /markets/nearby` in `market_map_screen.dart` — replace `_mockMarkets` with a `FutureBuilder` or a new `MarketBloc`.
3. Wire up `GET /community/feed` in `community_screen.dart` — replace `_mockFeed` with a paginated `ListView` backed by a `CommunityBloc`.
4. Handle the `isFallback` flag from `/prices/stats` — show a subtle disclaimer chip when the histogram is based on city-wide fallback data.
5. Test runtime permissions on a physical Android and iOS device. `PermissionScreen` already calls `permission_handler`; verify the denied and permanently-denied flows.

### Week 9: Finalization

- Replace the placeholder app icon with the finalized True Price logo.
- Conduct an RTL layout audit — all Arabic text uses `textDirection: TextDirection.rtl` but verify that no layout accidentally left-aligns RTL content on wider screens.
- Run `flutter build apk --release` and `flutter build web --release` and address any tree-shaking or font-embedding warnings.
- Confirm `NotoSansArabic` renders correctly on all target devices (Android, iOS, Chrome).

---

## Key Design Decisions

| Decision | Rationale |
|---|---|
| **Z-score thresholds (1.5 / 0.0)** | A z > 1.5 (roughly 1.5 standard deviations above average) corresponds to a noticeably overpriced item in typical produce markets. The 0.0 threshold marks anything above average as "negotiable" to encourage users to always try bargaining. |
| **EGP currency, Cairo region only** | Scoping the MVP to a single city and currency reduces backend complexity and keeps statistical samples dense enough for meaningful distributions. |
| **`isFallback` flag** | When a product has fewer than 10 nearby observations the backend falls back to city-wide data. The flag lets the client show a disclaimer so users understand the data quality. |
| **Web platform first** | No physical device is available during development, so Chrome is used for all UI iteration. Platform-specific plugins (camera, geolocator) degrade gracefully on web — the scan flow accepts gallery images instead of live camera frames. |
| **In-memory cache for price stats** | `PriceRepositoryImpl._cache` stores one `RegionStats` per `productId` per session. This avoids redundant API calls when the user navigates back and forth in the scan flow. The cache is invalidated immediately after a price submission to keep data fresh. |
| **Anonymous UUID** | `UserIdService` generates a UUID v4 on first launch and stores it in `SharedPreferences`. This allows the server to deduplicate rapid duplicate submissions from the same device without requiring account creation. |
