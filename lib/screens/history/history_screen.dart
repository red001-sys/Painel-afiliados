import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/sale.dart';
import '../../providers/sales_provider.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/state_widgets.dart';
import '../../widgets/status_chip.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _searchQuery = '';
  String _statusFilter = 'all';
  int _displayCount = 20;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _loadMore() {
    final all = ref.read(salesProvider).valueOrNull ?? [];
    final filtered = _applyFilters(all);
    if (_displayCount < filtered.length) {
      setState(() => _displayCount += 20);
    }
  }

  List<Sale> _applyFilters(List<Sale> sales) {
    var result = sales;

    if (_statusFilter != 'all') {
      result = result.where((s) {
        final status = s.status?.toLowerCase() ?? '';
        switch (_statusFilter) {
          case 'pending':
            return status == 'pending' || status == 'locked';
          case 'approved':
            return status == 'approved';
          case 'cancelled':
            return status == 'rejected' || status == 'cancelled';
          default:
            return status == _statusFilter;
        }
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((s) {
        final product = s.product?.toLowerCase() ?? '';
        final advertiser = s.advertiser?.toLowerCase() ?? '';
        return product.contains(q) || advertiser.contains(q);
      }).toList();
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final salesAsync = ref.watch(salesProvider);

    return Column(
      children: [
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            onChanged: (v) => setState(() {
              _searchQuery = v;
              _displayCount = 20;
            }),
            decoration: const InputDecoration(
              hintText: 'Pesquisar produto ou anunciante...',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
        ),

        // Filters
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              _FilterChip(
                label: 'Todos',
                selected: _statusFilter == 'all',
                onTap: () => setState(() {
                  _statusFilter = 'all';
                  _displayCount = 20;
                }),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Pendentes',
                selected: _statusFilter == 'pending',
                onTap: () => setState(() {
                  _statusFilter = 'pending';
                  _displayCount = 20;
                }),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Aprovados',
                selected: _statusFilter == 'approved',
                onTap: () => setState(() {
                  _statusFilter = 'approved';
                  _displayCount = 20;
                }),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Cancelados',
                selected: _statusFilter == 'cancelled',
                onTap: () => setState(() {
                  _statusFilter = 'cancelled';
                  _displayCount = 20;
                }),
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: salesAsync.when(
            loading: () => const HistorySkeleton(),
            error: (e, _) => ErrorState(
              message: 'Erro ao carregar histórico',
              onRetry: () => ref.invalidate(salesProvider),
            ),
            data: (sales) {
              final filtered = _applyFilters(sales);

              if (filtered.isEmpty) {
                return EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Nenhuma venda encontrada',
                  subtitle: _searchQuery.isNotEmpty || _statusFilter != 'all'
                      ? 'Tente alterar os filtros de pesquisa'
                      : 'Suas vendas aparecerão aqui',
                  actionLabel: 'Atualizar',
                  onAction: () => ref.invalidate(salesProvider),
                );
              }

              final items = filtered.take(_displayCount).toList();
              final hasMore = items.length < filtered.length;

              return RefreshIndicator(
                onRefresh: () async {
                  setState(() => _displayCount = 20);
                  ref.invalidate(salesProvider);
                  await ref.read(salesProvider.future);
                },
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: items.length + (hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == items.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return _SaleTile(sale: items[index]);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SaleTile extends StatelessWidget {
  const _SaleTile({required this.sale});

  final Sale sale;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    sale.product ?? 'Produto desconhecido',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                StatusChip(status: sale.status ?? ''),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              sale.advertiser ?? 'Anunciante',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'Venda: R\$ ${(sale.saleAmount ?? 0).toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const Spacer(),
                Text(
                  'Comissão: R\$ ${sale.affiliateCommission.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            if (sale.saleDate != null) ...[
              const SizedBox(height: 6),
              Text(
                '${sale.saleDate!.day.toString().padLeft(2, '0')}/${sale.saleDate!.month.toString().padLeft(2, '0')}/${sale.saleDate!.year}',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final chipColor = colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? chipColor.withValues(alpha: 0.12)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? chipColor.withValues(alpha: 0.4)
                : colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? chipColor : colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}
