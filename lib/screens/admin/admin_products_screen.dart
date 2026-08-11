import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/product.dart';
import '../../providers/product_provider.dart';
import '../../widgets/copyright_footer.dart';

enum _StatusFilter { all, active, inactive }

class AdminProductsScreen extends ConsumerStatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  ConsumerState<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends ConsumerState<AdminProductsScreen> {
  String _search = '';
  bool _syncing = false;
  _StatusFilter _statusFilter = _StatusFilter.all;

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

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
                    hintText: 'Pesquisar produto...',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: _syncing ? null : () => _runSync(context),
                tooltip: 'Sincronizar produtos da CJ',
                icon: _syncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () => _showProductDialog(context, ref),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              _FilterChip(
                label: 'Todos',
                selected: _statusFilter == _StatusFilter.all,
                onSelected: () => setState(() => _statusFilter = _StatusFilter.all),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Ativos',
                selected: _statusFilter == _StatusFilter.active,
                onSelected: () => setState(() => _statusFilter = _StatusFilter.active),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Inativos',
                selected: _statusFilter == _StatusFilter.inactive,
                onSelected: () => setState(() => _statusFilter = _StatusFilter.inactive),
              ),
            ],
          ),
        ),
        Expanded(
          child: productsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erro: $e')),
            data: (products) {
              final filtered = products.where((p) {
                if (_statusFilter == _StatusFilter.active && !p.ativo) return false;
                if (_statusFilter == _StatusFilter.inactive && p.ativo) return false;
                if (_search.isEmpty) return true;
                final q = _search.toLowerCase();
                return p.nome.toLowerCase().contains(q) ||
                    (p.categoria?.toLowerCase().contains(q) ?? false);
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 64,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
                      const SizedBox(height: 16),
                      Text(
                        _search.isNotEmpty || _statusFilter != _StatusFilter.all
                            ? 'Nenhum produto encontrado'
                            : 'Nenhum produto cadastrado',
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
                onRefresh: () async {
                  ref.invalidate(productsProvider);
                  ref.invalidate(activeProductsProvider);
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length + 1,
                  itemBuilder: (context, index) {
                    if (index == filtered.length) {
                      return const CopyrightFooter();
                    }
                    return _ProductTile(
                      product: filtered[index],
                      onEdit: () => _showProductDialog(context, ref, product: filtered[index]),
                      onDelete: () => _deleteProduct(context, ref, filtered[index]),
                      onToggleAtivo: () => _toggleAtivo(context, ref, filtered[index]),
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

  Future<void> _runSync(BuildContext context) async {
    setState(() => _syncing = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _SyncProgressDialog(),
    );

    try {
      final result = await ref.read(productRepositoryProvider).syncFromCJ();
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

      if (!context.mounted) return;
      if (result['success'] == true) {
        showDialog(
          context: context,
          builder: (_) => _SyncResultDialog(result: result),
        );
      } else {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Falha na sincronização'),
            content: Text(result['error']?.toString() ?? 'Erro desconhecido'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fechar'),
              ),
            ],
          ),
        );
      }
      ref.invalidate(productsProvider);
      ref.invalidate(activeProductsProvider);
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao sincronizar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _toggleAtivo(BuildContext context, WidgetRef ref, Product product) async {
    try {
      await ref.read(productRepositoryProvider).updateAtivo(product.id, !product.ativo);
      ref.invalidate(productsProvider);
      ref.invalidate(activeProductsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar produto: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showProductDialog(BuildContext context, WidgetRef ref, {Product? product}) {
    final isEdit = product != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ProductDialogBody(
        product: product,
        isEdit: isEdit,
        ref: ref,
      ),
    );
  }

  void _deleteProduct(BuildContext context, WidgetRef ref, Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir produto'),
        content: Text('Deseja excluir "${product.nome}"?'),
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
        await ref.read(productRepositoryProvider).delete(product.id);
        ref.invalidate(productsProvider);
        ref.invalidate(activeProductsProvider);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir produto: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleAtivo,
  });

  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleAtivo;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: product.imagemUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  product.imagemUrl!,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.inventory_2_rounded, color: colorScheme.primary),
                  ),
                ),
              )
            : Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.inventory_2_rounded, color: colorScheme.primary),
              ),
        title: Text(product.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  product.categoria ?? 'Sem categoria',
                  style: TextStyle(fontSize: 13, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                ),
                if (product.preco != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${_priceSymbol(product)} ${product.preco!.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ],
            ),
            if (product.descricao != null && product.descricao!.isNotEmpty)
              Text(
                product.descricao!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.4)),
              ),
          ],
        ),
        isThreeLine: product.descricao != null && product.descricao!.isNotEmpty,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (product.cjProductId != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'CJ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.indigo,
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
            InkWell(
              onTap: onToggleAtivo,
              borderRadius: BorderRadius.circular(8),
              child: Tooltip(
                message: product.ativo ? 'Desativar' : 'Ativar',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: (product.ativo ? colorScheme.primary : Colors.orange).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    product.ativo ? 'Ativo' : 'Inativo',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: product.ativo ? colorScheme.primary : Colors.orange,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
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
      ),
    );
  }

  String _priceSymbol(Product product) {
    return product.currency?.toUpperCase() == 'USD' ? r'$' : r'R$';
  }
}

