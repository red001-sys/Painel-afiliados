import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/app_config.dart';
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
  StreamSubscription<Uri>? _linkSubscription;
  final _appLinks = AppLinks();

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
        } else if (event == AuthChangeEvent.passwordRecovery) {
          debugPrint('[APP] passwordRecovery → navigating to reset password');
          if (mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              AppRouter.resetPassword,
              (route) => false,
            );
          }
        }
      },
    );
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        debugPrint('[APP] Initial deep link: $initialUri');
        _handleDeepLink(initialUri);
      }
      _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
        debugPrint('[APP] Deep link received: $uri');
        _handleDeepLink(uri);
      });
    } catch (e) {
      debugPrint('[APP] Deep link init error: $e');
    }
  }

  void _handleDeepLink(Uri uri) async {
    debugPrint('[APP] Deep link received: $uri');
    try {
      await Supabase.instance.client.auth.getSessionFromUrl(uri);
      debugPrint('[APP] getSessionFromUrl OK');
    } catch (e) {
      debugPrint('[APP] getSessionFromUrl error (no auth tokens?): $e');
    }
    if (uri.scheme == AppConfig.passwordResetScheme) {
      debugPrint('[APP] Password reset deep link detected');
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRouter.resetPassword,
          (route) => false,
        );
      }
    }
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'Nex Vendedores',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      initialRoute: AppRouter.splash,
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}
