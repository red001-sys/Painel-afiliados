import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/affiliate.dart';
import '../../../providers/admin_provider.dart';

class AffiliateInfoTab extends ConsumerWidget {
  const AffiliateInfoTab({super.key, required this.affiliate});

  final Affiliate affiliate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(affiliateStatsProvider(affiliate.id));
    final isActive = affiliate.authUserId != null;
    final dateFormat = DateFormat('dd/MM/yyyy');
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: (isActive ? colorScheme.primary : Colors.orange)
                        .withValues(alpha: 0.1),
                    child: Icon(
                      Icons.person_rounded,
                      size: 32,
                      color: isActive ? colorScheme.primary : Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          affiliate.nome ?? 'Sem nome',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          affiliate.email ?? 'Sem email',
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'SID: ${affiliate.sid}',
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isActive ? colorScheme.primary : Colors.orange)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isActive ? 'Ativo' : 'Pendente',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isActive ? colorScheme.primary : Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Resumo',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          statsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Text('Erro ao carregar stats'),
            data: (stats) => Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Total de Vendas',
                        value: '${stats['salesCount'] ?? 0}',
                        icon: Icons.shopping_cart_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatCard(
                        label: 'Valor Vendido',
                        value: 'US\$ ${((stats['totalSales'] ?? 0) as num).toStringAsFixed(2)}',
                        icon: Icons.payments_rounded,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Comissão Total',
                        value: 'US\$ ${((stats['totalCommission'] ?? 0) as num).toStringAsFixed(2)}',
                        icon: Icons.attach_money_rounded,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatCard(
                        label: 'Pendente',
                        value: 'US\$ ${((stats['pendingCommission'] ?? 0) as num).toStringAsFixed(2)}',
                        icon: Icons.schedule_rounded,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Aprovada',
                        value: 'US\$ ${((stats['approvedCommission'] ?? 0) as num).toStringAsFixed(2)}',
                        icon: Icons.check_circle_outline,
                        color: colorScheme.primary,
                      ),
                    ),
                    const Expanded(child: SizedBox()),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.calendar_today_rounded, size: 20),
              title: const Text('Data de Cadastro'),
              subtitle: Text(dateFormat.format(affiliate.createdAt)),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.primary;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: effectiveColor),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: effectiveColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
