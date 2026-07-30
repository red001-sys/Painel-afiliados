import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/sale.dart';

class SalesRepository {
  SalesRepository(this._client);

  final SupabaseClient _client;

  Future<List<Sale>> getSales() async {
    final response = await _client
        .from('sales')
        .select()
        .order('sale_date', ascending: false);

    return (response as List).map((e) => Sale.fromJson(e)).toList();
  }

  Future<List<Sale>> getSalesByPeriod({
    required DateTime start,
    required DateTime end,
  }) async {
    final response = await _client
        .from('sales')
        .select()
        .gte('sale_date', start.toIso8601String())
        .lte('sale_date', end.toIso8601String())
        .order('sale_date', ascending: false);

    return (response as List).map((e) => Sale.fromJson(e)).toList();
  }
}
