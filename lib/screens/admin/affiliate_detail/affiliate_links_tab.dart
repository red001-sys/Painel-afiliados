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

/// Monta o link final de um vendedor pra um produto, a partir do link base
/// da CJ que já vem salvo no produto (products.cj_url). A CJ atribui o
/// clique pelo parâmetro "sid" na URL — então pra gerar o link de um novo
/// vendedor não precisa voltar no site da CJ, só trocar esse parâmetro.
String? buildAffiliateLinkFromBase(String? baseCjUrl, String affiliateSid) {
  if (baseCjUrl == null || baseCjUrl.trim().isEmpty) return null;
  final uri = Uri.tryParse(baseCjUrl.trim());
  if (uri == null) return null;

  final newParams = Map<String, String>.from(uri.queryParameters);
  newParams['sid'] = affiliateSid;

  return uri.replace(queryParameters: newParams).toString();
}

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
    final Set<String> selectedProductIds = {if (link != null) link.productId};
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
                if (!isEdit) ...[
                  const SizedBox(height: 4),
                  Text(
                    'O link de cada produto já sai pronto com o SID deste vendedor.',
                    style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                ],
                SizedBox(height: AppTheme.spacingLG),
                Builder(
                  builder: (fieldCtx) {
                    final allProducts = ref.read(activeProductsProvider).valueOrNull;
                    final sellable = _dedupedSellableProducts(allProducts);
                    final selectedProducts = sellable.where((p) => selectedProductIds.contains(p.id)).toList();

                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () async {
                        final picked = await _showProductPicker(
                          fieldCtx,
                          sellable,
                          initiallySelected: selectedProductIds,
                          multiSelect: !isEdit,
                        );
                        if (picked != null) {
                          setModalState(() {
                            selectedProductIds.clear();
                            selectedProductIds.addAll(picked.map((p) => p.id));
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: isEdit ? 'Produto *' : 'Produto(s) *',
                          helperText: isEdit ? null : 'Toque pra selecionar um ou vários',
                        ),
                        child: selectedProducts.isEmpty
                            ? Text(
                                'Selecionar produto...',
                                style: TextStyle(color: Theme.of(fieldCtx).colorScheme.onSurface.withValues(alpha: 0.5)),
                              )
                            : Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final p in selectedProducts)
                                    _SelectedProductChip(
                                      product: p,
                                      onViewDescription: () => _showProductDescriptionDialog(fieldCtx, p),
                                      onRemove: isEdit
                                          ? null
                                          : () => setModalState(() => selectedProductIds.remove(p.id)),
                                    ),
                                ],
                              ),
                      ),
                    );
                  },
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
                      if (selectedProductIds.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Selecione ao menos 1 produto'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }

                      final affiliateAsync = ref.read(affiliateDetailProvider(widget.affiliateId));
                      final affiliate = affiliateAsync.valueOrNull;
                      if (affiliate == null) return;

                      final allProducts = ref.read(activeProductsProvider).valueOrNull ?? [];
                      final repo = ref.read(affiliateLinkRepositoryProvider);

                      try {
                        if (isEdit) {
                          final product = allProducts.firstWhere((p) => p.id == selectedProductIds.first);
                          final finalLink = buildAffiliateLinkFromBase(product.cjUrl, affiliate.sid);
                          if (finalLink == null) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Esse produto não tem link base da CJ cadastrado'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return;
                          }

                          await repo.update(AffiliateLink(
                            id: link.id,
                            affiliateId: widget.affiliateId,
                            productId: product.id,
                            cjBaseLink: product.cjUrl,
                            finalLink: finalLink,
                            linkName: link.linkName,
                            displayOrder: link.displayOrder,
                            ativo: ativo,
                            createdAt: link.createdAt,
                            updatedAt: DateTime.now(),
                          ));
                        } else {
                          final existingPairs = await repo.getExistingPairs();
                          final newLinks = <AffiliateLink>[];
                          var skippedNoUrl = 0;
                          var skippedExisting = 0;

                          for (final productId in selectedProductIds) {
                            if (existingPairs.contains('${affiliate.id}|$productId')) {
                              skippedExisting++;
                              continue;
                            }

                            final product = allProducts.firstWhere((p) => p.id == productId);
                            final finalLink = buildAffiliateLinkFromBase(product.cjUrl, affiliate.sid);
                            if (finalLink == null) {
                              skippedNoUrl++;
                              continue;
                            }

                            newLinks.add(AffiliateLink(
                              id: '',
                              affiliateId: affiliate.id,
                              productId: product.id,
                              cjBaseLink: product.cjUrl,
                              finalLink: finalLink,
                              displayOrder: 0,
                              ativo: ativo,
                              createdAt: DateTime.now(),
                              updatedAt: DateTime.now(),
                            ));
                          }

                          final created = await repo.createBulk(newLinks);

                          if (ctx.mounted && (skippedNoUrl > 0 || skippedExisting > 0)) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text(
                                '$created link(s) criados.'
                                '${skippedExisting > 0 ? ' $skippedExisting já existiam.' : ''}'
                                '${skippedNoUrl > 0 ? ' $skippedNoUrl sem link base da CJ.' : ''}',
                              )),
                            );
                          }
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
    // Peças pequenas/acessórios avulsos — normalmente não fazem sentido
    // como produto próprio pro vendedor divulgar (é o item principal que
    // se vende, não o cabo/peça de reposição dele).
    'cable',
    'connector',
    'adapter',
    'replacement part',
    'spare part',
    'screw',
    'bracket',
    'mounting kit',
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

