import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/routes/app_router.dart';
import 'core/theme/app_theme.dart';
import 'providers/admin_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/product_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/sales_provider.dart';
import 'providers/affiliate_provider.dart';

class CJApp extends ConsumerStatefulWidget {
  const CJApp({super.key});


  @override
  ConsumerState<CJApp> createState() => _CJAppState();
}

class _CJAppState extends ConsumerState<CJApp> {
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    ref.read(themeModeProvider.notifier).load();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        final event = data.event;
        debugPrint('[APP] Auth state changed: $event');
        if (event == AuthChangeEvent.signedOut) {
          debugPrint('[APP] signedOut → invalidating all providers');
          ref.invalidate(salesProvider);
          ref.invalidate(currentAffiliateProvider);
          ref.invalidate(productsProvider);
          ref.invalidate(activeProductsProvider);
          ref.invalidate(adminDashboardProvider);
          ref.invalidate(adminAffiliatesProvider);
          ref.invalidate(currentProfileProvider);
          ref.invalidate(isAdminProvider);
          ref.invalidate(isAffiliateProvider);
          ref.invalidate(syncHistoryProvider);
          ref.invalidate(syncTodayStatsProvider);
          ref.invalidate(adminAffiliatesWithStatsProvider);
        } else if (event == AuthChangeEvent.signedIn) {
          debugPrint('[APP] signedIn');
        } else if (event == AuthChangeEvent.tokenRefreshed) {
          debugPrint('[APP] tokenRefreshed');
        }
      },
    );
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'RedStar Painel',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      initialRoute: AppRouter.splash,
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}
