import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

Future<ui.Image> rgbaBytesToUiImage({
  required Uint8List rgbaBytes,
  required int width,
  required int height,
}) async {
  if (rgbaBytes.length != width * height * 4) {
    throw ArgumentError('rgbaBytes length mismatch');
  }
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    Uint8List.fromList(rgbaBytes),
    width,
    height,
    ui.PixelFormat.rgba8888,
    (img) => completer.complete(img),
  );
  return completer.future;
}

Future<ui.Image> bgrBytesToUiImage({
  required Uint8List bgrBytes,
  required int width,
  required int height,
}) async {
  if (bgrBytes.length != width * height * 3) {
    throw ArgumentError('bgrBytes length mismatch');
  }
  final rgba = Uint8List(width * height * 4);
  int si = 0;
  int di = 0;
  while (si < bgrBytes.length) {
    final b = bgrBytes[si++];
    final g = bgrBytes[si++];
    final r = bgrBytes[si++];
    rgba[di++] = r;
    rgba[di++] = g;
    rgba[di++] = b;
    rgba[di++] = 255;
  }
  return rgbaBytesToUiImage(rgbaBytes: rgba, width: width, height: height);
}

