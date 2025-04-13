import 'package:flutter/material.dart';
import 'bar.dart';
import 'mainview.dart';

class Timeline extends StatelessWidget {
  const Timeline({super.key});

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
      child: Stack(
        children: [
          // Top header bar
          Positioned(top: 0, left: 0, right: 0, height: 25, child: Bar()),

          // Left sidebar area (empty space)
          Positioned(
            top: 25,
            left: 0,
            width: 36,
            bottom: 0,
            child: Container(color: Theme.of(context).colorScheme.surface),
          ),

          // Main timeline view
          Positioned(top: 25, left: 34, right: 0, bottom: 0, child: MainView()),
        ],
      ),
    );
  }
}
