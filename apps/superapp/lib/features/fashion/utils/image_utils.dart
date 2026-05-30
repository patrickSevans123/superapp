import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ImageUtils {
  ImageUtils._();

  static Future<File?> compressImage(
    File file, {
    int quality = 80,
    int maxWidth = 1080,
    int maxHeight = 1080,
  }) async {
    final targetPath =
        '${file.parent.path}/${DateTime.now().millisecondsSinceEpoch}_compressed.jpg';

    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: quality,
      minWidth: maxWidth,
      minHeight: maxHeight,
    );

    if (result == null) return null;
    return File(result.path);
  }

  static Future<List<int>> compressToBytes(
    File file, {
    int quality = 80,
    int maxWidth = 1080,
    int maxHeight = 1080,
  }) async {
    final result = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      quality: quality,
      minWidth: maxWidth,
      minHeight: maxHeight,
    );
    return result ?? await file.readAsBytes();
  }
}
