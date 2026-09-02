import 'package:flutter_app/ml/model_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('model descriptors name the three sequential offline models', () {
    expect(ModelManager.hindiAsr.fileName, endsWith('.onnx'));
    expect(ModelManager.hindiSantaliTranslation.fileName, endsWith('.onnx'));
    expect(ModelManager.santaliTts.fileName, endsWith('.onnx'));
  });
}