Future<List<Product>?> _showProductPicker(
  BuildContext context,
  List<Product> products, {
  Set<String> initiallySelected = const {},
  bool multiSelect = true,
}) {
  return showModalBottomSheet<List<Product>>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _ProductPickerSheet(
      products: products,
      initiallySelected: initiallySelected,
      multiSelect: multiSelect,
    ),
  );
}

class _ProductPickerSheet extends StatefulWidget {
  const _ProductPickerSheet({
    required this.products,
    required this.initiallySelected,
    required this.multiSelect,
  });

  final List<Product> products;
  final Set<String> initiallySelected;
  final bool multiSelect;

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  String _search = '';
  late final Set<String> _selected = {...widget.initiallySelected};

  @override
  Widget build(BuildContext context) {
    final filtered = _search.isEmpty
        ? widget.products
        : widget.products
            .where((p) => p.nome.toLowerCase().contains(_search.toLowerCase()))
            .toList();

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.multiSelect ? 'Selecionar produtos' : 'Selecionar produto',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                if (widget.multiSelect && _selected.isNotEmpty)
                  Text('${_selected.length} selecionado(s)', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar produto',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('Nenhum produto encontrado'))
                // ListView.builder só constrói (e só carrega a imagem) das
                // linhas visíveis na tela — é isso que evita disparar
                // centenas de downloads de imagem de uma vez, que era o
                // que travava o app com o dropdown antigo.
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final p = filtered[index];
                      final isSelected = _selected.contains(p.id);
                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: p.imagemUrl != null
                                ? Image.network(
                                    p.imagemUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: AppColors.neutral200,
                                      child: const Icon(Icons.inventory_2_outlined, size: 18),
                                    ),
                                  )
                                : Container(
                                    color: AppColors.neutral200,
                                    child: const Icon(Icons.inventory_2_outlined, size: 18),
                                  ),
                          ),
                        ),
                        title: Text(p.nome, maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: p.preco != null ? Text('R\$ ${p.preco!.toStringAsFixed(2)}') : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.info_outline_rounded, size: 20),
                              tooltip: 'Ver descrição completa',
                              onPressed: () => _showProductDescriptionDialog(context, p),
                            ),
                            if (widget.multiSelect)
                              Checkbox(
                                value: isSelected,
                                onChanged: (v) => setState(() {
                                  if (v == true) {
                                    _selected.add(p.id);
                                  } else {
                                    _selected.remove(p.id);
                                  }
                                }),
                              ),
                          ],
                        ),
                        onTap: () {
                          if (widget.multiSelect) {
                            setState(() {
                              if (isSelected) {
                                _selected.remove(p.id);
                              } else {
                                _selected.add(p.id);
                              }
                            });
                          } else {
                            Navigator.of(context).pop([p]);
                          }
                        },
                      );
                    },
                  ),
          ),
          if (widget.multiSelect)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _selected.isEmpty
                        ? null
                        : () => Navigator.of(context).pop(
                              widget.products.where((p) => _selected.contains(p.id)).toList(),
                            ),
                    child: Text('Confirmar (${_selected.length})'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

void _showProductDescriptionDialog(BuildContext context, Product product) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(product.nome),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product.imagemUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  product.imagemUrl!,
                  height: 140,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              product.descricao?.isNotEmpty == true
                  ? product.descricao!
                  : 'Sem descrição cadastrada.',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar')),
      ],
    ),
  );
}

class _SelectedProductChip extends StatelessWidget {
  const _SelectedProductChip({
    required this.product,
    required this.onViewDescription,
    this.onRemove,
  });

  final Product product;
  final VoidCallback onViewDescription;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          width: 20,
          height: 20,
          child: product.imagemUrl != null
              ? Image.network(
                  product.imagemUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2_outlined, size: 12),
                )
              : const Icon(Icons.inventory_2_outlined, size: 12),
        ),
      ),
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 140),
        child: Text(product.nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
      ),
      deleteIcon: const Icon(Icons.info_outline_rounded, size: 16),
      onDeleted: onViewDescription,
    );
  }
}
