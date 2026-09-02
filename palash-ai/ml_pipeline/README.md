# EduVaani ML Pipeline

This pipeline prepares a Hindi-Santali prototype dataset, documents the training/evaluation stages, exports ONNX models, quantizes models to INT8, and benchmarks actual inference latency.

All translations in `data/` are prototype-only. A production model requires native Santali speakers and education experts to review both training data and outputs.

## Order

1. Create a reviewed parallel dataset.
2. Run `preprocessing/preprocess.py`.
3. Fine-tune and evaluate a selected translation model.
4. Export to ONNX with `export/export_onnx.py`.
5. Quantize with `quantization/quantize.py`.
6. Benchmark on the 2 GB Android target before packaging model files.

Place only validated, quantized `.onnx` files in the app model store. The Flutter app keeps mock services active when files are absent.
