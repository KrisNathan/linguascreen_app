import 'dart:ui';

import 'package:lingua_screen/models/ocr_word.dart';

class OcrLine {
  final String text;
  final List<Offset> polygon;
  final List<OcrWord> words;
  bool isSelected;
  OcrLine({
    required this.text,
    required this.polygon,
    required this.words,
    this.isSelected = false,
  });
  Rect get boundingBox {
    final left = polygon.map((p) => p.dx).reduce((a, b) => a < b ? a : b);
    final top = polygon.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
    final right = polygon.map((p) => p.dx).reduce((a, b) => a > b ? a : b);
    final bottom = polygon.map((p) => p.dy).reduce((a, b) => a > b ? a : b);
    return Rect.fromLTRB(left, top, right, bottom);
  }
  factory OcrLine.fromJson(Map<String, dynamic> json) {
    return OcrLine(
      text: json['text'] ?? '',
      polygon: (json['boundingPolygon'] as List)
          .map((point) =>
              Offset(point['x'].toDouble(), point['y'].toDouble()))
          .toList(),
      words: (json['words'] as List)
          .map((word) => OcrWord.fromJson(word))
          .toList(),
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'bounding_polygon': polygon // snake_case used for python backend
          .map((point) => {'x': point.dx, 'y': point.dy})
          .toList(),
      'words': words.map((word) => word.toJson()).toList(),
    };
  }
}