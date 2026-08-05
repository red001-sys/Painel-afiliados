import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/withdrawal_request.dart';
import '../repositories/withdrawal_repository.dart';
import 'auth_provider.dart';

final withdrawalRepositoryProvider = Provider<WithdrawalRepository>((ref) {
  return WithdrawalRepository(ref.watch(supabaseClientProvider));
});

final myBalanceProvider = FutureProvider<double>((ref) async {
  return ref.watch(withdrawalRepositoryProvider).getMyBalance();
});

final myWithdrawalRequestsProvider =
    FutureProvider<List<WithdrawalRequest>>((ref) async {
  return ref.watch(withdrawalRepositoryProvider).getMyRequests();
});

final adminWithdrawalRequestsProvider =
    FutureProvider<List<WithdrawalRequest>>((ref) async {
  return ref.watch(withdrawalRepositoryProvider).getAllRequests();
});

final pendingWithdrawalCountProvider = FutureProvider<int>((ref) async {
  return ref.watch(withdrawalRepositoryProvider).getPendingCount();
});
