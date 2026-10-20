import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:lingua_screen/ocr/page_text.dart';

import 'ocr/image_transform.dart';
import 'ocr/ocr_overlays.dart';
import 'ocr/ocr_painter.dart';
import 'ocr/selection_gesture.dart';

/// Shows an image with its recognized sentences outlined on top and lets the
/// user pick one.
///
/// The canvas only reports the unit under a tap through [onPick]; the parent
/// selects the sentence it belongs to and passes it back as [selStart] and
/// [selEnd] (unit indices, inclusive).
class OCRCanvas extends StatefulWidget {
  final ui.Image image;
  final PageText? page;
  final int? selStart;
  final int? selEnd;

  /// The unit under the tap, or null for a tap on empty space.
  final void Function(int? unit) onPick;

  const OCRCanvas({
    super.key,
    required this.image,
    this.page,
    this.selStart,
    this.selEnd,
    required this.onPick,
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
  );

  /// One rect per line of every sentence. Cached: it only changes with the
  /// page.
  List<Rect> _sentenceRects = [];

  @override
  void initState() {
    super.initState();
    _gesture.page = widget.page;
    _onPageChanged();
  }

  @override
  void didUpdateWidget(OCRCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    _gesture.page = widget.page;
    if (oldWidget.page != widget.page) _onPageChanged();
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
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

        return GestureDetector(
          onTapUp: (d) => _gesture.tap(d.localPosition, transform),
          child: Stack(
            fit: StackFit.expand,
            children: [
              RawImage(image: widget.image, fit: BoxFit.contain),
              ..._overlays(),
            ],
          ),
        );
      },
    );
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
