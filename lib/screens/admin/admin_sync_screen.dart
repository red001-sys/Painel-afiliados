import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/admin_provider.dart';

class AdminSyncScreen extends ConsumerStatefulWidget {
  const AdminSyncScreen({super.key});

  @override
  ConsumerState<AdminSyncScreen> createState() => _AdminSyncScreenState();
}

class _AdminSyncScreenState extends ConsumerState<AdminSyncScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(syncHistoryProvider);
      ref.invalidate(syncTodayStatsProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSyncing = ref.watch(syncExecutingProvider);
    final historyAsync = ref.watch(syncHistoryProvider);
    final todayStatsAsync = ref.watch(syncTodayStatsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: EdgeInsets.all(AppTheme.spacingMD),
      children: [
        Card(
          child: Padding(
            padding: EdgeInsets.all(AppTheme.spacingMD),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.sync_rounded,
                        color: AppColors.ecoGreen),
                    const SizedBox(width: 8),
                    Text(
                      'Sincronizar RedStar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppTheme.spacingMD),
                if (todayStatsAsync.hasValue &&
                    todayStatsAsync.value != null) ...[
                  _TodayStats(stats: todayStatsAsync.value!),
                  SizedBox(height: AppTheme.spacingMD),
                ],
                if (isSyncing) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(
                    'Sincronizando... aguarde.',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurface
                          .withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ] else
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () => _executeSync(context),
                      icon: const Icon(Icons.sync_rounded),
                      label: const Text('Sincronizar agora'),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(height: AppTheme.spacingMD),
        Text(
          'Histórico de sincronizações',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        historyAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erro: $e')),
          data: (logs) {
            if (logs.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'Nenhuma sincronização realizada ainda.',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              );
            }

            return Column(
              children: logs.map((log) => _SyncLogTile(log: log)).toList(),
            );
          },
        ),
      ],
    );
  }

  Future<void> _executeSync(BuildContext context) async {
    try {
      await executeSync(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sincronização concluída!'),
            backgroundColor: AppColors.ecoGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro na sincronização: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

class _TodayStats extends StatelessWidget {
  const _TodayStats({required this.stats});

  final Map<String, dynamic> stats;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hoje',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _StatPill(
                label: 'Syncs',
                value: '${stats['todaySyncCount'] ?? 0}',
                color: Colors.blue,
              ),
              const SizedBox(width: 8),
              _StatPill(
                label: 'Importadas',
                value: '${stats['todayImported'] ?? 0}',
                color: Colors.green,
              ),
              const SizedBox(width: 8),
              _StatPill(
                label: 'Atualizadas',
                value: '${stats['todayUpdated'] ?? 0}',
                color: Colors.orange,
              ),
              const SizedBox(width: 8),
              _StatPill(
                label: 'Falhas',
                value: '${stats['todayFailed'] ?? 0}',
                color: AppColors.error,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncLogTile extends StatelessWidget {
  const _SyncLogTile({required this.log});

  final Map<String, dynamic> log;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final status = log['status'] as String? ?? 'unknown';
    final startedAt = log['started_at'] as String?;
    final imported = log['transactions_imported'] as int? ?? 0;
    final updated = log['transactions_updated'] as int? ?? 0;
    final skipped = log['transactions_skipped'] as int? ?? 0;
    final unknownSid = log['unknown_sid'] as int? ?? 0;
    final failed = log['transactions_failed'] as int? ?? 0;
    final errorMsg = log['error_message'] as String?;

    final statusColor = status == 'success'
        ? Colors.green
        : status == 'partial'
            ? Colors.orange
            : status == 'running'
                ? Colors.blue
                : AppColors.error;

    final statusLabel = status == 'success'
        ? 'Sucesso'
        : status == 'partial'
            ? 'Parcial'
            : status == 'running'
                ? 'Executando'
                : 'Erro';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (startedAt != null)
                  Text(
                    _formatDateTime(startedAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface
                          .withValues(alpha: 0.5),
                    ),
                  ),
                const Spacer(),
                if (errorMsg != null)
                  Icon(Icons.warning_amber_rounded,
                      size: 16, color: AppColors.error),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _LogStat(
                    label: 'Importadas',
                    value: '$imported',
                    color: Colors.green),
                _LogStat(
                    label: 'Atualizadas',
                    value: '$updated',
                    color: Colors.blue),
                _LogStat(
                    label: 'Duplicadas',
                    value: '$skipped',
                    color: Colors.orange),
                if (unknownSid > 0)
                  _LogStat(
                      label: 'SIDs desc.',
                      value: '$unknownSid',
                      color: AppColors.error),
                if (failed > 0)
                  _LogStat(
                      label: 'Falhas',
                      value: '$failed',
                      color: AppColors.error),
              ],
            ),
            if (errorMsg != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  errorMsg,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDateTime(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} '
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

class _LogStat extends StatelessWidget {
  const _LogStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}
