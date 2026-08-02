import '../models/sale.dart';

class DailyChartPoint {
  const DailyChartPoint({required this.date, required this.amount});

  final DateTime date;
  final double amount;

  static List<DailyChartPoint> last7Days(List<Sale> sales) {
    final now = DateTime.now();
    final days = List.generate(7, (i) {
      return DateTime(now.year, now.month, now.day - (6 - i));
    });

    final dayTotals = <int, double>{};
    for (final s in sales) {
      if (s.saleDate == null) continue;
      final dayKey = DateTime(
        s.saleDate!.year, s.saleDate!.month, s.saleDate!.day,
      ).millisecondsSinceEpoch;
      dayTotals[dayKey] = (dayTotals[dayKey] ?? 0) + s.affiliateCommission;
    }

    return days.map((date) {
      final key = DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
      return DailyChartPoint(date: date, amount: dayTotals[key] ?? 0);
    }).toList();
  }
}

class MonthlyChartPoint {
  const MonthlyChartPoint({required this.month, required this.amount});

  final DateTime month;
  final double amount;

  static List<MonthlyChartPoint> last12Months(List<Sale> sales) {
    final now = DateTime.now();
    final months = List.generate(12, (i) {
      return DateTime(now.year, now.month - (11 - i), 1);
    });

    final monthTotals = <int, double>{};
    for (final s in sales) {
      if (s.saleDate == null) continue;
      final key = s.saleDate!.year * 100 + s.saleDate!.month;
      monthTotals[key] = (monthTotals[key] ?? 0) + s.affiliateCommission;
    }

    return months.map((month) {
      final key = month.year * 100 + month.month;
      return MonthlyChartPoint(month: month, amount: monthTotals[key] ?? 0);
    }).toList();
  }
}
