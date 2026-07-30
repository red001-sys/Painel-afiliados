import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ranking_entry.dart';
import '../providers/ranking_provider.dart';

class RankingList extends ConsumerWidget {
  const RankingList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankingAsync = ref.watch(rankingProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return rankingAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro ao carregar ranking: $e')),
      data: (ranking) {
        if (ranking.isEmpty) {
          return Center(
            child: Text(
              'Nenhuma venda registrada ainda',
              style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5)),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(rankingProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: ranking.length,
            itemBuilder: (context, index) {
              final entry = ranking[index];
              final position = index + 1;
              return _RankingTile(entry: entry, position: position);
            },
          ),
        );
      },
    );
  }
}

class _RankingTile extends StatelessWidget {
  const _RankingTile({required this.entry, required this.position});

  final RankingEntry entry;
  final int position;

  Color get _positionColor {
    switch (position) {
      case 1:
        return const Color(0xFFF4B400);
      case 2:
        return const Color(0xFFC0C0C0);
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  String _starsText() {
    final total = entry.estrelas;
    if (total <= 0) return '☆☆☆☆☆';
    final stars = total <= 1 ? total : 1.0 + (total - 1) * 0.5;
    final capped = stars.clamp(0, 5);
    final full = capped.floor();
    final half = capped - full >= 0.5 ? 1 : 0;
    final empty = 5 - full - half;
    return '${'★' * full}${half == 1 ? '½' : ''}${'☆' * empty}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isTopThree = position <= 3;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            if (isTopThree)
              Container(
                width: 4,
                height: 40,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: _positionColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              )
            else
              const SizedBox(width: 16),
            isTopThree
                ? Icon(Icons.emoji_events_rounded, color: _positionColor, size: 28)
                : const SizedBox(width: 28),
            const SizedBox(width: 8),
            Text(
              '#$position',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: isTopThree ? _positionColor : const Color(0xFF9E9E9E),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.nome,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        _starsText(),
                        style: const TextStyle(fontSize: 14, letterSpacing: 1),
                      ),
                      if (entry.ciclosCompletos > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          '${entry.ciclosCompletos} ciclos completos',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
