import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../core/app_theme.dart';
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
  TranslationResult? _result;
  bool _creatingAudio = false;
  TextToSpeechResult? _ttsResult;

  @override
  void dispose() {
    _controller.dispose();
    _player.dispose();
    super.dispose();
  }

  void _translate() {
    final service = TranslationService.instance;
    setState(() {
      _result = _hindiToSantali
          ? service.hindiToSantali(_controller.text)
          : service.santaliToHindi(_controller.text);
      _ttsResult = null;
    });
  }

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

  void _usePhrase(ClassroomPhrase phrase) {
    _controller.text = _hindiToSantali ? phrase.hindi : phrase.santali;
    _translate();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          // ── Gradient app bar ──────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 140,
            backgroundColor: AppColors.cardText,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration:
                    BoxDecoration(gradient: AppGradients.card(AppColors.cardText)),
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
                            borderRadius: BorderRadius.circular(AppRadius.sm),
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
                              fontWeight: FontWeight.w700),
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
                // Disclaimer
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                        color: AppColors.info.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: AppColors.info, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Offline prototype dictionary. Not a live neural model.',
                          style: TextStyle(
                              color: AppColors.info,
                              fontSize: 12,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Direction toggle
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
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
                        }),
                      ),
                      _DirectionTab(
                        label: 'Santali → Hindi',
                        icon: Icons.arrow_back_rounded,
                        selected: !_hindiToSantali,
                        onTap: () => setState(() {
                          _hindiToSantali = false;
                          _result = null;
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Input field
                TextField(
                  controller: _controller,
                  minLines: 3,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: _hindiToSantali ? 'Enter Hindi text' : 'Enter Santali text',
                    alignLabelWithHint: true,
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _controller.clear();
                              setState(() => _result = null);
                            },
                          )
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.md),

                // Translate button
                PrimaryButton(
                  label: 'Translate',
                  icon: Icons.translate_rounded,
                  color: AppColors.cardText,
                  onPressed: _controller.text.trim().isEmpty ? null : _translate,
                ),

                // Result card
                if (_result != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _ResultCard(
                    result: _result!,
                    hindiToSantali: _hindiToSantali,
                    creatingAudio: _creatingAudio,
                    ttsResult: _ttsResult,
                    onPlayAudio: _playSantaliAudio,
                  ),
                ],

                // Phrase suggestions
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Text('Classroom Phrases',
                        style: Theme.of(context).textTheme.titleMedium),
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

// ── Direction tab ─────────────────────────────

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
              Icon(icon,
                  size: 16,
                  color: selected ? Colors.white : AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
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

// ── Result card ───────────────────────────────

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
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.cardText.withValues(alpha: 0.06),
            AppColors.teal.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.cardText.withValues(alpha: 0.2)),
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
                  label: result.matchedPhrase ? 'Phrase match' : 'Prototype / partial',
                  style: result.matchedPhrase ? ChipStyle.success : ChipStyle.warning,
                  icon: result.matchedPhrase
                      ? Icons.check_circle_rounded
                      : Icons.warning_amber_rounded,
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Copy',
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  color: AppColors.textSecondary,
                  onPressed: result.output.isEmpty
                      ? null
                      : () {
                          Clipboard.setData(ClipboardData(text: result.output));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copied to clipboard')),
                          );
                        },
                ),
              ],
            ),
          ),

          // Translation output
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
            child: SelectableText(
              result.output.isEmpty ? '—' : result.output,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: result.output.isEmpty
                        ? AppColors.textHint
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),

          if (result.note != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
              child: Text(result.note!,
                  style: Theme.of(context).textTheme.bodySmall),
            ),

          // Audio button
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
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.volume_up_rounded, size: 18),
                      label: Text(creatingAudio
                          ? 'Generating audio…'
                          : 'Play Santali audio'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.teal,
                        side: BorderSide(
                            color: AppColors.teal.withValues(alpha: 0.4)),
                      ),
                    ),
                  ),
                  if (ttsResult != null) ...[
                    const SizedBox(width: 10),
                    StatusChip(
                      label: '${ttsResult!.duration.inMilliseconds} ms',
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

// ── Phrase tile ───────────────────────────────

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
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hindiToSantali ? phrase.hindi : phrase.santali,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(phrase.englishHint,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Icon(Icons.north_west_rounded,
                size: 16, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}
