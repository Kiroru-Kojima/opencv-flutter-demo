import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../opencv/native_channel_backend.dart';
import '../../opencv/test_image.dart';

class BenchScreen extends StatefulWidget {
  const BenchScreen({super.key});

  @override
  State<BenchScreen> createState() => _BenchScreenState();
}

class _BenchScreenState extends State<BenchScreen> {
  final _backend = OpenCvNativeChannelBackend();

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
      final r = await _backend.benchmarkCannyProfile(
        img.bgrBytes,
        width: img.width,
        height: img.height,
        warmup: _warmup,
        iterations: _iterations,
        threshold1: 80,
        threshold2: 160,
        apertureSize: 3,
        l2gradient: false,
      );
      setState(() => _summary = _BenchSummary.fromNative(r));
    } catch (e, st) {
      debugPrint('OpenCV native bench error: $e\n$st');
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
      final r = await _backend.benchmarkFgExtractProfile(
        warmup: _warmup,
        iterations: _iterations,
        alpha: 0.05,
        threshold: 25.0,
        morphIterations: 1,
      );
      setState(() => _videoSummary = _VideoBenchSummary.fromNative(r));
    } catch (e, st) {
      debugPrint('OpenCV native video bench error: $e\n$st');
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
      debugPrint('MP4 bench start (native): warmup=$_warmup iterations=$_iterations');
      final r = await _backend.benchmarkMp4FgExtractProfile(
        warmup: _warmup,
        iterations: _iterations,
        alpha: 0.05,
        threshold: 25.0,
        morphIterations: 1,
      );
      double avg(List<double> xs) => xs.isEmpty ? 0.0 : xs.reduce((a, b) => a + b) / xs.length;
      debugPrint('MP4 bench done (native): total(avg)=${avg(r.totalMs).toStringAsFixed(3)}ms '
          'decode(avg)=${avg(r.decodeMs).toStringAsFixed(3)}ms process(avg)=${avg(r.processMs).toStringAsFixed(3)}ms');
      debugPrint('MP4 bench source (native): ${r.usedPath}');
      setState(() => _mp4Summary = _Mp4BenchSummary.fromNative(r));
    } catch (e, st) {
      debugPrint('OpenCV native mp4 bench error: $e\n$st');
      debugPrint('MP4 bench error (native): $e');
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
        Text('backend: Platform Channel (native OpenCV)', style: theme.textTheme.bodyMedium),
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
            Text('native(avg/p50/p90/p99): ${summary.native.avgMs.toStringAsFixed(3)} / '
                '${summary.native.p50Ms.toStringAsFixed(3)} / ${summary.native.p90Ms.toStringAsFixed(3)} / '
                '${summary.native.p99Ms.toStringAsFixed(3)} ms', style: mono),
            Text('overhead(avg/p50/p90/p99): ${summary.overhead.avgMs.toStringAsFixed(3)} / '
                '${summary.overhead.p50Ms.toStringAsFixed(3)} / ${summary.overhead.p90Ms.toStringAsFixed(3)} / '
                '${summary.overhead.p99Ms.toStringAsFixed(3)} ms', style: mono),
            Text('fps≈ (native avg): ${summary.nativeFps.toStringAsFixed(1)}', style: mono),
            if (summary.lastNativeStagesUs != null) ...[
              const SizedBox(height: 8),
              Text('native stages (us): ${_formatStages(summary.lastNativeStagesUs!)}', style: mono),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatStages(Map<String, int> stages) {
    final keys = stages.keys.toList()..sort();
    return keys.map((k) => '$k=${stages[k]}').join(', ');
  }
}

class _BenchSummary {
  _BenchSummary({
    required this.count,
    required this.total,
    required this.native,
    required this.overhead,
    required this.nativeFps,
    required this.lastNativeStagesUs,
  });

  final int count;
  final _Stats total;
  final _Stats native;
  final _Stats overhead;
  final double nativeFps;
  final Map<String, int>? lastNativeStagesUs;

  factory _BenchSummary.fromNative(NativeBenchSamples r) {
    final total = _Stats.fromSamples(r.totalMs);
    final native = _Stats.fromSamples(r.nativeMs);
    final overhead = _Stats.fromSamples(r.overheadMs);
    final fps = native.avgMs <= 0 ? 0.0 : 1000.0 / native.avgMs;
    return _BenchSummary(
      count: r.totalMs.length,
      total: total,
      native: native,
      overhead: overhead,
      nativeFps: fps,
      lastNativeStagesUs: r.lastNativeStagesUs,
    );
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
            Text('video: ${summary.width}x${summary.height}, frames=${summary.frameCount}', style: mono),
            if (summary.lastFgCount != null) Text('lastFgCount: ${summary.lastFgCount}', style: mono),
            Text('total(avg/p50/p90/p99): ${summary.total.avgMs.toStringAsFixed(3)} / '
                '${summary.total.p50Ms.toStringAsFixed(3)} / ${summary.total.p90Ms.toStringAsFixed(3)} / '
                '${summary.total.p99Ms.toStringAsFixed(3)} ms', style: mono),
            Text('native(avg/p50/p90/p99): ${summary.native.avgMs.toStringAsFixed(3)} / '
                '${summary.native.p50Ms.toStringAsFixed(3)} / ${summary.native.p90Ms.toStringAsFixed(3)} / '
                '${summary.native.p99Ms.toStringAsFixed(3)} ms', style: mono),
            Text('overhead(avg/p50/p90/p99): ${summary.overhead.avgMs.toStringAsFixed(3)} / '
                '${summary.overhead.p50Ms.toStringAsFixed(3)} / ${summary.overhead.p90Ms.toStringAsFixed(3)} / '
                '${summary.overhead.p99Ms.toStringAsFixed(3)} ms', style: mono),
            Text('fps≈ (native avg): ${summary.nativeFps.toStringAsFixed(1)}', style: mono),
            if (summary.lastNativeStagesUs != null) ...[
              const SizedBox(height: 8),
              Text('native stages (us): ${_SummaryCard._formatStages(summary.lastNativeStagesUs!)}', style: mono),
            ],
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
    required this.native,
    required this.overhead,
    required this.nativeFps,
    required this.lastNativeStagesUs,
    required this.lastFgCount,
    required this.width,
    required this.height,
    required this.frameCount,
  });

  final int count;
  final _Stats total;
  final _Stats native;
  final _Stats overhead;
  final double nativeFps;
  final Map<String, int>? lastNativeStagesUs;
  final int? lastFgCount;
  final int width;
  final int height;
  final int frameCount;

  factory _VideoBenchSummary.fromNative(NativeFgBenchSamples r) {
    final total = _Stats.fromSamples(r.totalMs);
    final native = _Stats.fromSamples(r.nativeMs);
    final overhead = _Stats.fromSamples(r.overheadMs);
    final fps = native.avgMs <= 0 ? 0.0 : 1000.0 / native.avgMs;
    return _VideoBenchSummary(
      count: r.totalMs.length,
      total: total,
      native: native,
      overhead: overhead,
      nativeFps: fps,
      lastNativeStagesUs: r.lastNativeStagesUs,
      lastFgCount: r.lastFgCount,
      width: r.width,
      height: r.height,
      frameCount: r.frameCount,
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
            Text('dartCall(total): ${summary.dartCallMs.toStringAsFixed(3)} ms', style: mono),
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
    required this.dartCallMs,
  });

  final int count;
  final _Stats total;
  final _Stats decode;
  final _Stats process;
  final double fps;
  final int? lastFgCount;
  final double dartCallMs;

  factory _Mp4BenchSummary.fromNative(NativeMp4BenchSamples r) {
    final total = _Stats.fromSamples(r.totalMs);
    final fps = total.avgMs <= 0 ? 0.0 : 1000.0 / total.avgMs;
    return _Mp4BenchSummary(
      count: r.totalMs.length,
      total: total,
      decode: _Stats.fromSamples(r.decodeMs),
      process: _Stats.fromSamples(r.processMs),
      fps: fps,
      lastFgCount: r.lastFgCount,
      dartCallMs: r.dartCallMs,
    );
  }
}
