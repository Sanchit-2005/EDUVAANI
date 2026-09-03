"""
PALASH-AI — Translation Service Test Suite
===========================================
Tests the Python FastAPI service directly via HTTP.

Requirements
------------
The service must be running before you execute this script:

    # In a separate terminal (from ml_pipeline/translation_service/):
    python app.py
    # or: uvicorn translation_service.app:app --port 8000

Usage
-----
    # From ml_pipeline/translation_service/:
    python test_translation.py

    # Or with pytest (from any directory):
    pytest ml_pipeline/translation_service/test_translation.py -v

What is tested
--------------
    Case 1  Hindi → Santali  "नमस्ते"          → success, non-empty output
    Case 2  Hindi → Santali  "आप कैसे हैं?"    → success, non-empty output
    Case 3  Hindi → Santali  multi-sentence     → success, non-empty output
    Case 4  Santali → Hindi  Ol Chiki phrase    → success, non-empty output
    Case 5  Empty text                          → 422 validation error
    Case 6  Unsupported source language         → 422 validation error
    Case 7  Unsupported target language         → 422 validation error
    Case 8  Same-language pair (hin → hin)      → 422 validation error
    Case 9  GET /health                         → status ok, model_loaded true
    Case 10 Missing 'text' field                → 422 validation error
"""

import sys
import json
import urllib.request
import urllib.error

# ── Configuration ─────────────────────────────────────────────────────────────

BASE_URL = "http://127.0.0.1:8000"
TRANSLATE_URL = f"{BASE_URL}/translate"
HEALTH_URL = f"{BASE_URL}/health"

# ── Helpers ───────────────────────────────────────────────────────────────────

def _post(payload: dict) -> tuple[int, dict]:
    """Send a POST request and return (status_code, body_dict)."""
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        TRANSLATE_URL,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            return resp.status, json.loads(resp.read())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read())


def _get(url: str) -> tuple[int, dict]:
    req = urllib.request.Request(url, method="GET")
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return resp.status, json.loads(resp.read())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read())


# ── Test cases ────────────────────────────────────────────────────────────────

PASS = "✓ PASS"
FAIL = "✗ FAIL"
results: list[tuple[str, str, str]] = []   # (label, status, detail)


def run(label: str, check_fn):
    """Run a single test case and record the result."""
    try:
        check_fn()
        results.append((label, PASS, ""))
        print(f"  {PASS}  {label}")
    except AssertionError as e:
        results.append((label, FAIL, str(e)))
        print(f"  {FAIL}  {label}")
        print(f"          → {e}")
    except Exception as e:
        results.append((label, FAIL, str(e)))
        print(f"  {FAIL}  {label}")
        print(f"          → Unexpected error: {e}")


# ── Case 9: /health (run first so we know the server is up) ───────────────────

def test_health():
    status, body = _get(HEALTH_URL)
    assert status == 200, f"Expected 200, got {status}"
    assert body.get("status") == "ok", f"status != ok: {body}"
    assert "model" in body, f"'model' key missing: {body}"
    model_loaded = body.get("model_loaded")
    assert model_loaded is True, (
        f"model_loaded is {model_loaded!r}. "
        "The model may still be initialising — wait a moment and retry."
    )


# ── Case 1: Hindi → Santali  "नमस्ते" ─────────────────────────────────────────

def test_hindi_to_santali_hello():
    status, body = _post({
        "text": "नमस्ते",
        "source_language": "hin_Deva",
        "target_language": "sat_Olck",
    })
    assert status == 200, f"Expected 200, got {status}. Body: {body}"
    assert body.get("success") is True, f"success != true: {body}"
    translation = body.get("translation", "")
    assert translation and translation.strip(), f"translation is empty: {body}"
    assert body.get("source_language") == "hin_Deva"
    assert body.get("target_language") == "sat_Olck"
    print(f"          → '{body['input']}' → '{translation}'")


# ── Case 2: Hindi → Santali  "आप कैसे हैं?" ──────────────────────────────────

def test_hindi_to_santali_question():
    status, body = _post({
        "text": "आप कैसे हैं?",
        "source_language": "hin_Deva",
        "target_language": "sat_Olck",
    })
    assert status == 200, f"Expected 200, got {status}. Body: {body}"
    assert body.get("success") is True
    translation = body.get("translation", "")
    assert translation and translation.strip(), f"translation is empty: {body}"
    print(f"          → '{body['input']}' → '{translation}'")


# ── Case 3: Hindi → Santali  multi-sentence ───────────────────────────────────

def test_hindi_to_santali_multi():
    text = "मेरा नाम राहुल है। मैं एक शिक्षक हूँ।"
    status, body = _post({
        "text": text,
        "source_language": "hin_Deva",
        "target_language": "sat_Olck",
    })
    assert status == 200, f"Expected 200, got {status}. Body: {body}"
    assert body.get("success") is True
    translation = body.get("translation", "")
    assert translation and translation.strip(), f"translation is empty: {body}"
    print(f"          → '{body['input']}' → '{translation}'")


