import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/admin_provider.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(adminDashboardProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(adminDashboardProvider),
      child: dataAsync.when(
        loading: () => const _Skeleton(),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              const Text('Erro ao carregar dados'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () =>
                    ref.invalidate(adminDashboardProvider),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
        data: (data) => ListView(
          padding: EdgeInsets.all(AppTheme.spacingMD),
          children: [
            Row(
              children: [
                Expanded(
                    child: _MetricCard(
                  icon: Icons.people_rounded,
                  label: 'Total Afiliados',
                  value: '${data['affiliatesCount']}',
                  color: AppColors.ecoGreen,
                )),
                const SizedBox(width: 12),
                Expanded(
                    child: _MetricCard(
                  icon: Icons.person_rounded,
                  label: 'Ativos',
                  value: '${data['activeAffiliatesCount']}',
                  color: Colors.blue,
                )),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _MetricCard(
                  icon: Icons.inventory_2_rounded,
                  label: 'Produtos',
                  value: '${data['productsCount']}',
                  color: Colors.orange,
                )),
                const SizedBox(width: 12),
                Expanded(
                    child: _MetricCard(
                  icon: Icons.receipt_long_rounded,
                  label: 'Total Vendas',
                  value: '${data['salesCount']}',
                  color: Colors.purple,
                )),
              ],
            ),
            const SizedBox(height: 12),
            _MetricCard(
              icon: Icons.attach_money_rounded,
              label: 'Comissão Total (Aprovada)',
              value:
                  'R\$ ${(data['totalCommission'] as num?)?.toDouble().toStringAsFixed(2) ?? '0.00'}',
              color: AppColors.ecoGreen,
              wide: true,
            ),
            const SizedBox(height: 20),
            _LastSyncCard(
                syncData: data['lastSync'] as Map<String, dynamic>?),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.wide = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: wide ? 28 : 24,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LastSyncCard extends StatelessWidget {
  const _LastSyncCard({required this.syncData});

  final Map<String, dynamic>? syncData;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (syncData == null) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(AppTheme.spacingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.sync_rounded,
                      size: 20, color: AppColors.ecoGreen),
                  const SizedBox(width: 8),
                  Text(
                    'Última Sincronização',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Nenhuma sincronização realizada',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurface
                      .withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final status = syncData!['status'] ?? 'unknown';
    final imported =
        syncData!['transactions_imported'] ?? 0;
    final updated = syncData!['transactions_updated'] ?? 0;
    final skipped =
        syncData!['transactions_skipped'] ?? 0;
    final unknownSid = syncData!['unknown_sid'] ?? 0;
    final failed =
        syncData!['transactions_failed'] ?? 0;
    final finishedAt = syncData!['finished_at'];
    final durationMs = syncData!['duration_ms'] as int?;

    final statusColor = status == 'success'
        ? Colors.green
        : status == 'partial'
            ? Colors.orange
            : AppColors.error;

    final statusLabel = status == 'success'
        ? 'Sucesso'
        : status == 'partial'
            ? 'Parcial'
            : 'Erro';

    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sync_rounded,
                    size: 20, color: AppColors.ecoGreen),
                const SizedBox(width: 8),
                Text(
                  'Última Sincronização',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
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
              ],
            ),
            const SizedBox(height: 12),
            if (finishedAt != null) ...[
              Text(
                'Data: ${_formatFinishedDate(finishedAt)}'
                '${durationMs != null ? ' · ${_formatDuration(durationMs)}' : ''}',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurface
                      .withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _SyncStat(
                    label: 'Importadas',
                    value: '$imported',
                    color: Colors.green),
                _SyncStat(
                    label: 'Atualizadas',
                    value: '$updated',
                    color: Colors.blue),
                _SyncStat(
                    label: 'Duplicadas',
                    value: '$skipped',
                    color: Colors.orange),
                _SyncStat(
                    label: 'SIDs desc.',
                    value: '$unknownSid',
                    color: AppColors.error),
                if (failed > 0)
                  _SyncStat(
                      label: 'Falhas',
                      value: '$failed',
                      color: AppColors.error),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatFinishedDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  String _formatDuration(int ms) {
    final seconds = (ms / 1000).round();
    if (seconds < 60) return '${seconds}s';
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes}m ${remainingSeconds}s';
  }
}

class _SyncStat extends StatelessWidget {
  const _SyncStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color),
        ),
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

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                  child: _ShimmerBox(
                      width: double.infinity, height: 90)),
              const SizedBox(width: 12),
              const Expanded(
                  child: _ShimmerBox(
                      width: double.infinity, height: 90)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                  child: _ShimmerBox(
                      width: double.infinity, height: 90)),
              const SizedBox(width: 12),
              const Expanded(
                  child: _ShimmerBox(
                      width: double.infinity, height: 90)),
            ],
          ),
          const SizedBox(height: 12),
          const _ShimmerBox(width: double.infinity, height: 90),
        ],
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
