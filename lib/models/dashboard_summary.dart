import '../models/sale.dart';

class DashboardSummary {
  const DashboardSummary({
    required this.totalCommission,
    required this.pendingCommission,
    required this.approvedCommission,
    required this.totalSales,
    required this.salesCount,
  });

  final double totalCommission;
  final double pendingCommission;
  final double approvedCommission;
  final double totalSales;
  final int salesCount;

  factory DashboardSummary.fromSales(List<Sale> sales) {
    double pending = 0;
    double approved = 0;
    double rejected = 0;
    double totalSalesVal = 0;

    for (final s in sales) {
      final status = s.status?.toLowerCase() ?? '';
      final commission = s.commissionAmount ?? 0;
      final saleAmount = s.saleAmount ?? 0;

      if (status == 'approved') {
        approved += commission;
      } else if (_isPending(status)) {
        pending += commission;
      } else if (_isRejected(status)) {
        rejected += commission;
      }

      if (!_isRejected(status)) {
        totalSalesVal += saleAmount;
      }
    }

    return DashboardSummary(
      totalCommission: approved,
      pendingCommission: pending,
      approvedCommission: approved,
      totalSales: totalSalesVal,
      salesCount: sales.length,
    );
  }

  static bool _isPending(String status) {
    return status == 'pending' || status == 'locked';
  }

  static bool _isRejected(String status) {
    return status == 'rejected' || status == 'cancelled';
  }
}
