import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class ImageCard extends StatelessWidget {
  const ImageCard({super.key, required this.title, required this.image});

  final String title;
  final ui.Image? image;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            AspectRatio(
              aspectRatio: image == null ? 4 / 3 : image!.width / image!.height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: image == null
                      ? const Center(child: Text('No image'))
                      : RawImage(image: image, filterQuality: FilterQuality.none),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

