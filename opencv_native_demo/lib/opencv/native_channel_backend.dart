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

  Future<NativeBenchSamples> benchmarkCannyProfile(
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

    final totalMs = <double>[];
    final nativeMs = <double>[];
    final overheadMs = <double>[];
    Map<String, int>? lastNativeStages;

    for (int i = 0; i < iterations; i++) {
      final sw = Stopwatch()..start();
      final r = await _api.cannyBgrToRgbaProfile(
        bgr: bgrBytes,
        width: width,
        height: height,
        threshold1: threshold1,
        threshold2: threshold2,
        apertureSize: apertureSize,
        l2gradient: l2gradient,
      );
      sw.stop();

      final total = sw.elapsedMicroseconds / 1000.0;
      final native = r.nativeTotalUs / 1000.0;
      final overhead = total - native;

      totalMs.add(total);
      nativeMs.add(native);
      overheadMs.add(overhead);
      lastNativeStages = r.stagesUs;
    }

    return NativeBenchSamples(
      totalMs: totalMs,
      nativeMs: nativeMs,
      overheadMs: overheadMs,
      lastNativeStagesUs: lastNativeStages,
    );
  }
}

class NativeBenchSamples {
  NativeBenchSamples({
    required List<double> totalMs,
    required List<double> nativeMs,
    required List<double> overheadMs,
    required this.lastNativeStagesUs,
  })  : totalMs = List.unmodifiable(totalMs),
        nativeMs = List.unmodifiable(nativeMs),
        overheadMs = List.unmodifiable(overheadMs);

  final List<double> totalMs;
  final List<double> nativeMs;
  final List<double> overheadMs;

  /// For quick diagnostics (one sample's stage breakdown).
  final Map<String, int>? lastNativeStagesUs;
}
