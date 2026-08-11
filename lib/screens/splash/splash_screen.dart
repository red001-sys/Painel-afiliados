import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/routes/app_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    debugPrint('[SPLASH] _navigate() started');
    try {
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      final session = Supabase.instance.client.auth.currentSession;
      debugPrint('[SPLASH] currentSession: ${session != null ? "exists" : "null"}');

      if (session == null) {
        debugPrint('[SPLASH] No session → navigating to /login');
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(AppRouter.login);
        return;
      }

      final userId = Supabase.instance.client.auth.currentUser?.id;
      debugPrint('[SPLASH] currentUser.id: $userId');

      if (userId == null) {
        debugPrint('[SPLASH] userId is null → navigating to /login');
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(AppRouter.login);
        return;
      }

      debugPrint('[SPLASH] Querying profiles table for role...');
      debugPrint('[SPLASH] Request: GET /profiles?select=role&id=eq.$userId');

      final profileResponse = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();

      debugPrint('[SPLASH] profiles query result: $profileResponse');

      if (!mounted) return;

      if (profileResponse == null) {
        debugPrint('[SPLASH] profileResponse is null → navigating to /dashboard (fallback)');
        Navigator.of(context).pushReplacementNamed(AppRouter.dashboard);
        return;
      }

      final role = profileResponse['role'] as String?;
      debugPrint('[SPLASH] Role: $role');

      if (role == 'admin') {
        debugPrint('[SPLASH] Role = admin → navigating to /admin');
        Navigator.of(context).pushReplacementNamed(AppRouter.admin);
      } else {
        debugPrint('[SPLASH] Role = affiliate → navigating to /dashboard');
        Navigator.of(context).pushReplacementNamed(AppRouter.dashboard);
      }
    } catch (e, stackTrace) {
      debugPrint('[SPLASH] ERROR: $e');
      debugPrint('[SPLASH] stackTrace: $stackTrace');
      if (e.toString().contains('404')) {
        debugPrint('[SPLASH] ⚠️ 404 DETECTED');
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRouter.login);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        width: size.width,
        height: size.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.onPrimaryContainer,
              colorScheme.primary,
            ],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  size: 56,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Nex',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Painel de vendedores',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
