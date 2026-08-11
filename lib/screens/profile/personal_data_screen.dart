import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/affiliate_provider.dart';

class PersonalDataScreen extends ConsumerStatefulWidget {
  const PersonalDataScreen({super.key});

  @override
  ConsumerState<PersonalDataScreen> createState() => _PersonalDataScreenState();
}

class _PersonalDataScreenState extends ConsumerState<PersonalDataScreen> {
  final _nomeCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  bool _loadedOnce = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _whatsappCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final affiliateAsync = ref.watch(currentAffiliateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dados Pessoais'),
      ),
      body: affiliateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar dados: $e')),
        data: (affiliate) {
          if (affiliate == null) {
            return const Center(child: Text('Vendedor não encontrado'));
          }
          if (!_loadedOnce) {
            _nomeCtrl.text = affiliate.nome ?? '';
            _whatsappCtrl.text = affiliate.whatsapp ?? '';
            _loadedOnce = true;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _nomeCtrl,
                  decoration: const InputDecoration(labelText: 'Nome'),
                  textCapitalization: TextCapitalization.words,
                ),
                SizedBox(height: AppTheme.spacingMD),
                TextFormField(
                  initialValue: affiliate.email ?? '',
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    helperText: 'O email não pode ser alterado por aqui',
                  ),
                ),
                SizedBox(height: AppTheme.spacingMD),
                TextField(
                  controller: _whatsappCtrl,
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp',
                    hintText: 'Ex: 5511999999999',
                  ),
                  keyboardType: TextInputType.phone,
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
        'nome': _nomeCtrl.text.trim(),
        'whatsapp':
            _whatsappCtrl.text.trim().isEmpty ? null : _whatsappCtrl.text.trim(),
      });
      ref.invalidate(currentAffiliateProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dados atualizados')),
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
