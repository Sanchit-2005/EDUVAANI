import 'package:flutter/material.dart';
import '../core/app_theme.dart';

// ─────────────────────────────────────────────
//  EduVaani — Shared Widget Library
// ─────────────────────────────────────────────

// ── Gradient scaffold background ─────────────

class EduVaaniScaffold extends StatelessWidget {
  const EduVaaniScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.resizeToAvoidBottomInset = true,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: body,
    );
  }
}

// ── Gradient app bar ──────────────────────────

class EduVaaniAppBar extends StatelessWidget implements PreferredSizeWidget {
  const EduVaaniAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.bottom,
    this.gradient = false,
  });

  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final PreferredSizeWidget? bottom;
  final bool gradient;

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    if (!gradient) {
      return AppBar(
        title: Text(title),
        actions: actions,
        leading: leading,
        bottom: bottom,
      );
    }

    return Container(
      decoration: const BoxDecoration(gradient: AppGradients.brand),
      child: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        actions: actions,
        leading: leading,
        bottom: bottom,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
    );
  }
}

// ── Feature header (screen hero) ─────────────

class FeatureHeader extends StatelessWidget {
  const FeatureHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppGradients.card(color),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.colored(color),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Gradient card ─────────────────────────────

class GradientCard extends StatelessWidget {
  const GradientCard({
    super.key,
    required this.child,
    this.gradient,
    this.padding,
    this.borderRadius,
    this.onTap,
    this.shadows,
  });

  final Widget child;
  final Gradient? gradient;
  final EdgeInsetsGeometry? padding;
  final BorderRadiusGeometry? borderRadius;
  final VoidCallback? onTap;
  final List<BoxShadow>? shadows;

  @override
  Widget build(BuildContext context) {
    final br = (borderRadius ?? BorderRadius.circular(AppRadius.lg)) as BorderRadius;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: br,
        child: Ink(
          decoration: BoxDecoration(
            gradient: gradient ?? AppGradients.brandSubtle,
            borderRadius: br,
            boxShadow: shadows ?? AppShadows.sm,
          ),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(AppSpacing.md),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ── Info card (plain bordered) ────────────────

class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: padding ?? const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color ?? AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.sm,
          ),
          child: child,
        ),
      ),
    );
  }
}

// ── Section header ────────────────────────────

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.subtitle,
  });

  final String title;
  final Widget? trailing;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
         ?trailing,
        ],
      ),
    );
  }
}

// ── Status chip ───────────────────────────────

enum ChipStyle { success, warning, error, info, neutral }

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.style = ChipStyle.neutral,
    this.icon,
  });

  final String label;
  final ChipStyle style;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    switch (style) {
      case ChipStyle.success:
        bg = AppColors.success.withValues(alpha: 0.12);
        fg = AppColors.success;
      case ChipStyle.warning:
        bg = AppColors.warning.withValues(alpha: 0.12);
        fg = AppColors.warning;
      case ChipStyle.error:
        bg = AppColors.error.withValues(alpha: 0.12);
        fg = AppColors.error;
      case ChipStyle.info:
        bg = AppColors.info.withValues(alpha: 0.12);
        fg = AppColors.info;
      case ChipStyle.neutral:
        bg = AppColors.primary.withValues(alpha: 0.08);
        fg = AppColors.primary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Icon(
                icon,
                size: 40,
                color: AppColors.primary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

// ── Loading state ─────────────────────────────

class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(message!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

// ── Metric tile (stat box) ────────────────────

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: AppSpacing.sm),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: color.withValues(alpha: 0.8)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Labelled progress bar ─────────────────────

class LabelledProgress extends StatelessWidget {
  const LabelledProgress({
    super.key,
    required this.label,
    required this.value,
    this.color,
    this.trailing,
  });

  final String label;
  final double value;
  final Color? color;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final clr = color ?? AppColors.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            Text(
              trailing ?? '${(value * 100).round()}%',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: clr,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 8,
            color: clr,
            backgroundColor: clr.withValues(alpha: 0.12),
          ),
        ),
      ],
    );
  }
}

// ── Divider with label ────────────────────────

class LabelDivider extends StatelessWidget {
  const LabelDivider({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

// ── Pill badge ────────────────────────────────

class PillBadge extends StatelessWidget {
  const PillBadge({super.key, required this.text, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final clr = color ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: clr.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: clr.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: clr,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ── Icon container ────────────────────────────

class IconBox extends StatelessWidget {
  const IconBox({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

// ── Primary action button (full width) ────────

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final clr = color ?? AppColors.primary;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: loading ? null : onPressed,
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon ?? Icons.arrow_forward_rounded),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: clr,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// ── Secondary action button (full width) ──────

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon ?? Icons.arrow_forward_rounded),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
