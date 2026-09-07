"""FP32 vs INT8 ONNX IndicTrans2 generation comparison.

Uses the same generation logic as test_onnx_generation.py, but loads
INT8 quantized models from:
  ml_pipeline/export/models/indictrans2/int8/
"""
import sys
import os
import time
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
ROOT = Path(__file__).parents[1]
sys.path.insert(0, str(ROOT / "translation_service"))

import torch
import onnxruntime as ort
import numpy as np

from translator import translator

FP32_DIR = ROOT / "export" / "models" / "indictrans2" / "fp32"
INT8_DIR = ROOT / "export" / "models" / "indictrans2" / "int8"


def load_models(model_dir):
    sess_enc = ort.InferenceSession(str(model_dir / "encoder_model.onnx"), providers=["CPUExecutionProvider"])
    sess_dec = ort.InferenceSession(str(model_dir / "decoder_model.onnx"), providers=["CPUExecutionProvider"])
    sess_dec_past = ort.InferenceSession(str(model_dir / "decoder_with_past_model.onnx"), providers=["CPUExecutionProvider"])
    return sess_enc, sess_dec, sess_dec_past


def pytorch_greedy_translate(text, source_language, target_language):
    translator.load()
    preprocessed = translator._ip.preprocess_batch(
        [text], src_lang=source_language, tgt_lang=target_language, visualize=False
    )
    enc = translator._tokenizer(
        preprocessed, padding="longest", truncation=True, max_length=256, return_tensors="pt"
    )
    with torch.no_grad():
        output_ids = translator._model.generate(
            **enc,
            num_beams=1,
            num_return_sequences=1,
            max_length=256,
            early_stopping=True,
            min_length=1,
            length_penalty=1.0,
            do_sample=False,
            repetition_penalty=1.2,
        )
    decoded = translator._tokenizer.batch_decode(
        output_ids, skip_special_tokens=True, clean_up_tokenization_spaces=True
    )[0]
    return translator._ip.postprocess_batch([decoded], lang=target_language)[0]


def apply_repetition_penalty(logits, generated_ids, penalty):
    if penalty == 1.0:
        return logits
    for token_id in set(generated_ids):
        if logits[token_id] < 0:
            logits[token_id] *= penalty
        else:
            logits[token_id] /= penalty
    return logits


def onnx_greedy_generate(sess_enc, sess_dec, sess_dec_past, text, source_language, target_language, max_length=256, repetition_penalty=1.2):
    ip = translator._ip
    tokenizer = translator._tokenizer
    model = translator._model.cpu()
    model.eval()

    preprocessed = ip.preprocess_batch([text], src_lang=source_language, tgt_lang=target_language, visualize=False)
    inputs = tokenizer(preprocessed, padding="longest", truncation=True, max_length=256, return_tensors="pt")
    input_ids = inputs["input_ids"].numpy()
    attention_mask = inputs["attention_mask"].numpy()

    encoder_hidden = sess_enc.run(None, {
        "input_ids": input_ids,
        "attention_mask": attention_mask,
    })[0]

    bos_token_id = model.config.decoder_start_token_id
    eos_token_id = model.config.eos_token_id

    with torch.no_grad():
        torch_decoder_out = model.get_decoder()(
            input_ids=torch.tensor([[bos_token_id]]),
            attention_mask=torch.tensor([[1]]),
            encoder_hidden_states=torch.from_numpy(encoder_hidden),
            encoder_attention_mask=torch.from_numpy(attention_mask),
            use_cache=True,
        )
        past_flat = [tensor.detach().cpu().numpy() for layer in torch_decoder_out.past_key_values for tensor in layer]
        first_logits = model.lm_head(torch_decoder_out.last_hidden_state).cpu().numpy()

    generated_ids = [bos_token_id]
    first_logits = apply_repetition_penalty(first_logits[0, -1].copy(), generated_ids, repetition_penalty)
    next_token_id = int(np.argmax(first_logits))
    generated_ids.append(next_token_id)

    if next_token_id == eos_token_id:
        decoded = tokenizer.batch_decode([generated_ids], skip_special_tokens=True, clean_up_tokenization_spaces=True)[0]
        result = ip.postprocess_batch([decoded], lang=target_language)[0]
        return result

    past_inputs = {f"past_{i}": past_flat[i] for i in range(len(past_flat))}
    decoder_attention_mask = np.array([1, 1], dtype=np.int64)

    for _ in range(max_length - 1):
        onnx_inputs = {
            "input_ids": np.array([[generated_ids[-1]]], dtype=np.int64),
            "attention_mask": decoder_attention_mask.reshape(1, -1),
            "encoder_attention_mask": attention_mask,
            **past_inputs,
        }
        onnx_outputs = sess_dec_past.run(None, onnx_inputs)
        logits = onnx_outputs[0][0, -1].copy()
        logits = apply_repetition_penalty(logits, generated_ids, repetition_penalty)
        next_token_id = int(np.argmax(logits))
        generated_ids.append(next_token_id)

        if next_token_id == eos_token_id:
            break

        present_flat = [np.array(o) for o in onnx_outputs[1:]]
        past_inputs = {f"past_{i}": present_flat[i] for i in range(len(present_flat))}
        decoder_attention_mask = np.append(decoder_attention_mask, 1)

    decoded = tokenizer.batch_decode([generated_ids], skip_special_tokens=True, clean_up_tokenization_spaces=True)[0]
    result = ip.postprocess_batch([decoded], lang=target_language)[0]
    return result


