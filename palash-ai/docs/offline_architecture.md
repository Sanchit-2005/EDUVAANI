# Offline architecture and low-memory policy

## Data Storage

The app reads lessons, assessments, progress, translations, sync metadata, benchmarks, and scan history from SQLite. The backend is never contacted while a teacher uses lessons, translation, worksheets, flashcards, assessments, progress, or image scan screens.

## Memory Management

For devices with about 2 GB RAM, EduVaani uses sequential inference:

### Voice Translation Pipeline

1. ASR (Hindi speech recognition)
2. Translation (Hindi→Santali)
3. TTS (Santali speech synthesis)

### Image Scan Pipeline

1. Image preprocessing (resize, enhance)
2. OCR (Ol Chiki text extraction)
3. Translation (Santali→Hindi)
4. TTS (Hindi speech synthesis)

The model manager checks each model just before use; it does not load all models at startup. Mock TTS audio is capped at eight temporary cached files. Audio players and recorders are released when their screens close.

## Image Processing

Image preprocessing is lightweight:

- Resizing capped at 1920×1920
- Grayscale conversion
- Simple 3×3 median filter for noise reduction
- Histogram stretching for contrast
- Text area detection and cropping

No full-resolution image data is kept in memory during inference.

## Database

`scan_history` table stores scan results locally. Images are stored as file paths; the actual image files remain in the app's temporary directory and can be cleaned up by the OS at any time.

## Recommendations Before Production

1. Benchmark genuine quantized ONNX models (OCR, Santali→Hindi, Hindi TTS) on the target tablet
2. Do not report mock-service timings as production AI performance
3. Use INT8 quantized models to fit in 2GB RAM
4. Test memory usage during concurrent operations (e.g., displaying history + playing audio)
5. Validate Hindi TTS pronunciation and clarity with native speakers
