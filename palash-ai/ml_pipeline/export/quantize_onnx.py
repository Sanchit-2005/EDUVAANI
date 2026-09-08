"""INT8 quantization for IndicTrans2 ONNX models.

Reads FP32 ONNX artifacts from:
  ml_pipeline/export/models/indictrans2/fp32/

Writes INT8 ONNX artifacts to:
  ml_pipeline/export/models/indictrans2/int8/

Uses ONNX Runtime dynamic quantization with external data format
to preserve the 3-model encoder/decoder/decoder_with_past architecture.
"""
import sys
import os
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
ROOT = Path(__file__).parents[1]
sys.path.insert(0, str(ROOT))

from quantization.quantize import quantize  # noqa: E402

FP32_DIR = ROOT / "export" / "models" / "indictrans2" / "fp32"
INT8_DIR = ROOT / "export" / "models" / "indictrans2" / "int8"


def ensure_dirs():
    INT8_DIR.mkdir(parents=True, exist_ok=True)
    return FP32_DIR, INT8_DIR


def quantize_models():
    fp32_dir, int8_dir = ensure_dirs()
    models = [
        "encoder_model.onnx",
        "decoder_model.onnx",
        "decoder_with_past_model.onnx",
    ]

    results = []
    for name in models:
        input_path = fp32_dir / name
        output_path = int8_dir / name

        if not input_path.exists():
            raise FileNotFoundError(f"FP32 model not found: {input_path}")

        print(f"Quantizing {name} ...")
        quantize(str(input_path), str(output_path))

        if not output_path.exists():
            raise RuntimeError(f"Quantization failed for {name}: output not created")

        size = output_path.stat().st_size
        print(f"  -> {output_path} ({size:,} bytes)")
        results.append((name, output_path))

    return results


def validate_int8_models():
    import onnxruntime as ort

    print("\n=== INT8 ONNX Runtime validation ===")
    for name in [
        "encoder_model.onnx",
        "decoder_model.onnx",
        "decoder_with_past_model.onnx",
    ]:
        path = INT8_DIR / name
        if not path.exists():
            print(f"{name}: MISSING")
            continue
        try:
            sess = ort.InferenceSession(str(path), providers=["CPUExecutionProvider"])
            print(f"{name}: load OK, inputs={len(sess.get_inputs())}, outputs={len(sess.get_outputs())}")
        except Exception as exc:
            print(f"{name}: load FAILED: {exc}")
            raise


def main():
    print("Starting INT8 quantization ...")
    results = quantize_models()
    validate_int8_models()
    print("\nINT8 quantization complete.")
    for name, path in results:
        print(f"  {name}: {path}")


if __name__ == "__main__":
    main()
