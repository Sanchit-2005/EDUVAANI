import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/sync_status.dart';
import '../repositories/sync_repository.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';
import '../widgets/app_widgets.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final _urlController =
      TextEditingController(text: 'http://10.0.2.2:3000');
  final _repository = SyncRepository();
  final _service = SyncService();
  SyncStatus _status = SyncStatus.empty;
  bool _syncing = false;
  bool _online = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait(
        [_repository.getStatus(), ConnectivityService().isOnline]);
    if (mounted) {
      setState(() {
        _status = results[0] as SyncStatus;
        _online = results[1] as bool;
      });
    }
  }

  Future<void> _sync() async {
    setState(() => _syncing = true);
    try {
      final status = await _service.sync(_urlController.text.trim());
      if (mounted) setState(() => _status = status);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Unable to sync. Check your connection and server address.')),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
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
            backgroundColor: AppColors.cardSync,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                    gradient: AppGradients.card(AppColors.cardSync)),
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
                          child: const Icon(Icons.cloud_sync_rounded,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Sync Content',
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
                // ── Connection status ───────────────────
                _ConnectionCard(online: _online),
                const SizedBox(height: AppSpacing.md),

                // ── Sync stats ──────────────────────────
                Text('Sync Status',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: MetricTile(
                        label: 'Lessons',
                        value: '${_status.downloadedLessons}',
                        icon: Icons.menu_book_rounded,
                        color: AppColors.cardLessons,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: MetricTile(
                        label: 'Translations',
                        value: '${_status.downloadedTranslations}',
                        icon: Icons.translate_rounded,
                        color: AppColors.cardText,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: MetricTile(
                        label: 'Models',
                        value: '${_status.downloadedModels}',
                        icon: Icons.memory_rounded,
                        color: AppColors.cardVoice,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Last synced
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
                      IconBox(
                          icon: Icons.history_rounded,
                          color: AppColors.textSecondary),
                      const SizedBox(width: AppSpacing.md),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Last Synced',
                              style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 2),
                          Text(
                            _status.lastSyncedAt == null
                                ? 'Never synced'
                                : _formatDate(_status.lastSyncedAt!),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      const Spacer(),
                      StatusChip(
                        label: _status.lastSyncedAt == null ? 'Pending' : 'Done',
                        style: _status.lastSyncedAt == null
                            ? ChipStyle.warning
                            : ChipStyle.success,
                        icon: _status.lastSyncedAt == null
                            ? Icons.schedule_rounded
                            : Icons.check_rounded,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Backend URL ─────────────────────────
                Text('Backend Address',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _urlController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Server URL',
                    prefixIcon: Icon(Icons.link_rounded),
                    hintText: 'http://10.0.2.2:3000',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Sync button ─────────────────────────
                PrimaryButton(
                  label: _syncing
                      ? 'Syncing…'
                      : _online
                          ? 'Sync Now'
                          : 'No Connection',
                  icon: Icons.sync_rounded,
                  color: AppColors.cardSync,
                  loading: _syncing,
                  onPressed: _online && !_syncing ? _sync : null,
                ),
                const SizedBox(height: AppSpacing.sm),

                if (!_online)
                  Center(
                    child: Text(
                      'Connect to the internet to sync.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.warning),
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

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${local.day}/${local.month}/${local.year}';
  }
}

// ── Connection status card ────────────────────

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.online});
  final bool online;

  @override
  Widget build(BuildContext context) {
    final color = online ? AppColors.success : AppColors.warning;
    final icon =
        online ? Icons.wifi_rounded : Icons.wifi_off_rounded;
    final title = online ? 'Online' : 'Offline';
    final msg = online
        ? 'Connected — ready to synchronize optional updates.'
        : 'You are offline. All downloaded content remains available.';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  msg,
                  style: TextStyle(
                      color: color.withValues(alpha: 0.8), fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
