import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chart_data.dart';
import '../models/dashboard_summary.dart';
import 'sales_provider.dart';

final dashboardSummaryProvider = Provider<DashboardSummary?>((ref) {
  final salesAsync = ref.watch(salesProvider);
  return salesAsync.whenOrNull(data: DashboardSummary.fromSales);
});

final weeklyChartDataProvider = Provider<List<DailyChartPoint>>((ref) {
  final salesAsync = ref.watch(salesProvider);
  return salesAsync.whenOrNull(data: DailyChartPoint.last7Days) ?? [];
});

final monthlyChartDataProvider = Provider<List<MonthlyChartPoint>>((ref) {
  final salesAsync = ref.watch(salesProvider);
  return salesAsync.whenOrNull(data: MonthlyChartPoint.last12Months) ?? [];
});
