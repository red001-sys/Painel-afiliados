import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/video.dart';

class VideoRepository {
  VideoRepository(this._client);

  final SupabaseClient _client;

  /// Uploads a video file to the public "videos" Storage bucket and
  /// returns a direct-download URL (the `?download` param forces the
  /// browser to save the file instead of opening a player/viewer tab).
  Future<String> uploadVideo(
    Uint8List bytes,
    String fileName, {
    String? contentType,
  }) async {
    final path = '${DateTime.now().millisecondsSinceEpoch}_$fileName';

    await _client.storage.from('videos').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType ?? 'video/mp4',
            upsert: false,
          ),
        );

    final publicUrl = _client.storage.from('videos').getPublicUrl(path);
    return '$publicUrl?download';
  }

  Future<void> deleteUploadedFile(String storagePath) async {
    await _client.storage.from('videos').remove([storagePath]);
  }

  Future<List<Video>> getAll() async {
    final response = await _client
        .from('videos')
        .select()
        .order('display_order')
        .order('created_at', ascending: false);

    return (response as List).map((e) => Video.fromJson(e)).toList();
  }

  Future<List<Video>> getActive() async {
    final response = await _client
        .from('videos')
        .select()
        .eq('ativo', true)
        .order('display_order')
        .order('created_at', ascending: false);

    return (response as List).map((e) => Video.fromJson(e)).toList();
  }

  Future<Video> create(Video video) async {
    final response = await _client
        .from('videos')
        .insert(video.toJson())
        .select()
        .single();

    return Video.fromJson(response);
  }

  Future<void> update(Video video) async {
    await _client.from('videos').update(video.toJson()).eq('id', video.id);
  }

  Future<void> delete(String id) async {
    await _client.from('videos').delete().eq('id', id);
  }
}
