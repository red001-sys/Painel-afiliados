import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ranking_entry.dart';
import '../repositories/ranking_repository.dart';
import 'auth_provider.dart';

final rankingRepositoryProvider = Provider<RankingRepository>((ref) {
  return RankingRepository(ref.watch(supabaseClientProvider));
});

final rankingProvider = FutureProvider<List<RankingEntry>>((ref) async {
  return ref.watch(rankingRepositoryProvider).getRanking();
});