def main():
    print("Loading FP32 ONNX models...")
    fp32_models = load_models(FP32_DIR)
    print("Loading INT8 ONNX models...")
    int8_models = load_models(INT8_DIR)
    print("Models loaded.\n")

    test_cases = [
        ("नमस्ते", "hin_Deva", "sat_Olck"),
        ("आप कैसे हैं?", "hin_Deva", "sat_Olck"),
        ("मेरा नाम सचिन है।", "hin_Deva", "sat_Olck"),
        ("बच्चों को दस वस्तुएँ दें और उन्हें एक-एक करके गिनने के लिए कहें।", "hin_Deva", "sat_Olck"),
        ("ᱡᱚᱦᱟᱨ", "sat_Olck", "hin_Deva"),
        ("ᱵᱟᱨ ᱟᱨ ᱵᱟᱨ ᱛᱤᱱᱟᱹᱜ ᱦᱩᱭᱩᱜᱼᱟ, ᱜᱤᱫᱽᱨᱟᱹ ᱠᱚ ᱠᱩᱞᱤ ᱠᱚᱢ᱾", "sat_Olck", "hin_Deva"),
    ]

    print(f"{'Input':<40} {'PyTorch':<30} {'FP32 ONNX':<30} {'INT8 ONNX':<30} {'FP32==INT8'}")
    print("-" * 170)
    for text, src, tgt in test_cases:
        pytorch_out = pytorch_greedy_translate(text, src, tgt)

        t0 = time.perf_counter()
        fp32_out = onnx_greedy_generate(*fp32_models, text, src, tgt)
        fp32_ms = (time.perf_counter() - t0) * 1000

        t0 = time.perf_counter()
        int8_out = onnx_greedy_generate(*int8_models, text, src, tgt)
        int8_ms = (time.perf_counter() - t0) * 1000

        match = fp32_out.strip() == int8_out.strip()
        print(f"{text[:40]:<40} {pytorch_out[:30]:<30} {fp32_out[:30]:<30} {int8_out[:30]:<30} {'YES' if match else 'NO'}")
        print(f"  PyTorch: {pytorch_out}")
        print(f"  FP32:    {fp32_out}")
        print(f"  INT8:    {int8_out}")
        print(f"  Time: PyTorch ref | FP32: {fp32_ms:.1f} ms | INT8: {int8_ms:.1f} ms")
        if not match:
            print(f"  DIFF: FP32={fp32_out}")
            print(f"        INT8={int8_out}")
        print()


if __name__ == "__main__":
    main()
