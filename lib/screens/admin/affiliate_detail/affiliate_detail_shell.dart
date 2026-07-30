import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/routes/app_router.dart';
import '../../../providers/admin_provider.dart';
import 'affiliate_info_tab.dart';
import 'affiliate_links_tab.dart';
import 'affiliate_sales_tab.dart';
import 'affiliate_settings_tab.dart';

class AffiliateDetailShell extends ConsumerStatefulWidget {
  const AffiliateDetailShell({super.key, required this.affiliateId});

  final String affiliateId;

  @override
  ConsumerState<AffiliateDetailShell> createState() => _AffiliateDetailShellState();
}

class _AffiliateDetailShellState extends ConsumerState<AffiliateDetailShell>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _tabs = [
    Tab(icon: Icon(Icons.info_outline), text: 'Informações'),
    Tab(icon: Icon(Icons.link_rounded), text: 'Links'),
    Tab(icon: Icon(Icons.attach_money_rounded), text: 'Vendas'),
    Tab(icon: Icon(Icons.settings_outlined), text: 'Config'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final affiliateAsync = ref.watch(affiliateDetailProvider(widget.affiliateId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            ref.invalidate(adminAffiliatesProvider);
            ref.invalidate(adminAffiliatesWithStatsProvider);
            Navigator.pushReplacementNamed(context, AppRouter.admin);
          },
        ),
        title: affiliateAsync.when(
          loading: () => const Text('Carregando...'),
          error: (_, __) => const Text('Erro'),
          data: (a) => Text(a?.nome ?? a?.email ?? 'Afiliado'),
        ),
        centerTitle: true,
        backgroundColor: AppColors.ecoGreenDark,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
        ),
      ),
      body: affiliateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              const Text('Erro ao carregar afiliado'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(affiliateDetailProvider(widget.affiliateId)),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
        data: (affiliate) {
          if (affiliate == null) {
            return const Center(child: Text('Afiliado não encontrado'));
          }

          return TabBarView(
            controller: _tabController,
            children: [
              AffiliateInfoTab(affiliate: affiliate),
              AffiliateLinksTab(affiliateId: widget.affiliateId),
              AffiliateSalesTab(affiliateId: widget.affiliateId),
              AffiliateSettingsTab(affiliateId: widget.affiliateId),
            ],
          );
        },
      ),
    );
  }
}
