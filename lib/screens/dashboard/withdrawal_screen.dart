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

class WithdrawalScreen extends ConsumerStatefulWidget {
  const WithdrawalScreen({super.key});

  @override
  ConsumerState<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends ConsumerState<WithdrawalScreen> {
  final _valorController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _valorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final balanceAsync = ref.watch(myBalanceProvider);
    final requestsAsync = ref.watch(myWithdrawalRequestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitar Saque'),
        centerTitle: true,
      ),
      body: balanceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              const Text('Erro ao carregar saldo'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(myBalanceProvider);
                  ref.invalidate(myWithdrawalRequestsProvider);
                },
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
        data: (balance) => requestsAsync.when(
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
                  onPressed: () => ref.invalidate(myWithdrawalRequestsProvider),
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
          data: (requests) {
            final pending = requests.where((r) => r.isPending).toList();
            if (pending.isNotEmpty) {
              return _PendingRequestView(request: pending.first);
            }
            return _WithdrawalForm(
              balance: balance,
              hasPrevious: requests.isNotEmpty,
              valorController: _valorController,
              formKey: _formKey,
              isSubmitting: _isSubmitting,
              onSubmit: _handleSubmit,
            );
          },
        ),
      ),
    );
  }

  Future<void> _handleSubmit(double valor) async {
    setState(() => _isSubmitting = true);
    try {
      await ref.read(withdrawalRepositoryProvider).requestWithdrawal(valor);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solicitação de saque criada com sucesso!'),
          backgroundColor: AppColors.success,
        ),
      );
      ref.invalidate(myWithdrawalRequestsProvider);
      ref.invalidate(myBalanceProvider);
      _valorController.clear();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_cleanDbMessage(e.message)),
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
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _cleanDbMessage(String raw) {
    var msg = raw.trim();
    final firstLine = msg.split('\n').first;
    final clean = firstLine.replaceFirst(RegExp(r'^P0001'), '').trim();
    return clean.isEmpty ? raw : clean;
  }
}

class _PendingRequestView extends StatelessWidget {
  const _PendingRequestView({required this.request});

  final WithdrawalRequest request;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                const Icon(Icons.hourglass_top_rounded,
                    size: 48, color: AppColors.warning),
                const SizedBox(height: 12),
                Text(
                  'R\$ ${request.valor.toStringAsFixed(2)} em análise',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Solicitado em ${dateFormat.format(request.createdAt)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Você já tem um saque pendente de análise. '
                  'Assim que o pagamento for confirmado, você poderá '
                  'solicitar um novo saque.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const CopyrightFooter(),
        ],
      ),
    );
  }
}

class _WithdrawalForm extends StatelessWidget {
  const _WithdrawalForm({
    required this.balance,
    required this.hasPrevious,
    required this.valorController,
    required this.formKey,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final double balance;
  final bool hasPrevious;
  final TextEditingController valorController;
  final GlobalKey<FormState> formKey;
  final bool isSubmitting;
  final void Function(double valor) onSubmit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.ecoGreen, AppColors.ecoGreenDark],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Saldo disponível para saque',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'R\$ ${balance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'O saldo considera as comissões aprovadas descontando '
                    'saques pagos e pendentes.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingLG),
            Text(
              hasPrevious ? 'Escolha o valor do saque' : 'Informe o valor do saque',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hasPrevious
                  ? 'Após o primeiro saque, os valores permitidos são \$50, \$100 ou o saldo total.'
                  : 'O saque mínimo é de \$5 e o valor máximo é o seu saldo disponível.',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: AppTheme.spacingMD),

            if (hasPrevious)
              _ValueChips(
                balance: balance,
                valorController: valorController,
                formKey: formKey,
                isSubmitting: isSubmitting,
              )
            else
              TextFormField(
                controller: valorController,
                enabled: !isSubmitting,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                validator: (value) {
                  final v = double.tryParse(value ?? '');
                  if (v == null || v <= 0) return 'Informe um valor válido';
                  if (v < 5) return 'O saque mínimo é de \$5';
                  if (v > balance) return 'Valor maior que o saldo disponível';
                  return null;
                },
                decoration: const InputDecoration(
                  labelText: 'Valor (R\$)',
                  hintText: '0.00',
                  prefixIcon: Icon(Icons.attach_money_rounded),
                ),
              ),

            const SizedBox(height: AppTheme.spacingLG),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () {
                        if (!formKey.currentState!.validate()) return;
                        final v = double.tryParse(valorController.text);
                        if (v == null) return;
                        onSubmit(v);
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Solicitar saque'),
              ),
            ),
            const SizedBox(height: AppTheme.spacingLG),
            const CopyrightFooter(),
          ],
        ),
      ),
    );
  }
}

class _ValueChips extends StatelessWidget {
  const _ValueChips({
    required this.balance,
    required this.valorController,
    required this.formKey,
    required this.isSubmitting,
  });

  final double balance;
  final TextEditingController valorController;
  final GlobalKey<FormState> formKey;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    final options = [50.0, 100.0];
    final hasTotalOption = !options.contains(balance);

    Widget buildOption(double value, String label) {
      final enabled = !isSubmitting && value <= balance;
      return Expanded(
        child: OutlinedButton(
          onPressed: enabled
              ? () {
                  valorController.text = value.toStringAsFixed(2);
                  formKey.currentState!.validate();
                }
              : null,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: Text(label),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            buildOption(options[0], '\$50'),
            const SizedBox(width: 8),
            buildOption(options[1], '\$100'),
          ],
        ),
        if (hasTotalOption) ...[
          const SizedBox(height: 8),
          buildOption(balance, 'Sacar tudo (R\$ ${balance.toStringAsFixed(2)})'),
        ],
      ],
    );
  }
}
