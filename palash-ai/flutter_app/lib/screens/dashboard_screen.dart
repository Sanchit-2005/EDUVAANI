import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/connectivity_service.dart';
import '../widgets/app_widgets.dart';
import 'assessments_screen.dart';
import 'flashcards_screen.dart';
import 'lessons_screen.dart';
import 'progress_screen.dart';
import 'sync_screen.dart';
import 'text_translator_screen.dart';
import 'voice_translator_screen.dart';
import 'worksheet_screen.dart';

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
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Gradient background
                  Container(decoration: const BoxDecoration(gradient: AppGradients.brand)),

                  // Decorative circles
                  Positioned(
                    top: -40,
                    right: -30,
                    child: _Circle(size: 180, opacity: 0.12),
                  ),
                  Positioned(
                    bottom: 20,
                    right: 60,
                    child: _Circle(size: 80, opacity: 0.08),
                  ),

                  // Content
                  Positioned(
                    left: AppSpacing.md,
                    right: AppSpacing.md,
                    bottom: AppSpacing.lg,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
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
                              child: const Icon(Icons.translate_rounded, color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'EduVaani',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const Text(
                          'Welcome, Teacher! 👋',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Language: Santali  ·  Grade 1',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: Colors.white),
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings arrive in a later phase.')),
                ),
              ),
            ],
          ),

          // ── Connectivity banner ───────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
              child: const _ConnectivityBanner(),
            ),
          ),

          // ── Section label ─────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.sm),
              child: Row(
                children: [
                  Text(
                    'Quick Access',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(width: 6),
                  PillBadge(text: '8 features', color: AppColors.primary),
                ],
              ),
            ),
          ),

          // ── Feature grid ──────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, 0, AppSpacing.md, AppSpacing.xl),
            sliver: SliverGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: 1.05,
              children: [
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  static void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
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
            final icon = online ? Icons.cloud_done_rounded : Icons.cloud_off_rounded;
            final msg = online
                ? 'Online — classroom content served locally.'
                : 'Offline mode — downloaded content & AI available.';

            return Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
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
                      color: color.withValues(alpha: 0.15),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color,
              Color.lerp(color, Colors.black, 0.18)!,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: AppShadows.colored(color),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            splashColor: Colors.white.withValues(alpha: 0.15),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon box
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
          color: Colors.white.withValues(alpha: opacity),
          width: 1.5,
        ),
      ),
    );
  }
}
