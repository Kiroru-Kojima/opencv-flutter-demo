import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'opencv_native_channel.dart';
import 'opencv_native_channel_method_channel.dart';

abstract class OpencvNativeChannelPlatform extends PlatformInterface {
  /// Constructs a OpencvNativeChannelPlatform.
  OpencvNativeChannelPlatform() : super(token: _token);

  static final Object _token = Object();

  static OpencvNativeChannelPlatform _instance = MethodChannelOpencvNativeChannel();

  /// The default instance of [OpencvNativeChannelPlatform] to use.
  ///
  /// Defaults to [MethodChannelOpencvNativeChannel].
  static OpencvNativeChannelPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [OpencvNativeChannelPlatform] when
  /// they register themselves.
  static set instance(OpencvNativeChannelPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<Uint8List> cannyBgrToRgba({
    required Uint8List bgr,
    required int width,
    required int height,
    required double threshold1,
    required double threshold2,
    required int apertureSize,
    required bool l2gradient,
  }) {
    throw UnimplementedError('cannyBgrToRgba() has not been implemented.');
  }

  Future<CannyProfileResult> cannyBgrToRgbaProfile({
    required Uint8List bgr,
    required int width,
    required int height,
    required double threshold1,
    required double threshold2,
    required int apertureSize,
    required bool l2gradient,
  }) {
    throw UnimplementedError('cannyBgrToRgbaProfile() has not been implemented.');
  }

  Future<void> fgExtractReset() {
    throw UnimplementedError('fgExtractReset() has not been implemented.');
  }

  Future<FgExtractProfileResult> fgExtractBgrProfile({
    required Uint8List bgr,
    required int width,
    required int height,
    required double alpha,
    required double threshold,
    required int morphIterations,
  }) {
    throw UnimplementedError('fgExtractBgrProfile() has not been implemented.');
  }

  Future<Mp4FgBenchProfileResult> benchmarkMp4FgExtractProfile({
    required String path,
    required int warmup,
    required int iterations,
    required double alpha,
    required double threshold,
    required int morphIterations,
  }) {
    throw UnimplementedError('benchmarkMp4FgExtractProfile() has not been implemented.');
  }
}
