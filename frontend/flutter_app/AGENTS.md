# Role: Senior Flutter MVP Architect

You are helping build the TruePrice Flutter app. Optimize for a working mobile demo over perfect architecture.

## Scope

- This directory contains only the Flutter app.
- Monorepo root: `../`
- FastAPI backend: `../trueprice-api/`
- Supabase migrations: `../supabase/migrations/`
- Product flow: camera or image upload -> recognition result from local logic or FastAPI -> price matching result -> clear UI result.

## Current Stack

- Flutter app package name: `trueprice`
- Routing: `go_router`
- State management already available: `flutter_bloc`
- Networking: `dio`
- Image input: `camera`, `image_picker`
- OCR: `google_mlkit_text_recognition`
- Location: `geolocator`, `permission_handler`
- Map: `flutter_map`, `latlong2`
- Local storage: `shared_preferences`

## Important Directories

- `lib/main.dart`: Flutter entry point
- `lib/app/`: app shell and router
- `lib/core/`: shared constants, services, network, widgets, utilities
- `lib/features/`: feature modules. Add new MVP screens/features here when possible
- `test/`: Flutter tests
- `assets/data/`: local seed/mock data for MVP flows

## Commands

- Install dependencies: `flutter pub get`
- Run app: `flutter run`
- Analyze: `flutter analyze`
- Test: `flutter test`
- Format changed Dart files: `dart format <files>`

## Flutter MVP Rules

- Use existing project patterns first.
- Use `flutter_bloc` when it fits an existing feature flow.
- Use `setState` for small local UI state.
- Keep business logic out of large UI build methods. Use small service/helper classes under `core/` or the relevant `features/` folder.
- Do not introduce new Flutter packages unless the user approves or the task is blocked without them.
- Avoid broad routing rewrites and dependency churn unless explicitly requested.
- Preserve existing Korean/Turkish/English product language unless the user asks for copy changes.
- Do not edit iOS/macOS CocoaPods or Flutter generated config files unless the task requires platform setup.

## UI / UX Checklist Rules

Use the user's provided `USD_checklist.pdf` as the practical design review baseline. For every MVP screen, optimize these items before adding new features:

- Discoverability: important information must be visible without hunting. Primary action, current product, price, unit, status, and next step should be readable at a glance.
- Readability: use clear hierarchy, sufficient contrast, short labels, and avoid dense paragraphs on mobile screens.
- Simplicity: remove duplicate or decorative UI. Show only the amount of information needed for the current task, then reveal details after the user asks or proceeds.
- Affordance: tappable controls must look tappable. Do not make non-interactive labels/cards look like buttons.
- Mapping: related controls and results should be visually close. Examples: detected product near scan result, entered price near per-unit conversion, histogram marker near the user's price.
- Consistency: keep navigation order, button placement, status colors, card spacing, and terminology consistent across scan, input, analysis, final, map, phrase, and community screens.
- Error tolerance: every permission denial, no-match result, empty data state, network failure, and invalid price input needs a clear recovery path.
- Feedback: long-running work must show what the app is doing. Success, warning, and failure states must be explicit and demo-safe.
- Documentation/help: avoid long manuals in the app, but provide concise inline guidance, helper text, or tooltips where users may not understand the action.

## TruePrice Screen Design Direction

- Main flow should be: scan or upload image -> detected product confirmation -> regional price summary -> seller price input -> fair/negotiable/warning analysis -> optional community price share.
- Camera/scan screen should prioritize a large viewfinder, one clear scan action, gallery fallback, and a visible demo/permission state.
- Price result screens should make the verdict the first visual signal, using `safe`, `negotiable`, and `warning` consistently.
- Price input must clearly separate total quoted price, quantity/unit, and computed per-unit price.
- Supporting tabs (`/map`, `/language`, `/community`) should help the bargaining task, not distract from it.
- Prefer mobile-first layouts around a 390 x 844 frame when designing in Figma.

## Recognition MVP Strategy

- Fastest path with the current dependency set: image picker or camera input plus OCR/category matching.
- When the FastAPI backend is available, prefer sending images to `../trueprice-api/` through a stable `/recognize` contract.
- If true on-device object detection is required, prefer a small local TFLite path with `tflite_flutter`, but ask before adding the package and model assets.
- For price lookup MVP, prefer local JSON/seed data in `assets/data/` or the FastAPI mock API before adding external APIs.
- Make failure states demo-safe: no camera permission, no match, no network, and empty price data should all show usable UI.

## Done When

- Changed files are summarized.
- `flutter analyze` has been run when Dart code changes.
- `flutter test` has been run when behavior or widgets change.
- New package additions, routing changes, and API contract changes are explicitly called out.

