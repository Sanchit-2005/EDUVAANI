import 'package:flutter/foundation.dart';

import 'santali_ocr_service.dart';
import 'santali_to_hindi_service.dart';

/// Central place for mock ML services used in demo mode.
///
/// Keeps the mock behavior separate so real model adapters can replace it later
/// without changing screen logic.
class MockMlServices {
  const MockMlServices();

  static const SantaliOcrService ocr = MockSantaliOcrService();
  static const SantaliToHindiService translation = MockSantaliToHindiService();

  @visibleForTesting
  static bool isDemoModeEnabled = true;
}
