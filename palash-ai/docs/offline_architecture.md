# Offline architecture and low-memory policy

The app reads lessons, assessments, progress, translations, sync metadata, and benchmarks from SQLite. The backend is never contacted while a teacher uses lessons, translation, worksheets, flashcards, assessments, or progress screens.

For devices with about 2 GB RAM, EduVaani uses sequential inference: ASR, then translation, then TTS. The model manager checks each model just before use; it does not request all three at startup. Mock TTS audio is capped at eight temporary cached files. Audio players and recorders are released when their screens close.

Before a production release, benchmark genuine quantized ONNX models on the target tablet. Do not report the mock-service timings as production AI performance.
