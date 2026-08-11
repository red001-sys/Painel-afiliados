import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/withdrawal_request.dart';
import '../../providers/withdrawal_provider.dart';
import '../../widgets/copyright_footer.dart';

class AdminWithdrawalsScreen extends ConsumerStatefulWidget {
  const AdminWithdrawalsScreen({super.key});

  @override
  ConsumerState<AdminWithdrawalsScreen> createState() =>
      _AdminWithdrawalsScreenState();
}

class _AdminWithdrawalsScreenState
    extends ConsumerState<AdminWithdrawalsScreen> {
  String _filter = 'pendente';

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(adminWithdrawalRequestsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'pendente',
                label: Text('Pendentes'),
                icon: Icon(Icons.schedule_rounded),
              ),
              ButtonSegment(
                value: 'pago',
                label: Text('Pagos'),
                icon: Icon(Icons.check_circle_rounded),
              ),
              ButtonSegment(
                value: 'todos',
                label: Text('Todos'),
                icon: Icon(Icons.list_rounded),
              ),
            ],
            selected: {_filter},
            onSelectionChanged: (selection) {
              setState(() => _filter = selection.first);
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: requestsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                  const SizedBox(height: 16),
                  const Text('Erro ao carregar solicitações'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () =>
                        ref.invalidate(adminWithdrawalRequestsProvider),
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
            data: (requests) {
              final filtered = _filter == 'todos'
                  ? requests
                  : requests.where((r) => r.status == _filter).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.payments_outlined,
                        size: 64,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.2),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhuma solicitação ${_filter == 'pendente' ? 'pendente' : _filter == 'pago' ? 'paga' : ''}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(adminWithdrawalRequestsProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length + 1,
                  itemBuilder: (context, index) {
                    if (index == filtered.length) {
                      return const CopyrightFooter();
                    }
                    final request = filtered[index];
                    return _WithdrawalTile(
                      request: request,
                      onConfirmed: () async {
                        await _confirmPayment(request);
                      },
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _confirmPayment(WithdrawalRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar pagamento'),
        content: Text(
          'Confirma que o PIX de R\$ ${request.valor.toStringAsFixed(2)} '
          'para ${request.affiliateName ?? 'o vendedor'} foi pago? '
          'Esta ação não tem volta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar pagamento'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(withdrawalRepositoryProvider).confirmPayment(request.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pagamento confirmado!'),
          backgroundColor: AppColors.success,
        ),
      );
      ref.invalidate(adminWithdrawalRequestsProvider);
      ref.invalidate(pendingWithdrawalCountProvider);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

class _WithdrawalTile extends StatelessWidget {
  const _WithdrawalTile({required this.request, required this.onConfirmed});

  final WithdrawalRequest request;
  final VoidCallback onConfirmed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    final statusColor = switch (request.status) {
      'pendente' => AppColors.warning,
      'pago' => AppColors.success,
      _ => AppColors.neutral500,
    };

    final statusLabel = switch (request.status) {
      'pendente' => 'Pendente',
      'pago' => 'Pago',
      _ => 'Cancelado',
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                        request.affiliateName ?? 'Vendedor',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Pedido em ${dateFormat.format(request.createdAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
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
            Row(
              children: [
                Icon(Icons.attach_money_rounded, color: colorScheme.primary),
                Text(
                  'R\$ ${request.valor.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (request.chavePixSnapshot != null &&
                request.chavePixSnapshot!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.pix_rounded, size: 18, color: AppColors.neutral600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      request.chavePixSnapshot!,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: request.chavePixSnapshot!),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Chave PIX copiada!'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
            if (request.paidAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'Pago em ${dateFormat.format(request.paidAt!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
            if (request.isPending) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onConfirmed,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Confirmar pagamento'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
