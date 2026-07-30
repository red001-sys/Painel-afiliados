import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    debugPrint('[SCREEN] LoginScreen._handleLogin() called');
    debugPrint('[SCREEN] Email: $email');
    ref.read(loginProvider.notifier).signIn(email, password);
  }

  Future<void> _navigateAfterLogin() async {
    debugPrint('[NAVIGATE] _navigateAfterLogin() called');
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      debugPrint('[NAVIGATE] currentUser.id: $userId');

      if (userId == null) {
        debugPrint('[NAVIGATE] userId is null, navigating to dashboard (fallback)');
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(AppRouter.dashboard);
        return;
      }

      debugPrint('[NAVIGATE] Querying profiles table for role...');
      debugPrint('[NAVIGATE] Request: GET /profiles?select=role&id=eq.$userId');

      final profile = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();

      debugPrint('[NAVIGATE] profiles query result: $profile');

      if (!mounted) return;

      if (profile != null && profile['role'] == 'admin') {
        debugPrint('[NAVIGATE] Role = admin → navigating to /admin');
        Navigator.of(context).pushReplacementNamed(AppRouter.admin);
      } else {
        debugPrint('[NAVIGATE] Role = ${profile?['role']} (not admin) → navigating to /dashboard');
        Navigator.of(context).pushReplacementNamed(AppRouter.dashboard);
      }
    } catch (e, stackTrace) {
      debugPrint('[NAVIGATE] ERROR in _navigateAfterLogin:');
      debugPrint('[NAVIGATE] error: $e');
      debugPrint('[NAVIGATE] stackTrace: $stackTrace');
      if (e.toString().contains('404')) {
        debugPrint('[NAVIGATE] ⚠️ 404 DETECTED — resource not found');
        debugPrint('[NAVIGATE] Check which URL returned 404 in Network tab');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
      Navigator.of(context).pushReplacementNamed(AppRouter.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final loginState = ref.watch(loginProvider);

    ref.listen<LoginState>(loginProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.error,
          ),
        );
      }
      if (previous?.isLoading == true && next.error == null && !next.isLoading) {
        _navigateAfterLogin();
      }
    });

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingLG),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.12),

              // Logo & Title
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.ecoGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    size: 40,
                    color: AppColors.ecoGreen,
                  ),
                ),
              ),
              SizedBox(height: AppTheme.spacingLG),
              Text(
                'Bem-vindo',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: AppTheme.spacingSM),
              Text(
                'Acesse o painel de subafiliados',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              SizedBox(height: AppTheme.spacingXXL),

              // Email Field
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                enabled: !loginState.isLoading,
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  hintText: 'seu@email.com',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
              ),
              SizedBox(height: AppTheme.spacingMD),

              // Password Field
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                enabled: !loginState.isLoading,
                onSubmitted: (_) => _handleLogin(),
                decoration: InputDecoration(
                  labelText: 'Senha',
                  hintText: '••••••••',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
              ),
              SizedBox(height: AppTheme.spacingSM),

              SizedBox(height: AppTheme.spacingMD),

              // Login Button
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: loginState.isLoading ? null : _handleLogin,
                  child: loginState.isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Entrar'),
                ),
              ),
              SizedBox(height: AppTheme.spacingXL),

              // First Access
              TextButton(
                onPressed: loginState.isLoading
                    ? null
                    : () => Navigator.of(context).pushNamed(AppRouter.firstAccess),
                child: const Text('Primeiro acesso? Crie sua senha'),
              ),
              SizedBox(height: AppTheme.spacingMD),

              // Footer
              Text(
                'EcoFlow × CJ Affiliate',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
