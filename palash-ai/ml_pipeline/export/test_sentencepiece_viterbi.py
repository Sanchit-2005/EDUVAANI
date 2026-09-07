import sys
from pathlib import Path
import struct

sys.stdout.reconfigure(encoding='utf-8')
sys.path.insert(0, str(Path(r'D:\V2 s123\EDUVAANI\palash-ai\ml_pipeline\translation_service')))
from translator import translator

# Verify Python tokenizer outputs
translator.load()
ip = translator._ip
tokenizer = translator._tokenizer
tests = [
    ('नमस्ते', 'hin_Deva', 'sat_Olck'),
    ('आप कैसे हैं?', 'hin_Deva', 'sat_Olck'),
    ('मेरा नाम सचिन है।', 'hin_Deva', 'sat_Olck'),
    ('ᱡᱚᱦᱟᱨ', 'sat_Olck', 'hin_Deva'),
]
print('=== Python Reference Tokenizer ===')
for text, src, tgt in tests:
    prep = ip.preprocess_batch([text], src_lang=src, tgt_lang=tgt, visualize=False)[0]
    ids = tokenizer(prep, padding=False, truncation=True, max_length=256, return_tensors='pt')['input_ids'][0].tolist()
    print(f'Input: {text!r}')
    print(f'Preprocessed: {prep!r}')
    print(f'IDs: {ids}')
    print()

# Inspect SentencePiece model structure
model_path = Path(r'D:\V2 s123\EDUVAANI\palash-ai\flutter_app\android\app\src\main\assets\models\indictrans2\int8\model.SRC')
with open(model_path, 'rb') as f:
    data = f.read()

print(f'Model size: {len(data)} bytes')

# Parse protobuf
buffer = bytearray(data)
pos = 0

def read_varint(buf, p):
    result = 0
    shift = 0
    while p < len(buf):
        b = buf[p]
        p += 1
        result |= (b & 0x7F) << shift
        if (b & 0x80) == 0:
            break
        shift += 7
    return result, p

pieces = []
version = None
unk_id = bos_id = eos_id = pad_id = None
unk_piece = bos_piece = eos_piece = pad_piece = None

while pos < len(buffer):
    tag, pos = read_varint(buffer, pos)
    field_number = tag >> 3
    wire_type = tag & 0x7
    
    if field_number == 1 and wire_type == 2:
        length, pos = read_varint(buffer, pos)
        piece_data = bytes(buffer[pos:pos+length])
        pos += length
        
        # Parse SentencePiece message
        p = 0
        piece = ""
        score = 0.0
        while p < len(piece_data):
            tag2, p = read_varint(piece_data, p)
            fn = tag2 >> 3
            wt = tag2 & 0x7
            
            if fn == 1 and wt == 2:
                length2, p = read_varint(piece_data, p)
                piece = piece_data[p:p+length2].decode('utf-8')
                p += length2
            elif fn == 2 and wt == 5:
                score = struct.unpack('<f', piece_data[p:p+4])[0]
                p += 4
            elif fn == 3 and wt == 0:
                _, p = read_varint(piece_data, p)
            else:
                if wt == 0:
                    _, p = read_varint(piece_data, p)
                elif wt == 2:
                    length2, p = read_varint(piece_data, p)
                    p += length2
                elif wt == 5:
                    p += 4
                else:
                    raise ValueError(f"Unknown wire type: {wt}")
        
        pieces.append((piece, score))
    elif field_number == 2 and wire_type == 0:
        version, pos = read_varint(buffer, pos)
    elif field_number == 5 and wire_type == 0:
        unk_id, pos = read_varint(buffer, pos)
    elif field_number == 6 and wire_type == 2:
        length, pos = read_varint(buffer, pos)
        unk_piece = buffer[pos:pos+length].decode('utf-8')
        pos += length
    elif field_number == 7 and wire_type == 0:
        bos_id, pos = read_varint(buffer, pos)
    elif field_number == 8 and wire_type == 2:
        length, pos = read_varint(buffer, pos)
        bos_piece = buffer[pos:pos+length].decode('utf-8')
        pos += length
    elif field_number == 9 and wire_type == 0:
        eos_id, pos = read_varint(buffer, pos)
    elif field_number == 10 and wire_type == 2:
        length, pos = read_varint(buffer, pos)
        eos_piece = buffer[pos:pos+length].decode('utf-8')
        pos += length
    elif field_number == 11 and wire_type == 0:
        pad_id, pos = read_varint(buffer, pos)
    elif field_number == 12 and wire_type == 2:
        length, pos = read_varint(buffer, pos)
        pad_piece = buffer[pos:pos+length].decode('utf-8')
        pos += length
    else:
        if wire_type == 0:
            _, pos = read_varint(buffer, pos)
        elif wire_type == 2:
            length, pos = read_varint(buffer, pos)
            pos += length
        elif wire_type == 5:
            pos += 4
        else:
            raise ValueError(f"Unknown top-level wire type: {wire_type}")

