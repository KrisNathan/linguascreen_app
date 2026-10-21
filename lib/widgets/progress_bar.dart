import 'package:flutter/material.dart';

/// A rounded [LinearProgressIndicator] that eases to each new [value].
class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => LinearProgressIndicator(
        value: v,
        minHeight: 6,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
