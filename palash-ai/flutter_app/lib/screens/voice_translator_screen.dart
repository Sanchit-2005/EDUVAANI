import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../core/app_theme.dart';
import '../models/latency_benchmark.dart';
import '../repositories/benchmark_repository.dart';
import '../services/speech_recognition_service.dart';
import '../services/text_to_speech_service.dart';
import '../services/translation_service.dart';
import '../widgets/app_widgets.dart';

class VoiceTranslatorScreen extends StatefulWidget {
  const VoiceTranslatorScreen({super.key});

  @override
  State<VoiceTranslatorScreen> createState() => _VoiceTranslatorScreenState();
}

class _VoiceTranslatorScreenState extends State<VoiceTranslatorScreen>
    with SingleTickerProviderStateMixin {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  final TextToSpeechService _ttsService = MockTextToSpeechService();
  final BenchmarkRepository _benchmarkRepository = BenchmarkRepository();

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  bool _recording = false;
  bool _busy = false;
  String? _audioPath;
  ClassroomPhrase _selectedPhrase = TranslationService.phrases.first;
  TranslationResult? _result;
  SpeechRecognitionResult? _asrResult;
  TextToSpeechResult? _ttsResult;
  Duration? _translationDuration;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.14).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _recorder.dispose();
    _player.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleRecord() async {
    if (_recording) {
      setState(() => _busy = true);
      try {
        final path = await _recorder.stop();
        _pulseCtrl.stop();
        if (path == null) throw StateError('No audio recorded.');
        final asr = await MockSpeechRecognitionService(
          demoTranscript: _selectedPhrase.hindi,
        ).transcribeHindi(path);
        final sw = Stopwatch()..start();
        final translation =
            TranslationService.instance.hindiToSantali(asr.transcript);
        sw.stop();
        if (!mounted) return;
        setState(() {
          _recording = false;
          _audioPath = path;
          _asrResult = asr;
          _result = translation;
          _translationDuration = sw.elapsed;
          _busy = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _recording = false;
          _busy = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not process the recording. Please try again.')),
        );
      }
      return;
    }

    final allowed = await _recorder.hasPermission();
    if (!allowed) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission is required.')),
      );
      return;
    }

    final dir = await getTemporaryDirectory();
    final path = p.join(
        dir.path, 'eduvaani_voice_${DateTime.now().millisecondsSinceEpoch}.m4a');
    await _recorder.start(const RecordConfig(), path: path);
    _pulseCtrl.repeat(reverse: true);
    setState(() {
      _recording = true;
      _audioPath = null;
      _result = null;
      _asrResult = null;
      _ttsResult = null;
      _translationDuration = null;
    });
  }

  Future<void> _play() async {
    final path = _audioPath;
    if (path == null) return;
    await _player.setFilePath(path);
    await _player.play();
  }

  Future<void> _playSantaliAudio() async {
    final text = _result?.output ?? '';
    if (text.isEmpty) return;
    setState(() => _busy = true);
    try {
      final output = await _ttsService.synthesizeSantali(text);
      await _player.setFilePath(output.audioPath);
      await _player.play();
      if (!mounted) return;
      setState(() => _ttsResult = output);
      final asr = _asrResult;
      final trans = _translationDuration;
      if (asr != null && trans != null) {
        final total = asr.duration + trans + output.duration;
        await _benchmarkRepository.save(LatencyBenchmark(
          asrMs: asr.duration.inMilliseconds,
          translationMs: trans.inMilliseconds,
          ttsMs: output.duration.inMilliseconds,
          totalMs: total.inMilliseconds,
          recordedAt: DateTime.now(),
        ));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to create Santali demo audio.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
            backgroundColor: AppColors.cardVoice,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                    gradient: AppGradients.card(AppColors.cardVoice)),
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
                          child: const Icon(Icons.mic_rounded,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Voice Translator',
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
                // Demo info
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
                          'Demo mode: select the phrase you will say, then record.',
                          style: TextStyle(
                              color: AppColors.info,
                              fontSize: 12,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // ── Mic button ──────────────────────────
                Center(
                  child: Column(
                    children: [
                      _MicButton(
                        recording: _recording,
                        busy: _busy,
                        pulseAnim: _pulseAnim,
                        onTap: _busy ? null : _toggleRecord,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _RecordingStatus(
                          recording: _recording, audioPath: _audioPath),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Play recording button
                if (_audioPath != null && !_recording)
                  OutlinedButton.icon(
                    onPressed: _play,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Play recording'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),

                // ── Phrase selector ─────────────────────
                const SizedBox(height: AppSpacing.lg),
                Text('Select demo phrase',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Mock ASR will return this Hindi transcript.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: TranslationService.phrases.map((phrase) {
                    final sel = _selectedPhrase.hindi == phrase.hindi;
                    return GestureDetector(
                      onTap: _recording || _busy
                          ? null
                          : () => setState(() => _selectedPhrase = phrase),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel
                              ? AppColors.cardVoice
                              : Colors.white,
                          borderRadius:
                              BorderRadius.circular(AppRadius.full),
                          border: Border.all(
                            color: sel
                                ? AppColors.cardVoice
                                : AppColors.border,
                          ),
                          boxShadow: sel ? AppShadows.colored(AppColors.cardVoice) : null,
                        ),
                        child: Text(
                          phrase.hindi,
                          style: TextStyle(
                            color: sel
                                ? Colors.white
                                : AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                // ── ASR result card ─────────────────────
                if (_asrResult != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _ResultCard(
                    icon: Icons.record_voice_over_rounded,
                    label: 'Recognised Speech',
                    accentColor: AppColors.info,
                    badge: StatusChip(
                      label:
                          '${_asrResult!.duration.inMilliseconds} ms · ASR',
                      style: ChipStyle.info,
                      icon: Icons.timer_rounded,
                    ),
                    child: Text(
                      _asrResult!.transcript,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],

                // ── Translation result ──────────────────
                if (_result != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _ResultCard(
                    icon: Icons.translate_rounded,
                    label: 'Santali Translation',
                    accentColor: AppColors.teal,
                    badge: _translationDuration != null
                        ? StatusChip(
                            label:
                                '${_translationDuration!.inMilliseconds} ms · translate',
                            style: ChipStyle.success,
                            icon: Icons.timer_rounded,
                          )
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hindi',
                            style: Theme.of(context).textTheme.titleSmall),
                        Text(_result!.source),
                        const SizedBox(height: AppSpacing.sm),
                        Text('Santali',
                            style: Theme.of(context).textTheme.titleSmall),
                        Text(
                          _result!.output,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(color: AppColors.teal),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Play Santali audio button
                  PrimaryButton(
                    label: _busy ? 'Generating Santali audio…' : 'Play Santali Audio',
                    icon: Icons.volume_up_rounded,
                    color: AppColors.teal,
                    loading: _busy,
                    onPressed: _busy ? null : _playSantaliAudio,
                  ),
                ],

                // ── Latency card ────────────────────────
                if (_asrResult != null &&
                    _translationDuration != null &&
                    _ttsResult != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _LatencyCard(
                    asrMs: _asrResult!.duration.inMilliseconds,
                    translationMs: _translationDuration!.inMilliseconds,
                    ttsMs: _ttsResult!.duration.inMilliseconds,
                  ),
                ],

                const SizedBox(height: AppSpacing.xl),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mic button ────────────────────────────────

class _MicButton extends StatelessWidget {
  const _MicButton({
    required this.recording,
    required this.busy,
    required this.pulseAnim,
    required this.onTap,
  });

  final bool recording;
  final bool busy;
  final Animation<double> pulseAnim;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = recording ? AppColors.error : AppColors.cardVoice;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: pulseAnim,
        builder: (_, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulse ring (only when recording)
              if (recording)
                Container(
                  width: 100 * pulseAnim.value,
                  height: 100 * pulseAnim.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.15),
                  ),
                ),
              // Inner ring
              if (recording)
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.2),
                  ),
                ),
              // Main button
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      color,
                      Color.lerp(color, Colors.black, 0.2)!,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: AppShadows.colored(color),
                ),
                child: busy
                    ? const Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : Icon(
                        recording ? Icons.stop_rounded : Icons.mic_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Recording status ──────────────────────────

class _RecordingStatus extends StatelessWidget {
  const _RecordingStatus({required this.recording, required this.audioPath});
  final bool recording;
  final String? audioPath;

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color color;

    if (recording) {
      label = '● Recording… speak in Hindi';
      color = AppColors.error;
    } else if (audioPath != null) {
      label = '✓ Clip saved on this device';
      color = AppColors.success;
    } else {
      label = 'Tap the mic to start recording';
      color = AppColors.textHint;
    }

    return Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

// ── Generic result card ───────────────────────

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.icon,
    required this.label,
    required this.accentColor,
    required this.child,
    this.badge,
  });

  final IconData icon;
  final String label;
  final Color accentColor;
  final Widget child;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.lg),
                topRight: Radius.circular(AppRadius.lg),
              ),
              border: Border(
                  bottom:
                      BorderSide(color: accentColor.withValues(alpha: 0.15))),
            ),
            child: Row(
              children: [
                Icon(icon, size: 15, color: accentColor),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                ),
                const Spacer(),
                if (badge != null) badge!,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ── Latency summary card ──────────────────────

class _LatencyCard extends StatelessWidget {
  const _LatencyCard({
    required this.asrMs,
    required this.translationMs,
    required this.ttsMs,
  });

  final int asrMs;
  final int translationMs;
  final int ttsMs;

  @override
  Widget build(BuildContext context) {
    final totalMs = asrMs + translationMs + ttsMs;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.speed_rounded,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Pipeline Latency',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _LatencyItem(label: 'ASR', ms: asrMs, color: AppColors.info),
              _LatencyItem(
                  label: 'Translate',
                  ms: translationMs,
                  color: AppColors.cardVoice),
              _LatencyItem(label: 'TTS', ms: ttsMs, color: AppColors.teal),
              _LatencyItem(
                  label: 'Total',
                  ms: totalMs,
                  color: AppColors.primary,
                  bold: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _LatencyItem extends StatelessWidget {
  const _LatencyItem(
      {required this.label,
      required this.ms,
      required this.color,
      this.bold = false});
  final String label;
  final int ms;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '${ms}ms',
            style: TextStyle(
              fontSize: bold ? 16 : 14,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }
}
