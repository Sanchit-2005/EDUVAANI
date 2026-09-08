import onnxruntime as ort
import numpy as np
import json
import sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

with open(r'EDUVAANI/palash-ai/flutter_app/android/app/src/main/assets/models/indictrans2/int8/dict.TGT.json', encoding='utf-8') as f:
    tgt_vocab = json.load(f)
tgt_id2tok = {v: k for k, v in tgt_vocab.items()}

enc_sess = ort.InferenceSession(r'EDUVAANI/palash-ai/flutter_app/android/app/src/main/assets/models/indictrans2/int8/encoder_model.onnx')
dec_kv_sess = ort.InferenceSession(r'EDUVAANI/palash-ai/flutter_app/android/app/src/main/assets/models/indictrans2/int8/decoder_with_kv_model.onnx')
dwp_sess = ort.InferenceSession(r'EDUVAANI/palash-ai/flutter_app/android/app/src/main/assets/models/indictrans2/int8/decoder_with_past_model.onnx')

# Test 1: long sentence
src_ids = np.array([[8, 29925, 2227, 33, 6423, 2457, 6327, 2482, 26, 590, 34, 2272, 30120, 1826, 43557, 75, 12, 58, 38887, 77634, 2]], dtype=np.int64)
src_mask = np.ones((1, src_ids.shape[1]), dtype=np.int64)
EOS_ID = 2
TGT_LANG_ID = 29925

def translate(src_ids, src_mask, max_steps=60):
    enc_out = enc_sess.run(None, {'input_ids': src_ids, 'attention_mask': src_mask})
    encoder_hidden = enc_out[0]

    dec_ids = np.array([[EOS_ID, TGT_LANG_ID]], dtype=np.int64)
    dec_mask = np.ones((1, 2), dtype=np.int64)
    kv_out = dec_kv_sess.run(None, {
        'input_ids': dec_ids,
        'attention_mask': dec_mask,
        'encoder_hidden_states': encoder_hidden,
        'encoder_attention_mask': src_mask
    })
    first_logits = kv_out[0][0, -1, :].copy()

    # Build past: self-attn starts empty, cross-attn comes from kv_out
    past = {}
    kv_idx = 1
    for layer in range(18):
        cross_k = kv_out[kv_idx]
        cross_v = kv_out[kv_idx + 1]
        kv_idx += 2
        if cross_k.ndim == 3:
            cross_k = cross_k[np.newaxis]
        if cross_v.ndim == 3:
            cross_v = cross_v[np.newaxis]
        past[f'past_{layer*4}']   = np.zeros((1, 8, 0, 64), dtype=np.float32)
        past[f'past_{layer*4+1}'] = np.zeros((1, 8, 0, 64), dtype=np.float32)
        past[f'past_{layer*4+2}'] = cross_k
        past[f'past_{layer*4+3}'] = cross_v

    next_token = int(np.argmax(first_logits))
    print(f'  Step 0 (seed): token {next_token} = {repr(tgt_id2tok.get(next_token, "?"))}')

    if next_token == EOS_ID:
        return [TGT_LANG_ID]

    generated = [TGT_LANG_ID, next_token]
    # attention_mask = self_past_len + cur_len; self_past_len starts at 0 after seed step
    self_past_len = 0

    for step in range(max_steps):
        input_ids = np.array([[next_token]], dtype=np.int64)
        # attention_mask covers self-attn: previous self-attn past + current token
        attn_mask = np.ones((1, self_past_len + 1), dtype=np.int64)
        feed = {'input_ids': input_ids, 'attention_mask': attn_mask, 'encoder_attention_mask': src_mask}
        feed.update(past)
        dwp_out = dwp_sess.run(None, feed)
        step_logits = dwp_out[0][0, 0, :].copy()

        for tok in set(generated):
            if 0 <= tok < len(step_logits):
                v = step_logits[tok]
                step_logits[tok] = v / 1.2 if v > 0 else v * 1.2

        next_token = int(np.argmax(step_logits))
        generated.append(next_token)
        print(f'  Step {step+1}: token {next_token} = {repr(tgt_id2tok.get(next_token, "?"))}')

        # Extract present tensors as new past
        new_past = {}
        for j in range(1, len(dwp_out)):
            new_past[f'past_{j-1}'] = dwp_out[j]
        past = new_past
        self_past_len += 1

        if next_token == EOS_ID:
            break

    return generated

print("=== Test: बच्चों को दस वस्तुएँ दें... (hin→sat) ===")
gen = translate(src_ids, src_mask)
print()
tokens = [tgt_id2tok.get(t, f'[{t}]') for t in gen]
print('Generated tokens:', tokens)
raw = ''.join(t.lstrip('▁') if not t.startswith('▁') else ' ' + t[1:] for t in tokens).strip()
print('Decoded:', raw)
