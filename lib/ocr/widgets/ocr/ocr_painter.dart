import 'package:flutter/material.dart';
import 'package:lingua_screen/ocr/page_text.dart';

import 'image_transform.dart';

const _accent = Color(0xFF4285F4);

/// Draws everything on top of the image, back to front:
/// sentence outlines, then the selected sentence.
class OcrPainter extends CustomPainter {
  final PageText page;
  final Size imageSize;
  final int? selStart;
  final int? selEnd;

  /// One rect per line of every sentence, in image pixels.
  final List<Rect> sentenceRects;

  /// 0 -> 1 when a page appears; fades the sentence outlines in.
  final Animation<double> intro;

  OcrPainter({
    required this.page,
    required this.imageSize,
    required this.sentenceRects,
    required this.intro,
    this.selStart,
    this.selEnd,
  }) : super(repaint: intro);

  /// Developer aid: outline every single unit in red.
  static const showUnitBoxes = false;

  @override
  void paint(Canvas canvas, Size size) {
    final transform = ImageTransform(imageSize, size);

    _paintSentenceOutlines(canvas, transform);
    if (showUnitBoxes) _paintUnitBoxes(canvas, transform);

    final start = selStart;
    final end = selEnd;
    if (start != null && end != null) {
      _paintSelection(canvas, transform, start, end);
    }
  }

  /// A soft outline around every sentence, so it is clear what a tap
  /// selects.
  void _paintSentenceOutlines(Canvas canvas, ImageTransform transform) {
    final progress = Curves.easeOut.transform(intro.value);
    if (progress <= 0) return;

    final fill = Paint()..color = _accent.withValues(alpha: 0.10 * progress);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = _accent.withValues(alpha: 0.55 * progress);

    for (final rect in sentenceRects) {
      final rounded = _rounded(transform, rect, inflate: 3, radius: 6);
      canvas.drawRRect(rounded, fill);
      canvas.drawRRect(rounded, edge);
    }
  }

  void _paintUnitBoxes(Canvas canvas, ImageTransform transform) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.red;

    for (final unit in page.units) {
      canvas.drawRect(transform.rectToWidget(unit.rect), paint);
    }
  }

  void _paintSelection(Canvas canvas, ImageTransform t, int start, int end) {
    final paint = Paint()..color = _accent.withValues(alpha: 0.4);

    for (final rect in page.rectsFor(start, end)) {
      canvas.drawRRect(_rounded(t, rect, inflate: 2, radius: 8), paint);
    }
  }

  RRect _rounded(
    ImageTransform transform,
    Rect imageRect, {
    required double inflate,
    required double radius,
  }) {
    return RRect.fromRectAndRadius(
      transform.rectToWidget(imageRect).inflate(inflate),
      Radius.circular(radius),
    );
  }

  @override
  bool shouldRepaint(covariant OcrPainter old) {
    return old.page != page ||
        old.imageSize != imageSize ||
        old.selStart != selStart ||
        old.selEnd != selEnd ||
        old.sentenceRects != sentenceRects;
  }
}
