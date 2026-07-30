import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/video.dart';
import '../repositories/video_repository.dart';
import 'auth_provider.dart';

final videoRepositoryProvider = Provider<VideoRepository>((ref) {
  return VideoRepository(ref.watch(supabaseClientProvider));
});

final videosProvider = FutureProvider<List<Video>>((ref) async {
  return ref.watch(videoRepositoryProvider).getAll();
});

final activeVideosProvider = FutureProvider<List<Video>>((ref) async {
  return ref.watch(videoRepositoryProvider).getActive();
});
