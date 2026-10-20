import 'package:flutter/widgets.dart';

/// Converts between the two coordinate spaces the canvas deals with:
///
/// - **image space**: pixels of the picture. OCR boxes live here.
/// - **widget space**: pixels on screen. Touches and drawing live here.
///
/// The picture is shown with [BoxFit.contain], so it may be letterboxed:
/// [dest] is where it actually sits inside the widget, and [scale] is how many
/// widget pixels one image pixel takes.
class ImageTransform {
  final Rect dest;
  final double scale;

  const ImageTransform._(this.dest, this.scale);

  factory ImageTransform(Size imageSize, Size widgetSize) {
    final fitted = applyBoxFit(BoxFit.contain, imageSize, widgetSize);
    final dest = Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & widgetSize,
    );

    return ImageTransform._(dest, dest.width / imageSize.width);
  }

  Offset toImage(Offset widgetPoint) => Offset(
    (widgetPoint.dx - dest.left) / scale,
    (widgetPoint.dy - dest.top) / scale,
  );

  Offset toWidget(Offset imagePoint) => Offset(
    dest.left + imagePoint.dx * scale,
    dest.top + imagePoint.dy * scale,
  );

  Rect rectToWidget(Rect imageRect) => Rect.fromLTWH(
    dest.left + imageRect.left * scale,
    dest.top + imageRect.top * scale,
    imageRect.width * scale,
    imageRect.height * scale,
  );
}
