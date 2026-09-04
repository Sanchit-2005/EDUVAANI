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
      if (!mounted) return;
      setState(() {
        _grades = grades;
        _subjects = subjects;
        _lessons = lessons;
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

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
      itemCount: _lessons.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) {
        final lesson = _lessons[i];
        return _LessonTile(
          lesson: lesson,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LessonDetailScreen(lesson: lesson),
            ),
          ),
        );
      },
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
  double get minExtent => 72;
  @override
  double get maxExtent => 72;

  @override
  bool shouldRebuild(_FilterHeaderDelegate old) =>
      old.selectedGrade != selectedGrade ||
      old.selectedSubject != selectedSubject ||
      old.grades != grades ||
      old.subjects != subjects;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      height: 72,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: _FilterDropdown(
              label: 'Grade',
              value: selectedGrade,
              items: grades,
              onChanged: onGradeChanged,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _FilterDropdown(
              label: 'Subject',
              value: selectedSubject,
              items: subjects,
              onChanged: onSubjectChanged,
            ),
          ),
        ],
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

// ── Lesson tile ───────────────────────────────

class _LessonTile extends StatelessWidget {
  const _LessonTile({required this.lesson, required this.onTap});
  final Lesson lesson;
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
                color: AppColors.cardLessons.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(Icons.menu_book_rounded,
                  color: AppColors.cardLessons, size: 24),
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
                    '${lesson.grade} · ${lesson.subject}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Badge + chevron
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (lesson.isPrototypeTranslation)
                  const PillBadge(
                      text: 'Prototype',
                      color: AppColors.warning),
                const SizedBox(height: 4),
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
