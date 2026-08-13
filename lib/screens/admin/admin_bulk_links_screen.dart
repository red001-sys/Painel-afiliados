import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/affiliate.dart';
import '../../models/affiliate_link.dart';
import '../../models/product.dart';
import '../../providers/admin_provider.dart';
import '../../providers/product_provider.dart';

/// Monta o link final de um afiliado pra um produto, a partir do link base
/// da CJ que já vem salvo no produto (products.cj_url). A CJ atribui o
/// clique pelo parâmetro "sid" na URL — então pra gerar o link de um novo
/// afiliado não precisa voltar no site da CJ, só trocar esse parâmetro.
String? buildAffiliateLinkFromBase(String? baseCjUrl, String affiliateSid) {
  if (baseCjUrl == null || baseCjUrl.trim().isEmpty) return null;
  final uri = Uri.tryParse(baseCjUrl.trim());
  if (uri == null) return null;

  final newParams = Map<String, String>.from(uri.queryParameters);
  newParams['sid'] = affiliateSid;

  return uri.replace(queryParameters: newParams).toString();
}

class AdminBulkLinksScreen extends ConsumerStatefulWidget {
  const AdminBulkLinksScreen({super.key});

  @override
  ConsumerState<AdminBulkLinksScreen> createState() => _AdminBulkLinksScreenState();
}

