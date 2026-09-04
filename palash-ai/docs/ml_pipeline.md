# ML and ONNX deployment

## Voice Translation Pipeline

EduVaani uses sequential model execution to protect 2 GB RAM devices:

1. Hindi ASR (speech recognition)
2. Hindi→Santali translation
3. Santali TTS (speech synthesis)

## Image Scan Pipeline

New image scanning functionality requires:

1. Ol Chiki OCR (optical character recognition)
2. Santali→Hindi translation (reverse direction)
3. Hindi TTS (speech synthesis)

## Model Management

Model adapters are present in Flutter, but real inference is intentionally **disabled** until validated and quantized model files exist.

The model manager looks for these files in `assets/models/`:

- `hindi_asr_int8.onnx` (existing)
- `hindi_santali_int8.onnx` (existing)
- `santali_tts_int8.onnx` (existing)
- `ol_chiki_ocr_int8.onnx` (new - for image scanning)
- `santali_hindi_int8.onnx` (new - for reverse translation)

It checks a model before the corresponding adapter runs and produces a clear missing-model message instead of crashing.

## Abstract Service Pattern

Each model adapter implements a Dart interface:

- `SantaliOcrService` → `MockSantaliOcrService` or `OnnxSantaliOcrService`
- `SantaliToHindiService` → `MockSantaliToHindiService` or `OnnxSantaliToHindiService`
- `TextToSpeechService` → `MockTextToSpeechService` (for Santali)
- `HindiTtsService` → `MockHindiTtsService` (new, for Hindi)

UI code does not change when swapping implementations.

## Validation and Benchmarking

Do not label prototype translations or audio as validated output. Record benchmark timings on the actual Android target after genuine model integration.

**Benchmarking checklist:**

- OCR latency per image size (480×640, 720×1080, 1920×1920)
- Translation latency for various text lengths
- TTS startup and playback latency
- Total scan-to-speech latency
- Peak RAM usage during inference
- Battery consumption

## Data Validation

All scanned and translated content must be reviewed by native Santali speakers and education experts before classroom deployment.
