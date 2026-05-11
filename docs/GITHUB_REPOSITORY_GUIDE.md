# GitHub Repository Guide

## 핵심 판단

현재 레포는 Flutter 앱, FastAPI 백엔드, Supabase DB, ML 데이터 준비 코드를 한 저장소에서 관리하는 MVP 모노레포 구조가 적합합니다. 지금 단계에서 분리 저장소로 쪼개면 배포보다 연결 비용이 커지므로, GitHub에는 재현 가능한 코드/설정/문서만 올리고 로컬 데이터셋, 학습 산출물, 비밀값은 제외합니다.

참고 기준:

- Flutter 공식 샘플과 공개 object detection 앱들은 `android/`, `ios/`, `lib/`, `test/`, `assets/`, `pubspec.yaml` 중심으로 앱을 올립니다.
- Flutter 문서는 `pubspec.lock`이 동일 의존성 버전을 재현하게 해준다고 설명하므로, 앱 레포에서는 `pubspec.lock`을 커밋합니다.
- Supabase 문서는 `.env`를 Git에 커밋하지 말고 `config.toml`에서 `env(...)`로 참조하라고 안내합니다.
- GitHub의 `.gitignore` 템플릿 기준처럼 빌드 결과, IDE 로컬 상태, 플랫폼 캐시, dependency cache는 제외합니다.

## 현재 프로젝트 구성

```text
hci_222/
├── frontend/flutter_app/  # Flutter mobile MVP
├── backend/               # FastAPI price/catalog API
├── db/                    # SQL migrations, seeds, views, RPC
├── supabase/              # Supabase local config
├── ml/                    # Dataset builders, audit tools, Colab notebook
└── docs/                  # Architecture and delivery notes
```

이 구조는 실제 서비스형 레포 기준으로 충분합니다. Flutter 앱 안은 이미 `lib/app`, `lib/core`, `lib/features`로 나뉘어 있어 MVP 이후 기능 확장도 가능합니다.

## GitHub에 올릴 것

### Root

- `README.md`
- `AGENTS.MD`
- `.gitignore`
- `docs/`

### Flutter

- `frontend/flutter_app/lib/`
- `frontend/flutter_app/test/`
- `frontend/flutter_app/integration_test/`
- `frontend/flutter_app/assets/data/`
- `frontend/flutter_app/assets/fonts/`
- `frontend/flutter_app/pubspec.yaml`
- `frontend/flutter_app/pubspec.lock`
- `frontend/flutter_app/analysis_options.yaml`
- `frontend/flutter_app/android/`, `ios/`, `web/`, `linux/`, `macos/`, `windows/` 안의 소스/설정 파일
- `frontend/flutter_app/ios/Podfile`
- `frontend/flutter_app/ios/Podfile.lock`
- `frontend/flutter_app/ios/Flutter/MapsSecrets.xcconfig.example`

### Backend

- `backend/app/`
- `backend/tests/`
- `backend/requirements.txt`
- `backend/README.md`
- mock/demo JSON 데이터: `backend/app/data/*.json`

### Database / Supabase

- `db/migrations/`
- `db/seeds/`
- `db/views/`
- `db/rpc/`
- `db/README.md`
- `supabase/config.toml`
- `supabase/.gitignore`

### ML

- `ml/README.md`
- `ml/scripts/`
- `ml/tools/`
- `ml/notebooks/` 중 재현용 notebook

## GitHub에 올리지 말 것

### 비밀값

- `.env`, `.env.*`
- 실제 Supabase URL/Anon key가 들어간 로컬 파일
- 실제 Google Maps API key가 들어간 `MapsSecrets.xcconfig`
- Android `local.properties`
- keystore, signing key, `key.properties`, `*.jks`, `*.keystore`

### Flutter / Native 산출물

- `build/`
- `.dart_tool/`
- `.flutter-plugins`, `.flutter-plugins-dependencies`
- `Pods/`, `.symlinks/`, `Generated.xcconfig`, `flutter_export_environment.sh`
- Android `.gradle/`, `captures/`
- `*.apk`, `*.aab`, `*.ipa`

### Python / Backend 산출물

- `__pycache__/`
- `.pytest_cache/`
- `.venv/`, `venv/`, `env/`
- coverage 결과

### ML 데이터 / 모델 산출물

- `datasets/`
- `dataset_open_v1/`
- `dataset_sources/`
- `outputs/`, `runs/`, `wandb/`
- `*.zip`, `*.tar.gz`, `*.pt`, `*.pth`, `*.onnx`, `*.tflite`, `*.engine`, `*.npy`, `*.parquet`

모델 파일이 앱 실행에 반드시 필요하면 일반 Git 커밋이 아니라 Git LFS, Release artifact, 또는 재다운로드 스크립트 중 하나로 관리합니다.

### 개인 IDE 상태

- `.idea/`
- `*.iml`
- `xcuserdata/`
- `.DS_Store`

현재 `.idea` 파일들이 이미 추적 중이면 아래 명령으로 로컬 파일은 유지하고 Git 추적만 제거합니다.

```bash
git rm --cached -r .idea
```

## 업로드 전 체크리스트

```bash
git status --short
git ls-files -ci --exclude-standard
git ls-files | rg '(^|/)(\.env($|/)|local\.properties$|Pods($|/)|build($|/)|\.dart_tool($|/)|\.gradle($|/)|\.DS_Store$)|\.(apk|aab|ipa|pt|onnx|tflite|zip|tar|gz)$' | rg -v 'example'
```

두 번째 명령은 이미 추적 중인데 현재 `.gitignore`에 걸리는 파일을 찾습니다. 세 번째 명령에서 결과가 나오면 올리기 전에 제거하거나 `.gitignore`를 보강합니다.

## 추천 커밋 단위

1. `chore: organize repository upload rules`
2. `docs: update project structure guide`
3. `chore: stop tracking local ide files`

기능 코드와 레포 정리 커밋은 분리하는 것이 좋습니다. 나중에 데모 직전 문제가 생겼을 때 구조 정리만 되돌리기 쉽습니다.
