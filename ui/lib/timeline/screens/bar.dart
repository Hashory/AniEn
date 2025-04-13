import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/timeline_provider.dart';

class Bar extends ConsumerStatefulWidget {
  const Bar({super.key});

  @override
  ConsumerState<Bar> createState() => _BarState();
}

class _BarState extends ConsumerState<Bar> {
  final TransformationController _transformationController =
      TransformationController();

  bool _isUpdatingFromExternal = false;

  void _onTransformationChange() {
    if (_isUpdatingFromExternal) return;

    // Only allow horizontal scaling (x-axis)
    final matrix = _transformationController.value;
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

    // Update the global xScroll position
    final newXScroll = -matrix.getTranslation().x;
    ref.read(xScrollProvider.notifier).setScroll(newXScroll);
  }

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_onTransformationChange);
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformationChange);
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final xScroll = ref.watch(xScrollProvider);

    // Sync with global xScroll position
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentTranslation =
          _transformationController.value.getTranslation();
      final currentXScroll = -currentTranslation.x;

      if (currentXScroll != xScroll) {
        _isUpdatingFromExternal = true;
        final matrix = Matrix4.identity();
        matrix.setEntry(0, 3, -xScroll); // Set X translation
        _transformationController.value = matrix;
        _isUpdatingFromExternal = false;
      }
    });

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
          child: Container(
            padding: const EdgeInsets.only(left: 3),
            height: double.infinity,
            width: double.infinity,
            child: InteractiveViewer(
              transformationController: _transformationController,
              boundaryMargin: const EdgeInsets.all(0),
              minScale: 1.0,
              maxScale: 1.0,
              constrained: false,
              panAxis: PanAxis.horizontal,
              child: Row(
                children: List.generate(100, (index) {
                  final isFive = (index + 1) % 5 == 0;
                  return SizedBox(
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
