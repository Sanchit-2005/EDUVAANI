import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../core/app_theme.dart';
import '../services/translation_service.dart';
import '../services/worksheet_service.dart';
import 'custom_assignment_screen.dart';
import '../widgets/app_widgets.dart';

class WorksheetScreen extends StatefulWidget {
  const WorksheetScreen({super.key});

  @override
  State<WorksheetScreen> createState() => _WorksheetScreenState();
}

class _WorksheetScreenState extends State<WorksheetScreen> {
  final WorksheetService _worksheetService = WorksheetService();
  Uint8List? _pdf;
  bool _creating = false;
  bool _highContrast = false;

  Future<void> _generate() async {
    setState(() => _creating = true);
    try {
      const hindi = 'अब मिलकर गिनो।';
      final santali =
          TranslationService.instance.hindiToSantali(hindi).output;
      final pdf = await _worksheetService.buildBilingualWorksheet(
        WorksheetData(
          grade: 'Grade 1',
          subject: 'Foundational Numeracy',
          topic: 'Counting 1-10',
          hindiInstruction: hindi,
          santaliInstruction: santali,
        ),
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
      if (mounted) setState(() => _creating = false);
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
            backgroundColor: AppColors.cardWorksheet,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: const [
              DeviceStatusAction(onDevice: true),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                    gradient: AppGradients.card(AppColors.cardWorksheet)),
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
                          child: const Icon(Icons.assignment_rounded,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Worksheet Generator',
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
                // Parameters label
                Text('Worksheet Parameters',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),

                // Parameter grid
                _ParameterGrid(
                  items: const [
                    _Param(
                        icon: Icons.school_rounded,
                        label: 'Grade',
                        value: 'Grade 1'),
                    _Param(
                        icon: Icons.calculate_rounded,
                        label: 'Subject',
                        value: 'Foundational Numeracy'),
                    _Param(
                        icon: Icons.tag_rounded,
                        label: 'Topic',
                        value: 'Counting 1-10'),
                    _Param(
                        icon: Icons.language_rounded,
                        label: 'Languages',
                        value: 'Hindi + Santali'),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // High-contrast / low-ink toggle
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.border),
                    boxShadow: AppShadows.sm,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.contrast_rounded,
                          size: 20, color: AppColors.cardWorksheet),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Print-friendly mode',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary)),
                            Text('Low-ink, high-contrast for printing',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textHint)),
                          ],
                        ),
                      ),
                      Switch(
                        value: _highContrast,
                        activeTrackColor: AppColors.cardWorksheet,
                        onChanged: (v) {
                          setState(() => _highContrast = v);
                          // Regenerate if a PDF already exists.
                          if (_pdf != null && !_creating) _generate();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Generate button
                PrimaryButton(
                  label: _creating ? 'Generating…' : 'Generate Worksheet',
                  icon: Icons.picture_as_pdf_rounded,
                  color: AppColors.cardWorksheet,
                  loading: _creating,
                  onPressed: _creating ? null : _generate,
                ),
                const SizedBox(height: AppSpacing.sm),

                // Navigate to custom assignment
                SecondaryButton(
                  label: 'Create Custom Assignment',
                  icon: Icons.edit_note_rounded,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CustomAssignmentScreen(),
                      ),
                    );
                  },
                ),

                // PDF preview section
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
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => Printing.sharePdf(
                            bytes: _pdf!,
                            filename: 'eduvaani_counting_1_10_worksheet.pdf',
                          ),
                          icon: const Icon(Icons.save_alt_rounded),
                          label: const Text('Save / Share'),
                          style: FilledButton.styleFrom(
                              backgroundColor: AppColors.cardWorksheet),
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

// ── Parameter grid ────────────────────────────

class _ParameterGrid extends StatelessWidget {
  const _ParameterGrid({required this.items});
  final List<_Param> items;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 2.8,
      children: items
          .map(
            (p) => Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
                boxShadow: AppShadows.sm,
              ),
              child: Row(
                children: [
                  Icon(p.icon,
                      size: 18, color: AppColors.cardWorksheet),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(p.label,
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textHint)),
                        Text(
                          p.value,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _Param {
  const _Param(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
}
