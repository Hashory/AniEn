class Strip {
  final String source;
  final int startFrame;
  final int length;

  Strip({required this.source, required this.startFrame, required this.length});
}

class Folder {
  final String name;
  final int startFrame;
  final int length;
  final List<List<Strip>> strips;

  Folder({
    required this.name,
    required this.startFrame,
    required this.length,
    this.strips = const [],
  });
}

// Data for the entire timeline (example)
class TimelineData {
  // properties
  double frameRate;

  // data
  Folder data = Folder(
    name: "Root",
    startFrame: 0,
    length: 1000,
    strips: [
      [
        Strip(source: "source1", startFrame: 0, length: 100),
        Strip(source: "source2", startFrame: 101, length: 150),
      ],
      [
        Strip(source: "source3", startFrame: 200, length: 50),
        Strip(source: "source4", startFrame: 300, length: 100),
      ],
    ],
  );

  TimelineData({this.frameRate = 24.0});
}
