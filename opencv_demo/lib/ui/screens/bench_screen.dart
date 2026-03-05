import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:opencv_bench_assets/opencv_bench_assets.dart';

import '../../opencv/ffi_backend.dart';
import '../../opencv/test_image.dart';

class BenchScreen extends StatefulWidget {
  const BenchScreen({super.key});

  @override
  State<BenchScreen> createState() => _BenchScreenState();
}

class _BenchScreenState extends State<BenchScreen> {
  final _backend = OpenCvFfiBackend();

  static const bool _autoRunMp4Bench = bool.fromEnvironment('AUTO_RUN_MP4_BENCH', defaultValue: false);

  bool _busy = false;
  String? _error;
  _BenchSummary? _summary;
  _VideoBenchSummary? _videoSummary;
  _Mp4BenchSummary? _mp4Summary;

  int _warmup = 10;
  int _iterations = 100;

  @override
  void initState() {
    super.initState();
    if (_autoRunMp4Bench && !kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _runMp4Bench();
      });
    }
  }

  @override
  void dispose() {
    _backend.dispose();
    super.dispose();
  }

  Future<void> _runBench() async {
    if (kIsWeb) {
      setState(() => _error = 'Webは未対応です（ネイティブOpenCV前提）');
      return;
    }
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _summary = null;
    });

    try {
      final img = buildCheckerboardBgrImage(width: 640, height: 480);
      final src = img.toMat();
      final r = await _backend.benchmarkCannyDetailed(
        src,
        warmup: _warmup,
        iterations: _iterations,
        threshold1: 80,
        threshold2: 160,
        apertureSize: 3,
        l2gradient: false,
      );
      src.dispose();

      setState(() {
        _summary = _BenchSummary.fromDetail(r);
      });
    } catch (e, st) {
      debugPrint('OpenCV bench error: $e\n$st');
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runVideoBench() async {
    if (kIsWeb) {
      setState(() => _error = 'Webは未対応です（ネイティブOpenCV前提）');
      return;
    }
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _videoSummary = null;
    });

    try {
      final video = await loadSampleBgrVideo160x120_90f();
      final r = await _backend.benchmarkForegroundExtractDetailed(
        video.frames,
        width: video.width,
        height: video.height,
        warmup: _warmup,
        iterations: _iterations,
        alpha: 0.05,
        threshold: 25.0,
        morphIterations: 1,
      );

      setState(() {
        _videoSummary = _VideoBenchSummary.fromDetail(r);
      });
    } catch (e, st) {
      debugPrint('OpenCV video bench error: $e\n$st');
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runMp4Bench() async {
    if (kIsWeb) {
      setState(() => _error = 'Webは未対応です（ネイティブOpenCV前提）');
      return;
    }
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _mp4Summary = null;
    });

    try {
      debugPrint('MP4 bench start (FFI): warmup=$_warmup iterations=$_iterations');
      final mp4Path = await ensureSampleMp4File160x120_90f();
      final movPath = await ensureSampleMovFile160x120_90f();
      OpenCvMp4FgBenchDetailResult r;
      String usedPath = mp4Path;
      try {
        r = await _backend.benchmarkMp4ForegroundExtractDetailed(
          mp4Path,
          warmup: _warmup,
          iterations: _iterations,
          alpha: 0.05,
          threshold: 25.0,
          morphIterations: 1,
        );
      } catch (_) {
        usedPath = movPath;
        r = await _backend.benchmarkMp4ForegroundExtractDetailed(
          movPath,
          warmup: _warmup,
          iterations: _iterations,
          alpha: 0.05,
          threshold: 25.0,
          morphIterations: 1,
        );
      }
      double avg(List<double> xs) => xs.isEmpty ? 0.0 : xs.reduce((a, b) => a + b) / xs.length;
      debugPrint('MP4 bench done (FFI): total(avg)=${avg(r.totalMs).toStringAsFixed(3)}ms '
          'decode(avg)=${avg(r.decodeMs).toStringAsFixed(3)}ms process(avg)=${avg(r.processMs).toStringAsFixed(3)}ms');
      debugPrint('MP4 bench source (FFI): $usedPath');
      setState(() => _mp4Summary = _Mp4BenchSummary.fromDetail(r));
    } catch (e, st) {
      debugPrint('OpenCV mp4 bench error: $e\n$st');
      debugPrint('MP4 bench error (FFI): $e');
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '同一入力に対して「GRAY + Canny」処理を繰り返し、処理時間の分布を表示します。',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Text('backend: FFI (opencv_dart)', style: theme.textTheme.bodyMedium),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _IntField(
                label: 'warmup',
                value: _warmup,
                enabled: !_busy,
                onChanged: (v) => setState(() => _warmup = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _IntField(
                label: 'iterations',
                value: _iterations,
                enabled: !_busy,
                onChanged: (v) => setState(() => _iterations = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _busy ? null : _runBench,
          icon: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.speed),
          label: const Text('Run benchmark'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _busy ? null : _runVideoBench,
          icon: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.movie),
          label: const Text('Run video benchmark (FG extract)'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _busy ? null : _runMp4Bench,
          icon: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.video_file),
          label: const Text('Run MP4 benchmark (decode + FG extract)'),
        ),
        const SizedBox(height: 12),
        if (_error != null)
          Text(
            _error!,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
          ),
        if (_summary != null) ...[
          const SizedBox(height: 12),
          _SummaryCard(summary: _summary!),
        ],
        if (_videoSummary != null) ...[
          const SizedBox(height: 12),
          _VideoSummaryCard(summary: _videoSummary!),
        ],
        if (_mp4Summary != null) ...[
          const SizedBox(height: 12),
          _Mp4SummaryCard(summary: _mp4Summary!),
        ],
      ],
    );
  }
}

