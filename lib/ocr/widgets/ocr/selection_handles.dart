import 'package:flutter/widgets.dart';
import 'package:lingua_screen/ocr/page_text.dart';

import 'image_transform.dart';

/// Centers of the two selection handles, in widget coordinates.
///
/// - Horizontal text: the start handle sits below the first unit's left edge,
///   the end handle below the last unit's right edge.
/// - Vertical text: the start handle sits right of the first unit's top, the
///   end handle left of the last unit's bottom.
(Offset, Offset) handleCenters(
  PageText page,
  int start,
  int end,
  ImageTransform transform,
) {
  final first = page.units[start];
  final startRect = transform.rectToWidget(first.rect);
  final endRect = transform.rectToWidget(page.units[end].rect);

  if (first.isVertical) {
    return (
      startRect.topRight + const Offset(10, -2),
      endRect.bottomLeft + const Offset(-10, 2),
    );
  }
  return (
    startRect.bottomLeft + const Offset(-2, 10),
    endRect.bottomRight + const Offset(2, 10),
  );
}
