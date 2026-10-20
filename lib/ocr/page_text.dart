import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lingua_screen/ocr/script_rules.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class PageText {
  final String text;
  final List<Unit> units;
  final ScriptRules scriptRules;

  const PageText({
    required this.text,
    required this.units,
    required this.scriptRules,
  });

  int? nearestUnit(Offset p, {double maxDistance = 12}) {
    int? best;
    var bestDist = double.infinity;
    for (var i = 0; i < units.length; i++) {
      final rect = units[i].rect;
      final dx = max(0.0, max(rect.left - p.dx, p.dx - rect.right));
      final dy = max(0.0, max(rect.top - p.dy, p.dy - rect.bottom));
      final d = sqrt(dx * dx + dy * dy);
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }

    return bestDist <= maxDistance ? best : null;
  }

  List<Rect> rectsFor(int firstUnit, int lastUnit) {
    final byLine = <int, Rect>{};

    for (final unit in units.sublist(firstUnit, lastUnit + 1)) {
      if (byLine.containsKey(unit.lineIdx)) {
        byLine[unit.lineIdx] = byLine[unit.lineIdx]!.expandToInclude(unit.rect);
      } else {
        byLine[unit.lineIdx] = unit.rect;
      }
    }

    return byLine.values.toList();
  }

  String textFor(int first, int last) {
    final a = units[first];
    final b = units[last];
    return text.substring(a.offset, b.offset + b.char.length);
  }

  (int, int) sentenceSpan(int firstUnit, int lastUnit) {
    final (start, _) = scriptRules.sentenceRange(text, units[firstUnit].offset);
    final (_, end) = scriptRules.sentenceRange(text, units[lastUnit].offset);

    return (start, end);
  }

  /// Like [sentenceSpan], but as inclusive unit indices (usable with [rectsFor]).
  (int, int) sentenceUnitSpan(int firstUnit, int lastUnit) {
    final (start, end) = sentenceSpan(firstUnit, lastUnit);
    var first = firstUnit;
    var last = lastUnit;
    while (first > 0 && units[first - 1].offset >= start) {
      first--;
    }
    while (last < units.length - 1 && units[last + 1].offset < end) {
      last++;
    }
    return (first, last);
  }

  /// Every sentence of the page in reading order, as inclusive unit indices.
  List<(int, int)> sentenceUnitSpans() {
    final spans = <(int, int)>[];
    var unit = 0;
    while (unit < units.length) {
      final span = sentenceUnitSpan(unit, unit);
      spans.add(span);
      unit = max(span.$2, unit) + 1;
    }
    return spans;
  }

  String sentenceFor(int firstUnit, int lastUnit) {
    final (start, end) = sentenceSpan(firstUnit, lastUnit);
    return text.substring(start, end);
  }
}

class PageTextBuilder {
  final _buf = StringBuffer();
  final _units = <Unit>[];
  String? _last; // last char written
  int _lineIdx = -1;
  bool _vertical = false; // orientation of the region being added

  final ScriptRules scriptRules;

  PageTextBuilder({required this.scriptRules});

  // '\n' between regions (not after the last one)
  void addRegion(Region region) {
    _vertical = region.isVertical;

    if (_buf.isNotEmpty) {
      _buf.write('\n');
      _last = null; // nothing precedes the first element of a new region
    }

    for (final line in region.lines) {
      _lineIdx++;
      _addLine(line);
    }
  }

  // paragraph gap
  void _addLine(TextLine line) {
    for (final el in line.elements) {
      _addElement(el);
    }
  }

  // space check
  void _addElement(TextElement element) {
    if (element.text.isEmpty) return;
    if (_last != null && scriptRules.needsSpace) {
      _buf.write(' ');
    }

    if (element.symbols.isEmpty) {
      // iOS has no symbols: the whole element is the smallest unit
      _addUnit(element.text, element.boundingBox);
      return;
    }

    for (final symbol in element.symbols) {
      _addUnit(symbol.text, symbol.boundingBox);
    }
  }

  void _addUnit(String text, Rect rect) {
    // offset is read BEFORE writing, so it points at this char's own position.
    _units.add(
      Unit(
        char: text,
        rect: rect,
        offset: _buf.length,
        lineIdx: _lineIdx,
        isVertical: _vertical,
      ),
    );
    _buf.write(text);
    _last = text;
  }

  PageText build() {
    return PageText(
      text: _buf.toString(),
      units: _units,
      scriptRules: scriptRules,
    );
  }
}

class ReadingAxes {
  final bool isVertical;

  /// Only matters when [isVertical]. Comes from ScriptRules.
  final bool verticalRightToLeft;

  const ReadingAxes({
    required this.isVertical,
    required this.verticalRightToLeft,
  });

  // "cross" runs across lines (right-to-left columns, or top-to-bottom rows),
  // "along" runs inside a line.
  double cross(Rect r) {
    if (!isVertical) return r.center.dy;
    return verticalRightToLeft ? -r.center.dx : r.center.dx;
  }

  double along(Rect r) => isVertical ? r.center.dy : r.center.dx;
}

class Region {
  List<TextLine> lines;
  ReadingAxes readingAxes;
  bool isVertical;
  double medianThickness;

  Region({
    required this.lines,
    required this.isVertical,
    required this.readingAxes,
    required this.medianThickness,
  });

  /// Smallest rectangle containing every line of this region.
  Rect get bounds =>
      lines.map((l) => l.boundingBox).reduce((a, b) => a.expandToInclude(b));

