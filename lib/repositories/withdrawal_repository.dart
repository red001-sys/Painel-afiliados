import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/withdrawal_request.dart';

class WithdrawalRepository {
  WithdrawalRepository(this._client);

  final SupabaseClient _client;

  Future<double> getMyBalance() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Não autenticado');

    final affiliate = await _client
        .from('affiliates')
        .select('id')
        .eq('auth_user_id', userId)
        .single();

    final response = await _client.rpc('get_affiliate_balance', params: {
      'p_affiliate_id': affiliate['id'],
    });

    return (response as num).toDouble();
  }

  Future<List<WithdrawalRequest>> getMyRequests() async {
    final response = await _client
        .from('withdrawal_requests')
        .select()
        .order('created_at', ascending: false);
    return (response as List)
        .map((e) => WithdrawalRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Lança uma exceção com a mensagem exata vinda do banco (ex: "Você já
  /// tem uma solicitação pendente...") — mostre `e.toString()` direto pro
  /// usuário, as mensagens já estão em português e prontas pra exibir.
  Future<WithdrawalRequest> requestWithdrawal(double valor) async {
    final response = await _client.rpc('request_withdrawal', params: {
      'p_valor': valor,
    });
    return WithdrawalRequest.fromJson(response as Map<String, dynamic>);
  }

  // --- Admin ---

  Future<List<WithdrawalRequest>> getAllRequests({String? status}) async {
    var query = _client
        .from('withdrawal_requests')
        .select('*, affiliates(nome, sid)');
    if (status != null) {
      query = query.eq('status', status);
    }
    final response = await query.order('created_at', ascending: false);
    return (response as List)
        .map((e) => WithdrawalRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> getPendingCount() async {
    final response = await _client
        .from('withdrawal_requests')
        .select('id')
        .eq('status', 'pendente');
    return (response as List).length;
  }

  Future<void> confirmPayment(String requestId) async {
    await _client.rpc('confirm_withdrawal_payment', params: {
      'p_request_id': requestId,
    });
  }
}
