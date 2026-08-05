import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/withdrawal_provider.dart';
import '../admin/admin_affiliates_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import '../admin/admin_products_screen.dart';
import '../admin/admin_settings_screen.dart';
import '../admin/admin_ranking_screen.dart';
import '../admin/admin_sync_screen.dart';
import '../admin/admin_videos_screen.dart';
import '../admin/admin_withdrawals_screen.dart';

class AdminShellScreen extends ConsumerStatefulWidget {
  const AdminShellScreen({super.key});

  @override
  ConsumerState<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends ConsumerState<AdminShellScreen> {
  int _selectedIndex = 0;

  static const _titles = [
    'Dashboard',
    'Afiliados',
    'Produtos',
    'Vídeos',
    'Ranking',
    'Saques',
    'Sincronização RedStar',
    'Configurações',
  ];

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return const AdminDashboardScreen();
      case 1:
        return const AdminAffiliatesScreen();
      case 2:
        return const AdminProductsScreen();
      case 3:
        return const AdminVideosScreen();
      case 4:
        return const AdminRankingScreen();
      case 5:
        return const AdminWithdrawalsScreen();
      case 6:
        return const AdminSyncScreen();
      case 7:
        return const AdminSettingsScreen();
      default:
        return const AdminDashboardScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 800;
    final pendingCount =
        ref.watch(pendingWithdrawalCountProvider).valueOrNull ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        centerTitle: true,
      ),
      drawer: isWide
          ? null
          : Drawer(
              child: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    const Icon(Icons.bolt_rounded, size: 48, color: AppColors.ecoGreen),
                    const SizedBox(height: 8),
                    const Text(
                      'RedStar Painel Admin',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const Divider(),
                    _DrawerItem(
                      icon: Icons.dashboard_rounded,
                      label: 'Dashboard',
                      selected: _selectedIndex == 0,
                      onTap: () => setState(() { _selectedIndex = 0; Navigator.pop(context); }),
                    ),
                    _DrawerItem(
                      icon: Icons.people_rounded,
                      label: 'Afiliados',
                      selected: _selectedIndex == 1,
                      onTap: () => setState(() { _selectedIndex = 1; Navigator.pop(context); }),
                    ),
                    _DrawerItem(
                      icon: Icons.inventory_2_rounded,
                      label: 'Produtos',
                      selected: _selectedIndex == 2,
                      onTap: () => setState(() { _selectedIndex = 2; Navigator.pop(context); }),
                    ),
                    _DrawerItem(
                      icon: Icons.video_library_rounded,
                      label: 'Vídeos',
                      selected: _selectedIndex == 3,
                      onTap: () => setState(() { _selectedIndex = 3; Navigator.pop(context); }),
                    ),
                    _DrawerItem(
                      icon: Icons.leaderboard_rounded,
                      label: 'Ranking',
                      selected: _selectedIndex == 4,
                      onTap: () => setState(() { _selectedIndex = 4; Navigator.pop(context); }),
                    ),
                    _DrawerItem(
                      icon: Icons.payments_rounded,
                      label: 'Saques',
                      selected: _selectedIndex == 5,
                      badgeCount: pendingCount,
                      onTap: () => setState(() { _selectedIndex = 5; Navigator.pop(context); }),
                    ),
                    _DrawerItem(
                      icon: Icons.sync_rounded,
                      label: 'Sincronização RedStar',
                      selected: _selectedIndex == 6,
                      onTap: () => setState(() { _selectedIndex = 6; Navigator.pop(context); }),
                    ),
                    const Divider(),
                    _DrawerItem(
                      icon: Icons.settings_rounded,
                      label: 'Configurações',
                      selected: _selectedIndex == 7,
                      onTap: () => setState(() { _selectedIndex = 7; Navigator.pop(context); }),
                    ),
                  ],
                ),
              ),
            ),
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                if (isWide)
                  NavigationRail(
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: (i) => setState(() => _selectedIndex = i),
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    indicatorColor: AppColors.ecoGreen.withValues(alpha: 0.15),
                    selectedIconTheme: const IconThemeData(color: AppColors.ecoGreen),
                    selectedLabelTextStyle: const TextStyle(color: AppColors.ecoGreen, fontSize: 11),
                    unselectedIconTheme: IconThemeData(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    leading: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Icon(Icons.bolt_rounded, size: 32, color: AppColors.ecoGreen),
                    ),
                    labelType: NavigationRailLabelType.all,
                    destinations: [
                      const NavigationRailDestination(
                        icon: Icon(Icons.dashboard_rounded),
                        label: Text('Dashboard'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.people_rounded),
                        label: Text('Afiliados'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.inventory_2_rounded),
                        label: Text('Produtos'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.video_library_rounded),
                        label: Text('Vídeos'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.leaderboard_rounded),
                        label: Text('Ranking'),
                      ),
                      NavigationRailDestination(
                        icon: _iconWithBadge(Icons.payments_rounded, pendingCount),
                        label: const Text('Saques'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.sync_rounded),
                        label: Text('Sync RedStar'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.settings_rounded),
                        label: Text('Config'),
                      ),
                    ],
                  ),
                if (isWide) const VerticalDivider(width: 1),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconWithBadge(IconData icon, int count) {
    return Badge.count(
      count: count,
      isLabelVisible: count > 0,
      backgroundColor: AppColors.error,
      child: Icon(icon),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: selected ? AppColors.ecoGreen : null,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected ? AppColors.ecoGreen : null,
        ),
      ),
      trailing: badgeCount != null && badgeCount! > 0
          ? Badge.count(
              count: badgeCount!,
              backgroundColor: AppColors.error,
            )
          : null,
      selected: selected,
      selectedTileColor: AppColors.ecoGreen.withValues(alpha: 0.08),
      onTap: onTap,
    );
  }
}
