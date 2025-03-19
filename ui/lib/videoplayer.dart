import 'package:flutter/material.dart';

class VideoPlayerSection extends StatelessWidget {
  const VideoPlayerSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: Text(
          'Video Player (Sample)',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}
