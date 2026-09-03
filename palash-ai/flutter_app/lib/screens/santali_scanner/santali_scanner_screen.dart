import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/app_theme.dart';
import 'image_preview_screen.dart';

class SantaliScannerScreen extends StatefulWidget {
  const SantaliScannerScreen({super.key});

  @override
  State<SantaliScannerScreen> createState() => _SantaliScannerScreenState();
}

class _SantaliScannerScreenState extends State<SantaliScannerScreen> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickFromCamera() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (!status.isGranted) {
      _showMessage('Camera permission denied');
      return;
    }

    final xFile = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (xFile != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ImagePreviewScreen(imagePath: xFile.path),
        ),
      );
    }
  }

  Future<void> _pickFromGallery() async {
    final status = await Permission.photos.request();
    if (!mounted) return;
    if (!status.isGranted) {
      _showMessage('Gallery permission denied');
      return;
    }

    final xFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (xFile != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ImagePreviewScreen(imagePath: xFile.path),
        ),
      );
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text('Scan Santali Text'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: AppColors.cardScanner.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: AppColors.cardScanner,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'Scan Santali text written in Ol Chiki and translate it into Hindi.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _pickFromCamera,
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: const Text('Take Photo'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickFromGallery,
                    icon: const Icon(Icons.photo_library_rounded),
                    label: const Text('Choose from Gallery'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.25),
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off_rounded, color: AppColors.success),
                  const SizedBox(width: AppSpacing.sm),
                  const Expanded(
                    child: Text('Offline Mode - local processing only'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
