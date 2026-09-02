"""Measure isolated ASR, translation and TTS model latency on target hardware."""
import time

def measure(operation):
    started = time.perf_counter()
    result = operation()
    return result, (time.perf_counter() - started) * 1000

if __name__ == '__main__':
    print('Wrap each real ONNX inference call with measure() and report actual milliseconds.')
