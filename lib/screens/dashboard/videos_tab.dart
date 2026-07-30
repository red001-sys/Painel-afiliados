import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/video_provider.dart';
import '../../widgets/video_preview.dart';

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
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (video.thumbnailUrl != null)
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          video.thumbnailUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: AppColors.ecoGreen.withValues(alpha: 0.1),
                            child: const Icon(Icons.play_circle_outline_rounded,
                                size: 40, color: AppColors.ecoGreen),
                          ),
                        ),
                      )
                    else
                      Container(
                        height: 100,
                        color: AppColors.ecoGreen.withValues(alpha: 0.1),
                        child: const Icon(Icons.play_circle_outline_rounded,
                            size: 40, color: AppColors.ecoGreen),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            video.titulo,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                          if (video.descricao != null && video.descricao!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              video.descricao!,
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 42,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      VideoPreview.show(context, video.videoUrl, video.titulo);
                                    },
                                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                                    label: const Text('Visualizar'),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SizedBox(
                                  height: 42,
                                  child: ElevatedButton.icon(
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
                                    icon: const Icon(Icons.download_rounded, size: 18),
                                    label: const Text('Baixar'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
