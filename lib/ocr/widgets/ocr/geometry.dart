import 'dart:math';

import 'package:flutter/widgets.dart';

/// Ray-casting point-in-polygon test. The polygon is implicitly closed.
bool pointInPolygon(Offset p, List<Offset> polygon) {
  var inside = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final a = polygon[i];
    final b = polygon[j];

    final straddlesRow = (a.dy > p.dy) != (b.dy > p.dy);
    final crossingX = (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx;

    if (straddlesRow && p.dx < crossingX) inside = !inside;
  }
  return inside;
}

/// Shortest distance from [p] to the path made of the segments of [points].
double distanceToPolyline(Offset p, List<Offset> points) {
  var best = double.infinity;

  for (var i = 0; i < points.length - 1; i++) {
    final from = points[i];
    final segment = points[i + 1] - from;
    final lengthSquared = segment.dx * segment.dx + segment.dy * segment.dy;

    // how far along the segment the closest point is (0 = start, 1 = end)
    final along = lengthSquared == 0
        ? 0.0
        : (((p.dx - from.dx) * segment.dx + (p.dy - from.dy) * segment.dy) /
                  lengthSquared)
              .clamp(0.0, 1.0);

    final closest = from + segment * along;
    best = min(best, (p - closest).distance);
  }

  return best;
}
