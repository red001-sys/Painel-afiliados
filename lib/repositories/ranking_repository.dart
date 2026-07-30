import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ranking_entry.dart';

class RankingRepository {
  RankingRepository(this._client);

  final SupabaseClient _client;

  Future<List<RankingEntry>> getRanking() async {
    final response = await _client.from('affiliate_ranking').select();
    return (response as List).map((e) => RankingEntry.fromJson(e)).toList();
  }
}
