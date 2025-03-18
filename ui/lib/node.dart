import 'package:flutter/material.dart';

class NodeSection extends StatefulWidget {
  const NodeSection({super.key});

  @override
  State<NodeSection> createState() => _NodeSectionState();
}

class _NodeSectionState extends State<NodeSection> {
  bool _checkBoxValue = false;
  double _sliderValue = 0.5;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[850],
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Text('Configuration', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          CheckboxListTile(
            title: const Text('Check Option'),
            value: _checkBoxValue,
            onChanged: (val) {
              setState(() {
                _checkBoxValue = val ?? false;
              });
            },
          ),
          const SizedBox(height: 16),
          Text('Parameter Slider: ${_sliderValue.toStringAsFixed(2)}'),
          Slider(
            min: 0,
            max: 1,
            value: _sliderValue,
            onChanged: (val) {
              setState(() {
                _sliderValue = val;
              });
            },
          ),
        ],
      ),
    );
  }
}
