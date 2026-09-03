import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../ml/santali_ocr_service.dart';
import '../../services/image_preprocessing_service.dart';
import 'ocr_result_screen.dart';

class ImagePreviewScreen extends StatefulWidget {
  const ImagePreviewScreen({required this.imagePath, super.key});

  final String imagePath;

  @override
  State<ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends State<ImagePreviewScreen> {
  bool _processing = false;
  String? _error;

  Future<void> _processImage() async {
    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      final processedPath = await const ImagePreprocessingService()
          .preprocessForOcr(widget.imagePath);
      final extractedText = await const MockSantaliOcrService().extractText(
        processedPath,
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OcrResultScreen(
            imagePath: widget.imagePath,
            preprocessedImagePath: processedPath,
            extractedText: extractedText,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _processing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Preview'),
        backgroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Image.file(
                File(widget.imagePath),
                width: double.infinity,
                height: 360,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(_error!),
              )
            else if (_processing)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: CircularProgressIndicator(),
              )
            else
              const Text('Image looks good for scanning.'),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _processing
                        ? null
                        : () => Navigator.pop(context),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retake'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _processing ? null : _processImage,
                    icon: const Icon(Icons.search_rounded),
                    label: const Text('Scan Text'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
