"""Export ai4bharat/indictrans2-indic-indic-dist-320M to FP32 ONNX.

The working PyTorch reference lives in:
  ml_pipeline/translation_service/translator.py

This script reuses the same model/tokenizer loading path and writes ONNX
artifacts to:
  ml_pipeline/export/models/indictrans2/fp32/

Exported files:
  encoder_model.onnx
  decoder_model.onnx
  decoder_with_past_model.onnx
"""
import sys
import os
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(Path(__file__).parent)

import torch
import onnxruntime as ort
import onnx

TRANSLATION_SERVICE_DIR = Path(__file__).parents[1] / "translation_service"
sys.path.insert(0, str(TRANSLATION_SERVICE_DIR))

from translator import translator  # noqa: E402

MODEL_ID = "ai4bharat/indictrans2-indic-indic-dist-320M"
OUTPUT_DIR = Path(__file__).parent / "models" / "indictrans2" / "fp32"
OPSET = 14


def ensure_output_dir() -> Path:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    return OUTPUT_DIR


def load_model():
    if not translator.is_loaded:
        translator.load()
    model = translator._model.cpu()
    model.eval()
    tokenizer = translator._tokenizer
    return model, tokenizer


def export_encoder(model: torch.nn.Module, output_dir: Path) -> Path:
    encoder = model.get_encoder()
    path = output_dir / "encoder_model.onnx"

    input_ids = torch.randint(0, model.config.encoder_vocab_size, (1, 8), dtype=torch.long)
    attention_mask = torch.ones((1, 8), dtype=torch.long)

    torch.onnx.export(
        encoder,
        (input_ids, attention_mask),
        str(path),
        input_names=["input_ids", "attention_mask"],
        output_names=["encoder_hidden_states"],
        dynamic_axes={
            "input_ids": {0: "batch", 1: "src_len"},
            "attention_mask": {0: "batch", 1: "src_len"},
            "encoder_hidden_states": {0: "batch", 1: "src_len"},
        },
        opset_version=OPSET,
        do_constant_folding=True,
        dynamo=False,
    )
    return path


class DecoderWithLMHead(torch.nn.Module):
    def __init__(self, decoder: torch.nn.Module, lm_head: torch.nn.Module):
        super().__init__()
        self.decoder = decoder
        self.lm_head = lm_head

    def forward(self, input_ids, attention_mask, encoder_hidden_states, encoder_attention_mask):
        out = self.decoder(
            input_ids=input_ids,
            attention_mask=attention_mask,
            encoder_hidden_states=encoder_hidden_states,
            encoder_attention_mask=encoder_attention_mask,
            use_cache=True,
        )
        return self.lm_head(out.last_hidden_state)


def export_decoder(model: torch.nn.Module, output_dir: Path) -> Path:
    path = output_dir / "decoder_model.onnx"
    wrapper = DecoderWithLMHead(model.get_decoder(), model.lm_head)
    wrapper.eval()

    input_ids = torch.randint(0, model.config.decoder_vocab_size, (1, 1), dtype=torch.long)
    attention_mask = torch.ones((1, 1), dtype=torch.long)
    encoder_hidden_states = torch.randn(1, 4, model.config.decoder_embed_dim)
    encoder_attention_mask = torch.ones((1, 4), dtype=torch.long)

    torch.onnx.export(
        wrapper,
        (input_ids, attention_mask, encoder_hidden_states, encoder_attention_mask),
        str(path),
        input_names=["input_ids", "attention_mask", "encoder_hidden_states", "encoder_attention_mask"],
        output_names=["logits"],
        dynamic_axes={
            "input_ids": {0: "batch", 1: "tgt_len"},
            "attention_mask": {0: "batch", 1: "tgt_len"},
            "encoder_hidden_states": {0: "batch", 1: "src_len"},
            "encoder_attention_mask": {0: "batch", 1: "src_len"},
            "logits": {0: "batch", 1: "tgt_len"},
        },
        opset_version=OPSET,
        do_constant_folding=True,
        dynamo=False,
    )
    return path


