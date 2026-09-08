"""
Replicates the exact Kotlin inference pipeline against the real ONNX models.
Mirrors: runFirstDecoderStep([EOS, tgt_lang_id]) + greedy generation loop.
"""
import json, numpy as np, onnxruntime as ort, sys, struct

sys.stdout.reconfigure(encoding="utf-8")

BASE = "palash-ai/flutter_app/android/app/src/main/assets/models/indictrans2/int8"

with open(f"{BASE}/dict.SRC.json", encoding="utf-8") as f:
    src_vocab = json.load(f)
with open(f"{BASE}/dict.TGT.json", encoding="utf-8") as f:
    tgt_vocab = json.load(f)

src_id2tok = {v: k for k, v in src_vocab.items()}
tgt_id2tok = {v: k for k, v in tgt_vocab.items()}

# Special tokens — match SentencePieceTokenizer.loadVocab()
eos_id  = src_vocab["</s>"]   # 2  — mBART decoder_start_token_id
bos_id  = src_vocab["<s>"]    # 0
unk_id  = src_vocab["<unk>"]  # 3
tgt_eos = tgt_vocab["</s>"]   # 2

print(f"eos_id={eos_id}  bos_id={bos_id}  unk_id={unk_id}  tgt_eos={tgt_eos}")

# ── SPM loader ────────────────────────────────────────────────────────────────
def load_spm(path):
    data = open(path, "rb").read()
    i, n = 0, len(data)
    p2id, id2p, p2sc = {}, {}, {}
    def rv():
        nonlocal i
        r, s = 0, 0
        while i < n:
            b = data[i]; i += 1; r |= (b & 0x7F) << s
            if not (b & 0x80): break
            s += 7
        return r
    def rb():
        nonlocal i; l = rv(); v = data[i:i+l]; i += l; return v
    while i < n:
        tag = rv(); f, w = tag >> 3, tag & 7
        if f == 1 and w == 2:
            chunk = rb(); j, m, ps, sc = 0, len(chunk), "", 0.0
            def iv():
                nonlocal j
                r, s = 0, 0
                while j < m:
                    b = chunk[j]; j += 1; r |= (b & 0x7F) << s
                    if not (b & 0x80): break
                    s += 7
                return r
            while j < m:
                t2 = iv(); f2, w2 = t2 >> 3, t2 & 7
                if   f2 == 1 and w2 == 2: sl = iv(); ps = chunk[j:j+sl].decode("utf-8"); j += sl
                elif f2 == 2 and w2 == 5: sc = struct.unpack_from("<f", chunk, j)[0]; j += 4
                elif w2 == 0: iv()
                elif w2 == 2: sl = iv(); j += sl
                elif w2 == 5: j += 4
                elif w2 == 1: j += 8
            pid = len(p2id); p2id[ps] = pid; id2p[pid] = ps; p2sc[pid] = sc
        elif w == 0: rv()
        elif w == 2: rb()
        elif w == 5: i += 4
        elif w == 1: i += 8
    return p2id, id2p, p2sc

spm_src_p2id, spm_src_id2p, spm_src_p2sc = load_spm(f"{BASE}/model.SRC")
print(f"SRC SPM loaded: {len(spm_src_p2id)} pieces")

def viterbi(text, p2id, id2p, p2sc):
    s = text.replace(" ", "\u2581")
    n = len(s)
    if not n: return []
    dp = [float("-inf")] * (n+1); dp[0] = 0.0; par = [(-1,-1)] * (n+1)
    for i in range(n):
        if dp[i] == float("-inf"): continue
        for l in range(1, n-i+1):
            p = s[i:i+l]
            if p in p2id:
                pid = p2id[p]; ns = dp[i] + p2sc.get(pid, -100.)
                if ns > dp[i+l]: dp[i+l] = ns; par[i+l] = (i, pid)
    if dp[n] == float("-inf"): return [unk_id] * n
    res, pos = [], n
    while pos > 0: prev, pid = par[pos]; res.append(id2p[pid]); pos = prev
    return list(reversed(res))

def tokenize(text, src_lang, tgt_lang):
    """Replicates IndicProcessor.preprocessBatch + SentencePieceTokenizer.encode()"""
    pieces = viterbi(text, spm_src_p2id, spm_src_id2p, spm_src_p2sc)
    forced_bos_id = src_vocab.get(tgt_lang, unk_id)   # tgtLangId
    ids = [src_vocab.get(src_lang, unk_id), forced_bos_id]
    for p in pieces:
        ids.append(src_vocab.get(p, unk_id))
    ids.append(eos_id)
    return ids, forced_bos_id, pieces

# ── ONNX sessions ─────────────────────────────────────────────────────────────
# decoder_with_past_model.onnx is intentionally NOT used: it cannot be
# bootstrapped with this asset set (decoder_model.onnx exports no present_*
# KV tensors, so the cross-attention past for [EOS, tgt_lang_id] can never
# be populated). Every step recomputes self-/cross-attention from scratch
# over the full growing sequence via decoder_model.onnx, mirroring
# OnDeviceTranslationEngine.runDecoderStep().
enc_sess = ort.InferenceSession(f"{BASE}/encoder_model.onnx", providers=["CPUExecutionProvider"])
dec_sess = ort.InferenceSession(f"{BASE}/decoder_model.onnx", providers=["CPUExecutionProvider"])

