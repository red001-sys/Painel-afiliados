import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/video.dart';
import '../../providers/video_provider.dart';
import '../../widgets/video_preview.dart';
import '../../widgets/video_thumbnail.dart';

class VideosTab extends ConsumerWidget {
  const VideosTab({super.key});

  /// Turns a "viewer" URL into a direct-download URL where possible, so the
  /// browser downloads the file instead of just opening a player/viewer tab.
  ///
  /// - Supabase Storage public object URLs support a native `?download`
  ///   query param that forces `Content-Disposition: attachment`.
  /// - Google Drive "view" links can be converted to Drive's documented
  ///   direct-download export link.
  /// Links from streaming platforms (e.g. YouTube) are intentionally left
  /// untouched — bypassing their playback restrictions to force a download
  /// isn't something we do here.
  static String _downloadUrl(String url) {
    if (url.contains('/storage/v1/object/public/')) {
      if (url.contains('download')) return url;
      return url.contains('?') ? '$url&download' : '$url?download';
    }

    final driveMatch = RegExp(r'drive\.google\.com/file/d/([^/]+)').firstMatch(url);
    if (driveMatch != null) {
      final fileId = driveMatch.group(1);
      return 'https://drive.google.com/uc?export=download&id=$fileId';
    }

    return url;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videosAsync = ref.watch(activeVideosProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return videosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro ao carregar vídeos: $e')),
      data: (videos) {
        if (videos.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.video_library_outlined,
                    size: 64, color: colorScheme.onSurface.withValues(alpha: 0.2)),
                const SizedBox(height: 16),
                Text(
                  'Nenhum vídeo disponível ainda',
                  style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5)),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(activeVideosProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: videos.length,
            itemBuilder: (context, index) {
              final video = videos[index];
              return _buildVideoRow(context, video, colorScheme);
            },
          ),
        );
      },
    );
  }

  Widget _buildVideoRow(BuildContext context, Video video, ColorScheme colorScheme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => VideoPreview.show(context, video.videoUrl, video.titulo),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Stack(
                children: [
                  VideoThumbnail(video: video, size: 72),
                  const Positioned.fill(
                    child: Center(
                      child: Icon(
                        Icons.play_circle_fill_rounded,
                        color: Colors.white,
                        size: 28,
                        shadows: [Shadow(color: Colors.black45, blurRadius: 6)],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.titulo,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (video.descricao != null && video.descricao!.isNotEmpty)
                      Text(
                        video.descricao!,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Baixar',
                onPressed: () async {
                  final launched = await launchUrl(
                    Uri.parse(_downloadUrl(video.videoUrl)),
                    mode: LaunchMode.externalApplication,
                  );
                  if (!launched && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Não foi possível baixar o vídeo')),
                    );
                  }
                },
                icon: const Icon(Icons.download_rounded, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
