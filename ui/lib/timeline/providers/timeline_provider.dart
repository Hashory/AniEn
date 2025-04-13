import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data_models.dart';

// X-axis scroll position provider
class XScrollNotifier extends StateNotifier<double> {
  XScrollNotifier() : super(0.0);

  void setScroll(double position) {
    state = position;
  }
}

final xScrollProvider = StateNotifierProvider<XScrollNotifier, double>((ref) {
  return XScrollNotifier();
});

// Y-axis scroll position provider
class YScrollNotifier extends StateNotifier<double> {
  YScrollNotifier() : super(0.0);

  void setScroll(double position) {
    state = position;
  }
}

final yScrollProvider = StateNotifierProvider<YScrollNotifier, double>((ref) {
  return YScrollNotifier();
});

// Timeline data provider
final timelineDataProvider = StateProvider<TimelineData>((ref) {
  return TimelineData();
});

// Scale factor for timeline (pixels per frame)
final timelineScaleProvider = StateProvider<double>((ref) {
  return 2.0; // Default scale: 2 pixels per frame
});

// Selected strip provider
final selectedStripProvider = StateProvider<Strip?>((ref) {
  return null;
});
