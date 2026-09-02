# EduVaani

Offline Mother-Tongue Learning Assistant for the SIH 2026 EduVaani MTB-MLE prototype. It helps Hindi-speaking teachers deliver foundational literacy and numeracy activities with Santali support.

## What works offline

- Local SQLite lessons, translations, assessments, progress, and sync metadata
- Hindi-Santali prototype text translation
- Demo Hindi voice workflow with measured mock-stage timings
- Local worksheet and flashcard PDF generation
- Offline progress tracking

## Architecture

Flutter is the classroom application. SQLite supports everyday offline use. Node.js/Express and MySQL are optional services for content and progress synchronization. The ML pipeline documents an eventual validated ONNX model workflow.

## Setup

### Flutter

Open `flutter_app`, run `flutter pub get`, then run `flutter run`. Android support starts at API 28 (Android 9).

### Backend

Open `backend`, copy `.env.example` to `.env`, create the MySQL schema using `database/schema.sql`, run `pnpm install`, then run `pnpm start`.

### Build Android APK

Run `flutter build apk --release` inside `flutter_app`.

## Limitations

Current ASR, translation, and TTS are clearly labelled offline mocks. Santali output needs native-speaker and education-expert validation. Real ONNX models and a Unicode font covering Devanagari and Ol Chiki are required before a production deployment.

See `docs/demo_script.md`, `docs/architecture.md`, and `docs/offline_architecture.md` for the demo and architecture details.
