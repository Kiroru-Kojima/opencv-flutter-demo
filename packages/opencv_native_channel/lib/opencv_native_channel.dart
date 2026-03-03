
import 'dart:typed_data';

import 'opencv_native_channel_platform_interface.dart';

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
}
