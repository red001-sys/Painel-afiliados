import 'package:flutter/material.dart';

import '../models/video.dart';

/// Miniatura quadrada de um vídeo, usada nas listas compactas.
///
/// Mostra a capa cadastrada (`thumbnail_url`) quando existir; caso
/// contrário, exibe um placeholder com o ícone de play. A capa é gerada no
/// momento do upload (veja `services/video_thumbnail_generator.dart`) — a
/// lista apenas exibe o que já está salvo no banco.
class VideoThumbnail extends StatelessWidget {
  const VideoThumbnail({super.key, required this.video, this.size = 72});

  final Video video;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final url = video.thumbnailUrl;

    final placeholder = Container(
      width: size,
      height: size,
      color: colorScheme.primary.withValues(alpha: 0.1),
      child: Center(
        child: Icon(
          Icons.play_arrow_rounded,
          color: colorScheme.primary,
          size: 28,
        ),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: size,
        height: size,
        child: url != null
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => placeholder,
              )
            : placeholder,
      ),
    );
  }
}
