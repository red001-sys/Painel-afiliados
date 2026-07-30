import 'package:flutter/material.dart';

import '../../screens/admin_shell/admin_shell_screen.dart';
import '../../screens/admin/affiliate_detail/affiliate_detail_shell.dart';
import '../../screens/dashboard/dashboard_screen.dart';
import '../../screens/first_access/first_access_screen.dart';
import '../../screens/history/history_screen.dart';
import '../../screens/login/login_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/splash/splash_screen.dart';

abstract final class AppRouter {
  static const String splash = '/';
  static const String login = '/login';
  static const String firstAccess = '/first-access';
  static const String dashboard = '/dashboard';
  static const String history = '/history';
  static const String profile = '/profile';
  static const String admin = '/admin';
  static const String affiliateDetail = '/admin/affiliate';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return _buildRoute(const SplashScreen(), settings);
      case login:
        return _buildRoute(const LoginScreen(), settings);
      case firstAccess:
        return _buildRoute(const FirstAccessScreen(), settings);
      case dashboard:
        return _buildRoute(const DashboardScreen(), settings);
      case history:
        return _buildRoute(const HistoryScreen(), settings);
      case profile:
        return _buildRoute(const ProfileScreen(), settings);
      case admin:
        return _buildRoute(const AdminShellScreen(), settings);
      case affiliateDetail:
        final affiliateId = settings.arguments as String?;
        if (affiliateId == null || affiliateId.isEmpty) {
          return _buildRoute(const AdminShellScreen(), settings);
        }
        return _buildRoute(
          AffiliateDetailShell(affiliateId: affiliateId),
          settings,
        );
      default:
        return _buildRoute(const LoginScreen(), settings);
    }
  }

  static PageRouteBuilder _buildRoute(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          ),
          child: child,
        );
      },
    );
  }
}
