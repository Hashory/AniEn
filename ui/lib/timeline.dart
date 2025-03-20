import 'package:flutter/material.dart';

class TimelineSection extends StatefulWidget {
  final Map<String, dynamic> timelineData;

  const TimelineSection({super.key, required this.timelineData});

  @override
  State<TimelineSection> createState() => _TimelineSectionState();
}

class _TimelineSectionState extends State<TimelineSection> {
  // Manages the current frame position
  int currentFrame = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Text('Current Frame: $currentFrame'),
          Slider(
            min: widget.timelineData["timeline"]["start"].toDouble(),
            max: widget.timelineData["timeline"]["length"].toDouble(),
            value: currentFrame.toDouble(),
            onChanged: (value) {
              setState(() {
                currentFrame = value.toInt();
              });
            },
          ),
        ],
      ),
    );
  }
}
