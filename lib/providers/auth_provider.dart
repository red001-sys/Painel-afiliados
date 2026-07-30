import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/auth_repository.dart';
import '../core/services/supabase_service.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return SupabaseService.client;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

// --- Login State ---

class LoginState {
  const LoginState({this.isLoading = false, this.error});

  final bool isLoading;
  final String? error;

  LoginState copyWith({bool? isLoading, String? error, bool clearError = false}) {
    return LoginState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class LoginNotifier extends StateNotifier<LoginState> {
  LoginNotifier(this._ref) : super(const LoginState());

  final Ref _ref;

  Future<bool> signIn(String email, String password) async {
    debugPrint('========== LOGIN START ==========');
    debugPrint('[LOGIN] Email: $email');
    debugPrint('[LOGIN] Iniciando signInWithPassword...');
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await _ref.read(authRepositoryProvider).signInWithEmailAndPassword(
            email: email,
            password: password,
          );

      debugPrint('[LOGIN] signInWithPassword OK');
      debugPrint('[LOGIN] User ID: ${response.user?.id}');
      debugPrint('[LOGIN] User Email: ${response.user?.email}');
      debugPrint('[LOGIN] Session: ${response.session != null ? "exists" : "null"}');
      debugPrint('[LOGIN] Access Token: ${response.session?.accessToken?.substring(0, 20)}...');

      state = state.copyWith(isLoading: false);
      debugPrint('========== LOGIN END ==========');
      return true;
    } on AuthException catch (e) {
      debugPrint('[LOGIN] AuthException: ${e.message}');
      debugPrint('[LOGIN] StatusCode: ${e.statusCode}');
      state = LoginState(isLoading: false, error: _mapAuthError(e));
      debugPrint('========== LOGIN FAILED ==========');
      return false;
    } catch (e, stackTrace) {
      debugPrint('[LOGIN] Generic Error: $e');
      debugPrint('[LOGIN] StackTrace: $stackTrace');
      state = LoginState(
        isLoading: false,
        error: _mapGenericError(e),
      );
      debugPrint('========== LOGIN FAILED ==========');
      return false;
    }
  }

  String _mapAuthError(AuthException e) {
    final message = e.message.toLowerCase();

    if (message.contains('invalid login credentials') ||
        message.contains('invalid')) {
      return 'Email ou senha incorretos';
    }
    if (message.contains('email not confirmed')) {
      return 'Email não confirmado. Verifique sua caixa de entrada.';
    }
    if (message.contains('too many requests')) {
      return 'Muitas tentativas. Aguarde alguns minutos.';
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

final loginProvider = StateNotifierProvider.autoDispose<LoginNotifier, LoginState>(
  (ref) => LoginNotifier(ref),
);
