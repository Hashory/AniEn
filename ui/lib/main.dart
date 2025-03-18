import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'theme.dart';
import 'timeline.dart';
import 'videoplayer.dart';
import 'node.dart';

void main() {
  runApp(const AniEnUI());
}

class AniEnUI extends StatelessWidget {
  const AniEnUI({super.key});

  @override
  Widget build(BuildContext context) {
    final materialTheme = MaterialTheme(const TextTheme());

    return MaterialApp(
      title: 'Anime Engine',
      theme: materialTheme.dark(),
      home: const AniEnRoot(),
    );
  }
}

class AniEnRoot extends StatelessWidget {
  const AniEnRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final outlineColor = Theme.of(context).colorScheme.outlineVariant;

    return Scaffold(
      body: MultiSplitViewTheme(
        data: MultiSplitViewThemeData(
          dividerPainter: DividerPainters.grooved1(
            color: outlineColor,
            highlightedColor: outlineColor,
          ),
        ),
        child: MultiSplitView(
          axis: Axis.vertical,
          initialAreas: [
            Area(
              builder:
                  (context, area) => MultiSplitView(
                    initialAreas: [
                      Area(builder: (context, area) => VideoPlayerSection()),
                      Area(builder: (context, area) => NodeSection()),
                    ],
                  ),
            ),
            Area(builder: (context, area) => TimelineSection()),
          ],
        ),
      ),
    );
  }
}
