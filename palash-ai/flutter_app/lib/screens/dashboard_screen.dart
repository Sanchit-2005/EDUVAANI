import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.primary,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Color(0xFF1E293B),
      ),
      child: Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.primary,
          border: const Border(
            top: BorderSide(
              color: Color(0xFF1E293B),
              width: 1.0,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 12,
            child: Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF8FAFC),
              Color(0xFFF0F4FF),
              Color(0xFFF5F3FF),
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            // ── Hero app bar ──────────────────────────────
            SliverAppBar(
              expandedHeight: 206,
              pinned: true,
              backgroundColor: const Color(0xFFEEF2FF),
              surfaceTintColor: Colors.transparent,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFEEF2FF),
                        Color(0xFFEDE9FE),
                        Color(0xFFF8FAFC),
                      ],
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: const Color(0xFFE2E8F0).withValues(alpha: 0.8),
                        width: 1,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.xl,
                  AppSpacing.md,
                  AppSpacing.lg,
                ),

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
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.primary,
                                  Color(0xFF334155),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.18),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: const Icon(
                              Icons.translate_rounded,
                              color: Colors.white,
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
                      RichText(
                        text: const TextSpan(
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                          children: [
                            TextSpan(text: 'Welcome, '),
                            TextSpan(
                              text: 'Teacher!',
                              style: TextStyle(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          border: Border.all(
                            color: const Color(0xFFCBD5E1),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.school_rounded,
                              size: 14,
                              color: AppColors.accent,
                            ),
                            const SizedBox(width: 6),
                            RichText(
                              text: const TextSpan(
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Language: ',
                                    style: TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  TextSpan(
                                    text: 'Santali',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '  •  ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w400,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'Grade 1',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
/*
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
*/
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: const Color(0xFFCBD5E1).withValues(alpha: 0.6),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                  Icons.settings_outlined,
                    color: AppColors.textPrimary,
                    size: 19,
                  ),
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
                mainAxisExtent: 136,
              ),
              delegate: SliverChildListDelegate([
                _FeatureCard(
                  icon: Icons.menu_book_rounded,
                  title: 'Lessons',
                  subtitle: 'Browse & filter',
                  color: AppColors.cardLessons,
                  isFeatured: true,
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
                  isFeatured: true,
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
        ),
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
                color: online ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.md),
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
                  _PulsingStatusDot(color: color, isOnline: online), /*
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
*/
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
    this.isFeatured = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool isFeatured;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
          decoration: BoxDecoration(
            color: isFeatured ? Color.lerp(AppColors.surfaceCard, color, 0.04)! : AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: isFeatured ? color.withValues(alpha: 0.35) : AppColors.border, width: isFeatured ? 1.2 : 1),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: color.withValues(alpha: isFeatured ? 0.12 : 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withValues(alpha: 0.22),
                      color.withValues(alpha: 0.08),
                    ],
                  ),
                  border: Border.all(
                    color: color.withValues(alpha: 0.15),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: color, size: 23),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 2,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12.5,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
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

// ── Pulsing status dot ────────────────────────

class _PulsingStatusDot extends StatefulWidget {
  const _PulsingStatusDot({required this.color, required this.isOnline});

  final Color color;
  final bool isOnline;

  @override
  State<_PulsingStatusDot> createState() => _PulsingStatusDotState();
}

class _PulsingStatusDotState extends State<_PulsingStatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _scale = Tween<double>(begin: 1.0, end: 2.2).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );

    _opacity = Tween<double>(begin: 0.55, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOnline) {
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      );
    }

    return SizedBox(
      width: 18,
      height: 18,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (context, child) {
              return Transform.scale(
                scale: _scale.value,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: _opacity.value),
                  ),
                ),
              );
            },
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.4),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
