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

def test_hindi_to_santali():
    """Test Hindi to Santali translation"""
    data = {
        "text": "नमस्ते",
        "source_language": "hin_Deva",
        "target_language": "sat_Olck"
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
            print("Status:", resp.status)
            print("Response:", json.dumps(result, ensure_ascii=False, indent=2))
            return result
    except urllib.error.HTTPError as e:
        print(f"HTTP Error {e.code}: {e.read().decode('utf-8')}")
        return None
    except Exception as e:
        print(f"Error: {e}")
        return None

if __name__ == "__main__":
    print("Testing Hindi to Santali translation...")
    result = test_hindi_to_santali()
    if result and result.get("success"):
        print("\nTranslation successful!")
        print(f"Input: {result['input']}")
        print(f"Translation: {result['translation']}")
    else:
        print("\nTranslation failed!")
