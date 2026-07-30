import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/sale.dart';
import '../repositories/sales_repository.dart';
import 'auth_provider.dart';

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  return SalesRepository(ref.watch(supabaseClientProvider));
});

final salesProvider = FutureProvider<List<Sale>>((ref) async {
  return ref.watch(salesRepositoryProvider).getSales();
});
