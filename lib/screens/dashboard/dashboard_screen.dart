import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/affiliate_link.dart';
import '../../providers/admin_provider.dart';
import '../../providers/affiliate_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/sales_provider.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/sales_charts.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/state_widgets.dart';
import '../history/history_screen.dart';
import '../profile/profile_screen.dart';
import 'ranking_tab.dart';
import 'videos_tab.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _currentIndex = 0;

  static const _titles = ['Dashboard', 'Meus Links', 'Vídeos', 'Ranking', 'Histórico', 'Perfil'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Nenhuma notificação no momento')),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          _DashboardTab(),
          _MyLinksTab(),
          VideosTab(),
          RankingTab(),
          HistoryScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.link_outlined),
            selectedIcon: Icon(Icons.link_rounded),
            label: 'Links',
          ),
          NavigationDestination(
            icon: Icon(Icons.video_library_outlined),
            selectedIcon: Icon(Icons.video_library_rounded),
            label: 'Vídeos',
          ),
          NavigationDestination(
            icon: Icon(Icons.leaderboard_outlined),
            selectedIcon: Icon(Icons.leaderboard_rounded),
            label: 'Ranking',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'Histórico',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

class _DashboardTab extends ConsumerWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesAsync = ref.watch(salesProvider);

    return salesAsync.when(
      loading: () => const DashboardSkeleton(),
      error: (e, _) => ErrorState(
        message: 'Erro ao carregar dados',
        onRetry: () => ref.invalidate(salesProvider),
      ),
      data: (sales) {
        if (sales.isEmpty) {
          return EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Nenhuma venda encontrada',
            subtitle: 'Suas vendas e comissões aparecerão aqui',
            actionLabel: 'Atualizar',
            onAction: () => ref.invalidate(salesProvider),
          );
        }
        return const _DashboardContent();
      },
    );
  }
}

class _DashboardContent extends ConsumerWidget {
  const _DashboardContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardSummaryProvider);
    final weeklyData = ref.watch(weeklyChartDataProvider);
    final monthlyData = ref.watch(monthlyChartDataProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(salesProvider);
        await ref.read(salesProvider.future);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(AppTheme.spacingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.ecoGreen, AppColors.ecoGreenDark],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Resumo Geral',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Acompanhe seu desempenho',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: AppTheme.spacingLG),

            // Metrics
            Text(
              'Métricas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(height: AppTheme.spacingSM),
            Row(
              children: [
                Expanded(
                  child: MetricCard(
                    title: 'Comissão Total',
                    value: 'R\$ ${(summary?.totalCommission ?? 0).toStringAsFixed(2)}',
                    icon: Icons.attach_money_rounded,
                    color: AppColors.ecoGreen,
                    delay: Duration.zero,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricCard(
                    title: 'Pendente',
                    value: 'R\$ ${(summary?.pendingCommission ?? 0).toStringAsFixed(2)}',
                    icon: Icons.schedule_rounded,
                    color: AppColors.warning,
                    delay: const Duration(milliseconds: 100),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: MetricCard(
                    title: 'Aprovada',
                    value: 'R\$ ${(summary?.approvedCommission ?? 0).toStringAsFixed(2)}',
                    icon: Icons.check_circle_outline_rounded,
                    color: AppColors.success,
                    delay: const Duration(milliseconds: 200),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricCard(
                    title: 'Valor Vendido',
                    value: 'R\$ ${(summary?.totalSales ?? 0).toStringAsFixed(2)}',
                    icon: Icons.shopping_cart_outlined,
                    color: AppColors.info,
                    delay: const Duration(milliseconds: 300),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            MetricCard(
              title: 'Total de Vendas',
              value: '${summary?.salesCount ?? 0}',
              icon: Icons.receipt_long_rounded,
              color: AppColors.neutral700,
              delay: const Duration(milliseconds: 400),
            ),

            // Charts
            SizedBox(height: AppTheme.spacingLG),
            WeeklyChart(data: weeklyData),
            SizedBox(height: AppTheme.spacingMD),
            MonthlyChart(data: monthlyData),
            SizedBox(height: AppTheme.spacingMD),
          ],
        ),
      ),
    );
  }
}

class _MyLinksTab extends ConsumerWidget {
  const _MyLinksTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final affiliateAsync = ref.watch(currentAffiliateProvider);

    return affiliateAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorState(
        message: 'Erro ao carregar afiliado',
        onRetry: () => ref.invalidate(currentAffiliateProvider),
      ),
      data: (affiliate) {
        if (affiliate == null) {
          return const EmptyState(
            icon: Icons.link_off_rounded,
            title: 'Afiliado não encontrado',
          );
        }

        final linksAsync = ref.watch(affiliateLinksProvider(affiliate.id));

        return linksAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorState(
            message: 'Erro ao carregar links',
            onRetry: () => ref.invalidate(affiliateLinksProvider(affiliate.id)),
          ),
          data: (links) {
            if (links.isEmpty) {
              return const EmptyState(
                icon: Icons.link_rounded,
                title: 'Nenhum link disponível',
                subtitle: 'Seus links aparecerão aqui',
              );
            }

            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(affiliateLinksProvider(affiliate.id)),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: links.length,
                itemBuilder: (context, index) => _AffiliateLinkCard(
                  link: links[index],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _AffiliateLinkCard extends StatelessWidget {
  const _AffiliateLinkCard({required this.link});

  final AffiliateLink link;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (link.productImagemUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      link.productImagemUrl!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 56,
                        height: 56,
                        color: AppColors.ecoGreen.withValues(alpha: 0.1),
                        child: const Icon(Icons.inventory_2_rounded, size: 28, color: AppColors.ecoGreen),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.ecoGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.inventory_2_rounded, size: 28, color: AppColors.ecoGreen),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        link.displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (link.productCategoria != null)
                        Text(
                          link.productCategoria!,
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (link.productDescricao != null && link.productDescricao!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                link.productDescricao!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: link.finalLink));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Link copiado!'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copiar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final box = context.findRenderObject() as RenderBox?;
                      await Share.share(
                        link.finalLink,
                        subject: link.displayName,
                        sharePositionOrigin: box != null
                            ? box.localToGlobal(Offset.zero) & box.size
                            : null,
                      );
                    },
                    icon: const Icon(Icons.share_rounded, size: 16),
                    label: const Text('Compartilhar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final launched = await launchUrl(Uri.parse(link.finalLink));
                      if (!launched && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Não foi possível abrir o link')),
                        );
                      }
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('Abrir'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
