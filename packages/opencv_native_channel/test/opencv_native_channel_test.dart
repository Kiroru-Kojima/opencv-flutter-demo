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
