import 'package:flutter/material.dart';

/// Tells the user what they can do, or that nothing was found.
/// Must be a direct child of a [Stack].
class OcrHint extends StatelessWidget {
  const OcrHint({super.key, required this.noText, required this.visible});

  final bool noText;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 12,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xCC303134),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                noText
                    ? 'No text found in this image'
                    : 'Tap a sentence to translate it',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
