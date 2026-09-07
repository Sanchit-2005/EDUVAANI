import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/connectivity_service.dart';
import 'assessments_screen.dart';
import 'flashcards_screen.dart';
import 'lessons_screen.dart';
import 'progress_screen.dart';
import 'sync_screen.dart';
import 'text_translator_screen.dart';
import 'voice_translator_screen.dart';
import 'worksheet_screen.dart';
import 'santali_scanner/santali_scanner_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          // ── Hero app bar ──────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.surface,
            surfaceTintColor: AppColors.surface,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xl,
                  AppSpacing.md,
                  AppSpacing.lg,
                ),
                color: AppColors.surface,
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: const Icon(
                              Icons.translate_rounded,
                              color: AppColors.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'EduVaani',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Text(
                        'Welcome, Teacher!',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Language: Santali • Grade 1',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.settings_outlined,
                  color: AppColors.textPrimary,
                ),
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Settings arrive in a later phase.'),
                  ),
                ),
              ),
            ],
          ),

          // ── Connectivity banner ───────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                0,
              ),
              child: const _ConnectivityBanner(),
            ),
          ),

          // ── Section label ─────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Text(
                    'Quick Access',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      '9 features',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Feature grid ──────────────────────────────
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.xl + MediaQuery.paddingOf(context).bottom,
            ),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount:
                    MediaQuery.sizeOf(context).width >= 360 ? 3 : 2,
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
                mainAxisExtent: 118,
              ),
              delegate: SliverChildListDelegate([
                _FeatureCard(
                  icon: Icons.menu_book_rounded,
                  title: 'Lessons',
                  subtitle: 'Browse & filter',
                  color: AppColors.cardLessons,
                  onTap: () => _open(context, const LessonsScreen()),
                ),
                _FeatureCard(
                  icon: Icons.mic_rounded,
                  title: 'Voice Translate',
                  subtitle: 'Speak in Hindi',
                  color: AppColors.cardVoice,
                  onTap: () => _open(context, const VoiceTranslatorScreen()),
                ),
                _FeatureCard(
                  icon: Icons.translate_rounded,
                  title: 'Text Translate',
                  subtitle: 'Hindi ↔ Santali',
                  color: AppColors.cardText,
                  onTap: () => _open(context, const TextTranslatorScreen()),
                ),
                _FeatureCard(
                  icon: Icons.assignment_rounded,
                  title: 'Worksheets',
                  subtitle: 'Generate PDF',
                  color: AppColors.cardWorksheet,
                  onTap: () => _open(context, const WorksheetScreen()),
                ),
                _FeatureCard(
                  icon: Icons.style_rounded,
                  title: 'Flashcards',
                  subtitle: 'Numbers & vocab',
                  color: AppColors.cardFlashcard,
                  onTap: () => _open(context, const FlashcardsScreen()),
                ),
                _FeatureCard(
                  icon: Icons.quiz_rounded,
                  title: 'Assessments',
                  subtitle: 'Bilingual questions',
                  color: AppColors.cardAssessment,
                  onTap: () => _open(context, const AssessmentsScreen()),
                ),
                _FeatureCard(
                  icon: Icons.bar_chart_rounded,
                  title: 'Progress',
                  subtitle: 'Class overview',
                  color: AppColors.cardProgress,
                  onTap: () => _open(context, const ProgressScreen()),
                ),
                _FeatureCard(
                  icon: Icons.cloud_sync_rounded,
                  title: 'Sync Content',
                  subtitle: 'Update offline data',
                  color: AppColors.cardSync,
                  onTap: () => _open(context, const SyncScreen()),
                ),
                _FeatureCard(
                  icon: Icons.image_search_rounded,
                  title: 'Scan Santali',
                  subtitle: 'Scan & translate text',
                  color: AppColors.cardScanner,
                  onTap: () => _open(context, const SantaliScannerScreen()),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  static void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

// ── Connectivity banner ───────────────────────

class _ConnectivityBanner extends StatelessWidget {
  const _ConnectivityBanner();

  static final ConnectivityService _svc = ConnectivityService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _svc.onConnectionChanged,
      builder: (context, snapshot) {
        return FutureBuilder<bool>(
          future: snapshot.hasData
              ? Future<bool>.value(snapshot.data)
              : _svc.isOnline,
          builder: (context, inner) {
            final online = inner.data ?? false;
            final color = online ? AppColors.success : AppColors.warning;
            final icon = online
                ? Icons.cloud_done_rounded
                : Icons.cloud_off_rounded;
            final msg = online
                ? 'Online — classroom content served locally.'
                : 'Offline mode — downloaded content & AI available.';

            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm + 2,
              ),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      msg,
                      style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ── Feature card ──────────────────────────────

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: AppShadows.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
