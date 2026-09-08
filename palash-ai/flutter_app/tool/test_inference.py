import onnxruntime as ort
import numpy as np
import json
import sys
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
sys.stderr = open(os.devnull, 'w') if False else sys.stderr
import os
log = open('EDUVAANI/palash-ai/flutter_app/tool/inference_log.txt', 'w', encoding='utf-8')

enc_sess = ort.InferenceSession(r'EDUVAANI/palash-ai/flutter_app/android/app/src/main/assets/models/indictrans2/int8/encoder_model.onnx')
dec_kv_sess = ort.InferenceSession(r'EDUVAANI/palash-ai/flutter_app/android/app/src/main/assets/models/indictrans2/int8/decoder_with_kv_model.onnx')
dwp_sess = ort.InferenceSession(r'EDUVAANI/palash-ai/flutter_app/android/app/src/main/assets/models/indictrans2/int8/decoder_with_past_model.onnx')

with open(r'EDUVAANI/palash-ai/flutter_app/android/app/src/main/assets/models/indictrans2/int8/dict.TGT.json', encoding='utf-8') as f:
    tgt_vocab = json.load(f)
tgt_id2tok = {v: k for k, v in tgt_vocab.items()}

# Test: 'बच्चों को दस वस्तुएँ दें और उन्हें एक-एक करके गिनने के लिए कहें।'
# hin_Deva=8, sat_Olck=29925; SPM tokenized + EOS=2
src_ids = np.array([[8, 29925, 2227, 33, 6423, 2457, 6327, 2482, 26, 590, 34, 2272, 30120, 1826, 43557, 75, 12, 58, 38887, 77634, 2]], dtype=np.int64)
src_mask = np.ones((1, src_ids.shape[1]), dtype=np.int64)

print('src_ids shape:', src_ids.shape)

# 1. Encode
enc_out = enc_sess.run(None, {'input_ids': src_ids, 'attention_mask': src_mask})
encoder_hidden = enc_out[0]
src_len = encoder_hidden.shape[1]
print('encoder_hidden:', encoder_hidden.shape)

# 2. Get cross-attn KV + first logits from decoder_with_kv
EOS_ID = 2
TGT_LANG_ID = 29925  # sat_Olck in SRC vocab

dec_ids = np.array([[EOS_ID, TGT_LANG_ID]], dtype=np.int64)
dec_mask = np.ones((1, 2), dtype=np.int64)

kv_out = dec_kv_sess.run(None, {
    'input_ids': dec_ids,
    'attention_mask': dec_mask,
    'encoder_hidden_states': encoder_hidden,
    'encoder_attention_mask': src_mask
})
logits = kv_out[0]  # [1, 2, vocab_size] - take last position
first_logits = logits[0, -1, :].copy()  # [vocab_size]
print('first_logits shape:', first_logits.shape)
print('cross_k_0 raw shape:', kv_out[1].shape)

# Build initial past dict
# Layer i: past_{4i} = self_k, past_{4i+1} = self_v, past_{4i+2} = cross_k, past_{4i+3} = cross_v
past = {}
kv_idx = 1
for layer in range(18):
    self_k = np.zeros((1, 8, 0, 64), dtype=np.float32)
    self_v = np.zeros((1, 8, 0, 64), dtype=np.float32)
    cross_k = kv_out[kv_idx]
    cross_v = kv_out[kv_idx + 1]
    kv_idx += 2

    # Ensure shape is [1, 8, src_len, 64]
    if cross_k.ndim == 3:
        cross_k = cross_k[np.newaxis]
    if cross_v.ndim == 3:
        cross_v = cross_v[np.newaxis]

    past[f'past_{layer*4}'] = self_k
    past[f'past_{layer*4+1}'] = self_v
    past[f'past_{layer*4+2}'] = cross_k
    past[f'past_{layer*4+3}'] = cross_v

print('self-attn past_0:', past['past_0'].shape)
print('cross-attn past_2:', past['past_2'].shape)

# First content token
next_token = int(np.argmax(first_logits))
tok_str = tgt_id2tok.get(next_token, '?')
print(f'Step 1: token {next_token} = {repr(tok_str)}')

if next_token == EOS_ID:
    print('EOS at step 1 - model gives nothing for this input')
else:
    attn_mask_len = 3  # past_len=2 (EOS+tgt_lang) + cur=1
    generated = [TGT_LANG_ID, next_token]

    for step in range(50):
        input_ids = np.array([[next_token]], dtype=np.int64)
        attn_mask = np.ones((1, attn_mask_len), dtype=np.int64)

        feed = {
            'input_ids': input_ids,
            'attention_mask': attn_mask,
            'encoder_attention_mask': src_mask
        }
        feed.update(past)

        dwp_out = dwp_sess.run(None, feed)

        step_logits = dwp_out[0][0, 0, :].copy()
        for tok in set(generated):
            if 0 <= tok < len(step_logits):
                v = step_logits[tok]
                step_logits[tok] = v / 1.2 if v > 0 else v * 1.2

        next_token = int(np.argmax(step_logits))
        generated.append(next_token)
        tok_str = tgt_id2tok.get(next_token, '?')
        print(f'Step {step+2}: token {next_token} = {repr(tok_str)}')

        # Extract presents as new past
        new_past = {}
        for j in range(1, len(dwp_out)):
            tensor = dwp_out[j]
            if step == 0:
                print(f'  present_{j-1}: {tensor.shape}')
            new_past[f'past_{j-1}'] = tensor
        past = new_past
        attn_mask_len += 1

        if next_token == EOS_ID:
            print('EOS reached')
            break

    print()
    print('Generated token IDs:', generated)
    tokens = [tgt_id2tok.get(t, f'[{t}]') for t in generated]
    print('Generated tokens:', tokens)
