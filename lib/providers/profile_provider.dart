import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/profile.dart';
import '../repositories/profile_repository.dart';
import 'auth_provider.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseClientProvider));
});

final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  debugPrint('[PROVIDER:Profile] currentProfileProvider loaded');
  final repo = ref.watch(profileRepositoryProvider);
  final result = await repo.getCurrentProfile();
  debugPrint('[PROVIDER:Profile] currentProfileProvider result: ${result != null ? "role=${result.role}" : "null"}');
  return result;
});

final isAdminProvider = Provider<bool>((ref) {
  final profileAsync = ref.watch(currentProfileProvider);
  final result = profileAsync.whenOrNull(data: (p) => p?.isAdmin) ?? false;
  debugPrint('[PROVIDER:Profile] isAdminProvider = $result');
  return result;
});

final isAffiliateProvider = Provider<bool>((ref) {
  final profileAsync = ref.watch(currentProfileProvider);
  final result = profileAsync.whenOrNull(data: (p) => p?.isAffiliate) ?? false;
  debugPrint('[PROVIDER:Profile] isAffiliateProvider = $result');
  return result;
});
