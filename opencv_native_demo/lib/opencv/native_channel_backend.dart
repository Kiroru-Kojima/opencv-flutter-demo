import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:opencv_native_channel/opencv_native_channel.dart';
import 'package:opencv_bench_assets/opencv_bench_assets.dart';

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

  Future<NativeFgBenchSamples> benchmarkFgExtractProfile({
    required int warmup,
    required int iterations,
    double alpha = 0.05,
    double threshold = 25.0,
    int morphIterations = 1,
  }) async {
    final video = await loadSampleBgrVideo160x120_90f();

    await _api.fgExtractReset();
    for (int i = 0; i < warmup; i++) {
      final bgrBytes = video.frames[i % video.frames.length];
      await _api.fgExtractBgrProfile(
        bgr: bgrBytes,
        width: video.width,
        height: video.height,
        alpha: alpha,
        threshold: threshold,
        morphIterations: morphIterations,
      );
    }

    final totalMs = <double>[];
    final nativeMs = <double>[];
    final overheadMs = <double>[];
    Map<String, int>? lastNativeStages;
    int? lastFgCount;

    for (int i = 0; i < iterations; i++) {
      final bgrBytes = video.frames[i % video.frames.length];
      final sw = Stopwatch()..start();
      final r = await _api.fgExtractBgrProfile(
        bgr: bgrBytes,
        width: video.width,
        height: video.height,
        alpha: alpha,
        threshold: threshold,
        morphIterations: morphIterations,
      );
      sw.stop();

      final total = sw.elapsedMicroseconds / 1000.0;
      final native = r.nativeTotalUs / 1000.0;
      final overhead = total - native;

      totalMs.add(total);
      nativeMs.add(native);
      overheadMs.add(overhead);
      lastNativeStages = r.stagesUs;
      lastFgCount = r.fgCount;
    }

    return NativeFgBenchSamples(
      totalMs: totalMs,
      nativeMs: nativeMs,
      overheadMs: overheadMs,
      lastNativeStagesUs: lastNativeStages,
      lastFgCount: lastFgCount,
      width: video.width,
      height: video.height,
      frameCount: video.frames.length,
    );
  }

  Future<NativeMp4BenchSamples> benchmarkMp4FgExtractProfile({
    required int warmup,
    required int iterations,
    double alpha = 0.05,
    double threshold = 25.0,
    int morphIterations = 1,
  }) async {
    final mp4Path = await ensureSampleMp4File160x120_90f();
    final movPath = await ensureSampleMovFile160x120_90f();

    final sw = Stopwatch()..start();
    Mp4FgBenchProfileResult r;
    String usedPath = mp4Path;
    try {
      r = await _api.benchmarkMp4FgExtractProfile(
        path: mp4Path,
        warmup: warmup,
        iterations: iterations,
        alpha: alpha,
        threshold: threshold,
        morphIterations: morphIterations,
      );
    } catch (e) {
      // On some iOS OpenCV builds, VideoCapture fails to open MP4 from sandbox paths.
      // Try MOV container as a fallback to keep "OpenCV decode" path testable.
      usedPath = movPath;
      r = await _api.benchmarkMp4FgExtractProfile(
        path: movPath,
        warmup: warmup,
        iterations: iterations,
        alpha: alpha,
        threshold: threshold,
        morphIterations: morphIterations,
      );
    }
    sw.stop();

    List<double> toMs(List<int> us) => us.map((v) => v / 1000.0).toList(growable: false);

    return NativeMp4BenchSamples(
      totalMs: toMs(r.totalUs),
      decodeMs: toMs(r.decodeUs),
      processMs: toMs(r.processUs),
      lastFgCount: r.lastFgCount,
      dartCallMs: sw.elapsedMicroseconds / 1000.0,
      usedPath: usedPath,
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

class NativeFgBenchSamples {
  NativeFgBenchSamples({
    required List<double> totalMs,
    required List<double> nativeMs,
    required List<double> overheadMs,
    required this.lastNativeStagesUs,
    required this.lastFgCount,
    required this.width,
    required this.height,
    required this.frameCount,
  })  : totalMs = List.unmodifiable(totalMs),
        nativeMs = List.unmodifiable(nativeMs),
        overheadMs = List.unmodifiable(overheadMs);

  final List<double> totalMs;
  final List<double> nativeMs;
  final List<double> overheadMs;

  final Map<String, int>? lastNativeStagesUs;
  final int? lastFgCount;

  final int width;
  final int height;
  final int frameCount;
}

class NativeMp4BenchSamples {
  NativeMp4BenchSamples({
    required List<double> totalMs,
    required List<double> decodeMs,
    required List<double> processMs,
    required this.lastFgCount,
    required this.dartCallMs,
    required this.usedPath,
  })  : totalMs = List.unmodifiable(totalMs),
        decodeMs = List.unmodifiable(decodeMs),
        processMs = List.unmodifiable(processMs);

  final List<double> totalMs;
  final List<double> decodeMs;
  final List<double> processMs;

  final int? lastFgCount;
  final double dartCallMs;
  final String usedPath;
}
