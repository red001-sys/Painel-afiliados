import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/product.dart';
import '../../providers/product_provider.dart';

class AdminProductsScreen extends ConsumerStatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  ConsumerState<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends ConsumerState<AdminProductsScreen> {
  String _search = '';

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
              IconButton.filled(
                onPressed: () => _showProductDialog(context, ref),
                icon: const Icon(Icons.add_rounded),
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
                        _search.isNotEmpty ? 'Nenhum produto encontrado' : 'Nenhum produto cadastrado',
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
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => _ProductTile(
                    product: filtered[index],
                    onEdit: () => _showProductDialog(context, ref, product: filtered[index]),
                    onDelete: () => _deleteProduct(context, ref, filtered[index]),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
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
  });

  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
                  errorBuilder: (_, __, ___) => Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.ecoGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.inventory_2_rounded, color: AppColors.ecoGreen),
                  ),
                ),
              )
            : Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.ecoGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.inventory_2_rounded, color: AppColors.ecoGreen),
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
                    'R\$ ${product.preco!.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ecoGreenDark,
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: (product.ativo ? AppColors.ecoGreen : Colors.orange).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                product.ativo ? 'Ativo' : 'Inativo',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: product.ativo ? AppColors.ecoGreen : Colors.orange,
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
