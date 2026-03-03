import 'dart:ui' as ui;

import 'package:opencv_dart/opencv_dart.dart' as cv;

import 'mat_ui_image.dart';

class OpenCvFfiBackend {
  bool _disposed = false;

  void dispose() {
    _disposed = true;
  }

  Future<ui.Image> bgrToRgbaImage(cv.Mat bgr) async {
    _ensureNotDisposed();
    final rgba = await cv.cvtColorAsync(bgr, cv.COLOR_BGR2RGBA);
    try {
      return await rgbaMatToUiImage(rgba);
    } finally {
      rgba.dispose();
    }
  }

  Future<ui.Image> cannyEdgesRgbaImage(
    cv.Mat bgr, {
    required double threshold1,
    required double threshold2,
    required int apertureSize,
    required bool l2gradient,
  }) async {
    _ensureNotDisposed();

    final gray = await cv.cvtColorAsync(bgr, cv.COLOR_BGR2GRAY);
    try {
      final edges = await cv.cannyAsync(
        gray,
        threshold1,
        threshold2,
        apertureSize: apertureSize,
        l2gradient: l2gradient,
      );
      try {
        final rgba = await cv.cvtColorAsync(edges, cv.COLOR_GRAY2RGBA);
        try {
          return await rgbaMatToUiImage(rgba);
        } finally {
          rgba.dispose();
        }
      } finally {
        edges.dispose();
      }
    } finally {
      gray.dispose();
    }
  }

  Future<OpenCvBenchResult> benchmarkCanny(
    cv.Mat bgr, {
    required int warmup,
    required int iterations,
    required double threshold1,
    required double threshold2,
    required int apertureSize,
    required bool l2gradient,
  }) async {
    _ensureNotDisposed();
    final samples = <double>[];

    for (int i = 0; i < warmup; i++) {
      final gray = await cv.cvtColorAsync(bgr, cv.COLOR_BGR2GRAY);
      final edges = await cv.cannyAsync(
        gray,
        threshold1,
        threshold2,
        apertureSize: apertureSize,
        l2gradient: l2gradient,
      );
      gray.dispose();
      edges.dispose();
    }

    for (int i = 0; i < iterations; i++) {
      final sw = Stopwatch()..start();
      final gray = await cv.cvtColorAsync(bgr, cv.COLOR_BGR2GRAY);
      final edges = await cv.cannyAsync(
        gray,
        threshold1,
        threshold2,
        apertureSize: apertureSize,
        l2gradient: l2gradient,
      );
      gray.dispose();
      edges.dispose();
      sw.stop();
      samples.add(sw.elapsedMicroseconds / 1000.0);
    }

    return OpenCvBenchResult(samplesMs: samples);
  }

  void _ensureNotDisposed() {
    if (_disposed) throw StateError('OpenCvFfiBackend is disposed');
  }
}

class OpenCvBenchResult {
  OpenCvBenchResult({required List<double> samplesMs}) : samplesMs = List.unmodifiable(samplesMs);

  final List<double> samplesMs;

  double get averageMs {
    if (samplesMs.isEmpty) return 0;
    final sum = samplesMs.fold<double>(0, (a, b) => a + b);
    return sum / samplesMs.length;
  }

  double percentileMs(double q) {
    if (samplesMs.isEmpty) return 0;
    if (q <= 0) return samplesMs.reduce((a, b) => a < b ? a : b);
    if (q >= 1) return samplesMs.reduce((a, b) => a > b ? a : b);
    final sorted = samplesMs.toList()..sort();
    final idx = (q * (sorted.length - 1)).round();
    return sorted[idx.clamp(0, sorted.length - 1)];
  }
}
