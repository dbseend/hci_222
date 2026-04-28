# True Price Flutter App

True Price is an iPhone-first Flutter MVP for travelers who need fast price checks in Egyptian markets. It helps users compare offered prices against regional/crowdsourced baselines and provides simple negotiation support.

## Current MVP Status
- Runs on mock data for scan detection, price stats, map markers, and community feed.
- Primary target is a physical iPhone device.
- Onboarding requests camera, location, and photo permissions up front.
- Home screen lets users choose Scan, Map, Phrases, or Community.
- Scan is split into two flows:
  - `Live Scan`: in-app camera preview using the `camera` package.
  - `Camel Ride`: no camera; user enters ride minutes and offered total price.
- MLKit/OCR is currently removed. Price recognition is mocked until backend detection/OCR is connected.

## Main User Flow
```text
Splash
-> Permission onboarding
-> Intro onboarding
-> Home
-> Price Check
   -> Live Scan -> Stats -> Input -> Analysis -> Final
   -> Camel Ride -> Analysis -> Final
-> Map / Phrases / Community
```

## Implemented Features
1. **Onboarding permissions**
   - Requests `camera`, `locationWhenInUse`, and `photos` through `permission_handler`.
   - Shows settings guidance when permissions are blocked.

2. **Home screen**
   - Entry hub for Price Check, Market Map, Phrases, and Community.

3. **Live Scan**
   - Uses `CameraController` and `CameraPreview` inside the app.
   - Captures with `takePicture()` and passes the image file to `ScanBloc`.
   - Keeps Gallery as fallback via `image_picker`.

4. **Camel Ride price check**
   - User enters minutes and offered total EGP.
   - App computes `EGP per minute` and reuses the existing price analysis screen.
   - Mock baseline is `RegionStats.mock('camel_ride')`.

5. **Price analysis**
   - Uses z-score classification from `PriceClassifier`.
   - Displays fair / negotiable / overpriced status and histogram.

6. **Supporting features**
   - Map screen with Cairo market markers.
   - Arabic phrase cards with TTS.
   - Community mock price report feed.

## Tech Stack
| Package | Purpose |
|---|---|
| `camera` | Native iPhone camera preview and capture |
| `image_picker` | Gallery fallback |
| `permission_handler` | Runtime permissions and settings deep-link |
| `go_router` | App routes, ShellRoute, nested scan routes |
| `flutter_bloc` | Scan and price state management |
| `fl_chart` | Price histogram |
| `flutter_map` / `latlong2` | OSM map and coordinates |
| `flutter_tts` | Arabic phrase pronunciation |
| `shared_preferences` / `uuid` | Anonymous local user ID |
| `dio` | Prepared HTTP client for backend integration |

Removed:
- `google_mlkit_text_recognition`: not needed for the current MVP and removed to avoid MLKit iOS framework warnings.

## Project Structure
```text
lib/
├── app/
│   ├── app.dart
│   └── router.dart
├── core/
│   ├── constants/
│   ├── network/
│   ├── services/
│   ├── utils/
│   └── widgets/
└── features/
    ├── home/
    │   └── presentation/screens/home_screen.dart
    ├── onboarding/
    │   └── presentation/screens/
    │       ├── splash_screen.dart
    │       ├── permission_screen.dart
    │       └── intro_screen.dart
    ├── scan/
    │   ├── data/models/
    │   ├── data/repositories/
    │   └── presentation/
    │       ├── bloc/
    │       └── screens/
    │           ├── scan_menu_screen.dart
    │           ├── scan_screen.dart
    │           ├── camel_price_input_screen.dart
    │           ├── price_stats_screen.dart
    │           ├── price_input_screen.dart
    │           ├── price_analysis_screen.dart
    │           └── final_price_screen.dart
    ├── market_map/
    ├── language/
    └── community/
```

## Run on iPhone
```bash
cd frontend/flutter_app
flutter clean
flutter pub get
cd ios
pod install
cd ..
open ios/Runner.xcworkspace
```

In Xcode:
```text
1. Open Runner.xcworkspace, not Runner.xcodeproj.
2. Select Runner scheme.
3. Select a physical iPhone.
4. Product > Clean Build Folder.
5. Run.
```

## Verify
```bash
flutter analyze
flutter test
flutter build ios --no-codesign
```

## Mock vs Real Backend
| Feature | Current State | Needed for production |
|---|---|---|
| Live scan detection | Captures real image, returns mock Grapes result | YOLO/FastAPI `/scan/detect-object` |
| Price stats | `RegionStats.mock()` | `/prices/stats` backed by DB |
| Price submission | Simulated delay | `/prices/submit` DB write |
| Camel ride stats | Mock `camel_ride` per-minute baseline | Service-price dataset |
| Community feed | Hardcoded entries | Paginated `/community/feed` |
| Market map | Hardcoded Cairo markers | `/markets/nearby` |
| OCR | Removed | Backend OCR or future on-device OCR decision |

## iOS Notes
- `Info.plist` includes camera, location, and photo library usage descriptions.
- `Podfile` forces iOS deployment target and Swift settings for plugin compatibility.
- If Xcode shows stale MLKit warnings, clean caches:
```bash
flutter clean
rm -rf ~/Library/Developer/Xcode/DerivedData
cd ios && pod install
```
