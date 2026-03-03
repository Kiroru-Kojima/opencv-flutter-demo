import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'opencv_native_channel_platform_interface.dart';

/// An implementation of [OpencvNativeChannelPlatform] that uses method channels.
class MethodChannelOpencvNativeChannel extends OpencvNativeChannelPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('opencv_native_channel');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  @override
  Future<Uint8List> cannyBgrToRgba({
    required Uint8List bgr,
    required int width,
    required int height,
    required double threshold1,
    required double threshold2,
    required int apertureSize,
    required bool l2gradient,
  }) async {
    final rgba = await methodChannel.invokeMethod<Uint8List>('cannyBgrToRgba', {
      'bgr': bgr,
      'width': width,
      'height': height,
      'threshold1': threshold1,
      'threshold2': threshold2,
      'apertureSize': apertureSize,
      'l2gradient': l2gradient,
    });
    if (rgba == null) {
      throw PlatformException(code: 'NULL', message: 'cannyBgrToRgba returned null');
    }
    return rgba;
  }
}
