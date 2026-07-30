import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/first_access_provider.dart';

class FirstAccessScreen extends ConsumerStatefulWidget {
  const FirstAccessScreen({super.key});

  @override
  ConsumerState<FirstAccessScreen> createState() => _FirstAccessScreenState();
}

class _FirstAccessScreenState extends ConsumerState<FirstAccessScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    ref.read(firstAccessProvider.notifier).createPassword(email, password);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final state = ref.watch(firstAccessProvider);

    ref.listen<FirstAccessState>(firstAccessProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: AppColors.error),
        );
      }
      if (next.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conta ativada com sucesso!'),
            backgroundColor: AppColors.ecoGreen,
          ),
        );
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (!context.mounted) return;
          Navigator.of(context).pushNamedAndRemoveUntil(
            AppRouter.dashboard,
            (route) => false,
          );
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar minha senha'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingLG),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: AppTheme.spacingXXL),

                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.ecoGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.person_add_rounded,
                      size: 40,
                      color: AppColors.ecoGreen,
                    ),
                  ),
                ),
                SizedBox(height: AppTheme.spacingLG),
                Text(
                  'Ative sua conta',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: AppTheme.spacingSM),
                Text(
                  'Cadastre sua senha para acessar o painel',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                SizedBox(height: AppTheme.spacingXXL),

                // Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  enabled: !state.isLoading,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe seu email';
                    }
                    if (!value.contains('@')) return 'Email inválido';
                    return null;
                  },
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    hintText: 'seu@email.com',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                ),
                SizedBox(height: AppTheme.spacingMD),

                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  enabled: !state.isLoading,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Crie uma senha';
                    }
                    if (value.length < 6) return 'Mínimo de 6 caracteres';
                    return null;
                  },
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
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                SizedBox(height: AppTheme.spacingMD),

                // Confirm Password
                TextFormField(
                  controller: _confirmController,
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  enabled: !state.isLoading,
                  onFieldSubmitted: (_) => _handleSubmit(),
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return 'As senhas não coincidem';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: 'Confirmar senha',
                    hintText: '••••••••',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                ),
                SizedBox(height: AppTheme.spacingXL),

                // Submit
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: state.isLoading ? null : _handleSubmit,
                    child: state.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Criar senha'),
                  ),
                ),
                SizedBox(height: AppTheme.spacingLG),

                // Back to login
                TextButton(
                  onPressed: state.isLoading
                      ? null
                      : () => Navigator.of(context).pushReplacementNamed(AppRouter.login),
                  child: const Text('Já tenho conta? Fazer login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
