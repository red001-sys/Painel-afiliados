import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../core/constants/app_colors.dart';
import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../models/affiliate.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/copyright_footer.dart';

class AdminAffiliatesScreen extends ConsumerStatefulWidget {
  const AdminAffiliatesScreen({super.key});

  @override
  ConsumerState<AdminAffiliatesScreen> createState() => _AdminAffiliatesScreenState();
}

class _AdminAffiliatesScreenState extends ConsumerState<AdminAffiliatesScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(adminAffiliatesWithStatsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: const InputDecoration(
                    hintText: 'Pesquisar por nome, email ou SID...',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () => _showCreateAffiliateDialog(),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ),
        Expanded(
          child: dataAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                  const SizedBox(height: 16),
                  const Text('Erro ao carregar afiliados'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(adminAffiliatesWithStatsProvider),
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
            data: (rows) {
              final filtered = rows.where((row) {
                if (_search.isEmpty) return true;
                final a = row['affiliate'] as Affiliate;
                final q = _search.toLowerCase();
                return (a.nome?.toLowerCase().contains(q) ?? false) ||
                    (a.email?.toLowerCase().contains(q) ?? false) ||
                    a.sid.toLowerCase().contains(q);
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
                      const SizedBox(height: 16),
                      Text(
                        _search.isNotEmpty ? 'Nenhum afiliado encontrado' : 'Nenhum afiliado cadastrado',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(adminAffiliatesWithStatsProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length + 1,
                  itemBuilder: (context, index) {
                    if (index == filtered.length) {
                      return const CopyrightFooter();
                    }
                    final row = filtered[index];
                    final affiliate = row['affiliate'] as Affiliate;
                    final salesCount = row['salesCount'] as int;
                    final totalCommission = row['totalCommission'] as double;
                    return _AffiliateTile(
                      affiliate: affiliate,
                      salesCount: salesCount,
                      totalCommission: totalCommission,
                      onRefresh: () => ref.invalidate(adminAffiliatesWithStatsProvider),
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

  void _showCreateAffiliateDialog() {
    final nomeCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final sidCtrl = TextEditingController();
    final whatsappCtrl = TextEditingController();
    final pixCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Novo Afiliado',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: AppTheme.spacingLG),
              TextField(
                controller: nomeCtrl,
                decoration: const InputDecoration(labelText: 'Nome *'),
                textCapitalization: TextCapitalization.words,
              ),
              SizedBox(height: AppTheme.spacingMD),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email *'),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: AppTheme.spacingMD),
              TextField(
                controller: sidCtrl,
                decoration: const InputDecoration(
                  labelText: 'SID *',
                  hintText: 'Ex: Mitchelllima',
                ),
              ),
              SizedBox(height: AppTheme.spacingMD),
              TextField(
                controller: whatsappCtrl,
                decoration: const InputDecoration(
                  labelText: 'WhatsApp',
                  hintText: 'Ex: 5511999999999',
                ),
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: AppTheme.spacingMD),
              TextField(
                controller: pixCtrl,
                decoration: const InputDecoration(
                  labelText: 'Chave PIX',
                ),
              ),
              SizedBox(height: AppTheme.spacingXL),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    final nome = nomeCtrl.text.trim();
                    final email = emailCtrl.text.trim();
                    final sid = sidCtrl.text.trim();

                    if (nome.isEmpty || email.isEmpty || sid.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Preencha todos os campos obrigatórios'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                      return;
                    }

                    try {
                      await ref.read(adminRepositoryProvider).createAffiliate(
                            nome: nome,
                            email: email,
                            sid: sid,
                            whatsapp: whatsappCtrl.text.trim().isEmpty
                                ? null
                                : whatsappCtrl.text.trim(),
                            chavePix: pixCtrl.text.trim().isEmpty
                                ? null
                                : pixCtrl.text.trim(),
                          );
                      if (ctx.mounted) Navigator.pop(ctx);
                      ref.invalidate(adminAffiliatesWithStatsProvider);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Afiliado criado com sucesso')),
                        );
                      }
                    } catch (e, stackTrace) {
                      debugPrint('[ADMIN_SCREEN] createAffiliate error: $e');
                      debugPrint('[ADMIN_SCREEN] stackTrace: $stackTrace');
                      if (ctx.mounted) {
                        String msg;
                        if (e is PostgrestException) {
                          debugPrint('[ADMIN_SCREEN] PostgrestException:');
                          debugPrint('[ADMIN_SCREEN]   code: ${e.code}');
                          debugPrint('[ADMIN_SCREEN]   message: ${e.message}');
                          debugPrint('[ADMIN_SCREEN]   details: ${e.details}');
                          debugPrint('[ADMIN_SCREEN]   hint: ${e.hint}');
                          if (e.code == '23505') {
                            msg = 'Email ou SID já cadastrado';
                          } else {
                            msg = 'Erro DB [${e.code}]: ${e.message}';
                          }
                        } else {
                          msg = 'Erro: $e';
                        }
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text(msg), backgroundColor: AppColors.error),
                        );
                      }
                    }
                  },
                  child: const Text('Salvar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AffiliateTile extends ConsumerWidget {
  const _AffiliateTile({
    required this.affiliate,
    required this.salesCount,
    required this.totalCommission,
    required this.onRefresh,
  });

  final Affiliate affiliate;
  final int salesCount;
  final double totalCommission;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isActive = affiliate.authUserId != null;
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: (isActive ? AppColors.ecoGreen : Colors.orange)
                      .withValues(alpha: 0.1),
                  child: Icon(
                    Icons.person_rounded,
                    color: isActive ? AppColors.ecoGreen : Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        affiliate.nome ?? affiliate.email ?? 'Sem nome',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (affiliate.email != null)
                        Text(
                          affiliate.email!,
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isActive ? AppColors.ecoGreen : Colors.orange)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isActive ? 'Ativo' : 'Pendente',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isActive ? AppColors.ecoGreen : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _InfoChip(
                  icon: Icons.tag_rounded,
                  label: 'SID: ${affiliate.sid}',
                  isMono: true,
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: affiliate.sid));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('SID copiado!'), duration: Duration(seconds: 1)),
                    );
                  },
                  child: Icon(Icons.copy_rounded, size: 14,
                    color: colorScheme.onSurface.withValues(alpha: 0.4)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _StatBadge(
                  label: 'Vendas',
                  value: '$salesCount',
                  color: AppColors.ecoGreen,
                ),
                const SizedBox(width: 8),
                _StatBadge(
                  label: 'Comissão',
                  value: 'US\$ ${totalCommission.toStringAsFixed(2)}',
                  color: AppColors.ecoGreen,
                ),
                const SizedBox(width: 8),
                _StatBadge(
                  label: 'Cadastro',
                  value: dateFormat.format(affiliate.createdAt),
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    await Navigator.pushNamed(
                      context,
                      AppRouter.affiliateDetail,
                      arguments: affiliate.id,
                    );
                    ref.invalidate(adminAffiliatesWithStatsProvider);
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Detalhes'),
                ),
                TextButton.icon(
                  onPressed: () => _deleteAffiliate(context, ref),
                  icon: const Icon(Icons.delete_rounded, size: 16, color: AppColors.error),
                  label: const Text('Excluir', style: TextStyle(color: AppColors.error)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAffiliate(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir afiliado'),
        content: Text('Deseja excluir ${affiliate.nome ?? affiliate.email}?'),
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Afiliado excluído')),
          );
        }
        onRefresh();
      } catch (e, stackTrace) {
        debugPrint('[ADMIN_SCREEN] deleteAffiliate error: $e');
        debugPrint('[ADMIN_SCREEN] stackTrace: $stackTrace');
        if (context.mounted) {
          String msg;
          if (e is PostgrestException) {
            msg = 'Erro DB [${e.code}]: ${e.message}';
          } else {
            msg = 'Erro ao excluir: $e';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label, this.isMono = false});

  final IconData icon;
  final String label;
  final bool isMono;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontFamily: isMono ? 'monospace' : null,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color ?? Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
