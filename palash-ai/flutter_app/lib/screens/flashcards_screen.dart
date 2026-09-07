import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../core/app_theme.dart';
import '../services/flashcard_service.dart';
import '../widgets/app_widgets.dart';

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  final FlashcardService _service = FlashcardService();
  Uint8List? _pdf;
  bool _generating = false;

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      final pdf = await _service.buildPdf();
      if (mounted) setState(() => _pdf = pdf);
    } finally {
      if (mounted) setState(() => _generating = false);
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
            backgroundColor: AppColors.cardFlashcard,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                    gradient: AppGradients.card(AppColors.cardFlashcard)),
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
                          child: const Icon(Icons.style_rounded,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Flashcard Generator',
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
                // Topic card
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.cardFlashcard.withValues(alpha: 0.08),
                        AppColors.cardFlashcard.withValues(alpha: 0.03),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                        color: AppColors.cardFlashcard.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.cardFlashcard.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: const Icon(Icons.looks_one_rounded,
                            color: AppColors.cardFlashcard, size: 28),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Numbers 1–10',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(color: AppColors.cardFlashcard),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '10 bilingual cards · Hindi + Santali',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      PillBadge(
                          text: '10 cards',
                          color: AppColors.cardFlashcard),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Validation warning
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: AppColors.warning, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Prototype cards require native-speaker validation.',
                          style: TextStyle(
                              color: AppColors.warning,
                              fontSize: 12,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Mini card preview strip
                Text('Card Preview',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: 80,
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [Colors.transparent, Colors.black],
                      stops: [0.0, 0.12],
                    ).createShader(bounds),
                    blendMode: BlendMode.dstIn,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(right: AppSpacing.lg),
                      itemCount: 10,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: AppSpacing.sm),
                      itemBuilder: (_, i) => _MiniCard(number: i + 1),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Generate button
                PrimaryButton(
                  label: _generating ? 'Generating…' : 'Generate 10 Flashcards',
                  icon: Icons.style_rounded,
                  color: AppColors.cardFlashcard,
                  loading: _generating,
                  onPressed: _generating ? null : _generate,
                ),

                if (_pdf != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Text('Preview',
                          style: Theme.of(context).textTheme.titleMedium),
                      const Spacer(),
                      StatusChip(
                          label: 'Ready',
                          style: ChipStyle.success,
                          icon: Icons.check_circle_rounded),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    height: 520,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.border),
                      boxShadow: AppShadows.sm,
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: PdfPreview(
                      build: (_) async => _pdf!,
                      allowPrinting: false,
                      allowSharing: false,
                      canChangeOrientation: false,
                      canChangePageFormat: false,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              Printing.layoutPdf(onLayout: (_) async => _pdf!),
                          icon: const Icon(Icons.print_rounded),
                          label: const Text('Print'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.cardFlashcard,
                            side: const BorderSide(
                                color: AppColors.cardFlashcard, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => Printing.sharePdf(
                            bytes: _pdf!,
                            filename: 'eduvaani_numbers_flashcards.pdf',
                          ),
                          icon: const Icon(Icons.save_alt_rounded),
                          label: const Text('Save / Share'),
                          style: FilledButton.styleFrom(
                              backgroundColor: AppColors.cardFlashcard),
                        ),
                      ),
                    ],
                  ),
                ],
                SizedBox(
                    height:
                        AppSpacing.xl + MediaQuery.paddingOf(context).bottom),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mini card ─────────────────────────────────

class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.number});
  final int number;

  static const _hindiNumerals = [
    '१', '२', '३', '४', '५', '६', '७', '८', '९', '१०'
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.cardFlashcard,
            Color.lerp(AppColors.cardFlashcard, Colors.orange, 0.4)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.colored(AppColors.cardFlashcard),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$number',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            _hindiNumerals[number - 1],
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
