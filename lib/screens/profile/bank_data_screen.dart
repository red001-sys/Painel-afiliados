import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/affiliate_provider.dart';

class BankDataScreen extends ConsumerStatefulWidget {
  const BankDataScreen({super.key});

  @override
  ConsumerState<BankDataScreen> createState() => _BankDataScreenState();
}

class _BankDataScreenState extends ConsumerState<BankDataScreen> {
  final _pixCtrl = TextEditingController();
  bool _loadedOnce = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _pixCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final affiliateAsync = ref.watch(currentAffiliateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dados Bancários'),
      ),
      body: affiliateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar dados: $e')),
        data: (affiliate) {
          if (affiliate == null) {
            return const Center(child: Text('Afiliado não encontrado'));
          }
          if (!_loadedOnce) {
            _pixCtrl.text = affiliate.chavePix ?? '';
            _loadedOnce = true;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.ecoGreenSurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 18, color: AppColors.ecoGreenDark),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Essa chave é usada para o pagamento das suas comissões.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.ecoGreenDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppTheme.spacingMD),
                TextField(
                  controller: _pixCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Chave PIX',
                    hintText: 'CPF, email, telefone ou chave aleatória',
                  ),
                ),
                SizedBox(height: AppTheme.spacingLG),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Salvar'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(affiliateRepositoryProvider).updateSelf({
        'chave_pix': _pixCtrl.text.trim().isEmpty ? null : _pixCtrl.text.trim(),
      });
      ref.invalidate(currentAffiliateProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chave PIX atualizada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
