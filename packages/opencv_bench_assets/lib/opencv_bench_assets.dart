import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

class SampleBgrVideo {
  SampleBgrVideo({
    required this.width,
    required this.height,
    required this.frames,
  });

  final int width;
  final int height;
  final List<Uint8List> frames;
}

Future<SampleBgrVideo> loadSampleBgrVideo160x120_90f() async {
  const jsonAsset = 'packages/opencv_bench_assets/assets/sample_video_160x120_90f.json';
  const bgrAsset = 'packages/opencv_bench_assets/assets/sample_video_160x120_90f.bgr';

  final jsonBytes = await rootBundle.load(jsonAsset);
  final meta = jsonDecode(utf8.decode(jsonBytes.buffer.asUint8List()));
  if (meta is! Map) {
    throw StateError('Invalid sample video metadata: not a JSON object');
  }

  int readInt(String key) {
    final v = meta[key];
    if (v is int) return v;
    throw StateError('Invalid sample video metadata: $key is not int');
  }

  final width = readInt('width');
  final height = readInt('height');
  final frameCount = readInt('frameCount');
  final bytesPerFrame = readInt('bytesPerFrame');

  final raw = (await rootBundle.load(bgrAsset)).buffer.asUint8List();
  final expected = frameCount * bytesPerFrame;
  if (raw.lengthInBytes != expected) {
    throw StateError('Invalid sample video data length: expected=$expected actual=${raw.lengthInBytes}');
  }

  final frames = <Uint8List>[];
  for (int i = 0; i < frameCount; i++) {
    final start = i * bytesPerFrame;
    final end = start + bytesPerFrame;
    frames.add(Uint8List.sublistView(raw, start, end));
  }

  return SampleBgrVideo(width: width, height: height, frames: List.unmodifiable(frames));
}

Future<String> ensureSampleMp4File160x120_90f() async {
  const mp4Asset = 'packages/opencv_bench_assets/assets/sample_video_160x120_90f.mp4';
  const fileName = 'opencv_bench_sample_video_160x120_90f.mp4';
  const legacyMovName = 'opencv_bench_sample_video_160x120_90f.mov';

  final bytes = (await rootBundle.load(mp4Asset)).buffer.asUint8List();
  final file = File('${Directory.systemTemp.path}${Platform.pathSeparator}$fileName');
  final legacyMov = File('${Directory.systemTemp.path}${Platform.pathSeparator}$legacyMovName');

  // If an old .mov remains (from previous builds), delete it to avoid confusion.
  if (await legacyMov.exists()) {
    try {
      await legacyMov.delete();
    } catch (_) {}
  }

  // Avoid re-writing when already identical (cheap header check).
  if (await file.exists()) {
    try {
      final st = await file.stat();
      if (st.size == bytes.lengthInBytes) {
        final head = await file.openRead(0, 16).fold<List<int>>(<int>[], (a, b) => a..addAll(b));
        final expectedHead = bytes.sublist(0, bytes.lengthInBytes < 16 ? bytes.lengthInBytes : 16);
        if (head.length == expectedHead.length) {
          bool ok = true;
          for (int i = 0; i < head.length; i++) {
            if (head[i] != expectedHead[i]) {
              ok = false;
              break;
            }
          }
          if (ok) return file.path;
        }
      }
    } catch (_) {}
  }

  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<String> ensureSampleMovFile160x120_90f() async {
  const movAsset = 'packages/opencv_bench_assets/assets/sample_video_160x120_90f.mov';
  const fileName = 'opencv_bench_sample_video_160x120_90f.mov';

  final bytes = (await rootBundle.load(movAsset)).buffer.asUint8List();
  final file = File('${Directory.systemTemp.path}${Platform.pathSeparator}$fileName');

  if (await file.exists()) {
    final st = await file.stat();
    if (st.size == bytes.lengthInBytes) return file.path;
  }

  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