class _ProductDialogBody extends StatefulWidget {
  const _ProductDialogBody({
    required this.product,
    required this.isEdit,
    required this.ref,
  });

  final Product? product;
  final bool isEdit;
  final WidgetRef ref;

  @override
  State<_ProductDialogBody> createState() => _ProductDialogBodyState();
}

class _ProductDialogBodyState extends State<_ProductDialogBody> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _catCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _imgCtrl;
  late final TextEditingController _precoCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.product?.nome ?? '');
    _catCtrl = TextEditingController(text: widget.product?.categoria ?? '');
    _descCtrl = TextEditingController(text: widget.product?.descricao ?? '');
    _urlCtrl = TextEditingController(text: widget.product?.cjUrl ?? '');
    _imgCtrl = TextEditingController(text: widget.product?.imagemUrl ?? '');
    _precoCtrl = TextEditingController(
      text: widget.product?.preco != null
          ? widget.product!.preco!.toStringAsFixed(2)
          : '',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _catCtrl.dispose();
    _descCtrl.dispose();
    _urlCtrl.dispose();
    _imgCtrl.dispose();
    _precoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.isEdit ? 'Editar Produto' : 'Novo Produto',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: AppTheme.spacingLG),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Nome *'),
            ),
            SizedBox(height: AppTheme.spacingMD),
            TextField(
              controller: _catCtrl,
              decoration: const InputDecoration(labelText: 'Categoria'),
            ),
            SizedBox(height: AppTheme.spacingMD),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Descrição'),
              maxLines: 2,
            ),
            SizedBox(height: AppTheme.spacingMD),
            TextField(
              controller: _urlCtrl,
              decoration: const InputDecoration(
                labelText: 'Link Base da CJ (opcional)',
                hintText: 'Apenas para referência',
              ),
            ),
            SizedBox(height: AppTheme.spacingMD),
            TextField(
              controller: _imgCtrl,
              decoration: const InputDecoration(labelText: 'URL da Imagem'),
            ),
            SizedBox(height: AppTheme.spacingMD),
            TextField(
              controller: _precoCtrl,
              decoration: const InputDecoration(
                labelText: 'Preço (R\$)',
                prefixText: 'R\$ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            SizedBox(height: AppTheme.spacingXL),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _save,
                child: Text(widget.isEdit ? 'Salvar' : 'Cadastrar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;

    final repo = widget.ref.read(productRepositoryProvider);
    final newProduct = Product(
      id: widget.product?.id ?? '',
      nome: _nameCtrl.text.trim(),
      categoria: _catCtrl.text.trim().isEmpty ? null : _catCtrl.text.trim(),
      descricao: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      cjUrl: _urlCtrl.text.trim().isEmpty ? null : _urlCtrl.text.trim(),
      imagemUrl: _imgCtrl.text.trim().isEmpty ? null : _imgCtrl.text.trim(),
      preco: double.tryParse(_precoCtrl.text.trim().replaceAll(',', '.')),
      ativo: widget.product?.ativo ?? true,
      createdAt: widget.product?.createdAt ?? DateTime.now(),
    );

    try {
      if (widget.isEdit) {
        await repo.update(newProduct);
      } else {
        await repo.create(newProduct);
      }
      if (mounted) Navigator.pop(context);
      widget.ref.invalidate(productsProvider);
      widget.ref.invalidate(activeProductsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar produto: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

class _SyncProgressDialog extends StatelessWidget {
  const _SyncProgressDialog();

  @override
  Widget build(BuildContext context) {
    return const AlertDialog(
      content: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          SizedBox(width: 16),
          Expanded(child: Text('Sincronizando catálogo...')),
        ],
      ),
    );
  }
}

class _SyncResultDialog extends StatelessWidget {
  const _SyncResultDialog({required this.result});

  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final imported = (result['imported'] as num?)?.toInt() ?? 0;
    final updated = (result['updated'] as num?)?.toInt() ?? 0;
    final skipped = (result['skippedNonUsd'] as num?)?.toInt() ?? 0;
    final failed = (result['failed'] as num?)?.toInt() ?? 0;
    final duration = (result['durationMs'] as num?)?.toInt() ?? 0;
    final total = (result['totalAvailable'] as num?)?.toInt() ?? 0;

    return AlertDialog(
      title: const Text('Sincronização concluída'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$total produtos no catálogo (US)'),
          const SizedBox(height: 12),
          _ResultRow(
            label: 'Novos importados',
            value: '$imported',
            color: colorScheme.primary,
          ),
          _ResultRow(
            label: 'Atualizados',
            value: '$updated',
            color: Colors.blue,
          ),
          _ResultRow(
            label: 'Ignorados (fora USD)',
            value: '$skipped',
            color: Colors.orange,
          ),
          _ResultRow(
            label: 'Falhas',
            value: '$failed',
            color: failed > 0 ? AppColors.error : colorScheme.primary,
          ),
          const SizedBox(height: 8),
          Text(
            'Duração: ${(duration / 1000).toStringAsFixed(1)}s',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      selectedColor: colorScheme.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? colorScheme.onPrimaryContainer : null,
      ),
    );
  }
}
