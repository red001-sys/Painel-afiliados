import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/affiliate.dart';
import '../repositories/affiliate_repository.dart';
import 'auth_provider.dart';

final affiliateRepositoryProvider = Provider<AffiliateRepository>((ref) {
  return AffiliateRepository(ref.watch(supabaseClientProvider));
});

final currentAffiliateProvider = FutureProvider<Affiliate?>((ref) async {
  debugPrint('[PROVIDER:Affiliate] currentAffiliateProvider loaded');
  final result = await ref.watch(affiliateRepositoryProvider).getCurrentAffiliate();
  debugPrint('[PROVIDER:Affiliate] currentAffiliateProvider result: ${result != null ? result.id : "null"}');
  return result;
});
