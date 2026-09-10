import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../core/app_theme.dart';
import '../ml/on_device_services.dart';
import '../ml/santali_phoneme_map.dart';
import '../models/latency_benchmark.dart';
import '../repositories/benchmark_repository.dart';
import '../services/speech_recognition_service.dart';
import '../services/text_to_speech_service.dart';
import '../services/translation_service.dart';
import '../widgets/app_widgets.dart';

enum VoicePipelineStage {
  idle,
  listening,
  transcribing,
  translating,
  generatingAudio,
  playing,
  ready,
}

class VoiceTranslatorScreen extends StatefulWidget {
  const VoiceTranslatorScreen({super.key});

  @override
  State<VoiceTranslatorScreen> createState() => _VoiceTranslatorScreenState();
}

class _VoiceTranslatorScreenState extends State<VoiceTranslatorScreen>
    with SingleTickerProviderStateMixin {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  final OnDeviceASRService _asrService = OnDeviceASRService();
  final OnDeviceTTSService _ttsService = OnDeviceTTSService();
  final OnDeviceTranslationService _onDeviceTranslation = OnDeviceTranslationService();
  final BenchmarkRepository _benchmarkRepository = BenchmarkRepository();
  final TextEditingController _hindiController = TextEditingController();

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
  VoicePipelineStage _stage = VoicePipelineStage.idle;
  int _speakerId = 0; // 0: Female (Priyamvada), 1: Male (Rohan)

  final bool _useOnDevice = !kIsWeb;
  bool _isAsrModelInstalled = false;
  bool _isTtsModelInstalled = false;
  bool _isMaleTtsAvailable = false;
  bool _isFemaleTtsAvailable = false;

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
    _checkModelAvailability();
  }

  Future<void> _checkModelAvailability() async {
    final asrReady = await _asrService.isModelAvailable();
    final ttsReady = await _ttsService.isModelAvailable();
    final maleReady = await _ttsService.isMaleModelAvailable();
    final femaleReady = await _ttsService.isFemaleModelAvailable();
    if (mounted) {
      setState(() {
        _isAsrModelInstalled = asrReady;
        _isTtsModelInstalled = ttsReady;
        _isMaleTtsAvailable = maleReady;
        _isFemaleTtsAvailable = femaleReady;
      });
    }
  }

  @override
  void dispose() {
    _recorder.dispose();
    _player.dispose();
    _pulseCtrl.dispose();
    _hindiController.dispose();
    _asrService.dispose();
    _ttsService.dispose();
    super.dispose();
  }

  Future<void> _toggleRecord() async {
    if (_recording) {
      try {
        final path = await _recorder.stop();
        _pulseCtrl.stop();
        if (!mounted) return;
        setState(() {
          _recording = false;
          _audioPath = path;
        });

        if (path == null) throw StateError('No audio recorded.');
        await _runPipelineFromAudio(path);
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _recording = false;
          _busy = false;
          _stage = VoicePipelineStage.idle;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not process the recording: $error')),
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
      dir.path,
      'eduvaani_voice_${DateTime.now().millisecondsSinceEpoch}.wav',
    );

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );

    _pulseCtrl.repeat(reverse: true);
    setState(() {
      _recording = true;
      _stage = VoicePipelineStage.listening;
      _audioPath = null;
      _result = null;
      _asrResult = null;
      _ttsResult = null;
      _translationDuration = null;
      _hindiController.clear();
    });
  }

  Future<void> _runPipelineFromAudio(String audioPath) async {
    setState(() {
      _stage = VoicePipelineStage.transcribing;
      _busy = true;
      _asrResult = null;
      _result = null;
      _ttsResult = null;
      _translationDuration = null;
    });

    try {
      // ── Step 1: Hindi ASR (Offline via Sherpa-ONNX) ───────────────────
      final asr = await _asrService.transcribeHindi(
        audioPath,
        demoTranscript: _selectedPhrase.hindi,
      );

      if (!mounted) return;
      _hindiController.text = asr.transcript;
      setState(() {
        _asrResult = asr;
      });

      // ── Steps 2 & 3: Translation and Speech Synthesis ───────────────────
      await _translateAndSynthesize(asr.transcript);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _stage = VoicePipelineStage.idle;
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Speech recognition failed: $error')),
      );
    }
  }

  Future<void> _translateAndSynthesize(String hindiText) async {
    final text = hindiText.trim();
    if (text.isEmpty) {
      setState(() {
        _stage = VoicePipelineStage.idle;
        _busy = false;
      });
      return;
    }

    setState(() {
      _stage = VoicePipelineStage.translating;
      _busy = true;
    });

    try {
      // ── Step 2: MT (IndicTrans2 offline on Android) ────────────────────
      final swTrans = Stopwatch()..start();
      TranslationResult translation;
      if (_useOnDevice) {
        try {
          translation = await _onDeviceTranslation.translate(
            text: text,
            sourceLanguage: 'hin_Deva',
            targetLanguage: 'sat_Olck',
          );
        } catch (_) {
          // Sync dictionary fallback if native channel unavailable (e.g. tests)
          translation = TranslationService.instance.hindiToSantali(text);
        }
      } else {
        translation = await TranslationService.instance.translate(
          text: text,
          sourceLanguage: 'hin_Deva',
          targetLanguage: 'sat_Olck',
        );
      }
      swTrans.stop();

      if (!mounted) return;
      setState(() {
        _result = translation;
        _translationDuration = swTrans.elapsed;
        _stage = VoicePipelineStage.generatingAudio;
      });

      // ── Step 3: TTS (Option A: Ol Chiki -> Hindi Phonemes -> Offline TTS)
      if (!_isTtsModelInstalled) {
        if (!mounted) return;
        setState(() {
          _ttsResult = null;
          _stage = VoicePipelineStage.ready;
          _busy = false;
        });
      } else {
        try {
          final output = await _ttsService.synthesizeSantali(
            translation.output,
            speakerId: _speakerId,
            speed: 1.0,
            fallbackToDemo: false,
          );

          if (!mounted) return;
          setState(() {
            _ttsResult = output;
            _stage = VoicePipelineStage.playing;
            _busy = false;
          });

          // ── Step 4: Audio Playback (asynchronous) ───────────────────────────
          if (output.audioPath.isNotEmpty) {
            try {
              await _player.setFilePath(output.audioPath);
              _player.play().catchError((_) {});
            } catch (_) {
              // In headless tests or unsupported devices, audio playback fails gracefully
            }
          }

          // ── Latency Benchmarking ──────────────────────────────────────────
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
        } catch (e, st) {
          debugPrint('[VoiceTranslator] TTS step synthesis error: $e\n$st');
          if (!mounted) return;
          setState(() {
            _ttsResult = null;
            _stage = VoicePipelineStage.ready;
            _busy = false;
          });
        }
      }

      if (!mounted) return;
      setState(() {
        _stage = VoicePipelineStage.ready;
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _stage = VoicePipelineStage.ready;
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Translation or speech error: $error')),
      );
    }
  }

  Future<void> _playOriginalRecording() async {
    final path = _audioPath;
    if (path == null) return;
    try {
      await _player.setFilePath(path);
      await _player.play();
    } catch (_) {}
  }

  Future<void> _playSantaliAudio() async {
    final text = _result?.output ?? '';
    if (text.isEmpty) return;

    if (!_isTtsModelInstalled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'TTS model not installed. Download it from Model Settings to hear Santali audio.',
          ),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    final cachedPath = _ttsResult?.audioPath;
    if (cachedPath != null && cachedPath.isNotEmpty && !(_ttsResult?.isMock ?? true)) {
      try {
        await _player.setFilePath(cachedPath);
        await _player.play();
        return;
      } catch (_) {}
    }

    setState(() => _busy = true);
    try {
      final output = await _ttsService.synthesizeSantali(
        text,
        speakerId: _speakerId,
        speed: 1.0,
        fallbackToDemo: false,
      );
      await _player.setFilePath(output.audioPath);
      await _player.play();
      if (!mounted) return;
      setState(() => _ttsResult = output);
    } catch (e, st) {
      debugPrint('[VoiceTranslator] _playSantaliAudio error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kIsWeb
                ? 'Santali TTS is only available in the Android app.'
                : 'Santali audio synthesis failed: $e',
          ),
          duration: const Duration(seconds: 5),
        ),
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
                  gradient: AppGradients.card(AppColors.cardVoice),
                ),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.lg,
                ),
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
                          child: const Icon(
                            Icons.mic_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Offline Voice Translator',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
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
                // ── Pipeline Info Banner ──────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm + 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: AppColors.info.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.offline_bolt_rounded,
                        color: AppColors.info,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isAsrModelInstalled && _isTtsModelInstalled
                              ? 'Fully Offline Voice Pipeline Active (ASR + MT + TTS)'
                              : 'Offline Voice Pipeline · Option A Phonetic Fallback Ready',
                          style: const TextStyle(
                            color: AppColors.info,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // ── Mic Button & Stage Status ─────────────────────────
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
                        stage: _stage,
                        audioPath: _audioPath,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Play User Voice Button ─────────────────────────────
                if (_audioPath != null && !_recording)
                  OutlinedButton.icon(
                    onPressed: _playOriginalRecording,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Play original recording (Hindi)'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44),
                    ),
                  ),

                // ── Voice Speaker Gender Selector ─────────────────────
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    runAlignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.record_voice_over_rounded,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Voice Speaker:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ChoiceChip(
                            avatar: const Icon(Icons.female_rounded, size: 16),
                            label: const Text('Female (Priyamvada)', style: TextStyle(fontSize: 12)),
                            selected: _speakerId == 0,
                            onSelected: _busy
                                ? null
                                : (sel) {
                                    if (sel) {
                                      setState(() => _speakerId = 0);
                                      if (_result != null) {
                                        _translateAndSynthesize(_hindiController.text);
                                      }
                                    }
                                  },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            avatar: const Icon(Icons.male_rounded, size: 16),
                            label: Text(
                              _isMaleTtsAvailable ? 'Male (Rohan)' : 'Male (Coming Soon)',
                              style: TextStyle(
                                fontSize: 12,
                                color: _isMaleTtsAvailable ? null : AppColors.textSecondary,
                              ),
                            ),
                            selected: _speakerId == 1,
                            onSelected: _busy
                                ? null
                                : (sel) {
                                    if (sel) {
                                      if (!_isMaleTtsAvailable) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Male voice (Rohan) is coming soon / not installed yet.'),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                      setState(() => _speakerId = 1);
                                      if (_result != null) {
                                        _translateAndSynthesize(_hindiController.text);
                                      }
                                    }
                                  },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Demo Phrase Quick Picker ──────────────────────────
                const SizedBox(height: AppSpacing.lg),
                const Text(
                  'Or pick classroom phrase',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Tap a phrase to quickly populate and run the voice pipeline.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: TranslationService.phrases.map((phrase) {
                    final sel = _selectedPhrase.hindi == phrase.hindi;
                    return GestureDetector(
                      key: ValueKey(phrase.id),
                      onTap: _recording || _busy
                          ? null
                          : () {
                              setState(() {
                                _selectedPhrase = phrase;
                                _hindiController.text = phrase.hindi;
                              });
                              _translateAndSynthesize(phrase.hindi);
                            },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: sel
                              ? AppColors.cardVoice
                              : AppColors.surfaceCard,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          border: Border.all(
                            color: sel
                                ? AppColors.cardVoice
                                : AppColors.border,
                          ),
                          boxShadow: sel
                              ? AppShadows.colored(AppColors.cardVoice)
                              : null,
                        ),
                        child: Text(
                          phrase.hindi,
                          style: TextStyle(
                            color: sel ? Colors.white : AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                // ── ASR Result Card (Editable Hindi Transcript) ───────
                if (_asrResult != null || _hindiController.text.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _ResultCard(
                    icon: Icons.record_voice_over_rounded,
                    label: 'Recognised Speech (Hindi)',
                    accentColor: AppColors.info,
                    badge: _asrResult != null
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              StatusChip(
                                label:
                                    '${_asrResult!.duration.inMilliseconds} ms · ${_asrResult!.isMock ? "ASR" : "Offline ASR"}',
                                style: ChipStyle.info,
                                icon: Icons.timer_rounded,
                              ),
                              // Show "corrected" badge when fuzzy matcher fired
                              if (!_asrResult!.isMock &&
                                  _asrResult!.rawTranscript != _asrResult!.transcript) ...[
                                const SizedBox(width: 4),
                                StatusChip(
                                  label: 'corrected',
                                  style: ChipStyle.success,
                                  icon: Icons.auto_fix_high_rounded,
                                ),
                              ],
                            ],
                          )
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _hindiController,
                          maxLines: null,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            hintText: 'Edit Hindi transcription...',
                            hintStyle: TextStyle(
                              color: AppColors.textSecondary.withValues(alpha: 0.6),
                              fontSize: 16,
                            ),
                          ),
                        ),
                        // Raw CTC output — only visible when correction was applied
                        if (_asrResult != null &&
                            !_asrResult!.isMock &&
                            _asrResult!.rawTranscript != _asrResult!.transcript) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.mic_none_rounded,
                                size: 11,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Raw ASR: "${_asrResult!.rawTranscript}"',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Tap text to edit & re-translate',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _translateAndSynthesize(
                                        _hindiController.text,
                                      ),
                              icon: const Icon(Icons.sync_rounded, size: 16),
                              label: const Text(
                                'Re-translate',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.info,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],


                // ── Santali Translation Result Card ───────────────────
                if (_result != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _ResultCard(
                    icon: Icons.translate_rounded,
                    label: 'Santali Translation',
                    accentColor: AppColors.teal,
                    badge: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_translationDuration != null)
                          StatusChip(
                            label:
                                '${_translationDuration!.inMilliseconds} ms · MT',
                            style: ChipStyle.success,
                            icon: Icons.timer_rounded,
                          ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(
                            Icons.copy_rounded,
                            size: 18,
                            color: AppColors.teal,
                          ),
                          tooltip: 'Copy Santali text',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: _result!.output),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Santali translation copied to clipboard.',
                                ),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Model badge
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.teal.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(AppRadius.xs),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.memory_rounded,
                                    size: 12,
                                    color: AppColors.teal,
                                  ),
                                  const SizedBox(width: 4),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 220),
                                    child: Text(
                                      _result!.model ?? 'IndicTrans2 (On-Device)',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.teal,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        SelectableText(
                          _result!.output,
                          style: const TextStyle(
                            color: AppColors.teal,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        // Option A Pronunciation Disclaimer
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(
                              color: AppColors.warning.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(top: 2),
                                    child: Icon(
                                      Icons.info_outline_rounded,
                                      size: 14,
                                      color: AppColors.warning,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Approximate pronunciation (Option A): Synthesized via Hindi phoneme mapping. Native Santali voice coming soon.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.warning,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Phonemes: ${santaliToHindiPhonemes(_result!.output)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Play Santali Audio Button
                  PrimaryButton(
                    label: _busy
                        ? 'Synthesizing Santali speech…'
                        : 'Replay Santali Speech',
                    icon: Icons.volume_up_rounded,
                    color: AppColors.teal,
                    loading: _busy,
                    onPressed: _busy ? null : _playSantaliAudio,
                  ),
                ],

                // ── Latency Summary Card ──────────────────────────────
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

                SizedBox(
                  height:
                      AppSpacing.xl + MediaQuery.paddingOf(context).bottom,
                ),
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
              if (recording)
                Container(
                  width: 100 * pulseAnim.value,
                  height: 100 * pulseAnim.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.15),
                  ),
                ),
              if (recording)
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.2),
                  ),
                ),
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

// ── Recording / Pipeline Status ───────────────

class _RecordingStatus extends StatelessWidget {
  const _RecordingStatus({
    required this.stage,
    required this.audioPath,
  });

  final VoicePipelineStage stage;
  final String? audioPath;

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color color;

    switch (stage) {
      case VoicePipelineStage.listening:
        label = '● Listening… hold a beat, then speak clearly in Hindi';
        color = AppColors.error;
        break;
      case VoicePipelineStage.transcribing:
        label = '⏳ Transcribing speech (offline ASR)…';
        color = AppColors.info;
        break;
      case VoicePipelineStage.translating:
        label = '⏳ Translating Hindi → Santali (IndicTrans2)…';
        color = AppColors.cardVoice;
        break;
      case VoicePipelineStage.generatingAudio:
        label = '⏳ Generating Santali speech (Option A TTS)…';
        color = AppColors.teal;
        break;
      case VoicePipelineStage.playing:
        label = '🔊 Playing Santali speech…';
        color = AppColors.success;
        break;
      case VoicePipelineStage.ready:
        label = '✓ Translation & speech ready';
        color = AppColors.success;
        break;
      case VoicePipelineStage.idle:
        label = audioPath != null
            ? '✓ Clip saved on this device'
            : 'Tap mic to speak (hold a beat before speaking)';
        color = audioPath != null ? AppColors.success : AppColors.textSecondary;
        break;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Text(
        label,
        key: ValueKey(label),
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Generic Result Card ───────────────────────

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
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.lg),
                topRight: Radius.circular(AppRadius.lg),
              ),
              border: Border(
                bottom: BorderSide(
                  color: accentColor.withValues(alpha: 0.15),
                ),
              ),
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
                ?badge,
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

// ── Latency Summary Card ──────────────────────

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
              const Icon(Icons.speed_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Pipeline Latency Breakdown',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _LatencyItem(label: 'ASR', ms: asrMs, color: AppColors.info),
              _LatencyItem(
                label: 'IndicTrans2',
                ms: translationMs,
                color: AppColors.cardVoice,
              ),
              _LatencyItem(label: 'TTS', ms: ttsMs, color: AppColors.teal),
              _LatencyItem(
                label: 'Total',
                ms: totalMs,
                color: AppColors.primary,
                bold: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LatencyItem extends StatelessWidget {
  const _LatencyItem({
    required this.label,
    required this.ms,
    required this.color,
    this.bold = false,
  });

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
            style: TextStyle(
              fontSize: 11,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
