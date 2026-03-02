import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../opencv/backend_kind.dart';
import '../../opencv/channel_backend.dart';
import '../../opencv/ffi_backend.dart';
import '../../opencv/pixel_conversion.dart';
import '../../opencv/test_image.dart';
import '../widgets/image_card.dart';

class DemoScreen extends StatefulWidget {
  const DemoScreen({super.key});

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  final _backend = OpenCvFfiBackend();
  final _channelBackend = OpenCvChannelBackend();

  ui.Image? _srcImage;
  ui.Image? _edgesImage;
  String? _error;
  bool _busy = false;

  OpenCvBackendKind _backendKind = OpenCvBackendKind.ffi;

  double _t1 = 80;
  double _t2 = 160;
  int _aperture = 3;
  bool _l2 = false;

  @override
  void initState() {
    super.initState();
    _runOnce();
  }

  @override
  void dispose() {
    _backend.dispose();
    _srcImage?.dispose();
    _edgesImage?.dispose();
    super.dispose();
  }

  Future<void> _runOnce() async {
    if (kIsWeb) {
      setState(() => _error = 'Webは未対応です（ネイティブOpenCV前提）');
      return;
    }
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final img = buildCheckerboardBgrImage(width: 320, height: 240);
      final srcUi = await bgrBytesToUiImage(bgrBytes: img.bgrBytes, width: img.width, height: img.height);

      ui.Image edgesUi;
      switch (_backendKind) {
        case OpenCvBackendKind.ffi:
          final srcMat = img.toMat();
          edgesUi = await _backend.cannyEdgesRgbaImage(
            srcMat,
            threshold1: _t1,
            threshold2: _t2,
            apertureSize: _aperture,
            l2gradient: _l2,
          );
          srcMat.dispose();
          break;
        case OpenCvBackendKind.platformChannel:
          edgesUi = await _channelBackend.cannyEdgesRgbaImage(
            img.bgrBytes,
            width: img.width,
            height: img.height,
            threshold1: _t1,
            threshold2: _t2,
            apertureSize: _aperture,
            l2gradient: _l2,
          );
          break;
      }

      setState(() {
        _srcImage?.dispose();
        _edgesImage?.dispose();
        _srcImage = srcUi;
        _edgesImage = edgesUi;
      });
    } catch (e, st) {
      debugPrint('OpenCV demo error: $e\n$st');
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backends = availableBackends();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('入力は合成画像（チェッカーボード）です。', style: theme.textTheme.bodyMedium),
        const SizedBox(height: 12),
        DropdownButtonFormField<OpenCvBackendKind>(
          key: ValueKey(_backendKind),
          initialValue: _backendKind,
          decoration: const InputDecoration(
            labelText: 'backend',
            border: OutlineInputBorder(),
          ),
          items: backends
              .map((k) => DropdownMenuItem(value: k, child: Text(k.label)))
              .toList(growable: false),
          onChanged: (_busy || backends.length <= 1)
              ? null
              : (v) {
                  if (v == null) return;
                  setState(() => _backendKind = v);
                },
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 360,
              child: ImageCard(title: 'Source (BGR→RGBA)', image: _srcImage),
            ),
            SizedBox(
              width: 360,
              child: ImageCard(title: 'Canny (GRAY→RGBA)', image: _edgesImage),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_error != null)
          Text(
            _error!,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
          ),
        const SizedBox(height: 8),
        _Controls(
          busy: _busy,
          threshold1: _t1,
          threshold2: _t2,
          apertureSize: _aperture,
          l2gradient: _l2,
          onChanged: (v) {
            setState(() {
              _t1 = v.threshold1;
              _t2 = v.threshold2;
              _aperture = v.apertureSize;
              _l2 = v.l2gradient;
            });
          },
          onRun: _runOnce,
        ),
      ],
    );
  }
}

class _ControlValues {
  const _ControlValues({
    required this.threshold1,
    required this.threshold2,
    required this.apertureSize,
    required this.l2gradient,
  });

  final double threshold1;
  final double threshold2;
  final int apertureSize;
  final bool l2gradient;
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.busy,
    required this.threshold1,
    required this.threshold2,
    required this.apertureSize,
    required this.l2gradient,
    required this.onChanged,
    required this.onRun,
  });

  final bool busy;
  final double threshold1;
  final double threshold2;
  final int apertureSize;
  final bool l2gradient;
  final ValueChanged<_ControlValues> onChanged;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _LabeledSlider(
          label: 'threshold1',
          value: threshold1,
          min: 0,
          max: 255,
          onChanged: busy ? null : (v) => onChanged(_ControlValues(
                threshold1: v,
                threshold2: threshold2,
                apertureSize: apertureSize,
                l2gradient: l2gradient,
              )),
        ),
        _LabeledSlider(
          label: 'threshold2',
          value: threshold2,
          min: 0,
          max: 255,
          onChanged: busy ? null : (v) => onChanged(_ControlValues(
                threshold1: threshold1,
                threshold2: v,
                apertureSize: apertureSize,
                l2gradient: l2gradient,
              )),
        ),
        Row(
          children: [
            const Text('aperture'),
            const SizedBox(width: 12),
            DropdownButton<int>(
              value: apertureSize,
              items: const [
                DropdownMenuItem(value: 3, child: Text('3')),
                DropdownMenuItem(value: 5, child: Text('5')),
                DropdownMenuItem(value: 7, child: Text('7')),
              ],
              onChanged: busy
                  ? null
                  : (v) {
                      if (v == null) return;
                      onChanged(_ControlValues(
                        threshold1: threshold1,
                        threshold2: threshold2,
                        apertureSize: v,
                        l2gradient: l2gradient,
                      ));
                    },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: l2gradient,
                title: const Text('L2 gradient'),
                onChanged: busy
                    ? null
                    : (v) => onChanged(_ControlValues(
                          threshold1: threshold1,
                          threshold2: threshold2,
                          apertureSize: apertureSize,
                          l2gradient: v ?? false,
                        )),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: busy ? null : onRun,
          icon: busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.play_arrow),
          label: const Text('Run'),
        ),
      ],
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 88, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            divisions: (max - min).toInt(),
            label: value.toStringAsFixed(0),
            onChanged: onChanged,
          ),
        ),
        SizedBox(width: 52, child: Text(value.toStringAsFixed(0), textAlign: TextAlign.end)),
      ],
    );
  }
}
