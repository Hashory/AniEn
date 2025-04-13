import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/timeline_provider.dart';
import '../providers/data_models.dart';

class MainView extends ConsumerStatefulWidget {
  const MainView({super.key});

  @override
  ConsumerState<MainView> createState() => _MainViewState();
}

class _MainViewState extends ConsumerState<MainView> {
  late ScrollController _scrollControllerX;
  late ScrollController _scrollControllerY;

  @override
  void initState() {
    super.initState();
    _scrollControllerX = ScrollController(
      initialScrollOffset: ref.read(xScrollProvider),
    );
    _scrollControllerX.addListener(_updateScrollPositionX);
    _scrollControllerY = ScrollController(
      initialScrollOffset: ref.read(yScrollProvider),
    );
    _scrollControllerY.addListener(_updateScrollPositionY);
  }

  @override
  void dispose() {
    _scrollControllerX.removeListener(_updateScrollPositionX);
    _scrollControllerY.removeListener(_updateScrollPositionY);
    _scrollControllerX.dispose();
    _scrollControllerY.dispose();
    super.dispose();
  }

  void _updateScrollPositionX() {
    ref.read(xScrollProvider.notifier).setScroll(_scrollControllerX.offset);
  }

  void _updateScrollPositionY() {
    ref.read(yScrollProvider.notifier).setScroll(_scrollControllerY.offset);
  }

  @override
  Widget build(BuildContext context) {
    final xScroll = ref.watch(xScrollProvider);
    final yScroll = ref.watch(yScrollProvider);
    final timelineData = ref.watch(timelineDataProvider);
    final scale = ref.watch(timelineScaleProvider);

    // Calculate total width based on root folder length and scale
    final totalWidth = timelineData.data.length * scale + 100; // Add padding

    // Update scroll position when xScroll changes from outside
    if (_scrollControllerX.hasClients && _scrollControllerX.offset != xScroll) {
      _scrollControllerX.jumpTo(xScroll);
    }

    // Update scroll position when yScroll changes from outside
    if (_scrollControllerY.hasClients && _scrollControllerY.offset != yScroll) {
      _scrollControllerY.jumpTo(yScroll);
    }

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      padding: const EdgeInsets.only(left: 3),
      child: SingleChildScrollView(
        controller: _scrollControllerX,
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          controller: _scrollControllerY,
          scrollDirection: Axis.vertical,
          child: SizedBox(
            width: totalWidth,
            height:
                timelineData.data.strips.length *
                (30 + 4), // Each track 34px + margin
            child: FolderView(folder: timelineData.data),
          ),
        ),
      ),
    );
  }
}

class FolderView extends ConsumerWidget {
  final Folder folder;

  const FolderView({super.key, required this.folder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        // Conditionally render folder header
        if (folder.name != "Root")
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Row(
              children: [
                Icon(Icons.folder, size: 16),
                const SizedBox(width: 8),
                Text(folder.name),
              ],
            ),
          ),

        // Tracks and strips
        ...folder.strips.asMap().entries.map((entry) {
          int trackIndex = entry.key;
          List<Strip> trackStrips = entry.value;

          return Container(
            height: 30,
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: Stack(
              children: [
                ...trackStrips.map(
                  (strip) => StripWidget(strip: strip, trackIndex: trackIndex),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class StripWidget extends ConsumerWidget {
  final Strip strip;
  final int trackIndex;

  const StripWidget({super.key, required this.strip, required this.trackIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = ref.watch(timelineScaleProvider);
    final selectedStrip = ref.watch(selectedStripProvider);
    final isSelected = selectedStrip == strip;

    // Calculate position based on startFrame and scale
    double left = strip.startFrame * scale;
    double width = strip.length * scale;

    return Positioned(
      left: left,
      top: 0,
      width: width,
      height: 26,
      child: GestureDetector(
        onTap: () {
          ref.read(selectedStripProvider.notifier).state = strip;
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color:
                  isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  strip.source,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
