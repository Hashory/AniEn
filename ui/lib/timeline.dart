import 'package:flutter/material.dart';

class TimelineSection extends StatelessWidget {
  final Map<String, dynamic> timelineData;

  const TimelineSection({super.key, required this.timelineData});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 25,
            width: double.infinity,
            child: TimelineFrameBar(),
          ),
          Expanded(
            child: Row(
              children: [
                SizedBox(width: 29, height: double.infinity),
                Expanded(child: TimelineMainView(timelineData: timelineData)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TimelineFrameBar extends StatefulWidget {
  const TimelineFrameBar({super.key});

  @override
  State<TimelineFrameBar> createState() => _TimelineFrameBarState();
}

class _TimelineFrameBarState extends State<TimelineFrameBar> {
  late TransformationController _transformationController;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _transformationController.addListener(_onTransformationChange);
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformationChange);
    _transformationController.dispose();
    super.dispose();
  }

  void _onTransformationChange() {
    final Matrix4 matrix = _transformationController.value;
    // Only allow horizontal scaling (x-axis)
    // Extract the scale values
    final double scaleX = matrix.getMaxScaleOnAxis();

    // Create a new matrix that only scales horizontally
    final Matrix4 newMatrix =
        Matrix4.identity()
          ..setEntry(0, 0, scaleX) // Scale X
          ..setEntry(1, 1, 1.0) // Keep Y scale at 1.0
          ..setEntry(0, 3, matrix.getTranslation().x) // Keep X translation
          ..setEntry(1, 3, 0.0); // Reset Y translation

    if (matrix != newMatrix) {
      _transformationController.value = newMatrix;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 29,
          height: 25,
          child: IconButton(
            color: Theme.of(context).colorScheme.secondaryContainer,
            iconSize: 20,
            padding: EdgeInsets.zero,
            onPressed: () {
              print("Button pressed");
            },
            icon: Icon(
              Icons.menu,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ),
        ),
        Expanded(
          child: SizedBox(
            height: double.infinity,
            width: double.infinity,
            child: InteractiveViewer(
              transformationController: _transformationController,
              boundaryMargin: EdgeInsets.all(0),
              minScale: 1.0,
              maxScale: 1.0,
              constrained: false,
              panAxis: PanAxis.horizontal,
              child: Row(
                children: List.generate(100, (index) {
                  final isFive = (index + 1) % 5 == 0;
                  return Container(
                    width: 40,
                    height: 25,
                    child: Container(
                      width: 2,
                      height: 6,
                      color: Theme.of(context).colorScheme.onSurface,
                      margin: EdgeInsets.only(
                        left: 19,
                        right: 19,
                        top: isFive ? 15 : 20,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class TimelineMainView extends StatefulWidget {
  final Map<String, dynamic> timelineData;

  const TimelineMainView({super.key, required this.timelineData});

  @override
  State<TimelineMainView> createState() => _TimelineMainViewState();
}

class _TimelineMainViewState extends State<TimelineMainView> {
  late final Map<String, dynamic> timeline;
  late TransformationController _transformationController;

  @override
  void initState() {
    super.initState();
    timeline = widget.timelineData["timeline"];
    _transformationController = TransformationController();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: InteractiveViewer(
        transformationController: _transformationController,
        boundaryMargin: const EdgeInsets.all(0),
        minScale: 1.0,
        maxScale: 5.0,
        constrained: false,
        child: _buildFolder(context, timeline, isRoot: true),
      ),
    );
  }

  Widget _buildTracks(BuildContext context, List<dynamic> tracks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var track in tracks)
          _buildTrack(context, track, tracks.indexOf(track)),
      ],
    );
  }

  Widget _buildTrack(
    BuildContext context,
    Map<String, dynamic> track,
    int trackIndex,
  ) {
    return Container(
      width: 4000, // Large enough width to accommodate clips
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      margin: const EdgeInsets.only(top: 4),
      child: Container(
        child: Row(
          children: [
            if (track["clips"] != null)
              for (var clip in track["clips"]) _buildClip(context, clip),
          ],
        ),
      ),
    );
  }

  Widget _buildClip(BuildContext context, Map<String, dynamic> clip) {
    // Calculate position based on start and length
    double startPosition = (clip["start"] ?? 0) * 40.0;
    double clipLength = (clip["length"] ?? 1) * 40.0;

    return Positioned(
      left: startPosition,
      top: 2,
      height: 57, // 61 - 4
      width: clipLength,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(7),
        ),
        child:
            clip["role"] == "folder"
                ? _buildFolder(context, clip)
                : _buildRegularClip(context, clip),
      ),
    );
  }

  Widget _buildRegularClip(BuildContext context, Map<String, dynamic> clip) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            clip["source"] ?? "Unnamed Clip",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            "Start: ${clip['start']}, Length: ${clip['length']}",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolder(
    BuildContext context,
    Map<String, dynamic> folder, {
    bool isRoot = false,
  }) {
    if (isRoot) {
      // Root folder just contains tracks directly
      return _buildTracks(context, folder["tracks"] ?? []);
    }

    // Non-root folders have a header and contain tracks
    return Column(
      children: [
        // Folder header
        Container(
          width: double.infinity,
          height: 25,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
          ),
          alignment: Alignment.centerLeft,
          child: Text(
            folder["name"] ?? "Unnamed Folder",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onTertiaryContainer,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // Folder content (tracks)
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(7),
              ),
            ),
            child:
                folder["tracks"] != null && folder["tracks"].isNotEmpty
                    ? _buildTracks(context, folder["tracks"])
                    : const Center(child: Text("Empty folder")),
          ),
        ),
      ],
    );
  }
}
