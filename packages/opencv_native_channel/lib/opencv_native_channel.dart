
import 'dart:typed_data';

import 'opencv_native_channel_platform_interface.dart';

class CannyProfileResult {
  CannyProfileResult({
    required this.rgba,
    required this.nativeTotalUs,
    required this.stagesUs,
  });

  final Uint8List rgba;
  final int nativeTotalUs;
  final Map<String, int> stagesUs;
}

class FgExtractProfileResult {
  FgExtractProfileResult({
    required this.fgCount,
    required this.nativeTotalUs,
    required this.stagesUs,
  });

  final int fgCount;
  final int nativeTotalUs;
  final Map<String, int> stagesUs;
}

class Mp4FgBenchProfileResult {
  Mp4FgBenchProfileResult({
    required List<int> totalUs,
    required List<int> decodeUs,
    required List<int> processUs,
    required this.lastFgCount,
  })  : totalUs = List.unmodifiable(totalUs),
        decodeUs = List.unmodifiable(decodeUs),
        processUs = List.unmodifiable(processUs);

  final List<int> totalUs;
  final List<int> decodeUs;
  final List<int> processUs;
  final int? lastFgCount;
}

class OpencvNativeChannel {
  Future<String?> getPlatformVersion() {
    return OpencvNativeChannelPlatform.instance.getPlatformVersion();
  }

  Future<Uint8List> cannyBgrToRgba({
    required Uint8List bgr,
    required int width,
    required int height,
    required double threshold1,
    required double threshold2,
    int apertureSize = 3,
    bool l2gradient = false,
  }) {
    return OpencvNativeChannelPlatform.instance.cannyBgrToRgba(
      bgr: bgr,
      width: width,
      height: height,
      threshold1: threshold1,
      threshold2: threshold2,
      apertureSize: apertureSize,
      l2gradient: l2gradient,
    );
  }

  Future<CannyProfileResult> cannyBgrToRgbaProfile({
    required Uint8List bgr,
    required int width,
    required int height,
    required double threshold1,
    required double threshold2,
    int apertureSize = 3,
    bool l2gradient = false,
  }) {
    return OpencvNativeChannelPlatform.instance.cannyBgrToRgbaProfile(
      bgr: bgr,
      width: width,
      height: height,
      threshold1: threshold1,
      threshold2: threshold2,
      apertureSize: apertureSize,
      l2gradient: l2gradient,
    );
  }

  Future<void> fgExtractReset() {
    return OpencvNativeChannelPlatform.instance.fgExtractReset();
  }

  Future<FgExtractProfileResult> fgExtractBgrProfile({
    required Uint8List bgr,
    required int width,
    required int height,
    double alpha = 0.05,
    double threshold = 25.0,
    int morphIterations = 1,
  }) {
    return OpencvNativeChannelPlatform.instance.fgExtractBgrProfile(
      bgr: bgr,
      width: width,
      height: height,
      alpha: alpha,
      threshold: threshold,
      morphIterations: morphIterations,
    );
  }

  Future<Mp4FgBenchProfileResult> benchmarkMp4FgExtractProfile({
    required String path,
    required int warmup,
    required int iterations,
    double alpha = 0.05,
    double threshold = 25.0,
    int morphIterations = 1,
  }) {
    return OpencvNativeChannelPlatform.instance.benchmarkMp4FgExtractProfile(
      path: path,
      warmup: warmup,
      iterations: iterations,
      alpha: alpha,
      threshold: threshold,
      morphIterations: morphIterations,
    );
  }
}
