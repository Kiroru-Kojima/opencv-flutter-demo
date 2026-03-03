
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
}
