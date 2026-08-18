import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product.dart';

class ProductRepository {
  ProductRepository(this._client);

  final SupabaseClient _client;

  Future<List<Product>> getAll() async {
    final response = await _client
        .from('products')
        .select()
        .order('created_at', ascending: false);

    return (response as List)
        .map((e) => Product.fromJson(e))
        .toList();
  }

  Future<List<Product>> getActive() async {
    final response = await _client
        .from('products')
        .select()
        .eq('ativo', true)
        .order('nome');

    return (response as List)
        .map((e) => Product.fromJson(e))
        .toList();
  }

  Future<Product> create(Product product) async {
    final response = await _client
        .from('products')
        .insert(product.toJson())
        .select()
        .single();

    return Product.fromJson(response);
  }

  Future<void> update(Product product) async {
    await _client
        .from('products')
        .update(product.toJson())
        .eq('id', product.id);
  }

  Future<void> delete(String id) async {
    await _client.from('products').delete().eq('id', id);
  }

  Future<void> updateAtivo(String id, bool ativo) async {
    await _client.from('products').update({'ativo': ativo}).eq('id', id);
  }

  /// Dispara a edge function que sincroniza o catálogo de produtos (USD) da CJ.
  Future<Map<String, dynamic>> syncFromCJ() async {
    final response = await _client.functions.invoke('sync-products');
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Gera o link de afiliado (deep link) real da CJ pra até 20 produtos de
  /// uma vez, via linkCode(pid). Já grava cj_url no banco pros que
  /// conseguiu gerar; retorna o resumo da chamada.
  Future<Map<String, dynamic>> generateDeepLinks(List<String> cjProductIds) async {
    final response = await _client.functions.invoke(
      'cj-deep-link',
      body: {'productIds': cjProductIds},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }
}