class DecoderWithPast(torch.nn.Module):
    def __init__(self, decoder: torch.nn.Module, lm_head: torch.nn.Module, num_layers: int):
        super().__init__()
        self.decoder = decoder
        self.lm_head = lm_head
        self.num_layers = num_layers

    def forward(self, input_ids, attention_mask, encoder_hidden_states, encoder_attention_mask, *past):
        past_key_values = []
        for i in range(self.num_layers):
            base = i * 4
            past_key_values.append((
                past[base],
                past[base + 1],
                past[base + 2],
                past[base + 3],
            ))
        past_key_values = tuple(past_key_values)

        out = self.decoder(
            input_ids=input_ids,
            attention_mask=attention_mask,
            encoder_hidden_states=encoder_hidden_states,
            encoder_attention_mask=encoder_attention_mask,
            past_key_values=past_key_values,
            use_cache=True,
        )
        logits = self.lm_head(out.last_hidden_state)
        present = []
        for layer_past in out.past_key_values:
            present.extend(layer_past)
        return (logits, *present)


def export_decoder_with_past(model: torch.nn.Module, output_dir: Path) -> Path:
    path = output_dir / "decoder_with_past_model.onnx"
    num_layers = model.config.decoder_layers
    num_heads = model.config.decoder_attention_heads
    head_dim = model.config.decoder_embed_dim // num_heads
    wrapper = DecoderWithPast(model.get_decoder(), model.lm_head, num_layers)
    wrapper.eval()

    input_ids = torch.randint(0, model.config.decoder_vocab_size, (1, 1), dtype=torch.long)
    attention_mask = torch.ones((1, 5), dtype=torch.long)
    encoder_hidden_states = torch.randn(1, 4, model.config.decoder_embed_dim)
    encoder_attention_mask = torch.ones((1, 4), dtype=torch.long)
    past = []
    for _ in range(num_layers):
        past.extend(
            [
                torch.randn(1, num_heads, 4, head_dim),
                torch.randn(1, num_heads, 4, head_dim),
                torch.randn(1, num_heads, 4, head_dim),
                torch.randn(1, num_heads, 4, head_dim),
            ]
        )

    input_names = [
        "input_ids",
        "attention_mask",
        "encoder_hidden_states",
        "encoder_attention_mask",
    ] + [f"past_{i}" for i in range(num_layers * 4)]
    output_names = ["logits"] + [f"present_{i}" for i in range(num_layers * 4)]

    dynamic_axes = {
        "input_ids": {0: "batch", 1: "cur_len"},
        "attention_mask": {0: "batch", 1: "total_len"},
        "encoder_hidden_states": {0: "batch", 1: "src_len"},
        "encoder_attention_mask": {0: "batch", 1: "src_len"},
        "logits": {0: "batch", 1: "cur_len"},
    }
    for i in range(num_layers * 4):
        dynamic_axes[f"past_{i}"] = {2: "past_len"}
        dynamic_axes[f"present_{i}"] = {2: "total_len"}

    torch.onnx.export(
        wrapper,
        (input_ids, attention_mask, encoder_hidden_states, encoder_attention_mask, *past),
        str(path),
        input_names=input_names,
        output_names=output_names,
        dynamic_axes=dynamic_axes,
        opset_version=OPSET,
        do_constant_folding=True,
        dynamo=False,
    )
    return path


def validate_with_onnxruntime(output_dir: Path) -> None:
    print("\n=== ONNX Runtime validation ===")
    for name in [
        "encoder_model.onnx",
        "decoder_model.onnx",
        "decoder_with_past_model.onnx",
    ]:
        path = output_dir / name
        if not path.exists():
            print(f"{name}: MISSING")
            continue
        size = path.stat().st_size
        model_proto = onnx.load(str(path))
        opset = model_proto.opset_import[0].version if model_proto.opset_import else "unknown"
        sess = ort.InferenceSession(str(path), providers=["CPUExecutionProvider"])
        print(f"{name}: size={size:,} bytes, opset={opset}, inputs={len(sess.get_inputs())}, outputs={len(sess.get_outputs())}, load=OK")


def main():
    print("Loading model:", MODEL_ID)
    model, tokenizer = load_model()
    print("Model loaded. Parameters:", sum(p.numel() for p in model.parameters()))

    output_dir = ensure_output_dir()
    print("Output directory:", output_dir)

    print("\nExporting encoder...")
    encoder_path = export_encoder(model, output_dir)
    print("Encoder saved:", encoder_path)

    print("\nExporting decoder...")
    decoder_path = export_decoder(model, output_dir)
    print("Decoder saved:", decoder_path)

    print("\nExporting decoder_with_past...")
    decoder_with_past_path = export_decoder_with_past(model, output_dir)
    print("Decoder_with_past saved:", decoder_with_past_path)

    validate_with_onnxruntime(output_dir)
    print("\nExport complete.")


if __name__ == "__main__":
    main()
