import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../database/database_helper.dart';
import '../models/lesson.dart';
import '../widgets/app_widgets.dart';
import 'lesson_detail_screen.dart';

class LessonsScreen extends StatefulWidget {
  const LessonsScreen({super.key});

  @override
  State<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends State<LessonsScreen> {
  String _grade = '';
  String _subject = '';
  List<String> _grades = [];
  List<String> _subjects = [];
  List<Lesson> _lessons = [];
  Set<int> _completedLessonIds = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final db = DatabaseHelper.instance;
      final grades = await db.getGrades();
      final subjects = await db.getSubjects();
      final lessons = await db.getLessons(
        grade: _grade.isEmpty ? null : _grade,
        subject: _subject.isEmpty ? null : _subject,
      );
      final completedLessonIds = await db.getCompletedLessonIds();
      if (!mounted) return;
      setState(() {
        _grades = grades;
        _subjects = subjects;
        _lessons = lessons;
        _completedLessonIds = completedLessonIds;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load lessons from the local database.';
        _loading = false;
      });
    }
  }

  Future<void> _toggleCompletion(Lesson lesson) async {
    if (lesson.id == null) return;
    final completed = await DatabaseHelper.instance.toggleLessonCompletion(lesson.id!);
    if (!mounted) return;
    setState(() {
      if (completed) {
        _completedLessonIds.add(lesson.id!);
      } else {
        _completedLessonIds.remove(lesson.id!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          // ── Gradient app bar ──────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 140,
            backgroundColor: AppColors.cardLessons,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: AppGradients.card(AppColors.cardLessons),
                ),
                child: Padding(
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
                            child: const Icon(Icons.menu_book_rounded,
                                color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Lessons',
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
          ),

          // ── Filter row ────────────────────────────────
          SliverPersistentHeader(
            pinned: true,
            delegate: _FilterHeaderDelegate(
              grades: _grades,
              subjects: _subjects,
              selectedGrade: _grade,
              selectedSubject: _subject,
              onGradeChanged: (v) {
                setState(() => _grade = v ?? '');
                _load();
              },
              onSubjectChanged: (v) {
                setState(() => _subject = v ?? '');
                _load();
              },
            ),
          ),
        ],
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const LoadingState(message: 'Loading lessons…');
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Something went wrong',
        subtitle: _error,
      );
    }
    if (_lessons.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No lessons found',
        subtitle: 'Try changing the grade or subject filter.',
      );
    }

    final sequences = <String, List<Lesson>>{};
    for (final lesson in _lessons) {
      final key = '${lesson.grade}|${lesson.subject}';
      sequences.putIfAbsent(key, () => []).add(lesson);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
      children: [
        for (final sequence in sequences.values) ...[
          _SubjectSequenceHeader(
            grade: sequence.first.grade,
            subject: sequence.first.subject,
            lessonCount: sequence.length,
            color: sequence.first.subjectColor,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final lesson in sequence) ...[
            _LessonTile(
              lesson: lesson,
              step: lesson.sequenceNumber,
              totalSteps: sequence.length,
              isComplete: lesson.id != null && _completedLessonIds.contains(lesson.id),
              onCompletionChanged: () => _toggleCompletion(lesson),
              onTap: () => Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                      builder: (_) => LessonDetailScreen(lesson: lesson),
                    ),
                  )
                  .then((_) => _load()),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

// ── Filter persistent header ──────────────────

class _FilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _FilterHeaderDelegate({
    required this.grades,
    required this.subjects,
    required this.selectedGrade,
    required this.selectedSubject,
    required this.onGradeChanged,
    required this.onSubjectChanged,
  });

  final List<String> grades;
  final List<String> subjects;
  final String selectedGrade;
  final String selectedSubject;
  final ValueChanged<String?> onGradeChanged;
  final ValueChanged<String?> onSubjectChanged;

  @override
  double get minExtent => 128;
  @override
  double get maxExtent => 128;

  @override
  bool shouldRebuild(_FilterHeaderDelegate old) =>
      old.selectedGrade != selectedGrade ||
      old.selectedSubject != selectedSubject ||
      old.grades != grades ||
      old.subjects != subjects;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final gradeFilter = _FilterDropdown(
      label: 'Grade',
      value: selectedGrade,
      items: grades,
      onChanged: onGradeChanged,
    );
    final subjectFilter = _FilterDropdown(
      label: 'Subject',
      value: selectedSubject,
      items: subjects,
      onChanged: onSubjectChanged,
    );

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 480) {
            return Column(
              children: [
                gradeFilter,
                const SizedBox(height: AppSpacing.sm),
                subjectFilter,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: gradeFilter),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: subjectFilter),
            ],
          );
        },
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        filled: true,
        fillColor: AppColors.surfaceCard,
      ),
      items: [
        const DropdownMenuItem(
            value: '',
            child: Text('All', style: TextStyle(color: AppColors.textPrimary))),
        ...items.map((v) => DropdownMenuItem(
            value: v,
            child: Text(v, style: const TextStyle(color: AppColors.textPrimary)))),
      ],
      onChanged: onChanged,
    );
  }
}

class _SubjectSequenceHeader extends StatelessWidget {
  const _SubjectSequenceHeader({
    required this.grade,
    required this.subject,
    required this.lessonCount,
    required this.color,
  });

  final String grade;
  final String subject;
  final int lessonCount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(subject,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
              Text('$grade · $lessonCount-step sequence',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textHint)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Lesson tile ───────────────────────────────

class _LessonTile extends StatelessWidget {
  const _LessonTile({
    required this.lesson,
    required this.step,
    required this.totalSteps,
    required this.isComplete,
    required this.onCompletionChanged,
    required this.onTap,
  });

  final Lesson lesson;
  final int step;
  final int totalSteps;
  final bool isComplete;
  final VoidCallback onCompletionChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.sm,
        ),
        child: Row(
          children: [
            // Icon accent
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: lesson.subjectColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(lesson.topicIcon,
                  color: lesson.subjectColor, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.topic,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Step $step of $totalSteps · ${lesson.durationLabel}',
                    style: TextStyle(
                      color: lesson.subjectColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lesson.grade,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Completion control + chevron
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: onCompletionChanged,
                  tooltip: isComplete ? 'Mark as not taught' : 'Mark as taught',
                  icon: Icon(
                    isComplete
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: isComplete ? AppColors.success : AppColors.textHint,
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textHint, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
