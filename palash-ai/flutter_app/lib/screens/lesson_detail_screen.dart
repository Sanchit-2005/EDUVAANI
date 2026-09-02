import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/lesson.dart';
import '../widgets/app_widgets.dart';
import 'worksheet_screen.dart';

class LessonDetailScreen extends StatelessWidget {
  const LessonDetailScreen({super.key, required this.lesson});

  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          // ── Gradient hero ─────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 180,
            backgroundColor: AppColors.cardLessons,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: AppGradients.card(AppColors.cardLessons),
                    ),
                  ),
                  Positioned(
                    top: -20,
                    right: -20,
                    child: _Circle(size: 160, opacity: 0.12),
                  ),
                  Positioned(
                    bottom: 16,
                    left: AppSpacing.md,
                    right: AppSpacing.md,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          lesson.topic,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _WhiteChip(label: lesson.grade),
                            _WhiteChip(label: lesson.subject),
                            if (lesson.isPrototypeTranslation)
                              _WhiteChip(
                                  label: 'Prototype Santali',
                                  icon: Icons.warning_amber_rounded),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Content sections ──────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _ContentSection(
                  icon: Icons.emoji_objects_rounded,
                  label: 'Learning Outcome',
                  color: AppColors.info,
                  content: lesson.learningOutcome,
                ),
                const SizedBox(height: AppSpacing.md),
                _ContentSection(
                  icon: Icons.record_voice_over_rounded,
                  label: 'Teacher Instruction (Hindi)',
                  color: AppColors.cardVoice,
                  content: lesson.hindiInstruction,
                ),
                const SizedBox(height: AppSpacing.md),
                _ContentSection(
                  icon: Icons.translate_rounded,
                  label: 'Santali (Ol Chiki)',
                  color: AppColors.teal,
                  content: lesson.santaliTranslation ?? 'Not available yet.',
                  muted: lesson.santaliTranslation == null,
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── CTA button ────────────────────────
                PrimaryButton(
                  label: 'Create Worksheet',
                  icon: Icons.picture_as_pdf_rounded,
                  color: AppColors.cardWorksheet,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const WorksheetScreen()),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Content section card ──────────────────────

class _ContentSection extends StatelessWidget {
  const _ContentSection({
    required this.icon,
    required this.label,
    required this.color,
    required this.content,
    this.muted = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final String content;
  final bool muted;

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
          // Label row
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.lg),
                topRight: Radius.circular(AppRadius.lg),
              ),
              border: Border(
                  bottom: BorderSide(color: color.withValues(alpha: 0.15))),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              content,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: muted ? AppColors.textHint : AppColors.textPrimary,
                    fontStyle: muted ? FontStyle.italic : FontStyle.normal,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── White chip ────────────────────────────────

class _WhiteChip extends StatelessWidget {
  const _WhiteChip({required this.label, this.icon});
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: Colors.white),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({required this.size, required this.opacity});
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
            color: Colors.white.withValues(alpha: opacity), width: 1.5),
      ),
    );
  }
}
