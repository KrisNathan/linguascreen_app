import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:lingua_screen/ocr/page_text.dart';

import 'ocr/image_transform.dart';
import 'ocr/ocr_overlays.dart';
import 'ocr/ocr_painter.dart';
import 'ocr/selection_gesture.dart';

/// Shows an image with its recognized sentences outlined on top and lets the
/// user pick one, then adjust it with the selection handles.
///
/// The canvas only reports the unit under a tap through [onPick]; the parent
/// selects the sentence it belongs to and passes it back as [selStart] and
/// [selEnd] (unit indices, inclusive). Handle drags are reported through
/// [onAdjust] as they happen and [onAdjustEnd] when let go.
///
/// When something covers the bottom of the canvas ([coveredFraction]), the
/// image slides up as far as needed to keep the selection in view.
class OCRCanvas extends StatefulWidget {
  final ui.Image image;
  final PageText? page;
  final int? selStart;
  final int? selEnd;

  /// The unit under the tap, or null for a tap on empty space.
  final void Function(int? unit) onPick;

  final void Function(int start, int end) onAdjust;
  final VoidCallback onAdjustEnd;

  /// How much of the canvas height (0..1) is covered from the bottom, e.g.
  /// by a sheet.
  final double coveredFraction;

  const OCRCanvas({
    super.key,
    required this.image,
    this.page,
    this.selStart,
    this.selEnd,
    required this.onPick,
    required this.onAdjust,
    required this.onAdjustEnd,
    this.coveredFraction = 0,
  });

  @override
  State<OCRCanvas> createState() => _OCRCanvasState();
}

class _OCRCanvasState extends State<OCRCanvas>
    with SingleTickerProviderStateMixin {
  /// Fades the sentence outlines in when a page appears.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  late final SelectionGesture _gesture = SelectionGesture(
    onPick: (unit) => widget.onPick(unit),
    onAdjust: (start, end) => widget.onAdjust(start, end),
    onAdjustEnd: () => widget.onAdjustEnd(),
  );

  /// One rect per line of every sentence. Cached: it only changes with the
  /// page.
  List<Rect> _sentenceRects = [];

  /// How far (widget pixels) the image is slid up.
  double _lift = 0;

  /// Room kept between the selection and the covered edge, including the
  /// handles hanging below the text.
  static const _liftMargin = 32.0;

  @override
  void initState() {
    super.initState();
    _syncGesture();
    _onPageChanged();
  }

  @override
  void didUpdateWidget(OCRCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncGesture();
    if (oldWidget.page != widget.page) _onPageChanged();
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  void _syncGesture() {
    _gesture
      ..page = widget.page
      ..selStart = widget.selStart
      ..selEnd = widget.selEnd;
  }

  void _onPageChanged() {
    final page = widget.page;
    _sentenceRects = [
      if (page != null)
        for (final (first, last) in page.sentenceUnitSpans())
          ...page.rectsFor(first, last),
    ];
    _intro.forward(from: 0);
  }

  Size get _imageSize =>
      Size(widget.image.width.toDouble(), widget.image.height.toDouble());

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final transform = ImageTransform(_imageSize, constraints.biggest);
        // Kept still while a handle is dragged, so the text doesn't move
        // under the finger.
        if (!_gesture.isDragging) {
          _lift = _liftFor(transform, constraints.maxHeight);
        }

        final canvas = GestureDetector(
          onTapUp: (d) => _gesture.tap(d.localPosition, transform),
          onPanStart: (d) => _gesture.dragStart(d.localPosition, transform),
          onPanUpdate: (d) => _gesture.dragUpdate(d.localPosition, transform),
          onPanEnd: (_) => _gesture.dragEnd(),
          onPanCancel: _gesture.dragEnd,
          child: Stack(
            fit: StackFit.expand,
            children: [
              RawImage(image: widget.image, fit: BoxFit.contain),
              ..._overlays(),
            ],
          ),
        );

        return ClipRect(
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: _lift),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            builder: (context, lift, child) =>
                Transform.translate(offset: Offset(0, -lift), child: child),
            child: canvas,
          ),
        );
      },
    );
  }

  /// How far to slide the image up so the selection clears the covered
  /// bottom, without pushing the selection's top out of view.
  double _liftFor(ImageTransform transform, double height) {
    final page = widget.page;
    final start = widget.selStart;
    final end = widget.selEnd;
    if (page == null || start == null || end == null) return 0;

    final selection = page
        .rectsFor(start, end)
        .map(transform.rectToWidget)
        .reduce((a, b) => a.expandToInclude(b));
    final visibleBottom = height * (1 - widget.coveredFraction);

    final needed = selection.bottom + _liftMargin - visibleBottom;
    final allowed = selection.top - _liftMargin;
    return needed.clamp(0.0, max(0.0, allowed));
  }

  /// Everything drawn or shown on top of the image.
  List<Widget> _overlays() {
    final page = widget.page;
    final hasText = page != null && page.units.isNotEmpty;

    return [
      if (page != null)
        CustomPaint(
          painter: OcrPainter(
            page: page,
            imageSize: _imageSize,
            sentenceRects: _sentenceRects,
            intro: _intro,
            selStart: widget.selStart,
            selEnd: widget.selEnd,
          ),
        ),
      OcrHint(noText: !hasText, visible: !hasText || widget.selStart == null),
    ];
  }
}
