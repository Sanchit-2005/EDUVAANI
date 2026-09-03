import urllib.request, json, time

def tr(text, src, tgt):
    data = json.dumps({'text': text, 'source_language': src, 'target_language': tgt}).encode()
    req = urllib.request.Request(
        'http://127.0.0.1:8000/translate',
        data=data,
        headers={'Content-Type': 'application/json'},
        method='POST'
    )
    t0 = time.time()
    with urllib.request.urlopen(req, timeout=600) as resp:
        body = json.loads(resp.read())
    elapsed = time.time() - t0
    print(f'[{src}→{tgt}]  "{text}"  →  "{body["translation"]}"  ({elapsed:.1f}s)')

print("Testing Hindi → Santali...")
tr('नमस्ते', 'hin_Deva', 'sat_Olck')
tr('आप कैसे हैं?', 'hin_Deva', 'sat_Olck')
tr('बहुत अच्छा।', 'hin_Deva', 'sat_Olck')

print("\nTesting Santali → Hindi...")
tr('ᱡᱚᱦᱟᱨ', 'sat_Olck', 'hin_Deva')
tr('ᱟᱹᱰᱤ ᱵᱟᱹᱲᱤᱡᱽ᱾', 'sat_Olck', 'hin_Deva')
print("\nDone.")
