import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../core/api_config.dart';
import '../core/app_theme.dart';
import '../ml/on_device_services.dart';
import '../services/text_to_speech_service.dart';
import '../services/translation_service.dart';
import '../widgets/app_widgets.dart';

class TextTranslatorScreen extends StatefulWidget {
  const TextTranslatorScreen({super.key});

  @override
  State<TextTranslatorScreen> createState() => _TextTranslatorScreenState();
}

class _TextTranslatorScreenState extends State<TextTranslatorScreen> {
  final _controller = TextEditingController();
  final _player = AudioPlayer();
  final TextToSpeechService _ttsService = MockTextToSpeechService();

  bool _hindiToSantali = true;

  /// Result from the last translation (real model or phrase-tile mock).
  TranslationResult? _result;

  /// True while a real API translation request is in flight.
  /// Prevents duplicate simultaneous requests.
  bool _isTranslating = false;

  /// Persistent, retryable failure for the last ML request.
  TranslationApiException? _translationError;

  bool _creatingAudio = false;
  TextToSpeechResult? _ttsResult;

  bool _useOnDevice = true;

  // ── Language code helpers ─────────────────────────────────────────────────

  String get _sourceLang => _hindiToSantali ? 'hin_Deva' : 'sat_Olck';
  String get _targetLang => _hindiToSantali ? 'sat_Olck' : 'hin_Deva';

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _controller.dispose();
    _player.dispose();
    super.dispose();
  }

  // ── Translation — real IndicTrans2 model via API ───────────────────────────

  Future<void> _translate() async {
    final text = _controller.text.trim();

    // Guard: empty input — do not call the backend.
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter text to translate.')),
      );
      return;
    }

    // Guard: already translating — ignore duplicate taps.
    if (_isTranslating) return;

    setState(() {
      _isTranslating = true;
      _result = null;
      _translationError = null;
      _ttsResult = null;
    });

    try {
      final TranslationResult result;
      if (_useOnDevice) {
        result = await OnDeviceTranslationService().translate(
          text: text,
          sourceLanguage: _sourceLang,
          targetLanguage: _targetLang,
        );
      } else {
        result = await TranslationService.instance.translate(
          text: text,
          sourceLanguage: _sourceLang,
          targetLanguage: _targetLang,
        );
      }
      if (!mounted) return;
      setState(() {
        _result = result;
        _translationError = null;
      });
    } on TranslationApiException catch (error) {
      if (!mounted) return;
      setState(() => _translationError = error);
    } catch (error, stackTrace) {
      // Keep the UI safe while preserving the actual failure in development
      // logs. The entered text remains mounted for retry.
      dev.log(
        '[TextTranslator] Unexpected translation failure',
        name: 'TextTranslatorScreen',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _translationError = const TranslationApiException(
          kind: TranslationFailureKind.response,
          message:
              'Translation service returned an unexpected response. Please try again.',
        );
      });
    } finally {
      if (mounted) setState(() => _isTranslating = false);
    }
  }

  // ── Phrase-tile tap — populates input and triggers real model translation ─

  void _usePhrase(ClassroomPhrase phrase) {
    _controller.text = _hindiToSantali ? phrase.hindi : phrase.santali;
    _translate();
  }

  // ── Santali audio playback ────────────────────────────────────────────────

  Future<void> _playSantaliAudio() async {
    final text = _result?.output ?? '';
    if (text.isEmpty) return;
    setState(() => _creatingAudio = true);
    try {
      final output = await _ttsService.synthesizeSantali(text);
      await _player.setFilePath(output.audioPath);
      await _player.play();
      if (!mounted) return;
      setState(() => _ttsResult = output);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to create Santali demo audio.')),
      );
    } finally {
      if (mounted) setState(() => _creatingAudio = false);
    }
  }

  void _showServerConfigDialog() {
    final controller = TextEditingController(text: ApiConfig.backendBaseUrl);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backend Server URL'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your backend server base URL:\n'
              '• Android Emulator: http://10.0.2.2:3000\n'
              '• Physical Phone (Wi-Fi): http://<PC-LAN-IP>:3000\n'
              '• USB Port Forwarding: http://127.0.0.1:3000\n'
              '  (run: adb reverse tcp:3000 tcp:3000)',
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Server Base URL',
                hintText: 'http://192.168.x.x:3000',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              ApiConfig.customBackendBaseUrl = null;
              setState(() {});
              Navigator.pop(context);
            },
            child: const Text('Reset Default'),
          ),
          ElevatedButton(
            onPressed: () {
              ApiConfig.customBackendBaseUrl = controller.text.trim();
              setState(() {});
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          // ── Gradient app bar ────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 140,
            backgroundColor: AppColors.cardText,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: AppGradients.card(AppColors.cardText),
                ),
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius:
                                BorderRadius.circular(AppRadius.sm),
                          ),
                          child: const Icon(Icons.translate_rounded,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Text Translator',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.md),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Info banner ─────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.cardText.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                        color: AppColors.cardText.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: AppColors.cardText, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _useOnDevice
                              ? 'On-device translation\nRuns locally on this device'
                              : 'AI4Bharat IndicTrans2 engine (Indic-to-Indic 320M).\n'
                                'Endpoint: ${ApiConfig.backendBaseUrl}',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings_outlined, size: 18),
                        color: AppColors.cardText,
                        tooltip: _useOnDevice ? 'Switch to online mode' : 'Configure Backend IP',
                        onPressed: () {
                          setState(() {
                            _useOnDevice = !_useOnDevice;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Direction toggle ────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      _DirectionTab(
                        label: 'Hindi → Santali',
                        icon: Icons.arrow_forward_rounded,
                        selected: _hindiToSantali,
                        onTap: () => setState(() {
                           _hindiToSantali = true;
                           _result = null;
                           _translationError = null;
                        }),
                      ),
                      _DirectionTab(
                        label: 'Santali → Hindi',
                        icon: Icons.arrow_back_rounded,
                        selected: !_hindiToSantali,
                        onTap: () => setState(() {
                           _hindiToSantali = false;
                           _result = null;
                           _translationError = null;
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Input field ─────────────────────────────────────────
                TextField(
                  controller: _controller,
                  minLines: 3,
                  maxLines: 6,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    labelText: _hindiToSantali
                        ? 'Enter Hindi text'
                        : 'Enter Santali text (Ol Chiki)',
                    alignLabelWithHint: true,
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded,
                                color: AppColors.textSecondary),
                            onPressed: () {
                               _controller.clear();
                               setState(() {
                                 _result = null;
                                 _translationError = null;
                               });
                            },
                          )
                        : null,
                  ),
                   onChanged: (_) => setState(() {
                     _translationError = null;
                   }),
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Translate button ────────────────────────────────────
                PrimaryButton(
                  label: _isTranslating ? 'Translating…' : 'Translate',
                  icon: Icons.translate_rounded,
                  loading: _isTranslating,
                  color: AppColors.cardText,
                  onPressed: (_controller.text.trim().isEmpty || _isTranslating)
                      ? null
                      : _translate,
                ),

                // ── Request status ──────────────────────────────────────
                if (_isTranslating) ...[
                  const SizedBox(height: AppSpacing.sm),
                  const Center(
                    child: Text(
                      'Translating…',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ] else if (_translationError != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _TranslationErrorCard(
                    error: _translationError!,
                    onRetry: _controller.text.trim().isEmpty ? null : _translate,
                  ),
                ] else if (_result != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _ResultCard(
                    result: _result!,
                    hindiToSantali: _hindiToSantali,
                    creatingAudio: _creatingAudio,
                    ttsResult: _ttsResult,
                    onPlayAudio: _playSantaliAudio,
                  ),
                ],

                // ── Classroom phrase suggestions ────────────────────────
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    const Text(
                      'Classroom Phrases',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    PillBadge(
                        text: '${TranslationService.phrases.length}',
                        color: AppColors.cardText),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                ...TranslationService.phrases.map(
                  (phrase) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _PhraseTile(
                      phrase: phrase,
                      hindiToSantali: _hindiToSantali,
                      onTap: () => _usePhrase(phrase),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Direction tab ─────────────────────────────────────────────────────────────

class _DirectionTab extends StatelessWidget {
  const _DirectionTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.cardText : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.md - 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Translation error card ─────────────────────────────────────────────────────

class _TranslationErrorCard extends StatelessWidget {
  const _TranslationErrorCard({
    required this.error,
    required this.onRetry,
  });

  final TranslationApiException error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final isModelError = error.isModelError;
    final title = isModelError
        ? 'IndicTrans2 model error'
        : error.isUnavailable
            ? 'Translation service unavailable'
            : 'Translation response error';
    return Semantics(
      liveRegion: true,
      container: true,
      label: error.message,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 22,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    error.message,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Retry'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 40),
                        tapTargetSize: MaterialTapTargetSize.padded,
                      ),
                    ),
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

// ── Result card ───────────────────────────────────────────────────────────────

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.result,
    required this.hindiToSantali,
    required this.creatingAudio,
    required this.ttsResult,
    required this.onPlayAudio,
  });

  final TranslationResult result;
  final bool hindiToSantali;
  final bool creatingAudio;
  final TextToSpeechResult? ttsResult;
  final VoidCallback onPlayAudio;

  @override
  Widget build(BuildContext context) {
    final bool isReal = !result.isPrototype;
    final String chipLabel = isReal
        ? 'IndicTrans2'
        : (result.matchedPhrase ? 'Phrase match' : 'Prototype / partial');
    final ChipStyle chipStyle = isReal
        ? ChipStyle.success
        : (result.matchedPhrase ? ChipStyle.success : ChipStyle.warning);
    final IconData chipIcon = isReal
        ? Icons.auto_awesome_rounded
        : (result.matchedPhrase
            ? Icons.check_circle_rounded
            : Icons.warning_amber_rounded);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.cardText.withValues(alpha: 0.25)),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.sm, 0),
            child: Row(
              children: [
                StatusChip(
                  label: chipLabel,
                  style: chipStyle,
                  icon: chipIcon,
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Copy',
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  color: AppColors.textSecondary,
                  onPressed: result.output.isEmpty
                      ? null
                      : () {
                          Clipboard.setData(
                              ClipboardData(text: result.output));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Copied to clipboard')),
                          );
                        },
                ),
              ],
            ),
          ),

          // Translation output with explicit dark charcoal text
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md,
                AppSpacing.sm, AppSpacing.md, AppSpacing.md),
            child: SelectableText(
              result.output.isEmpty ? '—' : result.output,
              style: TextStyle(
                color: result.output.isEmpty
                    ? AppColors.textHint
                    : AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),

          if (result.note != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
              child: Text(
                result.note!,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),

          // Audio button (Santali output only)
          if (hindiToSantali) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: creatingAudio ? null : onPlayAudio,
                      icon: creatingAudio
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                          : const Icon(Icons.volume_up_rounded, size: 18),
                      label: Text(creatingAudio
                          ? 'Generating audio…'
                          : 'Play Santali audio'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.teal,
                        side: BorderSide(
                            color:
                                AppColors.teal.withValues(alpha: 0.4)),
                      ),
                    ),
                  ),
                  if (ttsResult != null) ...[
                    const SizedBox(width: 10),
                    StatusChip(
                      label:
                          '${ttsResult!.duration.inMilliseconds} ms',
                      style: ChipStyle.info,
                      icon: Icons.timer_rounded,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Phrase tile ───────────────────────────────────────────────────────────────

class _PhraseTile extends StatelessWidget {
  const _PhraseTile({
    required this.phrase,
    required this.hindiToSantali,
    required this.onTap,
  });

  final ClassroomPhrase phrase;
  final bool hindiToSantali;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hindiToSantali ? phrase.hindi : phrase.santali,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    phrase.englishHint,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.north_west_rounded,
                size: 16, color: AppColors.cardText),
          ],
        ),
      ),
    );
  }
}
