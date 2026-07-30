import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/affiliate.dart';

class AdminRepository {
  AdminRepository(this._client);

  final SupabaseClient _client;

  Future<int> getAffiliatesCount() async {
    debugPrint('[REPO:Admin] getAffiliatesCount() → Request: GET /affiliates?select=id');
    try {
      final response = await _client
          .from('affiliates')
          .select('id')
          .count(CountOption.exact);
      debugPrint('[REPO:Admin] getAffiliatesCount → Result: ${response.count}');
      return response.count;
    } catch (e, stackTrace) {
      debugPrint('[REPO:Admin] getAffiliatesCount ERROR: $e');
      debugPrint('[REPO:Admin] stackTrace: $stackTrace');
      rethrow;
    }
  }

  Future<int> getActiveAffiliatesCount() async {
    debugPrint('[REPO:Admin] getActiveAffiliatesCount() → Request: GET /affiliates?select=id&not.auth_user_id=is.null');
    try {
      final response = await _client
          .from('affiliates')
          .select('id')
          .not('auth_user_id', 'is', null)
          .count(CountOption.exact);
      debugPrint('[REPO:Admin] getActiveAffiliatesCount → Result: ${response.count}');
      return response.count;
    } catch (e, stackTrace) {
      debugPrint('[REPO:Admin] getActiveAffiliatesCount ERROR: $e');
      debugPrint('[REPO:Admin] stackTrace: $stackTrace');
      rethrow;
    }
  }

  Future<int> getProductsCount() async {
    debugPrint('[REPO:Admin] getProductsCount() → Request: GET /products?select=id');
    try {
      final response = await _client
          .from('products')
          .select('id')
          .count(CountOption.exact);
      debugPrint('[REPO:Admin] getProductsCount → Result: ${response.count}');
      return response.count;
    } catch (e, stackTrace) {
      debugPrint('[REPO:Admin] getProductsCount ERROR: $e');
      debugPrint('[REPO:Admin] stackTrace: $stackTrace');
      rethrow;
    }
  }

  Future<int> getSalesCount() async {
    debugPrint('[REPO:Admin] getSalesCount() → Request: GET /sales?select=id');
    try {
      final response = await _client
          .from('sales')
          .select('id')
          .count(CountOption.exact);
      debugPrint('[REPO:Admin] getSalesCount → Result: ${response.count}');
      return response.count;
    } catch (e, stackTrace) {
      debugPrint('[REPO:Admin] getSalesCount ERROR: $e');
      debugPrint('[REPO:Admin] stackTrace: $stackTrace');
      rethrow;
    }
  }

