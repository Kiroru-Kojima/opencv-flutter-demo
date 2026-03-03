import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:opencv_native_channel/opencv_native_channel.dart';

import 'pixel_conversion.dart';

class OpenCvNativeChannelBackend {
  final OpencvNativeChannel _api = OpencvNativeChannel();

  Future<ui.Image> cannyEdgesRgbaImage(
    Uint8List bgrBytes, {
    required int width,
    required int height,
    required double threshold1,
    required double threshold2,
    required int apertureSize,
    required bool l2gradient,
  }) async {
    final rgba = await _api.cannyBgrToRgba(
      bgr: bgrBytes,
      width: width,
      height: height,
      threshold1: threshold1,
      threshold2: threshold2,
      apertureSize: apertureSize,
      l2gradient: l2gradient,
    );
    return rgbaBytesToUiImage(rgbaBytes: rgba, width: width, height: height);
  }

  Future<List<double>> benchmarkCannyMs(
    Uint8List bgrBytes, {
    required int width,
    required int height,
    required int warmup,
    required int iterations,
    required double threshold1,
    required double threshold2,
    required int apertureSize,
    required bool l2gradient,
  }) async {
    for (int i = 0; i < warmup; i++) {
      await _api.cannyBgrToRgba(
        bgr: bgrBytes,
        width: width,
        height: height,
        threshold1: threshold1,
        threshold2: threshold2,
        apertureSize: apertureSize,
        l2gradient: l2gradient,
      );
    }

    final samples = <double>[];
    for (int i = 0; i < iterations; i++) {
      final sw = Stopwatch()..start();
      await _api.cannyBgrToRgba(
        bgr: bgrBytes,
        width: width,
        height: height,
        threshold1: threshold1,
        threshold2: threshold2,
        apertureSize: apertureSize,
        l2gradient: l2gradient,
      );
      sw.stop();
      samples.add(sw.elapsedMicroseconds / 1000.0);
    }
    return samples;
  }
}

