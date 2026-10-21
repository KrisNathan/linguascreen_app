import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:lingua_screen/ocr/page_text.dart';

import 'image_transform.dart';
import 'selection_handles.dart';

enum _Handle { start, end }

/// Turns touches on the canvas into selection changes:
///
/// - a tap picks the unit under it (the owner selects its sentence); a tap on
///   empty space picks nothing.
/// - dragging a selection handle moves that end of the selection, unit by
///   unit, across lines and regions alike.
class SelectionGesture {
  SelectionGesture({
    required this.onPick,
    required this.onAdjust,
    required this.onAdjustEnd,
  });

  /// The unit under the finger, or null.
  final void Function(int? unit) onPick;

  /// The selection while a handle is dragged (unit indices, inclusive).
  final void Function(int start, int end) onAdjust;

  /// A handle was let go.
  final VoidCallback onAdjustEnd;

  /// Kept in sync by the owner whenever the page or selection changes.
  PageText? page;
  int? selStart;
  int? selEnd;

  /// How close (image pixels) a tap must be to a unit.
  static const _unitReach = 12.0;

  /// How close (widget pixels) a drag must start to a handle.
  static const _handleReach = 32.0;

  _Handle? _held;

  bool get isDragging => _held != null;

  /// From the finger to the center of the unit the held handle belongs to,
  /// so that unit doesn't jump to whatever is under the finger.
  Offset _grab = Offset.zero;

  void tap(Offset pos, ImageTransform transform) {
    onPick(page?.nearestUnit(transform.toImage(pos), maxDistance: _unitReach));
  }

  /// Grabs a handle if [pos] is on one; otherwise the drag does nothing.
  void dragStart(Offset pos, ImageTransform transform) {
    final page = this.page;
    final start = selStart;
    final end = selEnd;
    if (page == null || start == null || end == null) return;

    final (startHandle, endHandle) = handleCenters(page, start, end, transform);
    final toStart = (pos - startHandle).distance;
    final toEnd = (pos - endHandle).distance;
    if (min(toStart, toEnd) > _handleReach) return;

    _held = toStart <= toEnd ? _Handle.start : _Handle.end;
    final unit = page.units[_held == _Handle.start ? start : end];
    _grab = transform.rectToWidget(unit.rect).center - pos;
  }

  void dragUpdate(Offset pos, ImageTransform transform) {
    final held = _held;
    final page = this.page;
    var start = selStart;
    var end = selEnd;
    if (held == null || page == null || start == null || end == null) return;

    final unit = page.nearestUnit(
      transform.toImage(pos + _grab),
      maxDistance: double.infinity,
    );
    if (unit == null) return;

    if (held == _Handle.start) {
      start = unit;
    } else {
      end = unit;
    }
    // dragged past the other end: the handles trade places
    if (start > end) {
      (start, end) = (end, start);
      _held = held == _Handle.start ? _Handle.end : _Handle.start;
    }
    if (start == selStart && end == selEnd) return;

    selStart = start;
    selEnd = end;
    onAdjust(start, end);
  }

  void dragEnd() {
    if (_held == null) return;
    _held = null;
    onAdjustEnd();
  }
}
