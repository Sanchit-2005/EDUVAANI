import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../core/app_theme.dart';
import '../database/database_helper.dart';
import '../models/custom_assignment.dart';
import '../services/translation_service.dart';
import '../services/worksheet_service.dart';
import '../widgets/app_widgets.dart';

/// Teacher-authored assignment form. Questions composed here are persisted
/// locally and rendered through the same [WorksheetService] PDF engine used
/// by auto-generated worksheets — no second rendering path.
class CustomAssignmentScreen extends StatefulWidget {
  /// When [existing] is non-null the form opens pre-filled for editing.
  const CustomAssignmentScreen({super.key, this.existing});

  final CustomAssignment? existing;

  @override
  State<CustomAssignmentScreen> createState() =>
      _CustomAssignmentScreenState();
}

class _CustomAssignmentScreenState extends State<CustomAssignmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _gradeCtrl = TextEditingController(text: 'Grade 1');
  final _subjectCtrl = TextEditingController(text: 'Foundational Numeracy');
  final _topicCtrl = TextEditingController();
  final _questionCtrls = <TextEditingController>[];

  bool _includeHindi = true;
  bool _includeSantali = true;
  bool _includeEnglish = false;
  bool _highContrast = false;

  /// Indices of questions whose Santali was auto-translated via the ML
  /// pipeline. These get the "AI-translated — review needed" label in the PDF.
  final Set<int> _aiTranslatedIndices = {};

  Uint8List? _pdf;
  bool _generating = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _addQuestion(); // start with one empty field.
    if (widget.existing != null) _loadExisting(widget.existing!);
  }

  void _loadExisting(CustomAssignment a) {
    _gradeCtrl.text = a.grade;
    _subjectCtrl.text = a.subject;
    _topicCtrl.text = a.topic;
    _includeHindi = a.includeHindi;
    _includeSantali = a.includeSantali;
    _includeEnglish = a.includeEnglish;

    // Clear the initial empty controller and populate from saved JSON.
    _questionCtrls.clear();
    final List<dynamic> decoded = jsonDecode(a.questionsJson) as List;
    for (final q in decoded) {
      final map = q as Map<String, dynamic>;
      _questionCtrls.add(
          TextEditingController(text: map['hindiText'] as String? ?? ''));
      if ((map['isAiTranslated'] as bool?) ?? false) {
        _aiTranslatedIndices.add(_questionCtrls.length - 1);
      }
    }
    if (_questionCtrls.isEmpty) _addQuestion();
  }

  void _addQuestion() {
    setState(() => _questionCtrls.add(TextEditingController()));
  }

  void _removeQuestion(int index) {
    setState(() {
      _questionCtrls[index].dispose();
      _questionCtrls.removeAt(index);
      // Re-index AI-translated set.
      final rebuilt = <int>{};
      for (final i in _aiTranslatedIndices) {
        if (i < index) rebuilt.add(i);
        if (i > index) rebuilt.add(i - 1);
      }
      _aiTranslatedIndices
        ..clear()
        ..addAll(rebuilt);
    });
  }

  /// Auto-translates the Hindi text at [index] to Santali via the ML pipeline
  /// and marks it as AI-translated.
  Future<void> _autoTranslate(int index) async {
    final hindi = _questionCtrls[index].text.trim();
    if (hindi.isEmpty) return;
    setState(() {}); // trigger rebuild so button shows busy state
    try {
      final result = await TranslationService.instance.translate(
        text: hindi,
        sourceLanguage: 'hin_Deva',
        targetLanguage: 'sat_Olck',
      );
      if (!mounted) return;
      // Store the translation alongside the question.
      _translations[index] = result.output;
      _aiTranslatedIndices.add(index);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Santali translation added — please review before printing.'),
          backgroundColor: AppColors.warning,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Translation unavailable. Enter Santali manually.'),
        ),
      );
    }
    if (mounted) setState(() {});
  }

  /// Teacher-entered Santali text (manual override for each question).
  final _translations = <int, String>{};

  @override
  void dispose() {
    _gradeCtrl.dispose();
    _subjectCtrl.dispose();
    _topicCtrl.dispose();
    for (final c in _questionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Persistence ──────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final questions = _buildQuestionList();
      final now = DateTime.now().toIso8601String();
      final assignment = CustomAssignment(
        id: widget.existing?.id,
        grade: _gradeCtrl.text.trim(),
        subject: _subjectCtrl.text.trim(),
        topic: _topicCtrl.text.trim(),
        questionsJson: jsonEncode(questions.map((q) => q.toMap()).toList()),
        includeHindi: _includeHindi,
        includeSantali: _includeSantali,
        includeEnglish: _includeEnglish,
        createdAt: widget.existing?.createdAt ?? now,
        updatedAt: widget.existing != null ? now : null,
      );
      if (assignment.id != null) {
        await DatabaseHelper.instance.updateCustomAssignment(assignment);
      } else {
        await DatabaseHelper.instance.insertCustomAssignment(assignment);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assignment saved locally.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── PDF generation ──────────────────────────────────────────────────────

  Future<void> _generatePdf() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _generating = true);
    try {
      final data = CustomWorksheetData(
        grade: _gradeCtrl.text.trim(),
        subject: _subjectCtrl.text.trim(),
        topic: _topicCtrl.text.trim(),
        questions: _buildQuestionList(),
        includeHindi: _includeHindi,
        includeSantali: _includeSantali,
        includeEnglish: _includeEnglish,
      );
      final pdf = await WorksheetService().buildCustomWorksheet(
        data,
        highContrast: _highContrast,
      );
      if (!mounted) return;
      setState(() => _pdf = pdf);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Unable to generate worksheet. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  List<CustomQuestion> _buildQuestionList() {
    return [
      for (var i = 0; i < _questionCtrls.length; i++)
        if (_questionCtrls[i].text.trim().isNotEmpty)
          CustomQuestion(
            hindiText: _questionCtrls[i].text.trim(),
            santaliText: _translations[i],
            isAiTranslated: _aiTranslatedIndices.contains(i),
            questionType: 'text',
          ),
    ];
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  UI
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          // ── App bar ────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 130,
            backgroundColor: AppColors.accent,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                    gradient: AppGradients.card(AppColors.accent)),
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: const Icon(Icons.edit_note_rounded,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isEditing
                            ? 'Edit Custom Assignment'
                            : 'New Custom Assignment',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.md),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Metadata ────────────────────────
                      Text('Assignment Details',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _gradeCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Grade',
                            prefixIcon: Icon(Icons.school_rounded)),
                        validator: _nonEmpty,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _subjectCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Subject',
                            prefixIcon: Icon(Icons.calculate_rounded)),
                        validator: _nonEmpty,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _topicCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Topic',
                            prefixIcon: Icon(Icons.tag_rounded)),
                        validator: _nonEmpty,
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // ── Language toggles ────────────────
                      Text('Languages',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.sm),
                      _LanguageToggle(
                        hindi: _includeHindi,
                        santali: _includeSantali,
                        english: _includeEnglish,
                        onChanged: (h, s, e) => setState(() {
                          _includeHindi = h;
                          _includeSantali = s;
                          _includeEnglish = e;
                        }),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // ── Questions ───────────────────────
                      Row(children: [
                        Text('Questions',
                            style:
                                Theme.of(context).textTheme.titleMedium),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _addQuestion,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add'),
                        ),
                      ]),
                      const SizedBox(height: AppSpacing.sm),
                      for (var i = 0; i < _questionCtrls.length; i++)
                        _QuestionCard(
                          index: i,
                          controller: _questionCtrls[i],
                          isAiTranslated:
                              _aiTranslatedIndices.contains(i),
                          santaliTranslation: _translations[i],
                          showSantali: _includeSantali,
                          onRemove: _questionCtrls.length > 1
                              ? () => _removeQuestion(i)
                              : null,
                          onAutoTranslate:
                              _includeSantali ? () => _autoTranslate(i) : null,
                        ),
                      const SizedBox(height: AppSpacing.md),

                      // ── Print-friendly toggle ──────────
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(children: [
                          const Icon(Icons.contrast_rounded,
                              size: 20, color: AppColors.accent),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text('Print-friendly mode',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                                Text('Low-ink, high-contrast',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textHint)),
                              ],
                            ),
                          ),
                          Switch(
                            value: _highContrast,
                            activeTrackColor: AppColors.accent,
                            onChanged: (v) {
                              setState(() => _highContrast = v);
                              if (_pdf != null && !_generating) {
                                _generatePdf();
                              }
                            },
                          ),
                        ]),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // ── Action buttons ─────────────────
                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: Icon(_saving
                                ? Icons.hourglass_top_rounded
                                : Icons.save_rounded),
                            label: Text(_saving ? 'Saving…' : 'Save'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          flex: 2,
                          child: PrimaryButton(
                            label: _generating
                                ? 'Generating…'
                                : 'Generate PDF',
                            icon: Icons.picture_as_pdf_rounded,
                            color: AppColors.accent,
                            loading: _generating,
                            onPressed: _generating ? null : _generatePdf,
                          ),
                        ),
                      ]),

                      // ── Preview ────────────────────────
                      if (_pdf != null) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Row(children: [
                          Text('Preview',
                              style: Theme.of(context).textTheme.titleMedium),
                          const Spacer(),
                          StatusChip(
                              label: 'Ready',
                              style: ChipStyle.success,
                              icon: Icons.check_circle_rounded),
                        ]),
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          height: 520,
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(AppRadius.lg),
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
                        Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Printing.layoutPdf(
                                  onLayout: (_) async => _pdf!),
                              icon: const Icon(Icons.print_rounded),
                              label: const Text('Print'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => Printing.sharePdf(
                                bytes: _pdf!,
                                filename:
                                    'eduvaani_custom_assignment.pdf',
                              ),
                              icon: const Icon(Icons.save_alt_rounded),
                              label: const Text('Save / Share'),
                              style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.accent),
                            ),
                          ),
                        ]),
                      ],

                      SizedBox(
                          height: AppSpacing.xl +
                              MediaQuery.paddingOf(context).bottom),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String? _nonEmpty(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;
}

