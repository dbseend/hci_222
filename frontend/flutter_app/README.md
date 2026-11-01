# True Price Flutter App

True Price is a Flutter MVP for travelers who need fast price checks in Egyptian markets. It helps users compare offered prices against regional/crowdsourced baselines and provides simple negotiation support.

## Current MVP Status
- Uses authenticated FastAPI calls for scan detection, price stats, scan
  history, and community posts/feed. Demo fallback is opt-in and disabled by
  default.
- Primary target is a physical mobile device (iOS / Android).
- Onboarding requests camera, location, and photo permissions up front.
- Home screen lets users choose Scan, Map, Phrases, or Community.
- Scan is split into two flows:
  - `Live Scan`: in-app camera preview using the `camera` package.
  - `Camel Ride`: no camera; user enters ride minutes and offered total price.
- MLKit/OCR is removed; the backend detects product identity and the user enters
  the quoted price explicitly.

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
   - The configured demo baseline is used only when demo fallback is enabled.

5. **Price analysis**
   - Uses z-score classification from `PriceClassifier`.
   - Displays fair / negotiable / overpriced status and histogram.
   - Submits the authenticated purchase once through `PurchaseSubmissionCubit`.

6. **Supporting features**
   - Map screen with Cairo market markers.
   - Arabic phrase cards with TTS.
   - Authenticated community feed with Cubit-owned loading/filter/sort state.

## Tech Stack
| Package | Purpose |
|---|---|
| `camera` | Native mobile camera preview and capture |
| `image_picker` | Gallery fallback |
| `permission_handler` | Runtime permissions and settings deep-link |
| `go_router` | App routes, ShellRoute, nested scan routes |
| `flutter_bloc` | Scan and price state management |
| `fl_chart` | Price histogram |
| `flutter_map` / `latlong2` | OSM map and coordinates |
| `flutter_tts` | Arabic phrase pronunciation |
| `shared_preferences` | Supabase anonymous Auth session persistence |
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

## Local Env Setup
Use one project env file as the source of truth.

1. Fill the project env file (git-ignored):
```text
../../.env
```

Required keys:
```bash
TRUEPRICE_API_BASE_URL=http://YOUR_BACKEND_HOST:8000
TRUEPRICE_EXCHANGE_RATE_API_URL=https://YOUR_EXCHANGE_RATE_HOST/v1/latest
SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co
SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLIC_SUPABASE_PUBLISHABLE_KEY
SUPABASE_SERVICE_ROLE_KEY=YOUR_BACKEND_ONLY_SERVICE_ROLE_KEY
TRUEPRICE_DETECTOR_MODE=yolo
TRUEPRICE_YOLO_MODEL_PATH=backend/models/best.pt
TRUEPRICE_WARM_UP_DETECTOR=true
TRUEPRICE_ENABLE_DEMO_FALLBACKS=false
TRUEPRICE_DEFAULT_REGION=cairo
```

2. Generate Flutter-only env constants:
```bash
cd ../..
python3 scripts/generate_flutter_defines.py
cd frontend/flutter_app
```

3. Run Flutter normally:
```bash
flutter run
```

You can also override the generated API URL without regenerating:
```bash
flutter run --dart-define=TRUEPRICE_API_BASE_URL=http://<mac-lan-ip>:8000
```

4. In VS Code, select launch config:
```text
Flutter (Supabase Dev)
```

The VS Code launch config runs the generate task automatically. The public
Supabase URL and publishable key are copied into Flutter so it can create an
anonymous Auth session. The service role key stays backend-only and is never
copied. Anonymous sign-ins must be enabled in the Supabase Auth settings.

## Verify
```bash
flutter analyze
flutter test
flutter build ios --no-codesign
```

## Mock vs Real Backend
| Feature | Current State | Needed for production |
|---|---|---|
| Live scan detection | Captures real image and calls YOLO/FastAPI `/scan/detect-object` | Larger product catalog and model QA |
| Price stats | FastAPI; local fallback only behind explicit demo flag | Live DB coverage for all products |
| Price comparison | FastAPI; local fallback only behind explicit demo flag | Server-side rule/version tracking |
| Scan history | Authenticated anonymous-user history via FastAPI/Supabase | Account linking and retention policy |
| Community feed | FastAPI; local feed only behind explicit demo flag | Cursor pagination/moderation |
| Market map | Hardcoded Cairo markers | `/markets/nearby` |
| OCR | Removed | Backend OCR or future on-device OCR decision |

Anonymous access tokens currently persist in `shared_preferences` to preserve
the MVP session. Before introducing persistent named accounts, add platform
secure storage and an account-linking policy.

## iOS Notes
- `Info.plist` includes camera, location, and photo library usage descriptions.
- `Info.plist` includes local network usage for physical iPhone -> Mac backend testing.
- `Podfile` forces iOS deployment target and Swift settings for plugin compatibility.
- For physical iPhone YOLO testing, set `TRUEPRICE_API_BASE_URL` to the Mac LAN IP, not `127.0.0.1`.
- If Xcode shows stale MLKit warnings, clean caches:
```bash
flutter clean
rm -rf ~/Library/Developer/Xcode/DerivedData
cd ios && pod install
```

## Android Notes
- `AndroidManifest.xml` includes:
  - `CAMERA`
  - `ACCESS_FINE_LOCATION`
  - `ACCESS_COARSE_LOCATION`
  - `INTERNET`
  - `READ_MEDIA_IMAGES`
  - `READ_EXTERNAL_STORAGE` (`maxSdkVersion=32`)
- Onboarding requires camera permission to proceed. Location/photos can stay optional for limited flow.
