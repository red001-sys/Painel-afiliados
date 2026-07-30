import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/affiliate.dart';
import '../../../providers/admin_provider.dart';

class AffiliateSettingsTab extends ConsumerStatefulWidget {
  const AffiliateSettingsTab({super.key, required this.affiliateId});

  final String affiliateId;

  @override
  ConsumerState<AffiliateSettingsTab> createState() => _AffiliateSettingsTabState();
}

class _AffiliateSettingsTabState extends ConsumerState<AffiliateSettingsTab> {
  @override
  Widget build(BuildContext context) {
    final affiliateAsync = ref.watch(affiliateDetailProvider(widget.affiliateId));

    return affiliateAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const Center(child: Text('Erro ao carregar afiliado')),
      data: (affiliate) {
        if (affiliate == null) {
          return const Center(child: Text('Afiliado não encontrado'));
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Editar Afiliado',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: AppTheme.spacingLG),
              _EditForm(affiliate: affiliate),
              SizedBox(height: AppTheme.spacingXL),
              const Divider(),
              SizedBox(height: AppTheme.spacingMD),
              const Text(
                'Zona de Perigo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
              SizedBox(height: AppTheme.spacingMD),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _deleteAffiliate(context, affiliate),
                  icon: const Icon(Icons.delete_rounded, color: AppColors.error),
                  label: const Text(
                    'Excluir Afiliado',
                    style: TextStyle(color: AppColors.error),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteAffiliate(BuildContext context, Affiliate affiliate) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir afiliado'),
        content: Text(
          'Deseja excluir ${affiliate.nome ?? affiliate.email}? '
          'Todos os links e dados associados serão removidos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      try {
        await ref.read(adminRepositoryProvider).deleteAffiliate(affiliate.id);
        if (context.mounted) {
          ref.invalidate(adminAffiliatesProvider);
          ref.invalidate(adminAffiliatesWithStatsProvider);
          Navigator.pushReplacementNamed(context, AppRouter.admin);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
}

class _EditForm extends ConsumerStatefulWidget {
  const _EditForm({required this.affiliate});

  final Affiliate affiliate;

  @override
  ConsumerState<_EditForm> createState() => _EditFormState();
}

class _EditFormState extends ConsumerState<_EditForm> {
  late TextEditingController _nomeCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _whatsappCtrl;
  late TextEditingController _pixCtrl;
  bool _isActive = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nomeCtrl = TextEditingController(text: widget.affiliate.nome ?? '');
    _emailCtrl = TextEditingController(text: widget.affiliate.email ?? '');
    _whatsappCtrl = TextEditingController(text: widget.affiliate.whatsapp ?? '');
    _pixCtrl = TextEditingController(text: widget.affiliate.chavePix ?? '');
    _isActive = widget.affiliate.authUserId != null;
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _emailCtrl.dispose();
    _whatsappCtrl.dispose();
    _pixCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        TextField(
          controller: _nomeCtrl,
          decoration: const InputDecoration(labelText: 'Nome'),
        ),
        SizedBox(height: AppTheme.spacingMD),
        TextField(
          controller: _emailCtrl,
          decoration: const InputDecoration(labelText: 'Email'),
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
        SizedBox(height: AppTheme.spacingMD),
        TextField(
          controller: _pixCtrl,
          decoration: const InputDecoration(labelText: 'Chave PIX'),
        ),
        SizedBox(height: AppTheme.spacingMD),
        TextFormField(
          initialValue: widget.affiliate.sid,
          readOnly: true,
          decoration: InputDecoration(
            labelText: 'SID',
            suffixIcon: Icon(
              Icons.lock_outline_rounded,
              size: 18,
              color: colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            helperText: 'O SID não pode ser editado diretamente',
            helperStyle: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ),
        SizedBox(height: AppTheme.spacingMD),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Ativo'),
          subtitle: Text(
            _isActive ? 'Afiliado com acesso ativo' : 'Afiliado pendente de ativação',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          value: _isActive,
          onChanged: (v) => setState(() => _isActive = v),
          activeColor: AppColors.ecoGreen,
        ),
        SizedBox(height: AppTheme.spacingLG),
        SizedBox(
          height: 48,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Salvar'),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    try {
      await ref.read(adminRepositoryProvider).updateAffiliate(
        widget.affiliate.id,
        {
          'nome': _nomeCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'whatsapp': _whatsappCtrl.text.trim().isEmpty
              ? null
              : _whatsappCtrl.text.trim(),
          'chave_pix': _pixCtrl.text.trim().isEmpty
              ? null
              : _pixCtrl.text.trim(),
        },
      );

      ref.invalidate(affiliateDetailProvider(widget.affiliate.id));
      ref.invalidate(adminAffiliatesProvider);
      ref.invalidate(adminAffiliatesWithStatsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Afiliado atualizado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