class _IntField extends StatelessWidget {
  const _IntField({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: ValueKey('$label-$value'),
      initialValue: value.toString(),
      enabled: enabled,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onChanged: (v) {
        final parsed = int.tryParse(v);
        if (parsed == null) return;
        onChanged(parsed.clamp(0, 100000));
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final _BenchSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mono = theme.textTheme.bodyMedium?.copyWith(fontFamily: 'Menlo');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('結果', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('count: ${summary.count}', style: mono),
            Text('total(avg/p50/p90/p99): ${summary.total.avgMs.toStringAsFixed(3)} / '
                '${summary.total.p50Ms.toStringAsFixed(3)} / ${summary.total.p90Ms.toStringAsFixed(3)} / '
                '${summary.total.p99Ms.toStringAsFixed(3)} ms', style: mono),
            Text('gray(avg/p50/p90/p99):  ${summary.gray.avgMs.toStringAsFixed(3)} / '
                '${summary.gray.p50Ms.toStringAsFixed(3)} / ${summary.gray.p90Ms.toStringAsFixed(3)} / '
                '${summary.gray.p99Ms.toStringAsFixed(3)} ms', style: mono),
            Text('canny(avg/p50/p90/p99): ${summary.canny.avgMs.toStringAsFixed(3)} / '
                '${summary.canny.p50Ms.toStringAsFixed(3)} / ${summary.canny.p90Ms.toStringAsFixed(3)} / '
                '${summary.canny.p99Ms.toStringAsFixed(3)} ms', style: mono),
            Text('fps≈ (total avg): ${summary.fps.toStringAsFixed(1)}', style: mono),
          ],
        ),
      ),
    );
  }
}

class _BenchSummary {
  _BenchSummary({
    required this.count,
    required this.total,
    required this.gray,
    required this.canny,
    required this.fps,
  });

  final int count;
  final _Stats total;
  final _Stats gray;
  final _Stats canny;
  final double fps;

  factory _BenchSummary.fromDetail(OpenCvBenchDetailResult r) {
    final total = _Stats.fromSamples(r.totalMs);
    final gray = _Stats.fromSamples(r.grayMs);
    final canny = _Stats.fromSamples(r.cannyMs);
    final fps = total.avgMs <= 0 ? 0.0 : 1000.0 / total.avgMs;
    return _BenchSummary(count: r.totalMs.length, total: total, gray: gray, canny: canny, fps: fps);
  }
}

class _Stats {
  _Stats({
    required this.avgMs,
    required this.p50Ms,
    required this.p90Ms,
    required this.p99Ms,
  });

  final double avgMs;
  final double p50Ms;
  final double p90Ms;
  final double p99Ms;

  factory _Stats.fromSamples(List<double> samplesMs) {
    double percentile(double q) {
      if (samplesMs.isEmpty) return 0.0;
      if (q <= 0) return samplesMs.reduce((a, b) => a < b ? a : b);
      if (q >= 1) return samplesMs.reduce((a, b) => a > b ? a : b);
      final sorted = samplesMs.toList()..sort();
      final idx = (q * (sorted.length - 1)).round();
      return sorted[idx.clamp(0, sorted.length - 1)];
    }

    final avg = samplesMs.isEmpty ? 0.0 : samplesMs.fold<double>(0, (a, b) => a + b) / samplesMs.length;
    return _Stats(
      avgMs: avg,
      p50Ms: percentile(0.50),
      p90Ms: percentile(0.90),
      p99Ms: percentile(0.99),
    );
  }
}

class _VideoSummaryCard extends StatelessWidget {
  const _VideoSummaryCard({required this.summary});

