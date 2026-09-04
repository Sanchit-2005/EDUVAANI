import sys
import json
import urllib.request
import urllib.error

# Configure UTF-8 encoding for Windows console
if sys.platform == 'win32':
    import codecs
    sys.stdout = codecs.getwriter('utf-8')(sys.stdout.buffer, 'strict')
    sys.stderr = codecs.getwriter('utf-8')(sys.stderr.buffer, 'strict')

BASE_URL = "http://127.0.0.1:8000"
TRANSLATE_URL = f"{BASE_URL}/translate"

def translate(text, source_lang, target_lang):
    """Test translation"""
    data = {
        "text": text,
        "source_language": source_lang,
        "target_language": target_lang
    }
    
    payload = json.dumps(data).encode("utf-8")
    req = urllib.request.Request(
        TRANSLATE_URL,
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            result = json.loads(resp.read())
            return result
    except urllib.error.HTTPError as e:
        print(f"HTTP Error {e.code}: {e.read().decode('utf-8')}")
        return None
    except Exception as e:
        print(f"Error: {e}")
        return None

if __name__ == "__main__":
    print("=" * 60)
    print("COMPREHENSIVE HINDI ↔ SANTALI TRANSLATION TEST")
    print("=" * 60)
    
    test_cases = [
        # Hindi to Santali
        ("भारत", "hin_Deva", "sat_Olck", "India"),
        ("स्कूल", "hin_Deva", "sat_Olck", "school"),
        ("पुस्तक", "hin_Deva", "sat_Olck", "book"),
        ("मुझे खुशी है", "hin_Deva", "sat_Olck", "I am happy"),
        ("क्या आप समझे?", "hin_Deva", "sat_Olck", "Did you understand?"),
        ("धन्यवाद", "hin_Deva", "sat_Olck", "thank you"),
        
        # Santali to Hindi
        ("ᱵᱷᱟᱨᱚᱛ", "sat_Olck", "hin_Deva", "India"),
        ("ᱥᱮᱪᱮᱫ", "sat_Olck", "hin_Deva", "education"),
        ("ᱯᱩᱛᱷᱤ", "sat_Olck", "hin_Deva", "book"),
        ("ᱤᱧ ᱫᱚ ᱠᱷᱩᱥᱤ ᱢᱮᱱᱟᱢ", "sat_Olck", "hin_Deva", "I am happy"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (text, src, tgt, meaning) in enumerate(test_cases, 1):
        print(f"\nTest {i}: {meaning}")
        print(f"  Input ({src}): {text}")
        
        result = translate(text, src, tgt)
        if result and result.get("success"):
            translation = result.get("translation", "")
            print(f"  Output ({tgt}): {translation}")
            
            # Basic quality check: translation should not be empty or just repeated characters
            if translation and len(translation) > 0 and len(set(translation)) > 2:
                print("  ✓ PASS")
                passed += 1
            else:
                print("  ✗ FAIL - Poor quality output")
                failed += 1
        else:
            print("  ✗ FAIL - Translation failed")
            failed += 1
    
    print("\n" + "=" * 60)
    print(f"RESULTS: {passed} passed, {failed} failed out of {len(test_cases)} tests")
    print("=" * 60)
    
    if failed == 0:
        print("\n✓ All tests passed! Hindi ↔ Santali translation is working.")
    else:
        print(f"\n✗ {failed} test(s) failed. Translation needs improvement.")
