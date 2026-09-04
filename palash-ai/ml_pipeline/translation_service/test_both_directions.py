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
    print("Testing both translation directions...\n")
    
    # Test 1: Hindi to Santali - different phrases
    print("Test 1: Hindi to Santali - 'नमस्ते' (hello)")
    result = translate("नमस्ते", "hin_Deva", "sat_Olck")
    if result:
        print(f"  Input: {result['input']}")
        print(f"  Translation: {result['translation']}")
        print(f"  Success: {result['success']}\n")
    
    print("Test 2: Hindi to Santali - 'आप कैसे हैं?' (how are you?)")
    result = translate("आप कैसे हैं?", "hin_Deva", "sat_Olck")
    if result:
        print(f"  Input: {result['input']}")
        print(f"  Translation: {result['translation']}")
        print(f"  Success: {result['success']}\n")
    
    print("Test 3: Hindi to Santali - 'मेरा नाम राहुल है' (my name is Rahul)")
    result = translate("मेरा नाम राहुल है", "hin_Deva", "sat_Olck")
    if result:
        print(f"  Input: {result['input']}")
        print(f"  Translation: {result['translation']}")
        print(f"  Success: {result['success']}\n")
    
    # Test 4: Santali to Hindi
    print("Test 4: Santali to Hindi - 'ᱡᱚᱦᱟᱨ' (johar - greeting)")
    result = translate("ᱡᱚᱦᱟᱨ", "sat_Olck", "hin_Deva")
    if result:
        print(f"  Input: {result['input']}")
        print(f"  Translation: {result['translation']}")
        print(f"  Success: {result['success']}\n")
