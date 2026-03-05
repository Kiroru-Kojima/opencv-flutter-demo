import 'dart:ui' as ui;
import 'dart:typed_data';

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

  Future<OpenCvBenchDetailResult> benchmarkCannyDetailed(
    cv.Mat bgr, {
    required int warmup,
    required int iterations,
    required double threshold1,
    required double threshold2,
    required int apertureSize,
    required bool l2gradient,
  }) async {
    _ensureNotDisposed();

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

    final totalMs = <double>[];
    final grayMs = <double>[];
    final cannyMs = <double>[];

    for (int i = 0; i < iterations; i++) {
      final swTotal = Stopwatch()..start();

      final swGray = Stopwatch()..start();
      final gray = await cv.cvtColorAsync(bgr, cv.COLOR_BGR2GRAY);
      swGray.stop();

      final swCanny = Stopwatch()..start();
      final edges = await cv.cannyAsync(
        gray,
        threshold1,
        threshold2,
        apertureSize: apertureSize,
        l2gradient: l2gradient,
      );
      swCanny.stop();

      gray.dispose();
      edges.dispose();

      swTotal.stop();
      totalMs.add(swTotal.elapsedMicroseconds / 1000.0);
      grayMs.add(swGray.elapsedMicroseconds / 1000.0);
      cannyMs.add(swCanny.elapsedMicroseconds / 1000.0);
    }

    return OpenCvBenchDetailResult(totalMs: totalMs, grayMs: grayMs, cannyMs: cannyMs);
  }

  Future<OpenCvVideoFgBenchDetailResult> benchmarkForegroundExtractDetailed(
    List<Uint8List> framesBgr, {
    required int width,
    required int height,
    required int warmup,
    required int iterations,
    double alpha = 0.05,
    double threshold = 25.0,
    int morphIterations = 1,
  }) async {
    _ensureNotDisposed();
    if (framesBgr.isEmpty) throw ArgumentError.value(framesBgr, 'framesBgr', 'must not be empty');

    final kernel = cv.getStructuringElement(cv.MORPH_ELLIPSE, (3, 3));
    cv.Mat? bg32f;

    Future<int> processOne(cv.Mat srcBgr) async {
      final gray = await cv.cvtColorAsync(srcBgr, cv.COLOR_BGR2GRAY);
      try {
        final gray32f = await gray.convertToAsync(cv.MatType.CV_32FC1);
        try {
          if (bg32f == null || bg32f!.rows != height || bg32f!.cols != width) {
            bg32f?.dispose();
            bg32f = await gray32f.cloneAsync();
          } else {
            await cv.accumulateWeightedAsync(gray32f, bg32f!, alpha);
          }

          final bg8u = await cv.convertScaleAbsAsync(bg32f!);
          try {
            final diff = await cv.absDiffAsync(gray, bg8u);
            try {
              final (_, mask) = await cv.thresholdAsync(diff, threshold, 255.0, cv.THRESH_BINARY);
              try {
                final opened = await cv.morphologyExAsync(mask, cv.MORPH_OPEN, kernel, iterations: morphIterations);
                try {
                  return cv.countNonZero(opened);
                } finally {
                  opened.dispose();
                }
              } finally {
                mask.dispose();
              }
            } finally {
              diff.dispose();
            }
          } finally {
            bg8u.dispose();
          }
        } finally {
          gray32f.dispose();
        }
      } finally {
        gray.dispose();
      }
    }

    try {
      for (int i = 0; i < warmup; i++) {
        final bgrBytes = framesBgr[i % framesBgr.length];
        final src = cv.Mat.fromList(height, width, cv.MatType.CV_8UC3, bgrBytes);
        try {
          await processOne(src);
        } finally {
          src.dispose();
        }
      }

      final totalMs = <double>[];
      final matMs = <double>[];
      final grayMs = <double>[];
      final bgUpdateMs = <double>[];
      final diffThresholdMs = <double>[];
      final morphMs = <double>[];
      final countMs = <double>[];

      int? lastFgCount;

      for (int i = 0; i < iterations; i++) {
        final bgrBytes = framesBgr[i % framesBgr.length];

        final swTotal = Stopwatch()..start();

        final swMat = Stopwatch()..start();
        final src = cv.Mat.fromList(height, width, cv.MatType.CV_8UC3, bgrBytes);
        swMat.stop();

        final swGray = Stopwatch()..start();
        final gray = await cv.cvtColorAsync(src, cv.COLOR_BGR2GRAY);
        swGray.stop();

        final swBg = Stopwatch()..start();
        final gray32f = await gray.convertToAsync(cv.MatType.CV_32FC1);
        if (bg32f == null || bg32f!.rows != height || bg32f!.cols != width) {
          bg32f?.dispose();
          bg32f = await gray32f.cloneAsync();
        } else {
          await cv.accumulateWeightedAsync(gray32f, bg32f!, alpha);
        }
        swBg.stop();

        final swDiff = Stopwatch()..start();
        final bg8u = await cv.convertScaleAbsAsync(bg32f!);
        final diff = await cv.absDiffAsync(gray, bg8u);
        final (_, mask) = await cv.thresholdAsync(diff, threshold, 255.0, cv.THRESH_BINARY);
        swDiff.stop();

        final swMorph = Stopwatch()..start();
        final opened = await cv.morphologyExAsync(mask, cv.MORPH_OPEN, kernel, iterations: morphIterations);
        swMorph.stop();

        final swCount = Stopwatch()..start();
        lastFgCount = cv.countNonZero(opened);
        swCount.stop();

        opened.dispose();
        mask.dispose();
        diff.dispose();
        bg8u.dispose();
        gray32f.dispose();
        gray.dispose();
        src.dispose();

        swTotal.stop();
        totalMs.add(swTotal.elapsedMicroseconds / 1000.0);
        matMs.add(swMat.elapsedMicroseconds / 1000.0);
        grayMs.add(swGray.elapsedMicroseconds / 1000.0);
        bgUpdateMs.add(swBg.elapsedMicroseconds / 1000.0);
        diffThresholdMs.add(swDiff.elapsedMicroseconds / 1000.0);
        morphMs.add(swMorph.elapsedMicroseconds / 1000.0);
        countMs.add(swCount.elapsedMicroseconds / 1000.0);
      }

      return OpenCvVideoFgBenchDetailResult(
        totalMs: totalMs,
        matMs: matMs,
        grayMs: grayMs,
        bgUpdateMs: bgUpdateMs,
        diffThresholdMs: diffThresholdMs,
        morphMs: morphMs,
        countMs: countMs,
        lastFgCount: lastFgCount,
      );
    } finally {
      bg32f?.dispose();
      kernel.dispose();
    }
  }

  Future<OpenCvMp4FgBenchDetailResult> benchmarkMp4ForegroundExtractDetailed(
    String mp4Path, {
    required int warmup,
    required int iterations,
    double alpha = 0.05,
    double threshold = 25.0,
    int morphIterations = 1,
  }) async {
    _ensureNotDisposed();

    cv.VideoCapture cap = cv.VideoCapture.fromFile(mp4Path);
    if (!cap.isOpened) {
      cap.dispose();
      throw StateError('VideoCapture.open failed: $mp4Path');
    }

    final kernel = cv.getStructuringElement(cv.MORPH_ELLIPSE, (3, 3));
    cv.Mat? bg32f;

    try {
      void restartCapture() {
        cap.dispose();
        cap = cv.VideoCapture.fromFile(mp4Path);
        if (!cap.isOpened) {
          cap.dispose();
          throw StateError('VideoCapture.reopen failed: $mp4Path');
        }
      }

      int processOneSync(cv.Mat frameBgr) {
        final gray = cv.cvtColor(frameBgr, cv.COLOR_BGR2GRAY);
        try {
          final gray32f = gray.convertTo(cv.MatType.CV_32FC1);
          try {
            if (bg32f == null || bg32f!.rows != gray.rows || bg32f!.cols != gray.cols) {
              bg32f?.dispose();
              bg32f = gray32f.clone();
            } else {
              cv.accumulateWeighted(gray32f, bg32f!, alpha);
            }

            final bg8u = cv.convertScaleAbs(bg32f!);
            try {
              final diff = cv.absDiff(gray, bg8u);
              try {
                final (_, mask) = cv.threshold(diff, threshold, 255.0, cv.THRESH_BINARY);
                try {
                  final opened = cv.morphologyEx(mask, cv.MORPH_OPEN, kernel, iterations: morphIterations);
                  try {
                    return cv.countNonZero(opened);
                  } finally {
                    opened.dispose();
                  }
                } finally {
                  mask.dispose();
                }
              } finally {
                diff.dispose();
              }
            } finally {
              bg8u.dispose();
            }
          } finally {
            gray32f.dispose();
          }
        } finally {
          gray.dispose();
        }
      }

      // Warmup
      for (int i = 0; i < warmup; i++) {
        var (ok, frame) = cap.read();
        if (!ok) {
          frame.dispose();
          restartCapture();
          (ok, frame) = cap.read();
          if (!ok) {
            frame.dispose();
            continue;
          }
        }
        try {
          processOneSync(frame);
        } finally {
          frame.dispose();
        }
      }

      final totalMs = <double>[];
      final decodeMs = <double>[];
      final processMs = <double>[];
      int? lastFgCount;

      for (int i = 0; i < iterations; i++) {
        final swTotal = Stopwatch()..start();

        final swDecode = Stopwatch()..start();
        var (ok, frame) = cap.read();
        swDecode.stop();

        if (!ok) {
          frame.dispose();
          swDecode.reset();
          swDecode.start();
          restartCapture();
          (ok, frame) = cap.read();
          swDecode.stop();
          if (!ok) {
            frame.dispose();
            throw StateError('VideoCapture.read failed after restart');
          }
        }

        final swProcess = Stopwatch()..start();
        try {
          lastFgCount = processOneSync(frame);
        } finally {
          frame.dispose();
        }
        swProcess.stop();

        swTotal.stop();
        totalMs.add(swTotal.elapsedMicroseconds / 1000.0);
        decodeMs.add(swDecode.elapsedMicroseconds / 1000.0);
        processMs.add(swProcess.elapsedMicroseconds / 1000.0);
      }

      return OpenCvMp4FgBenchDetailResult(
        totalMs: totalMs,
        decodeMs: decodeMs,
        processMs: processMs,
        lastFgCount: lastFgCount,
      );
    } finally {
      bg32f?.dispose();
      kernel.dispose();
      cap.dispose();
    }
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

class OpenCvBenchDetailResult {
  OpenCvBenchDetailResult({
    required List<double> totalMs,
    required List<double> grayMs,
    required List<double> cannyMs,
  })  : totalMs = List.unmodifiable(totalMs),
        grayMs = List.unmodifiable(grayMs),
        cannyMs = List.unmodifiable(cannyMs);

  final List<double> totalMs;
  final List<double> grayMs;
  final List<double> cannyMs;
}

class OpenCvVideoFgBenchDetailResult {
  OpenCvVideoFgBenchDetailResult({
    required List<double> totalMs,
    required List<double> matMs,
    required List<double> grayMs,
    required List<double> bgUpdateMs,
    required List<double> diffThresholdMs,
    required List<double> morphMs,
    required List<double> countMs,
    required this.lastFgCount,
  })  : totalMs = List.unmodifiable(totalMs),
        matMs = List.unmodifiable(matMs),
        grayMs = List.unmodifiable(grayMs),
        bgUpdateMs = List.unmodifiable(bgUpdateMs),
        diffThresholdMs = List.unmodifiable(diffThresholdMs),
        morphMs = List.unmodifiable(morphMs),
        countMs = List.unmodifiable(countMs);

  final List<double> totalMs;
  final List<double> matMs;
  final List<double> grayMs;
  final List<double> bgUpdateMs;
  final List<double> diffThresholdMs;
  final List<double> morphMs;
  final List<double> countMs;

  final int? lastFgCount;
}

class OpenCvMp4FgBenchDetailResult {
  OpenCvMp4FgBenchDetailResult({
    required List<double> totalMs,
    required List<double> decodeMs,
    required List<double> processMs,
    required this.lastFgCount,
  })  : totalMs = List.unmodifiable(totalMs),
        decodeMs = List.unmodifiable(decodeMs),
        processMs = List.unmodifiable(processMs);

  final List<double> totalMs;
  final List<double> decodeMs;
  final List<double> processMs;

  final int? lastFgCount;
}
