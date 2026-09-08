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

src_ids = np.array([[8, 29925, 2227, 33, 6423, 2457, 6327, 2482, 26, 590, 34, 2272, 30120, 1826, 43557, 75, 12, 58, 38887, 77634, 2]], dtype=np.int64)
src_mask = np.ones((1, src_ids.shape[1]), dtype=np.int64)

enc_out = enc_sess.run(None, {'input_ids': src_ids, 'attention_mask': src_mask})
encoder_hidden = enc_out[0]
src_len = encoder_hidden.shape[1]

EOS_ID = 2
TGT_LANG_ID = 29925

dec_ids = np.array([[EOS_ID, TGT_LANG_ID]], dtype=np.int64)
dec_mask = np.ones((1, 2), dtype=np.int64)

kv_out = dec_kv_sess.run(None, {
    'input_ids': dec_ids,
    'attention_mask': dec_mask,
    'encoder_hidden_states': encoder_hidden,
    'encoder_attention_mask': src_mask
})
first_logits = kv_out[0][0, -1, :].copy()

print(f"Step 1: token {int(np.argmax(first_logits))} = {repr(tgt_id2tok.get(int(np.argmax(first_logits)), '?'))}")

# Build past
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

# First decoder_with_past call
next_token = int(np.argmax(first_logits))
input_ids = np.array([[next_token]], dtype=np.int64)
# Self-attn past_len=0 (decoder_model has no self-attn past outputs), cur_len=1
# NOTE: cross-attn past has past_len=src_len=21 but attention_mask is for self-attn total_len
attn_mask_len = 1  # self_past_len=0 + cur=1
attn_mask = np.ones((1, attn_mask_len), dtype=np.int64)

feed = {'input_ids': input_ids, 'attention_mask': attn_mask, 'encoder_attention_mask': src_mask}
feed.update(past)

print(f"\nRunning dwp step 1...")
print(f"input_ids: {input_ids}")
print(f"attention_mask shape: {attn_mask.shape}")
print(f"past_0 shape: {past['past_0'].shape}")
print(f"past_1 shape: {past['past_1'].shape}")
print(f"past_2 shape: {past['past_2'].shape}")
print(f"past_3 shape: {past['past_3'].shape}")

try:
    dwp_out = dwp_sess.run(None, feed)
    print("SUCCESS!")
    print(f"logits shape: {dwp_out[0].shape}")
    print(f"present_0 shape: {dwp_out[1].shape}")
    print(f"present_1 shape: {dwp_out[2].shape}")
    print(f"present_2 shape: {dwp_out[3].shape}")
    print(f"present_3 shape: {dwp_out[4].shape}")
except Exception as e:
    print(f"ERROR: {e}")
