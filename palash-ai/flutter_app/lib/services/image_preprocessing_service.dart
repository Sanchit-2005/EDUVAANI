import 'dart:io';

import 'package:image/image.dart' as img;

/// Image preprocessing service for OCR optimization.
///
/// Prepares captured/gallery images for Santali OCR by applying
/// lightweight transformations suitable for low-end Android tablets.
class ImagePreprocessingService {
  const ImagePreprocessingService();

  /// Preprocesses an image for OCR.
  ///
  /// Applies transformations in this order:
  /// 1. Resize to max 1920x1920 (preserve aspect ratio)
  /// 2. Convert to grayscale
  /// 3. Auto-adjust contrast
  /// 4. Detect and crop text area
  ///
  /// Returns the path to the preprocessed image file.
  /// Throws [PreprocessingException] on failure.
  Future<String> preprocessForOcr(String inputPath) async {
    try {
      // Read image file
      final inputFile = File(inputPath);
      if (!await inputFile.exists()) {
        throw PreprocessingException('Image file not found: $inputPath');
      }

      final imageBytes = await inputFile.readAsBytes();

      // Decode image
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        throw PreprocessingException('Failed to decode image');
      }

      // 1. Resize if too large
      if (image.width > 1920 || image.height > 1920) {
        image = img.copyResize(
          image,
          width: image.width > 1920 ? 1920 : null,
          height: image.height > 1920 ? 1920 : null,
          interpolation: img.Interpolation.linear,
        );
      }

      // 2. Convert to grayscale
      image = _toGrayscale(image);

      // 3. Enhance contrast for text clarity
      image = _enhanceContrast(image);

      // 4. Apply light noise reduction
      image = _reduceNoise(image);

      // 5. Detect and crop text area (simple bounding box)
      image = _cropTextArea(image);

      // Encode and save
      final outputFile = File(
        inputPath.replaceFirst(RegExp(r'\.[^.]+$'), '_preprocessed.png'),
      );
      final pngBytes = img.encodePng(image);
      await outputFile.writeAsBytes(pngBytes);

      return outputFile.path;
    } catch (e) {
      throw PreprocessingException('Preprocessing failed: $e');
    }
  }

  /// Converts image to grayscale.
  img.Image _toGrayscale(img.Image image) {
    final gray = img.Image(width: image.width, height: image.height);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixelSafe(x, y);
        final r = pixel.r;
        final g = pixel.g;
        final b = pixel.b;
        // Standard grayscale conversion
        final grayVal = (0.299 * r + 0.587 * g + 0.114 * b).toInt();
        gray.setPixelRgba(x, y, grayVal, grayVal, grayVal, 255);
      }
    }
    return gray;
  }

  /// Enhances contrast for better text visibility.
  img.Image _enhanceContrast(img.Image image) {
    // Simple contrast enhancement using histogram stretching
    int minVal = 255, maxVal = 0;

    // Find min and max pixel values
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixelSafe(x, y);
        final grayVal = pixel.r.toInt();
        if (grayVal < minVal) minVal = grayVal;
        if (grayVal > maxVal) maxVal = grayVal;
      }
    }

    // Stretch histogram
    final range = maxVal - minVal;
    if (range == 0) return image; // No contrast to enhance

    final enhanced = img.Image(width: image.width, height: image.height);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixelSafe(x, y);
        final grayVal = pixel.r.toInt();
        final stretched = (((grayVal - minVal) * 255) ~/ range).clamp(0, 255);
        enhanced.setPixelRgba(x, y, stretched, stretched, stretched, 255);
      }
    }

    return enhanced;
  }

  /// Applies simple noise reduction using median filter (lightweight).
  img.Image _reduceNoise(img.Image image) {
    // Apply simple 3x3 median filter (light noise reduction)
    final filtered = img.Image(width: image.width, height: image.height);

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final values = <int>[];

        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            final nx = x + dx;
            final ny = y + dy;
            if (nx >= 0 && nx < image.width && ny >= 0 && ny < image.height) {
              final pixel = image.getPixelSafe(nx, ny);
              values.add(pixel.r.toInt());
            }
          }
        }

        values.sort();
        final median = values[values.length ~/ 2];
        filtered.setPixelRgba(x, y, median, median, median, 255);
      }
    }

    return filtered;
  }

  /// Detects and crops text bounding area (simple edge detection).
  img.Image _cropTextArea(img.Image image) {
    // Find top, bottom, left, right boundaries of non-white areas
    int top = image.height, bottom = 0, left = image.width, right = 0;
    const threshold = 240; // Pixels darker than this are considered text

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixelSafe(x, y);
        final grayVal = pixel.r.toInt();

        if (grayVal < threshold) {
          if (y < top) top = y;
          if (y > bottom) bottom = y;
          if (x < left) left = x;
          if (x > right) right = x;
        }
      }
    }

    // Add padding around detected text
    const padding = 10;
    top = (top - padding).clamp(0, image.height);
    bottom = (bottom + padding).clamp(0, image.height);
    left = (left - padding).clamp(0, image.width);
    right = (right + padding).clamp(0, image.width);

    // If no text detected, use full image
    if (left >= right || top >= bottom) {
      return image;
    }

    // Crop to detected area
    return img.copyCrop(
      image,
      x: left,
      y: top,
      width: right - left,
      height: bottom - top,
    );
  }
}

/// Exception thrown during image preprocessing.
class PreprocessingException implements Exception {
  const PreprocessingException(this.message);
  final String message;

  @override
  String toString() => 'PreprocessingException: $message';
}
