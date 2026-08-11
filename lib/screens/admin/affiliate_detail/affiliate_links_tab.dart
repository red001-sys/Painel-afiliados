import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/affiliate.dart';
import '../../../models/affiliate_link.dart';
import '../../../models/product.dart';
import '../../../providers/admin_provider.dart';
import '../../../providers/product_provider.dart';

const _allowedCjDomains = [
  'dpbolvw.net',
  'kqzyfj.com',
  'anrdoezrs.net',
  'tkqlhce.com',
  'jdoqocy.com',
  'dpbolvw.net',
  'kqzyfj.com',
];

class AffiliateLinksTab extends ConsumerStatefulWidget {
  const AffiliateLinksTab({super.key, required this.affiliateId});

  final String affiliateId;

  @override
  ConsumerState<AffiliateLinksTab> createState() => _AffiliateLinksTabState();
}

class _AffiliateLinksTabState extends ConsumerState<AffiliateLinksTab> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final linksAsync = ref.watch(affiliateLinksProvider(widget.affiliateId));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Links finais da CJ copiados pelo admin',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () => _showLinkDialog(),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ),
        Expanded(
          child: linksAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                  const SizedBox(height: 16),
                  const Text('Erro ao carregar links'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(affiliateLinksProvider(widget.affiliateId)),
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
            data: (links) {
              if (links.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.link_rounded, size: 64,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhum link cadastrado',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => _showLinkDialog(),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Adicionar Link'),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(affiliateLinksProvider(widget.affiliateId)),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: links.length,
                  itemBuilder: (context, index) => _LinkTile(
                    link: links[index],
                    onToggle: (ativo) => _toggleLink(links[index], ativo),
                    onDelete: () => _deleteLink(context, links[index]),
                    onEdit: () => _showLinkDialog(link: links[index]),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showLinkDialog({AffiliateLink? link}) {
    final isEdit = link != null;
    String? selectedProductId = link?.productId;
    final finalLinkCtrl = TextEditingController(text: link?.finalLink ?? '');
    bool ativo = link?.ativo ?? true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isEdit ? 'Editar Link' : 'Novo Link',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: AppTheme.spacingLG),
                DropdownButtonFormField<String>(
                  value: selectedProductId,
                  decoration: const InputDecoration(labelText: 'Produto *'),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Selecionar produto...'),
                    ),
                    ..._dedupedSellableProducts(ref.read(activeProductsProvider).valueOrNull)
                        .map(
                      (p) => DropdownMenuItem(
                        value: p.id,
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: p.imagemUrl != null
                                    ? Image.network(
                                        p.imagemUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: AppColors.neutral200,
                                          child: const Icon(Icons.inventory_2_outlined, size: 16),
                                        ),
                                      )
                                    : Container(
                                        color: AppColors.neutral200,
                                        child: const Icon(Icons.inventory_2_outlined, size: 16),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                p.nome,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) => setModalState(() => selectedProductId = v),
                ),
                SizedBox(height: AppTheme.spacingMD),
                TextField(
                  controller: finalLinkCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Link de vendedor *',
                    hintText: 'Cole o link completo com SID incluso',
                  ),
                  maxLines: 3,
                ),
                SizedBox(height: AppTheme.spacingMD),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ativo'),
                  value: ativo,
                  onChanged: (v) => setModalState(() => ativo = v),
                  activeColor: Theme.of(ctx).colorScheme.primary,
                ),
                SizedBox(height: AppTheme.spacingXL),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (selectedProductId == null || finalLinkCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Preencha produto e link final'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }

                      final linkUrl = finalLinkCtrl.text.trim();

                      final urlError = _validateCjLink(linkUrl);
                      if (urlError != null) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text(urlError), backgroundColor: AppColors.error),
                        );
                        return;
                      }

                      final affiliateAsync = ref.read(affiliateDetailProvider(widget.affiliateId));
                      final affiliate = affiliateAsync.valueOrNull;
                      if (affiliate == null) return;

                      final sidError = _validateSid(linkUrl, affiliate.sid);
                      if (sidError != null) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text(sidError), backgroundColor: AppColors.error),
                        );
                        return;
                      }

                      final repo = ref.read(affiliateLinkRepositoryProvider);
                      final newLink = AffiliateLink(
                        id: link?.id ?? '',
                        affiliateId: widget.affiliateId,
                        productId: selectedProductId!,
                        cjBaseLink: link?.cjBaseLink,
                        finalLink: linkUrl,
                        linkName: link?.linkName,
                        displayOrder: link?.displayOrder ?? 0,
                        ativo: ativo,
                        createdAt: link?.createdAt ?? DateTime.now(),
                        updatedAt: link?.updatedAt ?? DateTime.now(),
                      );

                      try {
                        if (isEdit) {
                          await repo.update(newLink);
                        } else {
                          await repo.create(newLink);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        ref.invalidate(affiliateLinksProvider(widget.affiliateId));
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text('Erro ao salvar link: $e'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
                    },
                    child: Text(isEdit ? 'Salvar' : 'Cadastrar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleLink(AffiliateLink link, bool ativo) async {
    try {
      await ref.read(affiliateLinkRepositoryProvider).toggleAtivo(link.id, ativo);
      ref.invalidate(affiliateLinksProvider(widget.affiliateId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _deleteLink(BuildContext context, AffiliateLink link) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir link'),
        content: const Text('Deseja excluir este link?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      try {
        await ref.read(affiliateLinkRepositoryProvider).delete(link.id);
        ref.invalidate(affiliateLinksProvider(widget.affiliateId));
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao excluir: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.link,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
  });

  final AffiliateLink link;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (link.productImagemUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      link.productImagemUrl!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 48,
                        height: 48,
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        child: Icon(Icons.inventory_2_rounded, size: 24, color: colorScheme.primary),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.inventory_2_rounded, size: 24, color: colorScheme.primary),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        link.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (link.productCategoria != null)
                        Text(
                          link.productCategoria!,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      if (link.productPreco != null)
                        Text(
                          '\$ ${link.productPreco!.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      if (link.productDescricao != null)
                        Text(
                          link.productDescricao!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: (link.ativo ? colorScheme.primary : Colors.orange).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    link.ativo ? 'Ativo' : 'Inativo',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: link.ativo ? colorScheme.primary : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            if (link.linkName != null && link.linkName!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Icon(Icons.label_rounded, size: 14,
                      color: colorScheme.onSurface.withValues(alpha: 0.4)),
                    const SizedBox(width: 4),
                    Text(
                      link.linkName!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                link.finalLink,
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  tooltip: 'Copiar',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: link.finalLink));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link copiado!'), duration: Duration(seconds: 1)),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  tooltip: 'Abrir',
                  onPressed: () async {
                    final launched = await launchUrl(Uri.parse(link.finalLink));
                    if (!launched && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Não foi possível abrir o link')),
                      );
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.share_rounded, size: 18),
                  tooltip: 'Compartilhar',
                  onPressed: () async {
                    final box = context.findRenderObject() as RenderBox?;
                    await Share.share(
                      link.finalLink,
                      subject: link.displayName,
                      sharePositionOrigin: box != null
                          ? box.localToGlobal(Offset.zero) & box.size
                          : null,
                    );
                  },
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    link.ativo ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                    size: 24,
                    color: link.ativo ? colorScheme.primary : Colors.orange,
                  ),
                  tooltip: link.ativo ? 'Desativar' : 'Ativar',
                  onPressed: () => onToggle(!link.ativo),
                ),
                PopupMenuButton<String>(
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Editar')),
                    const PopupMenuItem(value: 'delete', child: Text('Excluir')),
                  ],
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'delete') onDelete();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String? _validateCjLink(String url) {
  if (url.isEmpty) return 'Link é obrigatório';

  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
    return 'URL inválida';
  }

  final host = uri.host.toLowerCase();
  final allowed = _allowedCjDomains.any((d) => host == d || host.endsWith('.$d'));
  if (!allowed) {
    return 'Domínio não permitido. Use links da CJ Affiliate.';
  }

  final sid = uri.queryParameters['sid'];
  if (sid == null || sid.isEmpty) {
    return 'Parâmetro sid obrigatório no link';
  }

  return null;
}

/// Filtra itens de "produto" que na verdade são taxas/serviços agregados
/// vindos do feed da CJ (não são coisas que um vendedor divulgaria), e
/// remove duplicatas — o mesmo produto costuma aparecer várias vezes no
/// feed (variações de cor/tamanho, ou porque bateu em mais de uma palavra
/// de busca da sincronização), mas pra escolher um link só faz sentido
/// mostrar uma vez por nome.
List<Product> _dedupedSellableProducts(List<Product>? products) {
  if (products == null) return [];

  const junkNamePatterns = [
    'shipping protection',
    'turnkey installation service',
    'installation service',
    'extended warranty',
    'protection plan',
    'price match',
  ];

  final testSuffixPattern = RegExp(r'\btest\b', caseSensitive: false);

  final seenNames = <String>{};
  final result = <Product>[];

  for (final p in products) {
    final normalizedName = p.nome.trim().toLowerCase();

    final isJunk = junkNamePatterns.any((pattern) => normalizedName.contains(pattern)) ||
        testSuffixPattern.hasMatch(normalizedName);
    if (isJunk) continue;

    if (seenNames.contains(normalizedName)) continue;
    seenNames.add(normalizedName);

    result.add(p);
  }

  return result;
}

String? _validateSid(String url, String affiliateSid) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;

  final linkSid = uri.queryParameters['sid'];
  if (linkSid == null) return null;

  if (linkSid != affiliateSid) {
    return 'O SID do link ($linkSid) não corresponde ao SID deste vendedor ($affiliateSid).';
  }

  return null;
}