def run_encoder(ids):
    inp = np.array([ids], dtype=np.int64)
    return enc_sess.run(None, {"input_ids": inp, "attention_mask": np.ones_like(inp)})[0]

def run_decoder_step(seq, enc_hidden):
    """Kotlin runDecoderStep: full growing seq, read logits at last position."""
    src_len = enc_hidden.shape[1]
    di  = np.array([seq], dtype=np.int64)
    dam = np.ones_like(di)
    eam = np.ones((1, src_len), dtype=np.int64)
    out = dec_sess.run(None, {
        "input_ids":             di,
        "attention_mask":        dam,
        "encoder_hidden_states": enc_hidden,
        "encoder_attention_mask":eam,
    })
    return out[0][0, -1, :]   # last position

def decode_ids(ids, id2tok):
    """Replicates SentencePieceTokenizer.decodePieces via TGT vocab."""
    parts = []
    for i in ids:
        tok = id2tok.get(i, "?")
        if tok in ("</s>", "<s>", "<pad>"): continue
        if tok.startswith("\u2581"):
            if parts: parts.append(" ")
            parts.append(tok[1:])
        elif tok == "<unk>":
            parts.append("?")
        else:
            parts.append(tok)
    return "".join(parts).strip()

def translate(text, src_lang, tgt_lang, max_steps=60):
    print(f"\n{'='*70}")
    print(f"INPUT : {repr(text)}")
    print(f"DIR   : {src_lang} -> {tgt_lang}")

    enc_ids, forced_bos_id, pieces = tokenize(text, src_lang, tgt_lang)
    print(f"SPM pieces : {pieces}")
    print(f"enc input_ids ({len(enc_ids)} tokens): {enc_ids}")
    print(f"tgtLangId (forced_bos): {forced_bos_id} = {repr(src_vocab.get(tgt_lang))}")

    enc_hidden = run_encoder(enc_ids)
    print(f"Encoder output: {enc_hidden.shape}  norm[0,0]={float(np.linalg.norm(enc_hidden[0,0,:])):.3f}")

    min_new_tokens = 2   # EOS cannot be selected for the first 2 real tokens

    # ── step 1: seq=[EOS, forced_bos] ─────────────────────────────────────────
    seq = [eos_id, forced_bos_id]
    logits = run_decoder_step(seq, enc_hidden)
    logits[tgt_eos] = -np.inf   # suppress EOS on step 1
    next_token = int(np.argmax(logits))
    top5 = np.argsort(logits)[::-1][:5]
    print(f"\n[step 1] seed=[EOS={eos_id}, tgt_lang={forced_bos_id}] (EOS suppressed)")
    print(f"  argmax -> {next_token} {repr(tgt_id2tok.get(next_token,'?'))}")
    print(f"  top5: {[(int(x), repr(tgt_id2tok.get(int(x),'?'))) for x in top5]}")

    generated = [forced_bos_id, next_token]
    seq.append(next_token)

    # ── generation loop: always recompute over the full growing sequence ─────
    for step in range(1, max_steps):
        logits = run_decoder_step(seq, enc_hidden)

        # repetition penalty (Kotlin uses 1.2)
        for tid in set(generated):
            if 0 <= tid < len(logits):
                logits[tid] = logits[tid] / 1.2 if logits[tid] > 0 else logits[tid] * 1.2

        if step < min_new_tokens:
            logits[tgt_eos] = -np.inf

        next_token = int(np.argmax(logits))
        top3 = np.argsort(logits)[::-1][:3]
        is_eos = next_token == tgt_eos
        suppressed = " (EOS suppressed)" if step < min_new_tokens else ""
        print(f"[step {step+1}] seq_len={len(seq)} -> {next_token} "
              f"{repr(tgt_id2tok.get(next_token,'?'))}  is_eos={is_eos}{suppressed}  "
              f"top3={[(int(x), repr(tgt_id2tok.get(int(x),'?'))) for x in top3]}")

        generated.append(next_token)

        if is_eos:
            print(f"  -> EOS reached at step {step+1}")
            break

        seq.append(next_token)

    result = decode_ids(generated, tgt_id2tok)
    print(f"\nGenerated IDs  : {generated}")
    print(f"OUTPUT         : {repr(result)}")
    return result

# ── Test cases ────────────────────────────────────────────────────────────────
translate("नमस्ते", "hin_Deva", "sat_Olck")
translate("मैं भारतीय हूँ", "hin_Deva", "sat_Olck")
translate("चलो", "hin_Deva", "sat_Olck")
translate("बच्चों को दस वस्तुएँ दें और उन्हें एक-एक करके गिनने के लिए कहें।", "hin_Deva", "sat_Olck")
translate("ᱜᱤᱫᱽᱨᱟᱹ ᱠᱚ ᱜᱮᱞ ᱜᱚᱴᱟᱝ ᱡᱤᱱᱤᱥ ᱮᱢᱟ ᱠᱚᱢ ᱟᱨ ᱢᱤᱫ-ᱢᱤᱫ ᱛᱮ ᱞᱮᱠᱷᱟ ᱪᱚ ᱠᱚᱢ᱾", "sat_Olck", "hin_Deva")
