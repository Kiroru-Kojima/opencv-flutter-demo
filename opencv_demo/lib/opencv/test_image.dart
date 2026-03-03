import 'dart:typed_data';

import 'package:opencv_dart/opencv_dart.dart' as cv;

class BgrTestImage {
  BgrTestImage({
    required this.width,
    required this.height,
    required this.bgrBytes,
  });

  final int width;
  final int height;
  final Uint8List bgrBytes;

  cv.Mat toMat() => cv.Mat.fromList(height, width, cv.MatType.CV_8UC3, bgrBytes);
}

BgrTestImage buildCheckerboardBgrImage({required int width, required int height}) {
  const block = 16;
  final bytes = Uint8List(width * height * 3);

  int i = 0;
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final isWhite = ((x ~/ block) + (y ~/ block)) % 2 == 0;
      final v = isWhite ? 230 : 20;
      final gx = (x * 255 ~/ (width - 1)).clamp(0, 255).toInt();
      final gy = (y * 255 ~/ (height - 1)).clamp(0, 255).toInt();

      // BGR
      bytes[i++] = ((v + gx) ~/ 2).clamp(0, 255).toInt();
      bytes[i++] = ((v + gy) ~/ 2).clamp(0, 255).toInt();
      bytes[i++] = v;
    }
  }

  return BgrTestImage(width: width, height: height, bgrBytes: bytes);
}
