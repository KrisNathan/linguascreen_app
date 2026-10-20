import 'package:flutter/widgets.dart';
import 'package:lingua_screen/ocr/page_text.dart';

import 'image_transform.dart';

/// Turns taps on the canvas into picked units. The owner selects the
/// sentence the unit is in; a tap on empty space picks nothing.
class SelectionGesture {
  SelectionGesture({required this.onPick});

  /// The unit under the finger, or null.
  final void Function(int? unit) onPick;

  /// Kept in sync by the owner whenever the page changes.
  PageText? page;

  /// How close (image pixels) a tap must be to a unit.
  static const _unitReach = 12.0;

  void tap(Offset pos, ImageTransform transform) {
    onPick(page?.nearestUnit(transform.toImage(pos), maxDistance: _unitReach));
  }
}
