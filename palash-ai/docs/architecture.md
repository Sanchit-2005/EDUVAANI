# EduVaani architecture

## Voice Translation Workflow

Teacher Hindi speech
-> local recorder
-> ASR service
-> Hindi text
-> translation service
-> Santali text
-> TTS service
-> local audio playback

## Santali Image Scan & Translate Workflow

Camera/Gallery photo
-> image preprocessing
-> OCR service (Ol Chiki detection)
-> Santali text
-> translation service (Santali→Hindi)
-> Hindi text
-> TTS service
-> local audio playback
-> save to SQLite scan_history

## General Architecture

Flutter uses SQLite for normal offline teaching. Optional synchronization uses Express and MySQL only after an explicit user action while online. The current demo uses mock adapters; the same interfaces accept on-device ONNX adapters once approved model files are present.

## Key Design Principles

1. **Offline-first**: All core functionality works without internet
2. **Mockable services**: Services use abstract interfaces; mock implementations demonstrate workflows
3. **Lazy loading**: AI models are loaded only when needed to conserve RAM
4. **Local persistence**: SQLite stores all data (lessons, progress, scans, translations)
5. **Optional sync**: Backend synchronization is opt-in and explicit
6. **Clean architecture**: Services, repositories, and UI are cleanly separated
