import 'package:flutter_test/flutter_test.dart';
import 'package:opencv_native_channel/opencv_native_channel.dart';
import 'package:opencv_native_channel/opencv_native_channel_platform_interface.dart';
import 'package:opencv_native_channel/opencv_native_channel_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'dart:typed_data';

class MockOpencvNativeChannelPlatform
    with MockPlatformInterfaceMixin
    implements OpencvNativeChannelPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

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
    return Uint8List(width * height * 4);
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
    return CannyProfileResult(
      rgba: Uint8List(width * height * 4),
      nativeTotalUs: 1234,
      stagesUs: const {'cannyUs': 100},
    );
  }

  @override
  Future<void> fgExtractReset() async {}

  @override
  Future<FgExtractProfileResult> fgExtractBgrProfile({
    required Uint8List bgr,
    required int width,
    required int height,
    required double alpha,
    required double threshold,
    required int morphIterations,
  }) async {
    return FgExtractProfileResult(
      fgCount: 42,
      nativeTotalUs: 1234,
      stagesUs: const {'bgUpdateUs': 100},
    );
  }

  @override
  Future<Mp4FgBenchProfileResult> benchmarkMp4FgExtractProfile({
    required String path,
    required int warmup,
    required int iterations,
    required double alpha,
    required double threshold,
    required int morphIterations,
  }) async {
    return Mp4FgBenchProfileResult(
      totalUs: List<int>.filled(iterations, 2000),
      decodeUs: List<int>.filled(iterations, 800),
      processUs: List<int>.filled(iterations, 1200),
      lastFgCount: 123,
    );
  }
}

void main() {
  final OpencvNativeChannelPlatform initialPlatform = OpencvNativeChannelPlatform.instance;

  test('$MethodChannelOpencvNativeChannel is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelOpencvNativeChannel>());
  });

  test('getPlatformVersion', () async {
    OpencvNativeChannel opencvNativeChannelPlugin = OpencvNativeChannel();
    MockOpencvNativeChannelPlatform fakePlatform = MockOpencvNativeChannelPlatform();
    OpencvNativeChannelPlatform.instance = fakePlatform;

    expect(await opencvNativeChannelPlugin.getPlatformVersion(), '42');
  });
}
