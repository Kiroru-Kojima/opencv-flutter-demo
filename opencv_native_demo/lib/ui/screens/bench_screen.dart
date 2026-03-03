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

  bool _busy = false;
  String? _error;
  _BenchSummary? _summary;

  int _warmup = 10;
  int _iterations = 100;

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
      final samples = await _backend.benchmarkCannyMs(
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
      setState(() => _summary = _BenchSummary.fromSamples(samples));
    } catch (e, st) {
      debugPrint('OpenCV native bench error: $e\n$st');
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
            Text('avg:   ${summary.avgMs.toStringAsFixed(3)} ms', style: mono),
            Text('p50:   ${summary.p50Ms.toStringAsFixed(3)} ms', style: mono),
            Text('p90:   ${summary.p90Ms.toStringAsFixed(3)} ms', style: mono),
            Text('p99:   ${summary.p99Ms.toStringAsFixed(3)} ms', style: mono),
            Text('fps≈   ${summary.fps.toStringAsFixed(1)}', style: mono),
          ],
        ),
      ),
    );
  }
}

class _BenchSummary {
  _BenchSummary({
    required this.count,
    required this.avgMs,
    required this.p50Ms,
    required this.p90Ms,
    required this.p99Ms,
    required this.fps,
  });

  final int count;
  final double avgMs;
  final double p50Ms;
  final double p90Ms;
  final double p99Ms;
  final double fps;

  factory _BenchSummary.fromSamples(List<double> samplesMs) {
    double percentile(double q) {
      if (samplesMs.isEmpty) return 0.0;
      if (q <= 0) return samplesMs.reduce((a, b) => a < b ? a : b);
      if (q >= 1) return samplesMs.reduce((a, b) => a > b ? a : b);
      final sorted = samplesMs.toList()..sort();
      final idx = (q * (sorted.length - 1)).round();
      return sorted[idx.clamp(0, sorted.length - 1)];
    }

    final avg = samplesMs.isEmpty ? 0.0 : samplesMs.fold<double>(0, (a, b) => a + b) / samplesMs.length;
    return _BenchSummary(
      count: samplesMs.length,
      avgMs: avg,
      p50Ms: percentile(0.50),
      p90Ms: percentile(0.90),
      p99Ms: percentile(0.99),
      fps: avg <= 0 ? 0.0 : 1000.0 / avg,
    );
  }
}