// ── Question card ────────────────────────────────────────────────────────────

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.index,
    required this.controller,
    required this.isAiTranslated,
    required this.showSantali,
    this.santaliTranslation,
    this.onRemove,
    this.onAutoTranslate,
  });

  final int index;
  final TextEditingController controller;
  final bool isAiTranslated;
  final bool showSantali;
  final String? santaliTranslation;
  final VoidCallback? onRemove;
  final VoidCallback? onAutoTranslate;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: Text('${index + 1}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                      fontSize: 13)),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Question',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.textSecondary)),
            ),
            if (onRemove != null)
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded, size: 18),
                color: AppColors.error,
                tooltip: 'Remove question',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ]),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: controller,
            maxLines: 3,
            minLines: 1,
            decoration: const InputDecoration(
              hintText: 'Type your question in Hindi…',
              border: OutlineInputBorder(),
            ),
          ),

          // Santali row: auto-translate button + AI label.
          if (showSantali) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(children: [
              if (onAutoTranslate != null)
                OutlinedButton.icon(
                  onPressed: onAutoTranslate,
                  icon: const Icon(Icons.translate_rounded, size: 16),
                  label: const Text('Auto-translate to Santali'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: const BorderSide(color: AppColors.accent),
                    textStyle:
                        const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                  ),
                ),
              const Spacer(),
              if (isAiTranslated)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 12, color: AppColors.warning),
                      SizedBox(width: 4),
                      Text('AI-translated — review needed',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.warning)),
                    ],
                  ),
                ),
            ]),
            if (santaliTranslation != null) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.3)),
                ),
                child: Text(
                  santaliTranslation!,
                  style: const TextStyle(fontSize: 14, fontFamily: 'NotoSansOlChiki'),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ── Language toggle ──────────────────────────────────────────────────────────

class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle({
    required this.hindi,
    required this.santali,
    required this.english,
    required this.onChanged,
  });

  final bool hindi;
  final bool santali;
  final bool english;
  final void Function(bool hindi, bool santali, bool english) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        _LangChip(
          label: 'Hindi',
          active: hindi,
          color: const Color(0xFFFF6F00),
          onTap: () => onChanged(!hindi, santali, english),
        ),
        const SizedBox(width: 8),
        _LangChip(
          label: 'Santali',
          active: santali,
          color: const Color(0xFF2E7D32),
          onTap: () => onChanged(hindi, !santali, english),
        ),
        const SizedBox(width: 8),
        _LangChip(
          label: 'English',
          active: english,
          color: const Color(0xFF1565C0),
          onTap: () => onChanged(hindi, santali, !english),
        ),
      ]),
    );
  }
}

class _LangChip extends StatelessWidget {
  const _LangChip({
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: active ? color : AppColors.border,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (active) ...[
              Icon(Icons.check_rounded, size: 14, color: color),
              const SizedBox(width: 4),
            ],
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? color : AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
