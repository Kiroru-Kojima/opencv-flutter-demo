import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'opencv_native_channel.dart';
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

  @override
  Future<CannyProfileResult> cannyBgrToRgbaProfile({
    required Uint8List bgr,
    required int width,
    required int height,
    required double threshold1,
    required double threshold2,
    required int apertureSize,
    required bool l2gradient,
  }) async {
    final r = await methodChannel.invokeMethod<Map<Object?, Object?>>('cannyBgrToRgbaProfile', {
      'bgr': bgr,
      'width': width,
      'height': height,
      'threshold1': threshold1,
      'threshold2': threshold2,
      'apertureSize': apertureSize,
      'l2gradient': l2gradient,
    });
    if (r == null) {
      throw PlatformException(code: 'NULL', message: 'cannyBgrToRgbaProfile returned null');
    }

    final rgba = r['rgba'];
    final nativeTotalUs = r['nativeTotalUs'];
    final stages = r['stagesUs'];
    if (rgba is! Uint8List || nativeTotalUs is! int || stages is! Map) {
      throw PlatformException(code: 'BAD_RESULT', message: 'Unexpected result shape');
    }
    final stagesUs = <String, int>{};
    for (final e in stages.entries) {
      if (e.key is String && e.value is int) {
        stagesUs[e.key as String] = e.value as int;
      }
    }

    return CannyProfileResult(rgba: rgba, nativeTotalUs: nativeTotalUs, stagesUs: stagesUs);
  }
}