  Future<double> getTotalCommission() async {
    debugPrint('[REPO:Admin] getTotalCommission() → Request: GET /sales?select=commission_amount&status=eq.approved');
    try {
      final response = await _client
          .from('sales')
          .select('commission_amount')
          .eq('status', 'approved');

      final total = (response as List).fold<double>(
        0,
        (sum, e) =>
            sum + ((e['commission_amount'] as num?)?.toDouble() ?? 0),
      );
      debugPrint('[REPO:Admin] getTotalCommission → Result: $total');
      return total;
    } catch (e, stackTrace) {
      debugPrint('[REPO:Admin] getTotalCommission ERROR: $e');
      debugPrint('[REPO:Admin] stackTrace: $stackTrace');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getLastSyncLog() async {
    debugPrint('[REPO:Admin] getLastSyncLog() → Request: GET /sync_logs?order=started_at.desc&limit=1');
    try {
      final response = await _client
          .from('sync_logs')
          .select()
          .order('started_at', ascending: false)
          .limit(1)
          .maybeSingle();

      debugPrint('[REPO:Admin] getLastSyncLog → Result: $response');
      return response;
    } catch (e, stackTrace) {
      debugPrint('[REPO:Admin] getLastSyncLog ERROR: $e');
      debugPrint('[REPO:Admin] stackTrace: $stackTrace');
      rethrow;
    }
  }

  Future<List<Affiliate>> getAllAffiliates() async {
    final response = await _client
        .from('affiliates')
        .select()
        .order('created_at', ascending: false);

    return (response as List)
        .map((e) => Affiliate.fromJson(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>>
      getAllAffiliatesWithStats() async {
    final affiliates = await getAllAffiliates();

    final results = await Future.wait(
      affiliates.map((a) async {
        final stats = await getAffiliateStats(a.id);
        return {
          'affiliate': a,
          'salesCount': stats['salesCount'] ?? 0,
          'totalCommission': stats['totalCommission'] ?? 0.0,
        };
      }),
    );

    return results;
  }

  Future<void> deleteAffiliate(String id) async {
    debugPrint('[REPO:Admin] deleteAffiliate($id) → DELETE /affiliates?id=eq.$id');
    try {
      final response = await _client.from('affiliates').delete().eq('id', id);
      debugPrint('[REPO:Admin] deleteAffiliate → OK');
    } catch (e, stackTrace) {
      debugPrint('[REPO:Admin] deleteAffiliate ERROR: $e');
      debugPrint('[REPO:Admin] stackTrace: $stackTrace');
      rethrow;
    }
  }

  Future<void> updateAffiliate(
    String id,
    Map<String, dynamic> data,
  ) async {
    debugPrint('[REPO:Admin] updateAffiliate($id, $data) → PATCH /affiliates?id=eq.$id');
    try {
      await _client.from('affiliates').update(data).eq('id', id);
      debugPrint('[REPO:Admin] updateAffiliate → OK');
    } catch (e, stackTrace) {
      debugPrint('[REPO:Admin] updateAffiliate ERROR: $e');
      debugPrint('[REPO:Admin] stackTrace: $stackTrace');
      rethrow;
    }
  }

  Future<Affiliate> createAffiliate({
    required String nome,
    required String email,
    required String sid,
    String? whatsapp,
    String? chavePix,
    bool ativo = true,
  }) async {
    final payload = {
      'nome': nome,
      'email': email,
      'sid': sid,
      'whatsapp': whatsapp,
      'chave_pix': chavePix,
    };
    debugPrint('[REPO:Admin] createAffiliate() → Payload: $payload');
    debugPrint('[REPO:Admin] createAffiliate() → INSERT /affiliates');
    try {
      final response = await _client
          .from('affiliates')
          .insert(payload)
          .select()
          .single();
      debugPrint('[REPO:Admin] createAffiliate → Result: $response');
      return Affiliate.fromJson(response);
    } on PostgrestException catch (e, stackTrace) {
      debugPrint('[REPO:Admin] createAffiliate PostgrestException:');
      debugPrint('[REPO:Admin]   code: ${e.code}');
      debugPrint('[REPO:Admin]   message: ${e.message}');
      debugPrint('[REPO:Admin]   details: ${e.details}');
      debugPrint('[REPO:Admin]   hint: ${e.hint}');
      debugPrint('[REPO:Admin]   statusCode: ${e.code}');
      debugPrint('[REPO:Admin]   stackTrace: $stackTrace');
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('[REPO:Admin] createAffiliate ERROR: $e');
      debugPrint('[REPO:Admin] stackTrace: $stackTrace');
      rethrow;
    }
  }

  Future<Affiliate?> getAffiliateById(String id) async {
    final response = await _client
        .from('affiliates')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return Affiliate.fromJson(response);
  }

  Future<Map<String, dynamic>> getAffiliateStats(
    String affiliateId,
  ) async {
    final salesResponse = await _client
        .from('sales')
        .select('commission_amount, sale_amount, status')
        .eq('affiliate_id', affiliateId);

    final sales = salesResponse as List;

    double totalCommission = 0;
    double pendingCommission = 0;
    double approvedCommission = 0;
    double totalSales = 0;
    int salesCount = 0;

    for (final sale in sales) {
      final commission =
          (sale['commission_amount'] as num?)?.toDouble() ?? 0;
      final amount =
          (sale['sale_amount'] as num?)?.toDouble() ?? 0;
      final status = sale['status'] as String?;

      salesCount++;
      totalSales += amount;

      if (status == 'approved' || status == 'locked') {
        totalCommission += commission;
        approvedCommission += commission;
      } else if (status == 'pending') {
        pendingCommission += commission;
      }
    }

    return {
      'salesCount': salesCount,
      'totalSales': totalSales,
      'totalCommission': totalCommission,
      'pendingCommission': pendingCommission,
      'approvedCommission': approvedCommission,
    };
  }

  Future<List<Map<String, dynamic>>> getSalesByAffiliate(
    String affiliateId, {
    String? status,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    var query = _client
        .from('sales')
        .select()
        .eq('affiliate_id', affiliateId);

    if (status != null && status.isNotEmpty) {
      query = query.eq('status', status);
    }

    if (search != null && search.isNotEmpty) {
      final escaped = search
          .replaceAll('%', '\\%')
          .replaceAll('_', '\\_');
      query = query.or(
        'advertiser.ilike.%$escaped%,product.ilike.%$escaped%,order_id.ilike.%$escaped%',
      );
    }

    final response = await query
        .order('sale_date', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>?> executeSync() async {
    final response = await _client.functions.invoke(
      'sync-sales',
      method: HttpMethod.post,
    );

    if (response.status != 200) {
      final body = response.data;
      final errorMsg =
          body is Map ? (body['error'] ?? 'Sync failed') : 'Sync failed';
      throw Exception(errorMsg.toString());
    }

    return response.data as Map<String, dynamic>?;
  }

  Future<List<Map<String, dynamic>>> getSyncHistory({
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _client
        .from('sync_logs')
        .select()
        .order('started_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>?> getSyncStats() async {
    final today = DateTime.now().toUtc().toIso8601String().split('T')[0];

    final todayLogs = await _client
        .from('sync_logs')
        .select()
        .gte('started_at', '${today}T00:00:00Z')
        .order('started_at', ascending: false);

    final logs = todayLogs as List;
    if (logs.isEmpty) return null;

    int totalImported = 0;
    int totalUpdated = 0;
    int totalFailed = 0;
    int totalUnknownSid = 0;

    for (final log in logs) {
      totalImported +=
          (log['transactions_imported'] as int?) ?? 0;
      totalUpdated += (log['transactions_updated'] as int?) ?? 0;
      totalFailed += (log['transactions_failed'] as int?) ?? 0;
      totalUnknownSid += (log['unknown_sid'] as int?) ?? 0;
    }

    return {
      'todaySyncCount': logs.length,
      'todayImported': totalImported,
      'todayUpdated': totalUpdated,
      'todayFailed': totalFailed,
      'todayUnknownSid': totalUnknownSid,
    };
  }
}
