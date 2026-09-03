import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../ml/santali_to_hindi_service.dart';
import 'translation_result_screen.dart';

/// OCR Result Screen.
///
/// Displays:
/// - The original image
/// - Extracted Santali/Ol Chiki text
/// - Proceed to translation
class OcrResultScreen extends StatefulWidget {
  const OcrResultScreen({
    required this.imagePath,
    required this.preprocessedImagePath,
    required this.extractedText,
    super.key,
  });

  final String imagePath;
  final String preprocessedImagePath;
  final String extractedText;

  @override
  State<OcrResultScreen> createState() => _OcrResultScreenState();
}

class _OcrResultScreenState extends State<OcrResultScreen> {
  bool _translating = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: const Text('Extracted Text'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Original Image ────────────────────────────
              Text(
                'Source Image',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Container(
                  color: AppColors.border,
                  child: Image.file(
                    File(widget.imagePath),
                    fit: BoxFit.cover,
                    height: 200,
                    width: double.infinity,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Extracted Text Section ─────────────────────
              Text(
                'Extracted Santali Text (Ol Chiki)',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.cardText.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: AppColors.cardText.withValues(alpha: 0.2),
                  ),
                ),
                child: SelectableText(
                  widget.extractedText,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontFamily: 'Noto Sans Ol Chiki',
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Status Message ────────────────────────────
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.error_outline_rounded, color: AppColors.error),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Error: $_error',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: AppColors.error),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else if (widget.extractedText.isEmpty)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'No Santali text detected.\n'
                          'Please capture a clearer image.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.warning),
                        ),
                      ),
                    ],
                  ),
                )
              else if (_translating)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Row(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Translating to Hindi...',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),

              // ── Action Buttons ────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _translating
                          ? null
                          : () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: widget.extractedText.isEmpty || _translating
                          ? null
                          : _translateText,
                      icon: const Icon(Icons.translate_rounded),
                      label: const Text('Translate'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _translateText() async {
    setState(() {
      _translating = true;
      _error = null;
    });

    try {
      const translationService = MockSantaliToHindiService();
      final hindiText = await translationService.translate(
        widget.extractedText,
      );

      if (!mounted) return;

      // Navigate to translation result screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => TranslationResultScreen(
            imagePath: widget.imagePath,
            santaliText: widget.extractedText,
            hindiTranslation: hindiText,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
        _translating = false;
      });
    }
  }
}