# ── Case 4: Santali → Hindi ───────────────────────────────────────────────────

def test_santali_to_hindi():
    # "ᱡᱚᱦᱟᱨ" is a common Santali greeting (johar)
    status, body = _post({
        "text": "ᱡᱚᱦᱟᱨ",
        "source_language": "sat_Olck",
        "target_language": "hin_Deva",
    })
    assert status == 200, f"Expected 200, got {status}. Body: {body}"
    assert body.get("success") is True
    translation = body.get("translation", "")
    assert translation and translation.strip(), f"translation is empty: {body}"
    print(f"          → '{body['input']}' → '{translation}'")


# ── Case 5: Empty text ────────────────────────────────────────────────────────

def test_empty_text():
    status, body = _post({
        "text": "   ",
        "source_language": "hin_Deva",
        "target_language": "sat_Olck",
    })
    assert status == 422, f"Expected 422, got {status}. Body: {body}"


# ── Case 6: Unsupported source language ───────────────────────────────────────

def test_unsupported_source():
    status, body = _post({
        "text": "hello",
        "source_language": "eng_Latn",
        "target_language": "sat_Olck",
    })
    assert status == 422, f"Expected 422, got {status}. Body: {body}"


# ── Case 7: Unsupported target language ───────────────────────────────────────

def test_unsupported_target():
    status, body = _post({
        "text": "नमस्ते",
        "source_language": "hin_Deva",
        "target_language": "tel_Telu",
    })
    assert status == 422, f"Expected 422, got {status}. Body: {body}"


# ── Case 8: Same-language pair (hin_Deva → hin_Deva) ─────────────────────────

def test_same_language_pair():
    status, body = _post({
        "text": "नमस्ते",
        "source_language": "hin_Deva",
        "target_language": "hin_Deva",
    })
    assert status == 422, f"Expected 422, got {status}. Body: {body}"


# ── Case 10: Missing 'text' field ─────────────────────────────────────────────

def test_missing_text_field():
    status, body = _post({
        "source_language": "hin_Deva",
        "target_language": "sat_Olck",
    })
    assert status == 422, f"Expected 422, got {status}. Body: {body}"


# ── Runner ────────────────────────────────────────────────────────────────────

def main():
    print("\nPALASH-AI Translation Service — Test Suite")
    print("=" * 52)
    print(f"Target: {BASE_URL}\n")

    # Health check first — abort early if service is not up
    print("Case 9  GET /health")
    run("GET /health → ok and model_loaded=true", test_health)

    if results and results[-1][1] == FAIL:
        print("\n⚠  Service is not ready. Start the Python service and retry.")
        print("   cd ml_pipeline/translation_service")
        print("   python app.py\n")
        sys.exit(1)

    print("\nCase 1  Hindi → Santali  नमस्ते")
    run("hin_Deva → sat_Olck: नमस्ते", test_hindi_to_santali_hello)

    print("\nCase 2  Hindi → Santali  आप कैसे हैं?")
    run("hin_Deva → sat_Olck: question", test_hindi_to_santali_question)

    print("\nCase 3  Hindi → Santali  multi-sentence")
    run("hin_Deva → sat_Olck: multi-sentence", test_hindi_to_santali_multi)

    print("\nCase 4  Santali → Hindi  ᱡᱚᱦᱟᱨ")
    run("sat_Olck → hin_Deva: johar greeting", test_santali_to_hindi)

    print("\nCase 5  Empty text → 422")
    run("empty/whitespace text rejected", test_empty_text)

    print("\nCase 6  Unsupported source language → 422")
    run("eng_Latn source rejected", test_unsupported_source)

    print("\nCase 7  Unsupported target language → 422")
    run("tel_Telu target rejected", test_unsupported_target)

    print("\nCase 8  Same-language pair → 422")
    run("hin_Deva → hin_Deva rejected", test_same_language_pair)

    print("\nCase 10 Missing 'text' field → 422")
    run("missing text field rejected", test_missing_text_field)

    # ── Summary ───────────────────────────────────────────────────────────────
    passed = sum(1 for _, s, _ in results if s == PASS)
    failed = sum(1 for _, s, _ in results if s == FAIL)

    print("\n" + "=" * 52)
    print(f"Results: {passed} passed, {failed} failed\n")

    if failed:
        print("Failed cases:")
        for label, status, detail in results:
            if status == FAIL:
                print(f"  • {label}")
                if detail:
                    print(f"    {detail}")
        sys.exit(1)
    else:
        print("All tests passed. IndicTrans2 Hindi ↔ Santali is working correctly.\n")
        sys.exit(0)


if __name__ == "__main__":
    main()
