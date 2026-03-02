import 'package:flutter/material.dart';

import 'screens/bench_screen.dart';
import 'screens/demo_screen.dart';

class OpenCvDemoApp extends StatelessWidget {
  const OpenCvDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(seedColor: const Color(0xFF2D5BFF));
    return MaterialApp(
      title: 'OpenCV Demo',
      theme: ThemeData(colorScheme: colorScheme, useMaterial3: true),
      home: const _Home(),
    );
  }
}

class _Home extends StatelessWidget {
  const _Home();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('OpenCV Demo'),
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

