import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/affiliate_repository.dart';
import '../repositories/auth_repository.dart';
import '../repositories/profile_repository.dart';
import 'affiliate_provider.dart';
import 'auth_provider.dart';
import 'profile_provider.dart';

class FirstAccessState {
  const FirstAccessState({this.isLoading = false, this.error, this.success = false});

  final bool isLoading;
  final String? error;
  final bool success;

  FirstAccessState copyWith({bool? isLoading, String? error, bool? success, bool clearError = false}) {
    return FirstAccessState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      success: success ?? this.success,
    );
  }
}

class FirstAccessNotifier extends StateNotifier<FirstAccessState> {
  FirstAccessNotifier(this._ref) : super(const FirstAccessState());

  final Ref _ref;

  Future<void> createPassword(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final authRepo = _ref.read(authRepositoryProvider);
      final affiliateRepo = _ref.read(affiliateRepositoryProvider);

      // 1. Check if affiliate exists and if already activated
      final check = await affiliateRepo.checkAffiliateForFirstAccess(email);

      if (!check['exists']!) {
        state = const FirstAccessState(
          isLoading: false,
          error: 'Este e-mail não possui acesso ao painel. Entre em contato com o administrador.',
        );
        return;
      }

      if (check['activated']!) {
        state = const FirstAccessState(
          isLoading: false,
          error: 'Esta conta já foi ativada. Faça login normalmente.',
        );
        return;
      }

      // 2. Create auth user
      final response = await authRepo.signUp(
        email: email,
        password: password,
      );

      final userId = response.user?.id;
      if (userId == null) {
        state = const FirstAccessState(
          isLoading: false,
          error: 'Erro ao criar conta. Tente novamente.',
        );
        return;
      }

      // 3. Bind auth_user_id to affiliate
      try {
        await affiliateRepo.bindCurrentUser(email);
      } catch (e) {
        state = const FirstAccessState(
          isLoading: false,
          error: 'Erro ao vincular vendedor. Entre em contato com o administrador.',
        );
        return;
      }

      // 3.5. Create profile with affiliate role
      final profileRepo = _ref.read(profileRepositoryProvider);
      try {
        await profileRepo.createProfile(userId: userId, role: 'affiliate');
      } catch (e) {
        state = const FirstAccessState(
          isLoading: false,
          error: 'Erro ao criar perfil. Entre em contato com o administrador.',
        );
        return;
      }

      // 4. Sign in explicitly (signUp may not create session if email confirmation is on)
      final currentSession = authRepo.currentSession;
      if (currentSession == null) {
        await authRepo.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }

      state = state.copyWith(isLoading: false, success: true);
    } on AuthException catch (e) {
      state = FirstAccessState(isLoading: false, error: _mapAuthError(e));
    } catch (e) {
      state = FirstAccessState(
        isLoading: false,
        error: _mapGenericError(e),
      );
    }
  }

  String _mapAuthError(AuthException e) {
    final message = e.message.toLowerCase();

    if (message.contains('user already registered')) {
      return 'Esta conta já foi ativada. Faça login normalmente.';
    }
    if (message.contains('password')) {
      return 'Senha deve ter no mínimo 6 caracteres.';
    }
    if (message.contains('invalid email')) {
      return 'Email inválido.';
    }
    return e.message;
  }

  String _mapGenericError(Object e) {
    final errorString = e.toString().toLowerCase();
    if (errorString.contains('socket') || errorString.contains('network')) {
      return 'Sem conexão com a internet';
    }
    return 'Erro inesperado. Tente novamente.';
  }
}

final firstAccessProvider =
    StateNotifierProvider.autoDispose<FirstAccessNotifier, FirstAccessState>(
  (ref) => FirstAccessNotifier(ref),
);
