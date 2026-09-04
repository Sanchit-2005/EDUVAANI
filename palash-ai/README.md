# EduVaani

Offline Mother-Tongue Learning Assistant for the SIH 2026 EduVaani MTB-MLE prototype. It helps Hindi-speaking teachers deliver foundational literacy and numeracy activities with Santali support.

## What works offline

- Local SQLite lessons, translations, assessments, progress, and sync metadata
- **Hindi ↔ Santali neural translation via IndicTrans2** (requires Python service + Node.js backend)
- Demo Hindi voice workflow with measured mock-stage timings
- Local worksheet and flashcard PDF generation
- Offline progress tracking
- **Santali Image Scan & Translate**: Capture Ol Chiki text, extract via OCR, translate to Hindi, and play speech (offline)

## Architecture

Flutter is the classroom application. SQLite supports everyday offline use. Node.js/Express and MySQL are optional services for content and progress synchronization. The ML pipeline documents an eventual validated ONNX model workflow. Hindi ↔ Santali neural translation uses IndicTrans2 via a three-tier stack (Flutter → Node.js → Python FastAPI).

## IndicTrans2 Translation Setup

The Hindi ↔ Santali text translator now uses the real **[ai4bharat/indictrans2-indic-indic-dist-320M](https://huggingface.co/ai4bharat/indictrans2-indic-indic-dist-320M)** model running in a Python FastAPI service. Three processes must be running together.

```
Flutter App  →  Node.js Backend  →  Python FastAPI  →  IndicTrans2 320M
```

Language codes: `hin_Deva` (Hindi, Devanagari) ↔ `sat_Olck` (Santali, Ol Chiki)

> **First startup note:** The model (~1.3 GB) is downloaded from Hugging Face on first run and cached in `~/.cache/huggingface/`. Subsequent starts are fast.

---

### Terminal 1 — Python translation service

Requires **Python 3.10+**. Linux or macOS recommended; IndicTransToolkit is not tested on Windows.

```bash
cd ml_pipeline/translation_service

# Create and activate a virtual environment
python -m venv .venv

# Windows:
.venv\Scripts\activate
# Linux / macOS:
source .venv/bin/activate

# Install dependencies (includes IndicTransToolkit, torch, transformers, FastAPI)
pip install -r requirements.txt

# Start the service (downloads model on first run — allow a few minutes)
python app.py
# Python binds to 0.0.0.0:8000 by default; Node exposes the phone-facing API on 0.0.0.0:3000.
# Override port: set TRANSLATION_PORT=8001 before running.
```

Verify it is running:

```bash
curl http://127.0.0.1:8000/health
# → {"status":"ok","model":"ai4bharat/indictrans2-indic-indic-dist-320M","model_loaded":true}
```

---

### Terminal 2 — Node.js backend

```bash
cd backend

# Copy the example env file and set values
cp .env.example .env
# Edit .env:
#   PYTHON_TRANSLATION_URL=http://127.0.0.1:8000   (Python service URL)
#   TRANSLATION_TIMEOUT_MS=30000                    (30 s — safe for CPU)
#   PORT=3000
#   MYSQL_* credentials if using the content sync features

pnpm install
pnpm start
# or for development with auto-reload:
pnpm dev
```

---

### Terminal 3 — Flutter app

```bash
cd flutter_app

flutter pub get
flutter run
```

**Configure the backend URL** before running. A physical device must use the host's current LAN IPv4 address; DHCP can change it. Find it with `ipconfig` (Windows) or `ip a` (Linux/macOS), then use a build-time override or the Text Translator settings dialog:

```powershell
flutter run --dart-define=BACKEND_BASE_URL=http://<your-LAN-IP>:3000
```

| Environment | Value |
|---|---|
| Android emulator | `http://10.0.2.2:3000` |
| Physical device | `http://<your-LAN-IP>:3000` |
| iOS simulator | `http://127.0.0.1:3000` |

The Node server binds to `0.0.0.0:3000`; the phone can verify the complete stack at `http://<your-LAN-IP>:3000/health`. The response is `200` only when the Python service is reachable and `model_loaded` is true. If `/health` works on the PC but not on the phone, check that both devices are on the same Wi-Fi subnet, AP/client isolation is disabled, and Windows Firewall allows inbound TCP 3000 on the active network profile (the diagnosed host is currently Public). Debug/profile Android builds allow cleartext HTTP for this local development endpoint; release builds do not.

The host used during diagnosis currently reports `192.168.1.46` on Wi-Fi; `192.168.1.39` is stale and must not be used. Re-run `ipconfig` whenever DHCP changes the address.

---

### Testing the translation API

**Test the Python service directly** (service must be running):

```bash
cd ml_pipeline/translation_service
python test_translation.py
# Runs 10 cases: health, Hindi→Santali, Santali→Hindi, validation errors
```

**Manual curl tests:**

```bash
# Hindi → Santali
curl -X POST http://127.0.0.1:8000/translate \
  -H "Content-Type: application/json" \
  -d '{"text":"नमस्ते","source_language":"hin_Deva","target_language":"sat_Olck"}'

# Santali → Hindi
curl -X POST http://127.0.0.1:8000/translate \
  -H "Content-Type: application/json" \
  -d '{"text":"ᱡᱚᱦᱟᱨ","source_language":"sat_Olck","target_language":"hin_Deva"}'

# Via Node.js (POST /api/translate)
curl -X POST http://localhost:3000/api/translate \
  -H "Content-Type: application/json" \
  -d '{"text":"आप कैसे हैं?","source_language":"hin_Deva","target_language":"sat_Olck"}'
```

---

### Limitations of this implementation

- Translation requires the Python service and Node.js backend to be running. It is **not fully offline/on-device** in this version.
- First startup downloads ~1.3 GB from Hugging Face.
- CPU inference takes a few seconds per request. A CUDA GPU will be used automatically if available.
- Future path: fine-tune → quantize → ONNX export → Flutter on-device via `assets/models/`. The existing `ml_pipeline/quantization/` and `ml_pipeline/export/` scripts support this workflow.

## Setup

### Flutter

Open `flutter_app`, run `flutter pub get`, then run `flutter run`. Android support starts at API 28 (Android 9).

### Backend

Open `backend`, copy `.env.example` to `.env`, create the MySQL schema using `database/schema.sql`, run `pnpm install`, then run `pnpm start`.

### Build Android APK

Run `flutter build apk --release` inside `flutter_app`.

## Limitations

Hindi ↔ Santali neural translation uses IndicTrans2 and requires the Python service and Node.js backend — it is not yet on-device. All other ASR, non-translation TTS, and OCR features remain clearly labelled offline mocks. Santali output needs native-speaker and education-expert validation. Real ONNX models and a Unicode font covering Devanagari and Ol Chiki are required before a production deployment.

See `docs/demo_script.md`, `docs/architecture.md`, and `docs/offline_architecture.md` for the demo and architecture details.

## 5. Santali Image Scan & Translate

### Overview

Teachers can now capture photos of Santali textual content (especially text written in Ol Chiki script), extract the text using OCR, translate it to Hindi, and play the Hindi translation as speech.

### Workflow

1. **Dashboard** → Tap "Scan Santali"
2. **Camera/Gallery** → Take a photo or select from gallery
3. **Image Preview** → Review the image quality
4. **OCR Processing** → Extract Santali text from the image
5. **Translation** → Translate Santali to Hindi
6. **Playback** → Play Hindi speech
7. **Save** → Store result in local SQLite history
8. **History** → View previously scanned translations

### Key Features

- 📷 **Offline-first**: All processing happens locally
- 🔍 **Image Preprocessing**: Auto-resize, grayscale conversion, contrast enhancement, noise reduction
- 🔧 **Mockable Architecture**: OCR and translation services can be swapped with real ONNX models
- 💾 **Local Storage**: Results saved in SQLite, with optional backend sync
- 🔊 **Hindi TTS**: Play translations as speech
- 📱 **Lightweight**: Optimized for low-end Android tablets (~2GB RAM)

### Architecture

**Image Processing Pipeline:**

```
Camera/Gallery
    ↓
Image Preprocessing
    (resize, grayscale, contrast, denoise, deskew)
    ↓
Ol Chiki OCR Detection
    (mock: returns demo text)
    ↓
Santali Text Extraction
    ↓
Santali → Hindi Translation
    (mock: word-by-word lookup)
    ↓
Hindi Text
    ↓
Hindi TTS Engine
    (mock: generates demo audio)
    ↓
Audio Playback
    ↓
Save to scan_history Table
```

### Database

New `scan_history` table stores:

- `id`: Unique identifier
- `image_path`: Local path to scanned image
- `santali_text`: Extracted Ol Chiki text
- `hindi_translation`: Hindi translation result
- `created_at`: ISO 8601 timestamp
- `is_synced`: Sync status (0 = local, 1 = synced to backend)

### Services

- `SantaliOcrService`: Abstraction for OCR (mock included)
- `SantaliToHindiService`: Abstraction for translation (mock included)
- `HindiTtsService`: Hindi text-to-speech (mock included)
- `ImagePreprocessingService`: Image enhancement for OCR

### Screens

1. `SantaliScannerScreen`: Main entry point with camera/gallery buttons
2. `ImagePreviewScreen`: Show and confirm captured image
3. `OcrResultScreen`: Display extracted Santali text
4. `TranslationResultScreen`: Show Hindi translation and play audio
5. `ScanHistoryScreen`: View, search, and delete previous scans

### Production Readiness

**Not production-ready yet.** Replace mock services with real models:

1. **OCR Model**: Requires a trained Ol Chiki recognition model (ONNX format)
2. **Translation Model**: Requires Santali→Hindi model (Indic language support)
3. **TTS Model**: Requires offline Hindi TTS model

See `docs/ml_pipeline.md` for model requirements.
