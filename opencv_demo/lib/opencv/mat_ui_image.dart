import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:async';

import 'package:opencv_dart/opencv_dart.dart' as cv;

Future<ui.Image> rgbaMatToUiImage(cv.Mat rgba) async {
  if (rgba.channels != 4) {
    throw ArgumentError('rgbaMatToUiImage expects 4-channel Mat (got ${rgba.channels})');
  }
  final bytes = Uint8List.fromList(rgba.data);
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    bytes,
    rgba.cols,
    rgba.rows,
    ui.PixelFormat.rgba8888,
    (img) => completer.complete(img),
  );
  return completer.future;
}
