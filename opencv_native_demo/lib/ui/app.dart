import 'package:flutter/material.dart';

import 'screens/bench_screen.dart';
import 'screens/demo_screen.dart';

class OpenCvNativeDemoApp extends StatelessWidget {
  const OpenCvNativeDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(seedColor: const Color(0xFF18A999));
    return MaterialApp(
      title: 'OpenCV Native Demo',
      theme: ThemeData(colorScheme: colorScheme, useMaterial3: true),
      home: const _Home(),
    );
  }
}

class _Home extends StatelessWidget {
  const _Home();

  static const bool _autoRunMp4Bench = bool.fromEnvironment('AUTO_RUN_MP4_BENCH', defaultValue: false);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: _autoRunMp4Bench ? 1 : 0,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('OpenCV Native Demo'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Demo'),
              Tab(text: 'Bench'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            DemoScreen(),
            BenchScreen(),
          ],
        ),
      ),
    );
  }
}
