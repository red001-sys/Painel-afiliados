import 'dart:typed_data';

import 'video_thumbnail_generator_stub.dart'
    if (dart.library.html) 'video_thumbnail_generator_web.dart'
    if (dart.library.io) 'video_thumbnail_generator_io.dart';

/// Gera uma imagem JPEG (bytes) a partir do primeiro(s) segundo(s) de um
/// vídeo. Implementação real escolhida automaticamente conforme a
/// plataforma (web usa <video>+<canvas>, mobile usa video_thumbnail).
/// Retorna null se não conseguir gerar (o app deve continuar funcionando
/// sem capa nesse caso, não travar o upload do vídeo por causa disso).
Future<Uint8List?> generateVideoThumbnail(Uint8List videoBytes) {
  return generateVideoThumbnailImpl(videoBytes);
}
