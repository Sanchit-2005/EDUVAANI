"""INT8 dynamic quantization entry point for mobile deployment."""
from onnxruntime.quantization import QuantType, quantize_dynamic

def quantize(input_path, output_path):
    quantize_dynamic(input_path, output_path, weight_type=QuantType.QInt8)

if __name__ == '__main__':
    print('Import quantize(input_path, output_path) from this module after ONNX export.')
