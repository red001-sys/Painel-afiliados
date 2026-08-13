import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/affiliate_link.dart';

class AffiliateLinkRepository {
  AffiliateLinkRepository(this._client);

  final SupabaseClient _client;

  Future<List<AffiliateLink>> getByAffiliate(String affiliateId) async {
    final response = await _client
        .from('affiliate_links')
        .select('*, products(id, nome, categoria, imagem_url, descricao, preco)')
        .eq('affiliate_id', affiliateId)
        .order('display_order', ascending: true)
        .order('created_at', ascending: false);

    return (response as List)
        .map((e) => AffiliateLink.fromJson(e))
        .toList();
  }

  Future<AffiliateLink> create(AffiliateLink link) async {
    final response = await _client
        .from('affiliate_links')
        .insert(link.toJson())
        .select('*, products(id, nome, categoria, imagem_url, descricao, preco)')
        .single();

    return AffiliateLink.fromJson(response);
  }

  Future<void> update(AffiliateLink link) async {
    await _client
        .from('affiliate_links')
        .update(link.toJson())
        .eq('id', link.id);
  }

  Future<void> toggleAtivo(String id, bool ativo) async {
    await _client
        .from('affiliate_links')
        .update({'ativo': ativo})
        .eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('affiliate_links').delete().eq('id', id);
  }

  /// Retorna o conjunto de pares (affiliate_id, product_id) que já têm
  /// link cadastrado — usado pra não duplicar na geração em massa.
  Future<Set<String>> getExistingPairs() async {
    final response = await _client
        .from('affiliate_links')
        .select('affiliate_id, product_id');

    return (response as List)
        .map((e) => '${e['affiliate_id']}|${e['product_id']}')
        .toSet();
  }

  Future<int> createBulk(List<AffiliateLink> links) async {
    if (links.isEmpty) return 0;
    final payload = links.map((l) => l.toJson()).toList();
    final response =
        await _client.from('affiliate_links').insert(payload).select('id');
    return (response as List).length;
  }
}