class _AdminBulkLinksScreenState extends ConsumerState<AdminBulkLinksScreen> {
  final Set<String> _selectedProductIds = {};
  final Set<String> _selectedAffiliateIds = {};
  String _productSearch = '';
  String _affiliateSearch = '';
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(activeProductsProvider);
    final affiliatesAsync = ref.watch(adminAffiliatesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Gerar Links em Massa')),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (allProducts) {
          final products = allProducts.where((p) => p.cjUrl != null && p.cjUrl!.isNotEmpty).toList();
          final productsWithoutLink = allProducts.length - products.length;

          return affiliatesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erro: $e')),
            data: (affiliates) {
              final filteredProducts = products
                  .where((p) => p.nome.toLowerCase().contains(_productSearch.toLowerCase()))
                  .toList();
              final filteredAffiliates = affiliates
                  .where((a) => (a.nome ?? a.sid).toLowerCase().contains(_affiliateSearch.toLowerCase()))
                  .toList();

              final totalCombinations = _selectedProductIds.length * _selectedAffiliateIds.length;

              return Column(
                children: [
                  if (productsWithoutLink > 0)
                    Container(
                      width: double.infinity,
                      color: Colors.orange.withValues(alpha: 0.12),
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        '$productsWithoutLink produto(s) sem link base da CJ cadastrado — não aparecem aqui e precisam ser adicionados manualmente.',
                        style: const TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                    ),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _SelectionColumn(
                            title: 'Produtos (${_selectedProductIds.length} selecionados)',
                            searchHint: 'Buscar produto...',
                            onSearchChanged: (v) => setState(() => _productSearch = v),
                            itemCount: filteredProducts.length,
                            itemBuilder: (context, index) {
                              final p = filteredProducts[index];
                              final selected = _selectedProductIds.contains(p.id);
                              return CheckboxListTile(
                                dense: true,
                                value: selected,
                                title: Text(p.nome, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                                subtitle: p.preco != null ? Text('R\$ ${p.preco!.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11)) : null,
                                onChanged: (v) => setState(() {
                                  if (v == true) {
                                    _selectedProductIds.add(p.id);
                                  } else {
                                    _selectedProductIds.remove(p.id);
                                  }
                                }),
                              );
                            },
                            onSelectAll: () => setState(() {
                              _selectedProductIds
                                ..clear()
                                ..addAll(filteredProducts.map((p) => p.id));
                            }),
                            onClear: () => setState(() => _selectedProductIds.clear()),
                          ),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(
                          child: _SelectionColumn(
                            title: 'Afiliados (${_selectedAffiliateIds.length} selecionados)',
                            searchHint: 'Buscar afiliado...',
                            onSearchChanged: (v) => setState(() => _affiliateSearch = v),
                            itemCount: filteredAffiliates.length,
                            itemBuilder: (context, index) {
                              final a = filteredAffiliates[index];
                              final selected = _selectedAffiliateIds.contains(a.id);
                              return CheckboxListTile(
                                dense: true,
                                value: selected,
                                title: Text(a.nome ?? a.sid, style: const TextStyle(fontSize: 13)),
                                subtitle: Text(a.sid, style: const TextStyle(fontSize: 11)),
                                onChanged: (v) => setState(() {
                                  if (v == true) {
                                    _selectedAffiliateIds.add(a.id);
                                  } else {
                                    _selectedAffiliateIds.remove(a.id);
                                  }
                                }),
                              );
                            },
                            onSelectAll: () => setState(() {
                              _selectedAffiliateIds
                                ..clear()
                                ..addAll(filteredAffiliates.map((a) => a.id));
                            }),
                            onClear: () => setState(() => _selectedAffiliateIds.clear()),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            totalCombinations == 0
                                ? 'Selecione ao menos 1 produto e 1 afiliado'
                                : '$totalCombinations link(s) serão verificados (combinações que já existem são puladas automaticamente)',
                            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: AppTheme.spacingSM),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: (totalCombinations == 0 || _isGenerating)
                                  ? null
                                  : () => _generateLinks(products, affiliates),
                              icon: _isGenerating
                                  ? const SizedBox(
                                      width: 18, height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.auto_awesome_rounded),
                              label: Text(_isGenerating ? 'Gerando...' : 'Gerar Links'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _generateLinks(List<Product> products, List<Affiliate> affiliates) async {
    setState(() => _isGenerating = true);

    try {
      final repo = ref.read(affiliateLinkRepositoryProvider);
      final existingPairs = await repo.getExistingPairs();

      final selectedProducts = products.where((p) => _selectedProductIds.contains(p.id)).toList();
      final selectedAffiliates = affiliates.where((a) => _selectedAffiliateIds.contains(a.id)).toList();

      final newLinks = <AffiliateLink>[];
      var skippedExisting = 0;
      var skippedBadUrl = 0;

      for (final affiliate in selectedAffiliates) {
        for (final product in selectedProducts) {
          final pairKey = '${affiliate.id}|${product.id}';
          if (existingPairs.contains(pairKey)) {
            skippedExisting++;
            continue;
          }

          final finalLink = buildAffiliateLinkFromBase(product.cjUrl, affiliate.sid);
          if (finalLink == null) {
            skippedBadUrl++;
            continue;
          }

          newLinks.add(AffiliateLink(
            id: '',
            affiliateId: affiliate.id,
            productId: product.id,
            cjBaseLink: product.cjUrl,
            finalLink: finalLink,
            displayOrder: 0,
            ativo: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ));
        }
      }

      final created = await repo.createBulk(newLinks);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$created link(s) criados. '
              '${skippedExisting > 0 ? '$skippedExisting já existiam. ' : ''}'
              '${skippedBadUrl > 0 ? '$skippedBadUrl com link base inválido.' : ''}',
            ),
            backgroundColor: AppColors.ecoGreen,
          ),
        );
        setState(() {
          _selectedProductIds.clear();
          _selectedAffiliateIds.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar links: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }
}

class _SelectionColumn extends StatelessWidget {
  const _SelectionColumn({
    required this.title,
    required this.searchHint,
    required this.onSearchChanged,
    required this.itemCount,
    required this.itemBuilder,
    required this.onSelectAll,
    required this.onClear,
  });

  final String title;
  final String searchHint;
  final ValueChanged<String> onSearchChanged;
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            decoration: InputDecoration(
              isDense: true,
              hintText: searchHint,
              hintStyle: const TextStyle(fontSize: 12),
              prefixIcon: const Icon(Icons.search, size: 18),
            ),
            style: const TextStyle(fontSize: 13),
            onChanged: onSearchChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: onSelectAll, child: const Text('Selecionar todos', style: TextStyle(fontSize: 11))),
              TextButton(onPressed: onClear, child: const Text('Limpar', style: TextStyle(fontSize: 11))),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(itemCount: itemCount, itemBuilder: itemBuilder),
        ),
      ],
    );
  }
}