  static double getGap(Rect a, Rect b) {
    final dx = max(
      0.0,
      max(
        a.left - b.right, // b a
        b.left - a.right, // a b
      ),
    );
    final dy = max(
      0.0,
      max(
        a.top - b.bottom, // a below of b
        b.top - a.bottom, // b below of a
      ),
    );
    return sqrt(dx * dx + dy * dy);
  }

  static bool getIsVertical(List<TextLine> lines) {
    var verticalCount = 0;
    var horizontalCount = 0;

    for (final line in lines) {
      if (line.text.length < 2) continue; // 1 char only can't tell.

      final box = line.boundingBox;
      if (box.height > box.width) {
        verticalCount++;
      } else {
        horizontalCount++;
      }
    }

    return verticalCount > horizontalCount;
  }

  static List<Region> groupLines(
    List<TextLine> lines,
    double medianThickness,
    ScriptRules rules,
  ) {
    final threshold = medianThickness * 1;

    List<int> lineGroupIds = lines.indexed.map((pair) => pair.$1).toList();
    HashMap<int, List<TextLine>> groups = HashMap();
    groups.addEntries(
      lines.indexed.map((pair) => MapEntry(pair.$1, [pair.$2])),
    );

    for (var aId = 0; aId < lines.length; aId++) {
      for (var bId = aId + 1; bId < lines.length; bId++) {
        var isSameGroup = lineGroupIds[aId] == lineGroupIds[bId];
        if (isSameGroup) {
          continue;
        }

        var a = lines[aId];
        var b = lines[bId];

        if (getGap(a.boundingBox, b.boundingBox) < threshold) {
          int from = lineGroupIds[bId];
          int to = lineGroupIds[aId];

          for (var i = 0; i < lineGroupIds.length; i++) {
            if (lineGroupIds[i] == from) lineGroupIds[i] = to;
          }

          groups[to] = [...groups[to]!, ...groups[from]!];
          groups.remove(from);
        }
      }
    }

    List<Region> regions = groups.values.map((lines) {
      // scripts that are never written vertically skip the vote entirely
      bool isVertical = rules.canBeVertical && getIsVertical(lines);

      return Region(
        lines: lines,
        isVertical: isVertical,
        readingAxes: ReadingAxes(
          isVertical: isVertical,
          verticalRightToLeft: rules.verticalColumnsRightToLeft,
        ),
        medianThickness: medianThickness,
      );
    }).toList();

    return regions;
  }

  void orderLines() {
    lines.sort(
      (a, b) => readingAxes
          .cross(a.boundingBox)
          .compareTo(readingAxes.cross(b.boundingBox)),
    );

    final List<List<TextLine>> groupsOfLines =
        []; // lines on same/similar cross
    double crossDelta(TextLine a, TextLine b) =>
        (readingAxes.cross(a.boundingBox) - readingAxes.cross(b.boundingBox))
            .abs();

    for (final line in lines) {
      if (groupsOfLines.isNotEmpty &&
          crossDelta(line, groupsOfLines.last.first) < medianThickness * 0.5) {
        groupsOfLines.last.add(line);
      } else {
        groupsOfLines.add([line]);
      }
    }

    for (final group in groupsOfLines) {
      group.sort(
        (a, b) => readingAxes
            .along(a.boundingBox)
            .compareTo(readingAxes.along(b.boundingBox)),
      );
    }

    lines = [for (final group in groupsOfLines) ...group];
  }
}

class Unit {
  final String char;
  final Rect rect;
  final int offset;
  final int lineIdx;
  final bool isVertical;

  const Unit({
    required this.char,
    required this.rect,
    required this.offset,
    required this.lineIdx,
    required this.isVertical,
  });
}

class PageTextFactory {
  double _getMedianThickness(List<TextLine> lines) {
    // hopefully theres no single char line/blocks!
    double getThickness(TextLine line) =>
        min(line.boundingBox.width, line.boundingBox.height);

    final thicknesses = lines.map(getThickness).toList()..sort();
    return thicknesses[thicknesses.length ~/ 2];
  }

  /// Reading order of whole regions, using page coordinates:
  /// - stacked regions (little vertical overlap): top one first
  /// - side by side (more than half overlapping vertically): right-to-left if
  ///   both are vertical text, otherwise left-to-right
  List<Region> _orderRegions(List<Region> regions, ScriptRules rules) {
    return [...regions]..sort((a, b) {
      final ra = a.bounds;
      final rb = b.bounds;

      final yOverlap = min(ra.bottom, rb.bottom) - max(ra.top, rb.top);
      final sideBySide = yOverlap > min(ra.height, rb.height) * 0.5;

      if (!sideBySide) return ra.top.compareTo(rb.top);

      final rightToLeft =
          rules.verticalColumnsRightToLeft && a.isVertical && b.isVertical;

      return rightToLeft
          ? rb.right.compareTo(ra.right)
          : ra.left.compareTo(rb.left);
    });
  }

  PageText? build(RecognizedText recognizedText, ScriptRules rules) {
    final List<TextLine> lines = [
      for (final block in recognizedText.blocks) ...block.lines,
    ];
    if (lines.isEmpty) return null;

    double medianThickness = _getMedianThickness(lines);

    List<Region> regions = Region.groupLines(lines, medianThickness, rules);
    for (final region in regions) {
      region.orderLines(); // lines inside each region
    }
    List<Region> orderedRegions = _orderRegions(regions, rules); // the regions
    final builder = PageTextBuilder(scriptRules: rules);
    for (final region in orderedRegions) {
      builder.addRegion(region);
    }

    return builder.build();
  }
}
