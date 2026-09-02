"""Validate prototype parallel data and emit JSONL training records."""
import csv
import json
from pathlib import Path

root = Path(__file__).parents[1]
source = root / 'data' / 'hindi_santali_parallel.csv'
destination = root / 'data' / 'processed.jsonl'

with source.open(encoding='utf-8', newline='') as input_file, destination.open('w', encoding='utf-8') as output_file:
    for row in csv.DictReader(input_file):
        if not row['hindi'].strip() or not row['santali'].strip():
            continue
        output_file.write(json.dumps(row, ensure_ascii=False) + '\n')

print(f'Wrote {destination}')
