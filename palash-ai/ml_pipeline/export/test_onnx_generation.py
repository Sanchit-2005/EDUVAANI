"""FP32 ONNX IndicTrans2 generation test.

Compares PyTorch reference translation against ONNX Runtime inference
using:
  encoder_model.onnx
  decoder_model.onnx  (first step, logits only)
  decoder_with_past_model.onnx  (subsequent cached steps)

Strategy:
  1. Preprocess/tokenize exactly like translator.py.
  2. Run encoder ONNX.
  3. Run PyTorch decoder once to obtain initial past_key_values.
  4. Run decoder_with_past ONNX for all generation steps.
  5. Greedy decode until EOS or max_length.
  6. Postprocess with IndicProcessor.
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

EXPORT_DIR = ROOT / "export" / "models" / "indictrans2" / "fp32"
ENC_PATH = EXPORT_DIR / "encoder_model.onnx"
DEC_PATH = EXPORT_DIR / "decoder_model.onnx"
DEC_PAST_PATH = EXPORT_DIR / "decoder_with_past_model.onnx"


def load_onnx_models():
    sess_enc = ort.InferenceSession(str(ENC_PATH), providers=["CPUExecutionProvider"])
    sess_dec = ort.InferenceSession(str(DEC_PATH), providers=["CPUExecutionProvider"])
    sess_dec_past = ort.InferenceSession(str(DEC_PAST_PATH), providers=["CPUExecutionProvider"])
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
    print(f"  Step 0: BOS({bos_token_id}) -> {next_token_id} '{tokenizer.decode([next_token_id])}'")

    if next_token_id == eos_token_id:
        decoded = tokenizer.batch_decode([generated_ids], skip_special_tokens=True, clean_up_tokenization_spaces=True)[0]
        result = ip.postprocess_batch([decoded], lang=target_language)[0]
        return result

    past_inputs = {f"past_{i}": past_flat[i] for i in range(len(past_flat))}
    decoder_attention_mask = np.array([1, 1], dtype=np.int64)

    for step in range(1, max_length):
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
        
        print(f"  Step {step}: {generated_ids[-1]} -> {next_token_id} '{tokenizer.decode([next_token_id])}'")
        generated_ids.append(next_token_id)

        if next_token_id == eos_token_id:
            print(f"  EOS at step {step}")
            break

        present_flat = [np.array(o) for o in onnx_outputs[1:]]
        past_inputs = {f"past_{i}": present_flat[i] for i in range(len(present_flat))}
        decoder_attention_mask = np.append(decoder_attention_mask, 1)

    decoded = tokenizer.batch_decode([generated_ids], skip_special_tokens=True, clean_up_tokenization_spaces=True)[0]
    result = ip.postprocess_batch([decoded], lang=target_language)[0]
    return result


def main():
    print("Loading ONNX models...")
    sess_enc, sess_dec, sess_dec_past = load_onnx_models()
    print("Models loaded.\n")

    test_cases = [
        ("नमस्ते", "hin_Deva", "sat_Olck"),
        ("आप कैसे हैं?", "hin_Deva", "sat_Olck"),
        ("मेरा नाम सचिन है।", "hin_Deva", "sat_Olck"),
        ("बच्चों को दस वस्तुएँ दें और उन्हें एक-एक करके गिनने के लिए कहें।", "hin_Deva", "sat_Olck"),
        ("ᱡᱚᱦᱟᱨ", "sat_Olck", "hin_Deva"),
        ("ᱵᱟᱨ ᱟᱨ ᱵᱟᱨ ᱛᱤᱱᱟᱹᱜ ᱦᱩᱭᱩᱜᱼᱟ, ᱜᱤᱫᱽᱨᱟᱹ ᱠᱚ ᱠᱩᱞᱤ ᱠᱚᱢ᱾", "sat_Olck", "hin_Deva"),
    ]

    print(f"{'Input':<40} {'PyTorch':<30} {'ONNX':<30} {'Match'}")
    print("-" * 130)
    for text, src, tgt in test_cases:
        t0 = time.perf_counter()
        pytorch_out = pytorch_greedy_translate(text, src, tgt)
        pytorch_ms = (time.perf_counter() - t0) * 1000

        t0 = time.perf_counter()
        print(f"\nInput: {text}")
        onnx_out = onnx_greedy_generate(sess_enc, sess_dec, sess_dec_past, text, src, tgt)
        onnx_ms = (time.perf_counter() - t0) * 1000

        match = pytorch_out.strip() == onnx_out.strip()
        print(f"  PyTorch: {pytorch_out}")
        print(f"  ONNX:    {onnx_out}")
        print(f"  Match: {'YES' if match else 'NO'} | PyTorch: {pytorch_ms:.1f} ms | ONNX: {onnx_ms:.1f} ms")
        print()


if __name__ == "__main__":
    main()
