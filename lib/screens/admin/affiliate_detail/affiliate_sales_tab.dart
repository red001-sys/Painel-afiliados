import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../providers/admin_provider.dart';

class AffiliateSalesTab extends ConsumerStatefulWidget {
  const AffiliateSalesTab({super.key, required this.affiliateId});

  final String affiliateId;

  @override
  ConsumerState<AffiliateSalesTab> createState() => _AffiliateSalesTabState();
}

class _AffiliateSalesTabState extends ConsumerState<AffiliateSalesTab> {
  String _search = '';
  String _statusFilter = '';
  int _page = 0;
  static const _pageSize = 20;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final salesAsync = ref.watch(affiliateSalesProvider((
      affiliateId: widget.affiliateId,
      status: _statusFilter.isEmpty ? null : _statusFilter,
      search: _search.isEmpty ? null : _search,
    )));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: [
              TextField(
                onChanged: (v) => setState(() { _search = v; _page = 0; }),
                decoration: const InputDecoration(
                  hintText: 'Pesquisar por anunciante, produto ou pedido...',
                  prefixIcon: Icon(Icons.search_rounded),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Todos',
                      selected: _statusFilter.isEmpty,
                      onTap: () => setState(() { _statusFilter = ''; _page = 0; }),
                    ),
                    _FilterChip(
                      label: 'Pendente',
                      selected: _statusFilter == 'pending',
                      onTap: () => setState(() { _statusFilter = 'pending'; _page = 0; }),
                      color: Colors.orange,
                    ),
                    _FilterChip(
                      label: 'Aprovado',
                      selected: _statusFilter == 'approved',
                      onTap: () => setState(() { _statusFilter = 'approved'; _page = 0; }),
                      color: colorScheme.primary,
                    ),
                    _FilterChip(
                      label: 'Rejeitado',
                      selected: _statusFilter == 'rejected',
                      onTap: () => setState(() { _statusFilter = 'rejected'; _page = 0; }),
                      color: AppColors.error,
                    ),
                    _FilterChip(
                      label: 'Bloqueado',
                      selected: _statusFilter == 'locked',
                      onTap: () => setState(() { _statusFilter = 'locked'; _page = 0; }),
                      color: Colors.blueGrey,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: salesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                  const SizedBox(height: 16),
                  const Text('Erro ao carregar vendas'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(affiliateSalesProvider((
                      affiliateId: widget.affiliateId,
                      status: _statusFilter.isEmpty ? null : _statusFilter,
                      search: _search.isEmpty ? null : _search,
                    ))),
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
            data: (sales) {
              if (sales.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 64,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
                      const SizedBox(height: 16),
                      Text(
                        _search.isNotEmpty || _statusFilter.isNotEmpty
                            ? 'Nenhuma venda encontrada'
                            : 'Nenhuma venda registrada',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final now = DateTime.now();
              final todayStart = DateTime(now.year, now.month, now.day);
              final todaySales = sales.where((s) {
                final date = s['sale_date'] != null
                    ? DateTime.tryParse(s['sale_date'] as String)
                    : null;
                return date != null && date.isAfter(todayStart);
              }).toList();

              final todayCount = todaySales.length;
              final todayValue = todaySales.fold<double>(0, (sum, s) =>
                  sum + ((s['sale_amount'] as num?)?.toDouble() ?? 0));
              final todayCommission = todaySales.fold<double>(0, (sum, s) =>
                  sum + (((s['sale_amount'] as num?)?.toDouble() ?? 0) * 0.04));

              final totalPages = (sales.length / _pageSize).ceil();
              final pageSales = sales.skip(_page * _pageSize).take(_pageSize).toList();

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Card(
                      color: colorScheme.primary.withValues(alpha: 0.05),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(Icons.today_rounded,
                              color: colorScheme.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Hoje',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 16),
                            _TodayStat(label: 'Vendas', value: '$todayCount'),
                            const SizedBox(width: 12),
                            _TodayStat(
                              label: 'Valor',
                              value: 'US\$ ${todayValue.toStringAsFixed(2)}',
                            ),
                            const SizedBox(width: 12),
                            _TodayStat(
                              label: 'Comissão',
                              value: 'US\$ ${todayCommission.toStringAsFixed(2)}',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async => ref.invalidate(affiliateSalesProvider((
                        affiliateId: widget.affiliateId,
                        status: _statusFilter.isEmpty ? null : _statusFilter,
                        search: _search.isEmpty ? null : _search,
                      ))),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: pageSales.length,
                        itemBuilder: (context, index) => _SaleTile(sale: pageSales[index]),
                      ),
                    ),
                  ),
                  if (totalPages > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        border: Border(
                          top: BorderSide(
                            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left_rounded),
                            onPressed: _page > 0 ? () => setState(() => _page--) : null,
                          ),
                          Text(
                            '${_page + 1} / $totalPages',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right_rounded),
                            onPressed: _page < totalPages - 1 ? () => setState(() => _page++) : null,
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TodayStat extends StatelessWidget {
  const _TodayStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? effectiveColor.withValues(alpha: 0.15)
                : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? effectiveColor : Colors.transparent,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? effectiveColor : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}

class _SaleTile extends StatelessWidget {
  const _SaleTile({required this.sale});

  final Map<String, dynamic> sale;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final status = sale['status'] as String? ?? '';
    final saleAmount = (sale['sale_amount'] as num?)?.toDouble() ?? 0;
    final commissionAmount = saleAmount * 0.04;
    final saleDate = sale['sale_date'] != null
        ? DateTime.tryParse(sale['sale_date'] as String)
        : null;
    final dateFormat = DateFormat('dd/MM/yyyy');

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'approved':
        statusColor = colorScheme.primary;
        statusLabel = 'Aprovado';
      case 'pending':
        statusColor = Colors.orange;
        statusLabel = 'Pendente';
      case 'rejected':
        statusColor = AppColors.error;
        statusLabel = 'Rejeitado';
      case 'locked':
        statusColor = Colors.blueGrey;
        statusLabel = 'Bloqueado';
      default:
        statusColor = colorScheme.onSurface.withValues(alpha: 0.4);
        statusLabel = status;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sale['advertiser'] ?? sale['product'] ?? 'Sem anunciante',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (sale['product'] != null && sale['product'] != sale['advertiser'])
                        Text(
                          sale['product'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _SaleStat(
                  label: 'Venda',
                  value: 'US\$ ${saleAmount.toStringAsFixed(2)}',
                ),
                const SizedBox(width: 16),
                _SaleStat(
                  label: 'Comissão',
                  value: 'US\$ ${commissionAmount.toStringAsFixed(2)}',
                  color: colorScheme.primary,
                ),
                const Spacer(),
                if (saleDate != null)
                  Text(
                    dateFormat.format(saleDate),
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
              ],
            ),
            if (sale['order_id'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Pedido: ${sale['order_id']}',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SaleStat extends StatelessWidget {
  const _SaleStat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
