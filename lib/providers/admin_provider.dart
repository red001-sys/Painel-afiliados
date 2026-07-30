import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/affiliate.dart';
import '../models/affiliate_link.dart';
import '../repositories/admin_repository.dart';
import '../repositories/affiliate_link_repository.dart';
import 'auth_provider.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref.watch(supabaseClientProvider));
});

final adminDashboardProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  debugPrint('[PROVIDER:Admin] adminDashboardProvider loaded');
  final repo = ref.watch(adminRepositoryProvider);

  int affiliatesCount = 0;
  int activeAffiliatesCount = 0;
  int productsCount = 0;
  int salesCount = 0;
  double totalCommission = 0;
  Map<String, dynamic>? lastSync;

  debugPrint('[PROVIDER:Admin] Fetching dashboard data (6 queries)...');

  final results = await Future.wait([
    repo.getAffiliatesCount().catchError((e) {
      debugPrint('[PROVIDER:Admin] getAffiliatesCount failed: $e');
      return 0;
    }),
    repo.getActiveAffiliatesCount().catchError((e) {
      debugPrint('[PROVIDER:Admin] getActiveAffiliatesCount failed: $e');
      return 0;
    }),
    repo.getProductsCount().catchError((e) {
      debugPrint('[PROVIDER:Admin] getProductsCount failed: $e');
      return 0;
    }),
    repo.getSalesCount().catchError((e) {
      debugPrint('[PROVIDER:Admin] getSalesCount failed: $e');
      return 0;
    }),
    repo.getTotalCommission().catchError((e) {
      debugPrint('[PROVIDER:Admin] getTotalCommission failed: $e');
      return 0.0;
    }),
    repo.getLastSyncLog().catchError((e) {
      debugPrint('[PROVIDER:Admin] getLastSyncLog failed: $e');
      return null;
    }),
  ]);

  affiliatesCount = results[0] as int;
  activeAffiliatesCount = results[1] as int;
  productsCount = results[2] as int;
  salesCount = results[3] as int;
  totalCommission = results[4] as double;
  lastSync = results[5] as Map<String, dynamic>?;

  debugPrint('[PROVIDER:Admin] Dashboard data loaded:');
  debugPrint('[PROVIDER:Admin]   affiliatesCount=$affiliatesCount');
  debugPrint('[PROVIDER:Admin]   activeAffiliatesCount=$activeAffiliatesCount');
  debugPrint('[PROVIDER:Admin]   productsCount=$productsCount');
  debugPrint('[PROVIDER:Admin]   salesCount=$salesCount');
  debugPrint('[PROVIDER:Admin]   totalCommission=$totalCommission');
  debugPrint('[PROVIDER:Admin]   lastSync=${lastSync != null ? "exists" : "null"}');

  return {
    'affiliatesCount': affiliatesCount,
    'activeAffiliatesCount': activeAffiliatesCount,
    'productsCount': productsCount,
    'salesCount': salesCount,
    'totalCommission': totalCommission,
    'lastSync': lastSync,
  };
});

final adminAffiliatesProvider =
    FutureProvider<List<Affiliate>>((ref) async {
  return ref.watch(adminRepositoryProvider).getAllAffiliates();
});

final adminAffiliatesWithStatsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref
      .watch(adminRepositoryProvider)
      .getAllAffiliatesWithStats();
});

final affiliateLinkRepositoryProvider =
    Provider<AffiliateLinkRepository>((ref) {
  return AffiliateLinkRepository(
      ref.watch(supabaseClientProvider));
});

final affiliateDetailProvider =
    FutureProvider.family<Affiliate?, String>(
        (ref, affiliateId) async {
  return ref
      .watch(adminRepositoryProvider)
      .getAffiliateById(affiliateId);
});

final affiliateStatsProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
        (ref, affiliateId) async {
  return ref
      .watch(adminRepositoryProvider)
      .getAffiliateStats(affiliateId);
});

final affiliateLinksProvider =
    FutureProvider.family<List<AffiliateLink>, String>(
        (ref, affiliateId) async {
  return ref
      .watch(affiliateLinkRepositoryProvider)
      .getByAffiliate(affiliateId);
});

final affiliateSalesProvider = FutureProvider.family<
    List<Map<String, dynamic>>,
    ({String affiliateId, String? status, String? search})>(
    (ref, params) async {
  return ref.watch(adminRepositoryProvider).getSalesByAffiliate(
        params.affiliateId,
        status: params.status,
        search: params.search,
      );
});

// --- Sync providers ---

final syncExecutingProvider = StateProvider<bool>((ref) => false);

final syncHistoryProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref
      .watch(adminRepositoryProvider)
      .getSyncHistory(limit: 20);
});

final syncTodayStatsProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  return ref
      .watch(adminRepositoryProvider)
      .getSyncStats();
});

Future<void> executeSync(WidgetRef ref) async {
  ref.read(syncExecutingProvider.notifier).state = true;
  try {
    final repo = ref.read(adminRepositoryProvider);
    await repo.executeSync();
    ref.invalidate(adminDashboardProvider);
    ref.invalidate(syncHistoryProvider);
    ref.invalidate(syncTodayStatsProvider);
  } finally {
    ref.read(syncExecutingProvider.notifier).state = false;
  }
}
