import 'package:flutter_test/flutter_test.dart';
import 'package:opencv_channel/opencv_channel.dart';
import 'package:opencv_channel/opencv_channel_platform_interface.dart';
import 'package:opencv_channel/opencv_channel_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'dart:typed_data';

class MockOpencvChannelPlatform
    with MockPlatformInterfaceMixin
    implements OpencvChannelPlatform {

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
  final OpencvChannelPlatform initialPlatform = OpencvChannelPlatform.instance;

  test('$MethodChannelOpencvChannel is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelOpencvChannel>());
  });

  test('getPlatformVersion', () async {
    OpencvChannel opencvChannelPlugin = OpencvChannel();
    MockOpencvChannelPlatform fakePlatform = MockOpencvChannelPlatform();
    OpencvChannelPlatform.instance = fakePlatform;

    expect(await opencvChannelPlugin.getPlatformVersion(), '42');
  });
}
