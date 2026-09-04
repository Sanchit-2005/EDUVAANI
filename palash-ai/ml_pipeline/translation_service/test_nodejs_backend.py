import sys
import json
import urllib.request
import urllib.error

# Configure UTF-8 encoding for Windows console
if sys.platform == 'win32':
    import codecs
    sys.stdout = codecs.getwriter('utf-8')(sys.stdout.buffer, 'strict')
    sys.stderr = codecs.getwriter('utf-8')(sys.stderr.buffer, 'strict')

BASE_URL = "http://127.0.0.1:3000"
TRANSLATE_URL = f"{BASE_URL}/api/translate"
HEALTH_URL = f"{BASE_URL}/api/health"

def test_health():
    """Test Node.js health endpoint"""
    try:
        req = urllib.request.Request(HEALTH_URL, method="GET")
        with urllib.request.urlopen(req, timeout=10) as resp:
            result = json.loads(resp.read())
            print("Node.js Health Check:")
            print(f"  Status: {result.get('status')}")
            print(f"  Database: {result.get('database')}")
            return True
    except Exception as e:
        print(f"Node.js health check failed: {e}")
        return False

def test_translation(text, src, tgt):
    """Test translation through Node.js backend"""
    data = {
        "text": text,
        "source_language": src,
        "target_language": tgt
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
    except Exception as e:
        print(f"Translation failed: {e}")
        return None

if __name__ == "__main__":
    print("Complete Translation Flow Test (Flutter → Node.js → Python → IndicTrans2)")
    print("=" * 80)
    
    # First check Node.js health
    if not test_health():
        print("\n❌ Node.js backend is not healthy. Cannot proceed.")
        sys.exit(1)
    
    print("\n✓ Node.js backend is healthy. Testing translations...\n")
    
    # Test Hindi to Santali
    print("Test 1: Hindi to Santali - 'नमस्ते'")
    result = test_translation("नमस्ते", "hin_Deva", "sat_Olck")
    if result and result.get("success"):
        print(f"  Input: {result['input']}")
        print(f"  Translation: {result['translation']}")
        print(f"  ✓ Success")
    else:
        print(f"  ✗ Failed")
        print(f"  Response: {result}")
    
    print("\nTest 2: Hindi to Santali - 'आप कैसे हैं?'")
    result = test_translation("आप कैसे हैं?", "hin_Deva", "sat_Olck")
    if result and result.get("success"):
        print(f"  Input: {result['input']}")
        print(f"  Translation: {result['translation']}")
        print(f"  ✓ Success")
    else:
        print(f"  ✗ Failed")
        print(f"  Response: {result}")
    
    print("\nTest 3: Santali to Hindi - 'ᱡᱚᱦᱟᱨ'")
    result = test_translation("ᱡᱚᱦᱟᱨ", "sat_Olck", "hin_Deva")
    if result and result.get("success"):
        print(f"  Input: {result['input']}")
        print(f"  Translation: {result['translation']}")
        print(f"  ✓ Success")
    else:
        print(f"  ✗ Failed")
        print(f"  Response: {result}")
    
    print("\n" + "=" * 80)
    print("Complete flow test finished. You can now test in your Flutter app!")