print(f'\n=== SentencePiece Model ===')
print(f'Version: {version}')
print(f'Pieces: {len(pieces)}')
print(f'unk_id={unk_id}, bos_id={bos_id}, eos_id={eos_id}, pad_id={pad_id}')
print(f'unk_piece={unk_piece!r}, bos_piece={bos_piece!r}, eos_piece={eos_piece!r}, pad_piece={pad_piece!r}')
print(f'\nFirst 10 pieces:')
for piece, score in pieces[:10]:
    print(f'  {piece!r}: {score}')
print(f'\nSample pieces for नमस्ते:')
for piece, score in pieces:
    if 'नम' in piece or 'मस' in piece or 'ते' in piece or 'स्ते' in piece:
        print(f'  {piece!r}: {score}')

# Now implement Viterbi in Python and compare
class ViterbiTokenizer:
    def __init__(self, pieces, unk_id):
        self.pieces = pieces
        self.unk_id = unk_id
        self.trie = {}
        for idx, (piece, score) in enumerate(pieces):
            node = self.trie
            for char in piece:
                if char not in node:
                    node[char] = {}
                node = node[char]
            node['_id'] = idx
            node['_score'] = score
    
    def encode(self, text):
        normalized = text.replace(' ', '▁')
        n = len(normalized)
        if n == 0:
            return []
        
        dp = [float('-inf')] * (n + 1)
        parent = [(-1, -1)] * (n + 1)
        dp[0] = 0.0
        
        for i in range(n):
            if dp[i] == float('-inf'):
                continue
            
            node = self.trie
            j = i
            while j < n and normalized[j] in node:
                node = node[normalized[j]]
                j += 1
                if '_id' in node:
                    score = node['_score']
                    new_score = dp[i] + score
                    if new_score > dp[j]:
                        dp[j] = new_score
                        parent[j] = (i, node['_id'])
        
        if dp[n] == float('-inf'):
            return [self.unk_id] * n
        
        result = []
        pos = n
        while pos > 0:
            prev, piece_id = parent[pos]
            result.append(piece_id)
            pos = prev
        result.reverse()
        return result

print('\n=== Python Viterbi Tokenizer Test ===')
viterbi = ViterbiTokenizer(pieces, unk_id)
for text, src, tgt in tests:
    prep = ip.preprocess_batch([text], src_lang=src, tgt_lang=tgt, visualize=False)[0]
    expected_ids = tokenizer(prep, padding=False, truncation=True, max_length=256, return_tensors='pt')['input_ids'][0].tolist()
    
    # Extract just the text part (without BOS/EOS)
    text_part = prep
    actual_ids = viterbi.encode(text_part)
    
    print(f'Input: {text!r}')
    print(f'Preprocessed: {prep!r}')
    print(f'Expected IDs: {expected_ids}')
    print(f'Actual IDs:   {actual_ids}')
    print(f'Match: {"YES" if actual_ids == expected_ids else "NO"}')
    print()
