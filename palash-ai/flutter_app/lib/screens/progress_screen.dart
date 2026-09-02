import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/progress_record.dart';
import '../repositories/progress_repository.dart';
import '../widgets/app_widgets.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final ProgressRepository _repository = ProgressRepository();
  ProgressRecord? _progress;
  bool _loading = true;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final progress = await _repository.getGradeOneProgress();
      if (mounted) setState(() => _progress = progress);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to load local progress.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _completeLesson() async {
    final progress = _progress;
    if (progress == null) return;
    setState(() => _updating = true);
    try {
      final updated = await _repository.completeNextLesson(progress);
      if (mounted) setState(() => _progress = updated);
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: const LoadingState(message: 'Loading progress…'),
      );
    }

    final progress = _progress;
    if (progress == null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(title: const Text('Progress')),
        body: const EmptyState(
          icon: Icons.bar_chart_rounded,
          title: 'Progress unavailable',
          subtitle: 'Could not load data from the local database.',
        ),
      );
    }

    final lessonFraction =
        progress.lessonsCompleted / progress.totalLessons;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          // ── Gradient app bar ──────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 140,
            backgroundColor: AppColors.cardProgress,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                    gradient: AppGradients.card(AppColors.cardProgress)),
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
                          child: const Icon(Icons.bar_chart_rounded,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Progress Dashboard',
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
                // ── Class overview card ─────────────────
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.cardProgress.withValues(alpha: 0.08),
                        AppColors.teal.withValues(alpha: 0.04),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                        color: AppColors.cardProgress.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  progress.className,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(color: AppColors.cardProgress),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${progress.students} students enrolled',
                                  style:
                                      Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          _CircularStat(
                            value: lessonFraction,
                            label: '${progress.lessonsCompleted}/${progress.totalLessons}',
                            sublabel: 'lessons',
                            color: AppColors.cardProgress,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      LabelledProgress(
                        label: 'Lesson completion',
                        value: lessonFraction,
                        color: AppColors.cardProgress,
                        trailing:
                            '${progress.lessonsCompleted} / ${progress.totalLessons}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Quick stats ─────────────────────────
                Text('Subject Performance',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: MetricTile(
                        label: 'Literacy',
                        value: '${progress.literacyPercent}%',
                        icon: Icons.menu_book_rounded,
                        color: AppColors.cardLessons,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: MetricTile(
                        label: 'Numeracy',
                        value: '${progress.numeracyPercent}%',
                        icon: Icons.calculate_rounded,
                        color: AppColors.info,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: MetricTile(
                        label: 'Vocabulary',
                        value: '${progress.vocabularyPercent}%',
                        icon: Icons.abc_rounded,
                        color: AppColors.teal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Detailed progress bars ──────────────
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.border),
                    boxShadow: AppShadows.sm,
                  ),
                  child: Column(
                    children: [
                      LabelledProgress(
                        label: 'Literacy',
                        value: progress.literacyPercent / 100,
                        color: AppColors.cardLessons,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      LabelledProgress(
                        label: 'Numeracy',
                        value: progress.numeracyPercent / 100,
                        color: AppColors.info,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      LabelledProgress(
                        label: 'Vocabulary',
                        value: progress.vocabularyPercent / 100,
                        color: AppColors.teal,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Complete lesson button ──────────────
                PrimaryButton(
                  label: _updating
                      ? 'Saving…'
                      : progress.lessonsCompleted == progress.totalLessons
                          ? 'All Lessons Complete!'
                          : 'Mark Next Lesson Complete',
                  icon: Icons.check_circle_rounded,
                  color: AppColors.cardProgress,
                  loading: _updating,
                  onPressed: (_updating ||
                          progress.lessonsCompleted ==
                              progress.totalLessons)
                      ? null
                      : _completeLesson,
                ),
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: Text(
                    'Saved locally · Syncs when online',
                    style: Theme.of(context).textTheme.bodySmall,
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

// ── Circular stat widget ──────────────────────

class _CircularStat extends StatelessWidget {
  const _CircularStat({
    required this.value,
    required this.label,
    required this.sublabel,
    required this.color,
  });

  final double value;
  final String label;
  final String sublabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: value,
            strokeWidth: 6,
            color: color,
            backgroundColor: color.withValues(alpha: 0.15),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text(
                  sublabel,
                  style: const TextStyle(fontSize: 9, color: AppColors.textHint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
