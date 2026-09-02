# ML and ONNX deployment

EduVaani uses sequential model execution to protect 2 GB RAM devices: Hindi ASR, then Hindi-Santali translation, then Santali TTS. Model adapters are present in Flutter, but real inference is intentionally disabled until validated and quantized model files exist.

The model manager looks for three files: `hindi_asr_int8.onnx`, `hindi_santali_int8.onnx`, and `santali_tts_int8.onnx`. It checks a model before the corresponding adapter runs and produces a clear missing-model message instead of crashing.

Do not label prototype translations or audio as validated output. Record benchmark timings on the actual Android target after model integration.
