import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as vt;

Future<Uint8List?> generateVideoThumbnailImpl(Uint8List videoBytes) async {
  try {
    final tempDir = await getTemporaryDirectory();
    final tempVideoPath =
        '${tempDir.path}/thumb_source_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final tempFile = File(tempVideoPath);
    await tempFile.writeAsBytes(videoBytes);

    final thumbBytes = await vt.VideoThumbnail.thumbnailData(
      video: tempVideoPath,
      imageFormat: vt.ImageFormat.JPEG,
      maxWidth: 480,
      quality: 75,
    );

    try {
      await tempFile.delete();
    } catch (_) {
      // limpeza não é crítica
    }

    return thumbBytes;
  } catch (e) {
    return null;
  }
}
