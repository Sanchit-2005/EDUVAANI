/// Contract for Santali to Hindi translation.
///
/// This abstraction supports replacing mock implementations with real
/// ONNX-based Santali→Hindi models.
abstract class SantaliToHindiService {
  /// Translates Santali text to Hindi.
  ///
  /// Returns the Hindi translation.
  /// Throws [TranslationException] if translation fails.
  Future<String> translate(String santaliText);
}

/// Exception thrown when translation processing fails.
class TranslationException implements Exception {
  const TranslationException(this.message);
  final String message;

  @override
  String toString() => 'TranslationException: $message';
}

/// DEMO/MOCK Santali to Hindi translation service.
///
/// This implementation demonstrates the translation workflow without claiming
/// to perform accurate Santali→Hindi translation. Real translation is
/// performed by a suitable Indic language model in production.
///
/// IMPORTANT: This is NOT a real translation model.
/// It is a dictionary-based mock for demonstration only.
class MockSantaliToHindiService implements SantaliToHindiService {
  const MockSantaliToHindiService();

  /// Mock Santali → Hindi dictionary entries.
  /// In production, this would be replaced with ONNX neural inference.
  static const Map<String, String> _mockDictionary = {
    'ᱜᱤᱫᱽᱨᱟᱹ': 'बच्चा',
    'ᱜᱤᱫᱽᱨᱟᱹ ᱠᱚ': 'बच्चों',
    'ᱞᱮᱠᱷᱟ': 'गणना',
    'ᱠᱟᱜᱚᱡᱚ': 'किताब',
    'ᱠᱷᱩᱞᱟᱹᱣ': 'खोलना',
    'ᱠᱚᱢ': 'करना',
    'ᱟᱠᱚᱣᱟᱜ': 'उनकी',
    'ᱱᱚᱣᱟ': 'यह',
    'ᱛᱤᱱᱟᱹᱜ': 'कितना',
    'ᱦᱩᱭᱩᱜ': 'होना',
    'ᱟ': 'है',
    'ᱠᱩᱞᱤ': 'प्रश्न',
    'ᱯᱮ': 'करो',
    'ᱜᱚᱨ': 'कान',
    'ᱥᱟᱶ': 'साथ',
    'ᱟᱸᱡᱚᱢ': 'सुनना',
    'ᱠᱚᱯᱤ': 'नोटबुक',
    'ᱢᱮᱱᱟᱜ': 'है',
    'ᱢᱤᱫ': 'एक',
    'ᱥᱟᱞᱟᱧ': 'साथ',
  };

  @override
  Future<String> translate(String santaliText) async {
    // Simulate translation processing time
    await Future.delayed(const Duration(milliseconds: 800));

    if (santaliText.trim().isEmpty) {
      throw TranslationException('Santali text cannot be empty');
    }

    // Mock: Apply a simple word-by-word dictionary lookup
    // In production, this would run ONNX inference with a neural model
    final words = santaliText.split(RegExp(r'\s+'));
    final translatedWords = words.map((word) {
      return _mockDictionary[word] ?? word;
    }).toList();

    final result = translatedWords.join(' ');

    // If no words were translated, return a demo message
    if (result == santaliText) {
      return '[MOCK] $santaliText को हिंदी में अनुवाद करने के लिए मॉडल की आवश्यकता है।';
    }

    return result;
  }
}

/// ONNX-based Santali to Hindi translation (placeholder).
///
/// This would use ONNX Runtime Mobile with a suitable Indic language model
/// that supports Santali→Hindi translation direction.
/// To be implemented when such a model is available.
class OnnxSantaliToHindiService implements SantaliToHindiService {
  OnnxSantaliToHindiService({this.modelPath});

  final String? modelPath;

  @override
  Future<String> translate(String santaliText) async {
    throw UnimplementedError(
      'ONNX Santali→Hindi translation not yet implemented. '
      'Requires a trained Indic language model supporting this direction.',
    );
  }
}
