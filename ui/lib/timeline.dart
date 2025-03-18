import 'package:flutter/material.dart';

class TimelineSection extends StatefulWidget {
  const TimelineSection({super.key});

  @override
  State<TimelineSection> createState() => _TimelineSectionState();
}

class _TimelineSectionState extends State<TimelineSection> {
  // Sample data for strips arranged on the timeline
  List<String> strips = [
    'Image[1...30].tga',
    'Clip001',
    'Clip002',
    'BGM track',
    'SFX track',
  ];

  // Sample folder (directory) structure
  bool folderExpanded = true;

  // Manages the current frame position
  int currentFrame = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.blueGrey[900],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline title section
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Timeline',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          // Current frame display and movement buttons
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_left),
                onPressed: () {
                  setState(() {
                    currentFrame = (currentFrame - 1).clamp(0, 999999);
                  });
                },
              ),
              Text('Frame: $currentFrame'),
              IconButton(
                icon: const Icon(Icons.arrow_right),
                onPressed: () {
                  setState(() {
                    currentFrame++;
                  });
                },
              ),
            ],
          ),
          // Sample folder (hierarchical representation with ExpansionTile)
          ExpansionTile(
            title: const Text('Folder: Scenes'),
            initiallyExpanded: folderExpanded,
            onExpansionChanged: (val) {
              setState(() {
                folderExpanded = val;
              });
            },
            children: [
              Container(
                color: Colors.black54,
                padding: const EdgeInsets.all(8.0),
                child: const Text('Scene_01 content is expected to be here'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 8),
          // Arrange strips with ReorderableListView
          Expanded(
            // Note: ReorderableListView requires a scrollable area,
            // so wrap it as ListView.builder or use shrinkWrap:true, etc.
            child: ReorderableListView.builder(
              itemCount: strips.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }
                  final item = strips.removeAt(oldIndex);
                  strips.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final strip = strips[index];
                return ListTile(
                  key: ValueKey(strip),
                  title: Text(strip),
                  leading: const Icon(Icons.drag_indicator),
                  tileColor: index.isEven ? Colors.grey[800] : Colors.grey[700],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