  final _VideoBenchSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mono = theme.textTheme.bodyMedium?.copyWith(fontFamily: 'Menlo');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('動画（前景抽出）結果', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('count: ${summary.count}', style: mono),
            if (summary.lastFgCount != null) Text('lastFgCount: ${summary.lastFgCount}', style: mono),
            Text('total(avg/p50/p90/p99): ${summary.total.avgMs.toStringAsFixed(3)} / '
                '${summary.total.p50Ms.toStringAsFixed(3)} / ${summary.total.p90Ms.toStringAsFixed(3)} / '
                '${summary.total.p99Ms.toStringAsFixed(3)} ms', style: mono),
            Text('mat(avg): ${summary.mat.avgMs.toStringAsFixed(3)} ms', style: mono),
            Text('gray(avg): ${summary.gray.avgMs.toStringAsFixed(3)} ms', style: mono),
            Text('bgUpdate(avg): ${summary.bgUpdate.avgMs.toStringAsFixed(3)} ms', style: mono),
            Text('diff+thresh(avg): ${summary.diffThreshold.avgMs.toStringAsFixed(3)} ms', style: mono),
            Text('morph(avg): ${summary.morph.avgMs.toStringAsFixed(3)} ms', style: mono),
            Text('countNonZero(avg): ${summary.countNonZero.avgMs.toStringAsFixed(3)} ms', style: mono),
            Text('fps≈ (total avg): ${summary.fps.toStringAsFixed(1)}', style: mono),
          ],
        ),
      ),
    );
  }
}

class _VideoBenchSummary {
  _VideoBenchSummary({
    required this.count,
    required this.total,
    required this.mat,
    required this.gray,
    required this.bgUpdate,
    required this.diffThreshold,
    required this.morph,
    required this.countNonZero,
    required this.fps,
    required this.lastFgCount,
  });

  final int count;
  final _Stats total;
  final _Stats mat;
  final _Stats gray;
  final _Stats bgUpdate;
  final _Stats diffThreshold;
  final _Stats morph;
  final _Stats countNonZero;
  final double fps;
  final int? lastFgCount;

  factory _VideoBenchSummary.fromDetail(OpenCvVideoFgBenchDetailResult r) {
    final total = _Stats.fromSamples(r.totalMs);
    final fps = total.avgMs <= 0 ? 0.0 : 1000.0 / total.avgMs;
    return _VideoBenchSummary(
      count: r.totalMs.length,
      total: total,
      mat: _Stats.fromSamples(r.matMs),
      gray: _Stats.fromSamples(r.grayMs),
      bgUpdate: _Stats.fromSamples(r.bgUpdateMs),
      diffThreshold: _Stats.fromSamples(r.diffThresholdMs),
      morph: _Stats.fromSamples(r.morphMs),
      countNonZero: _Stats.fromSamples(r.countMs),
      fps: fps,
      lastFgCount: r.lastFgCount,
    );
  }
}

class _Mp4SummaryCard extends StatelessWidget {
  const _Mp4SummaryCard({required this.summary});

  final _Mp4BenchSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mono = theme.textTheme.bodyMedium?.copyWith(fontFamily: 'Menlo');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('MP4（デコード + 前景抽出）結果', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('count: ${summary.count}', style: mono),
            if (summary.lastFgCount != null) Text('lastFgCount: ${summary.lastFgCount}', style: mono),
            Text('total(avg): ${summary.total.avgMs.toStringAsFixed(3)} ms', style: mono),
            Text('decode(avg): ${summary.decode.avgMs.toStringAsFixed(3)} ms', style: mono),
            Text('process(avg): ${summary.process.avgMs.toStringAsFixed(3)} ms', style: mono),
            Text('fps≈ (total avg): ${summary.fps.toStringAsFixed(1)}', style: mono),
          ],
        ),
      ),
    );
  }
}

class _Mp4BenchSummary {
  _Mp4BenchSummary({
    required this.count,
    required this.total,
    required this.decode,
    required this.process,
    required this.fps,
    required this.lastFgCount,
  });

  final int count;
  final _Stats total;
  final _Stats decode;
  final _Stats process;
  final double fps;
  final int? lastFgCount;

  factory _Mp4BenchSummary.fromDetail(OpenCvMp4FgBenchDetailResult r) {
    final total = _Stats.fromSamples(r.totalMs);
    final fps = total.avgMs <= 0 ? 0.0 : 1000.0 / total.avgMs;
    return _Mp4BenchSummary(
      count: r.totalMs.length,
      total: total,
      decode: _Stats.fromSamples(r.decodeMs),
      process: _Stats.fromSamples(r.processMs),
      fps: fps,
      lastFgCount: r.lastFgCount,
    );
  }
}
