import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/affiliate.dart';

class AffiliateRepository {
  AffiliateRepository(this._client);

  final SupabaseClient _client;

  Future<Affiliate?> getCurrentAffiliate() async {
    final userId = _client.auth.currentUser?.id;
    debugPrint('[REPO:Affiliate] getCurrentAffiliate() called');
    debugPrint('[REPO:Affiliate] userId: $userId');
    if (userId == null) return null;

    debugPrint('[REPO:Affiliate] Request: GET /affiliates?auth_user_id=eq.$userId');
    try {
      final response = await _client
          .from('affiliates')
          .select()
          .eq('auth_user_id', userId)
          .maybeSingle();

      debugPrint('[REPO:Affiliate] Response: $response');
      return response != null ? Affiliate.fromJson(response) : null;
    } catch (e, stackTrace) {
      debugPrint('[REPO:Affiliate] ERROR: $e');
      debugPrint('[REPO:Affiliate] stackTrace: $stackTrace');
      rethrow;
    }
  }

  Future<Map<String, bool>> checkAffiliateForFirstAccess(String email) async {
    debugPrint('[REPO:Affiliate] checkAffiliateForFirstAccess($email)');
    try {
      final response = await _client
          .rpc('check_affiliate_for_first_access', params: {'p_email': email});

      debugPrint('[REPO:Affiliate] Response: $response');

      if (response == null || (response as List).isEmpty) {
        return {'exists': false, 'activated': false};
      }

      final row = response.first;
      return {
        'exists': (row['found'] as bool?) ?? false,
        'activated': (row['activated'] as bool?) ?? false,
      };
    } catch (e, stackTrace) {
      debugPrint('[REPO:Affiliate] ERROR: $e');
      debugPrint('[REPO:Affiliate] stackTrace: $stackTrace');
      rethrow;
    }
  }

  Future<void> updateSelf(Map<String, dynamic> data) async {
    final userId = _client.auth.currentUser?.id;
    debugPrint('[REPO:Affiliate] updateSelf($data)');
    if (userId == null) {
      throw Exception('Usuário não autenticado');
    }
    try {
      await _client
          .from('affiliates')
          .update(data)
          .eq('auth_user_id', userId);
      debugPrint('[REPO:Affiliate] updateSelf OK');
    } catch (e, stackTrace) {
      debugPrint('[REPO:Affiliate] updateSelf ERROR: $e');
      debugPrint('[REPO:Affiliate] stackTrace: $stackTrace');
      rethrow;
    }
  }

  Future<void> bindCurrentUser(String email) async {
    final userId = _client.auth.currentUser?.id;
    debugPrint('[REPO:Affiliate] bindCurrentUser($email)');
    debugPrint('[REPO:Affiliate] userId: $userId');
    if (userId == null) {
      throw Exception('Usuário não autenticado');
    }

    try {
      await _client.rpc('link_affiliate_to_auth', params: {
        'p_email': email,
      });
      debugPrint('[REPO:Affiliate] bindCurrentUser OK');
    } catch (e, stackTrace) {
      debugPrint('[REPO:Affiliate] bindCurrentUser ERROR: $e');
      debugPrint('[REPO:Affiliate] stackTrace: $stackTrace');
      rethrow;
    }
  }
}
