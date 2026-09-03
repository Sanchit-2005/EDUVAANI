import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/app_theme.dart';
import '../../database/database_helper.dart';
import '../../models/scan_result.dart';
import '../../repositories/scan_repository.dart';
import '../../services/hindi_tts_service.dart';
import 'scan_history_screen.dart';

class TranslationResultScreen extends StatefulWidget {
  const TranslationResultScreen({
    required this.imagePath,
    required this.santaliText,
    required this.hindiTranslation,
    super.key,
  });

  final String imagePath;
  final String santaliText;
  final String hindiTranslation;

  @override
  State<TranslationResultScreen> createState() =>
      _TranslationResultScreenState();
}

class _TranslationResultScreenState extends State<TranslationResultScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isSaving = false;
  bool _saved = false;
  String? _audioPath;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prepareSpeech();
    _audioPlayer.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state.playing;
      });
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _prepareSpeech() async {
    try {
      final result = await MockHindiTtsService().synthesizeHindi(
        widget.hindiTranslation,
      );
      if (!mounted) return;
      setState(() {
        _audioPath = result.audioPath;
      });
      await _audioPlayer.setFilePath(result.audioPath);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    }
  }

  Future<void> _saveToHistory() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final repository = ScanRepository(DatabaseHelper.instance);
      await repository.insertScan(
        ScanResult(
          imagePath: widget.imagePath,
          santaliText: widget.santaliText,
          hindiTranslation: widget.hindiTranslation,
          createdAt: DateTime.now().toIso8601String(),
        ),
      );

      if (!mounted) return;
      setState(() {
        _saved = true;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Scan saved to history')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isSaving = false;
      });
    }
  }

  Future<void> _copyText() async {
    await Clipboard.setData(ClipboardData(text: widget.hindiTranslation));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Hindi translation copied')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Translation Result'),
        backgroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Santali Text'),
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.cardText.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: SelectableText(
                widget.santaliText,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(fontFamily: 'Noto Sans Ol Chiki'),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text('Hindi Translation'),
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: SelectableText(
                widget.hindiTranslation,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.error))
            else
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _audioPath == null
                          ? null
                          : () async {
                              if (_isPlaying) {
                                await _audioPlayer.pause();
                              } else {
                                await _audioPlayer.play();
                              }
                            },
                      icon: Icon(
                        _isPlaying
                            ? Icons.stop_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      label: Text(_isPlaying ? 'Stop' : 'Play Hindi'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: !_isPlaying
                          ? null
                          : () async => _audioPlayer.stop(),
                      icon: const Icon(Icons.stop_rounded),
                      label: const Text('Stop'),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copyText,
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copy'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _saveToHistory,
                    icon: Icon(
                      _saved ? Icons.check_circle_rounded : Icons.save_rounded,
                    ),
                    label: Text(
                      _saved
                          ? 'Saved'
                          : _isSaving
                          ? 'Saving...'
                          : 'Save',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ScanHistoryScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.history_rounded),
                label: const Text('Scan Another'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Row(
                children: [
                  Icon(Icons.cloud_off_rounded, color: AppColors.success),
                  SizedBox(width: AppSpacing.sm),
                  Text('Offline Mode'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
