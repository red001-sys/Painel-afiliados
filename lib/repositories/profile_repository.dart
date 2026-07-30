import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';

class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  Future<Profile?> getCurrentProfile() async {
    final userId = _client.auth.currentUser?.id;
    debugPrint('[REPO:Profile] getCurrentProfile() called');
    debugPrint('[REPO:Profile] userId: $userId');
    if (userId == null) return null;

    debugPrint('[REPO:Profile] Request: GET /profiles?id=eq.$userId');
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      debugPrint('[REPO:Profile] Response: $response');
      return response != null ? Profile.fromJson(response) : null;
    } catch (e, stackTrace) {
      debugPrint('[REPO:Profile] ERROR: $e');
      debugPrint('[REPO:Profile] stackTrace: $stackTrace');
      rethrow;
    }
  }

  Future<void> createProfile({
    required String userId,
    required String role,
  }) async {
    await _client.from('profiles').insert({
      'id': userId,
      'role': role,
    });
  }

  Future<List<Profile>> getAllProfiles() async {
    final response = await _client
        .from('profiles')
        .select()
        .order('created_at', ascending: false);

    return (response as List)
        .map((e) => Profile.fromJson(e))
        .toList();
  }
}
