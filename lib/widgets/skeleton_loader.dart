import 'package:flutter/material.dart';

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({required this.width, required this.height, this.borderRadius = 8});

  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ShimmerBox(width: double.infinity, height: 120, borderRadius: 16),
          const SizedBox(height: 20),
          const _ShimmerBox(width: 160, height: 20),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(child: _ShimmerBox(width: double.infinity, height: 110)),
              const SizedBox(width: 12),
              const Expanded(child: _ShimmerBox(width: double.infinity, height: 110)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(child: _ShimmerBox(width: double.infinity, height: 110)),
              const SizedBox(width: 12),
              const Expanded(child: _ShimmerBox(width: double.infinity, height: 110)),
            ],
          ),
          const SizedBox(height: 20),
          const _ShimmerBox(width: 160, height: 20),
          const SizedBox(height: 12),
          const _ShimmerBox(width: double.infinity, height: 220, borderRadius: 12),
          const SizedBox(height: 12),
          const _ShimmerBox(width: double.infinity, height: 220, borderRadius: 12),
        ],
      ),
    );
  }
}

class HistorySkeleton extends StatelessWidget {
  const HistorySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) {
        return const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _ShimmerBox(width: double.infinity, height: 16)),
                      SizedBox(width: 12),
                      _ShimmerBox(width: 70, height: 24, borderRadius: 8),
                    ],
                  ),
                  SizedBox(height: 8),
                  _ShimmerBox(width: 120, height: 14),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      _ShimmerBox(width: 100, height: 14),
                      Spacer(),
                      _ShimmerBox(width: 110, height: 14),
                    ],
                  ),
                  SizedBox(height: 6),
                  _ShimmerBox(width: 80, height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
