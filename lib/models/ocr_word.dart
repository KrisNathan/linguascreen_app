import 'dart:ui';

class OcrWord {
  final String text;
  final List<Offset> polygon;
  bool isSelected;

  OcrWord({
    required this.text,
    required this.polygon,
    this.isSelected = false,
  });

  Rect get boundingBox {
    final left = polygon.map((p) => p.dx).reduce((a, b) => a < b ? a : b);
    final top = polygon.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
    final right = polygon.map((p) => p.dx).reduce((a, b) => a > b ? a : b);
    final bottom = polygon.map((p) => p.dy).reduce((a, b) => a > b ? a : b);
    return Rect.fromLTRB(left, top, right, bottom);
  }

  factory OcrWord.fromJson(Map<String, dynamic> json) {
    return OcrWord(
      text: json['text'] ?? '',
      polygon: (json['boundingPolygon'] as List)
          .map((point) =>
              Offset(point['x'].toDouble(), point['y'].toDouble()))
          .toList(),
    );
  }
}
