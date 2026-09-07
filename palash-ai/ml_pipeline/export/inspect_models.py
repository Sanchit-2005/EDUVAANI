import onnxruntime as ort
from pathlib import Path

for variant in ['fp32', 'int8']:
    root = Path(r'D:\V2 s123\EDUVAANI\palash-ai\ml_pipeline\export\models\indictrans2') / variant
    print(f"=== {variant.upper()} ===")
    for m in ['decoder_model.onnx', 'decoder_with_past_model.onnx']:
        sess = ort.InferenceSession(str(root / m), providers=['CPUExecutionProvider'])
        print(f"  {m}:")
        print(f"    Inputs ({len(sess.get_inputs())}):")
        for i in sess.get_inputs():
            print(f"      {i.name}: {i.shape} {i.type}")
        print(f"    Outputs ({len(sess.get_outputs())}):")
        for o in sess.get_outputs():
            print(f"      {o.name}: {o.shape} {o.type}")
    print()
