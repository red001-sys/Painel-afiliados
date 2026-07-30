import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final String status;

  Color get _color {
    switch (status.toLowerCase()) {
      case 'approved':
        return AppColors.success;
      case 'pending':
      case 'locked':
        return AppColors.warning;
      case 'cancelled':
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.neutral500;
    }
  }

  String get _label {
    switch (status.toLowerCase()) {
      case 'approved':
        return 'Aprovado';
      case 'pending':
        return 'Pendente';
      case 'locked':
        return 'Bloqueado';
      case 'cancelled':
        return 'Cancelado';
      case 'rejected':
        return 'Rejeitado';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _color,
        ),
      ),
    );
  }
}
