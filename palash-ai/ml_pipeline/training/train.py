"""Starter fine-tuning entry point. A reviewed parallel corpus and GPU are required."""
from pathlib import Path

if __name__ == '__main__':
    dataset = Path(__file__).parents[1] / 'data' / 'processed.jsonl'
    if not dataset.exists():
        raise SystemExit('Run preprocessing/preprocess.py first.')
    print('Training pipeline scaffold ready. Configure an IndicTrans2-compatible model and reviewed data before training.')
