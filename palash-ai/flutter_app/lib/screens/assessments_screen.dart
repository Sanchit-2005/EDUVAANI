import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/assessment.dart';
import '../repositories/assessment_repository.dart';
import '../services/translation_service.dart';
import '../widgets/app_widgets.dart';

class AssessmentsScreen extends StatefulWidget {
  const AssessmentsScreen({super.key});

  @override
  State<AssessmentsScreen> createState() => _AssessmentsScreenState();
}

class _AssessmentsScreenState extends State<AssessmentsScreen> {
  final AssessmentRepository _repository = AssessmentRepository();
  List<AssessmentQuestion> _questions = [];
  bool _saving = false;

  Future<void> _generate() async {
    setState(() => _saving = true);
    final items = _buildQuestions();
    try {
      await _repository.saveQuestions(items);
      if (mounted) setState(() => _questions = items);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save assessment locally.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<AssessmentQuestion> _buildQuestions() {
    const hindi = 'अब मिलकर गिनो।';
    final santali =
        TranslationService.instance.hindiToSantali(hindi).output;
    const common = 'Hindi: अब मिलकर गिनो।\nSantali: ';
    return [
      AssessmentQuestion(
        grade: 'Grade 1',
        subject: 'Foundational Numeracy',
        topic: 'Counting 1-10',
        questionNumber: 1,
        hindiText: '$common$santali\n\n1. वस्तुओं को गिनो: ● ● ●',
        santaliText: santali,
      ),
      AssessmentQuestion(
        grade: 'Grade 1',
        subject: 'Foundational Numeracy',
        topic: 'Counting 1-10',
        questionNumber: 2,
        hindiText: '$common$santali\n\n2. 4 के बाद कौन-सी संख्या आती है?',
        santaliText: santali,
      ),
      AssessmentQuestion(
        grade: 'Grade 1',
        subject: 'Foundational Numeracy',
        topic: 'Counting 1-10',
        questionNumber: 3,
        hindiText: '$common$santali\n\n3. संख्या को वस्तुओं से मिलाओ: 2, 5, 7',
        santaliText: santali,
      ),
    ];
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
            backgroundColor: AppColors.cardAssessment,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                    gradient: AppGradients.card(AppColors.cardAssessment)),
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
                          child: const Icon(Icons.quiz_rounded,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Assessment Generator',
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
                // Context card
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.border),
                    boxShadow: AppShadows.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Assessment Context',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(color: AppColors.textSecondary)),
                            const SizedBox(height: 8),
                            _ContextRow(icon: Icons.school_rounded,
                                label: 'Grade 1'),
                            _ContextRow(icon: Icons.calculate_rounded,
                                label: 'Foundational Numeracy'),
                            _ContextRow(icon: Icons.tag_rounded,
                                label: 'Counting 1-10'),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.cardAssessment.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '3',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: AppColors.cardAssessment,
                              ),
                            ),
                            Text(
                              'questions',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.cardAssessment,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Saved indicator
                if (_questions.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: AppColors.success, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Saved to this device. Sync when online.',
                          style: TextStyle(
                              color: AppColors.success,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                if (_questions.isNotEmpty) const SizedBox(height: AppSpacing.md),

                // Generate button
                PrimaryButton(
                  label: _saving ? 'Saving…' : 'Generate Assessment',
                  icon: Icons.quiz_rounded,
                  color: AppColors.cardAssessment,
                  loading: _saving,
                  onPressed: _saving ? null : _generate,
                ),

                // Question cards
                if (_questions.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text('Questions',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  ..._questions.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _QuestionCard(
                        number: entry.key + 1,
                        question: entry.value,
                      ),
                    ),
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

// ── Context row ───────────────────────────────

class _ContextRow extends StatelessWidget {
  const _ContextRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textHint),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

// ── Question card ─────────────────────────────

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.number, required this.question});
  final int number;
  final AssessmentQuestion question;

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
          // Number header
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
            decoration: BoxDecoration(
              color: AppColors.cardAssessment.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.lg),
                topRight: Radius.circular(AppRadius.lg),
              ),
              border: Border(
                bottom: BorderSide(
                    color: AppColors.cardAssessment.withValues(alpha: 0.15)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.cardAssessment,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$number',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Question $number',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.cardAssessment,
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              question.hindiText,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textPrimary, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}
