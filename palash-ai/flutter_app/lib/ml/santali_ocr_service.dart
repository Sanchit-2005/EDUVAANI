/// Contract for Santali/Ol Chiki OCR extraction.
///
/// This abstraction allows swapping between mock implementations and
/// real ONNX-based Ol Chiki OCR models without changing UI code.
abstract class SantaliOcrService {
  /// Extracts Santali text from an image.
  ///
  /// Returns the extracted Santali/Ol Chiki text.
  /// Throws [OcrException] if extraction fails.
  Future<String> extractText(String imagePath);
}

/// Exception thrown when OCR processing fails.
class OcrException implements Exception {
  const OcrException(this.message);
  final String message;

  @override
  String toString() => 'OcrException: $message';
}

/// DEMO/MOCK Santali OCR implementation.
///
/// This implementation demonstrates the OCR workflow without claiming
/// to perform actual Ol Chiki character recognition. It is replaced by
/// a real ONNX model in production.
///
/// IMPORTANT: This is NOT a real OCR model.
class MockSantaliOcrService implements SantaliOcrService {
  const MockSantaliOcrService();

  /// Mock extracted texts for demonstration.
  /// In production, this would be replaced with ONNX inference.
  static const Map<String, String> _mockDatabase = {
    // Common classroom phrases in Ol Chiki (Santali script)
    'demo_1': 'ᱜᱤᱫᱽᱨᱟᱹ ᱠᱚ ᱞᱮᱠᱷᱟ ᱪᱚ ᱠᱟᱢ',
    'demo_2': 'ᱟᱢ ᱠᱩᱞᱤ ᱟᱢᱮ ᱵᱩᱡᱷᱟᱹᱣ ᱟ',
    'demo_3': 'ᱱᱚᱣᱟ ᱛᱤᱱᱟᱹᱜ ᱦᱩᱭᱩᱜᱼᱟ',
  };

  @override
  Future<String> extractText(String imagePath) async {
    // Simulate OCR processing time
    await Future.delayed(const Duration(milliseconds: 1500));

    if (imagePath.isEmpty) {
      throw OcrException('Image path is empty');
    }

    // Mock: Return a sample Santali text
    // In production, this would run inference on the image using ONNX Runtime
    return _mockDatabase['demo_1'] ??
        'ᱜᱤᱫᱽᱨᱟᱹ ᱠᱚ ᱟᱠᱚᱣᱟᱜ ᱠᱟᱜᱚᱡᱚ ᱠᱷᱩᱞᱟᱹᱣ ᱠᱚᱢ';
  }
}

/// ONNX-based Santali OCR implementation (placeholder).
///
/// This would use ONNX Runtime Mobile and an Ol Chiki-specific model.
/// To be implemented when the model is available.
class OnnxSantaliOcrService implements SantaliOcrService {
  OnnxSantaliOcrService({this.modelPath});

  final String? modelPath;

  @override
  Future<String> extractText(String imagePath) async {
    throw UnimplementedError(
      'ONNX Santali OCR not yet implemented. '
      'Requires a trained Ol Chiki recognition model.',
    );
  }
}
