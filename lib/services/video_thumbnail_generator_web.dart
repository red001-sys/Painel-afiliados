// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

Future<Uint8List?> generateVideoThumbnailImpl(Uint8List videoBytes) async {
  try {
    final blob = html.Blob([videoBytes], 'video/mp4');
    final url = html.Url.createObjectUrlFromBlob(blob);

    final video = html.VideoElement()
      ..src = url
      ..muted = true
      ..preload = 'auto';

    html.document.body?.append(video);

    // Espera metadata carregar pra saber as dimensões reais do vídeo
    await video.onLoadedMetadata.first.timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception('Timeout carregando metadata do vídeo'),
    );

    video.currentTime = 1; // pega o frame no segundo 1 (evita frame preto do início)
    await video.onSeeked.first.timeout(const Duration(seconds: 10));

    final canvas = html.CanvasElement(
      width: video.videoWidth,
      height: video.videoHeight,
    );
    canvas.context2D.drawImage(video, 0, 0);

    final blobResult = await canvas.toBlob('image/jpeg', 0.75);
    final reader = html.FileReader();
    reader.readAsArrayBuffer(blobResult);
    await reader.onLoad.first;

    video.remove();
    html.Url.revokeObjectUrl(url);

    return (reader.result as ByteBuffer).asUint8List();
  } catch (e) {
    return null;
  }
}
