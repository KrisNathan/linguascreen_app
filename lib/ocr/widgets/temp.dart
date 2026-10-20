import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

enum _Drag { none, lasso, start, end }

class _HomePageState extends State<HomePage> {
  File? _selectedImage;
  String _result = "";
  TextRecognitionScript _script = TextRecognitionScript.latin;

  RecognizedText? _recognized;
  Size? _imageSize;
  bool _showBlocks = false;
  bool _showLines = false;
  bool _showElements = false;

  // Selection state. Indices point into _block.units (reading order).
  List<_BlockText> _blocks = [];
  List<Offset> _stroke = []; // lasso path, widget coordinates
  int? _selStart;
  int? _selEnd;
  _Drag _drag = _Drag.none;

  final ImagePicker _picker = ImagePicker();

  _BlockText? get _block => _blocks.isEmpty ? null : _blocks.first;

  String? get _selectedText {
    final b = _block;
    if (b == null || _selStart == null || _selEnd == null) return null;
    final first = b.units[_selStart!];
    final last = b.units[_selEnd!];
    return b.text.substring(first.offset, last.offset + last.char.length);
  }

  /// [start, end) of the sentence(s) covering the whole selection.
  (int, int)? get _sentenceSpan {
    final b = _block;
    if (b == null || _selStart == null || _selEnd == null) return null;
    final first = b.units[_selStart!];
    final last = b.units[_selEnd!];
    return (
      _sentenceRange(b.text, first.offset).$1,
      _sentenceRange(b.text, last.offset).$2,
    );
  }

  String? get _sentence {
    final span = _sentenceSpan;
    return span == null ? null : _block!.text.substring(span.$1, span.$2);
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);

    if (pickedFile != null) {
      final file = File(pickedFile.path);
      // Boxes are in image pixel space, so we need the image's real size.
      final decoded = await decodeImageFromList(await file.readAsBytes());
      setState(() {
        _selectedImage = file;
        _imageSize = Size(decoded.width.toDouble(), decoded.height.toDouble());
        _recognized = null;
        _blocks = [];
        _stroke = [];
        _selStart = null;
        _selEnd = null;
      });
      final recognized = await recognizeText(file);
      setState(() {
        _recognized = recognized;
        _blocks = _buildBlocks(recognized);
        _result = recognized.text;
      });
    }
  }

  Offset _toImage(Offset local, Size widgetSize) {
    final imageSize = _imageSize!;
    final dest = _imageDest(imageSize, widgetSize);
    final scale = dest.width / imageSize.width;
    return Offset(
      (local.dx - dest.left) / scale,
      (local.dy - dest.top) / scale,
    );
  }

  Offset _toWidget(Offset image, Size widgetSize) {
    final imageSize = _imageSize!;
    final dest = _imageDest(imageSize, widgetSize);
    final scale = dest.width / imageSize.width;
    return Offset(dest.left + image.dx * scale, dest.top + image.dy * scale);
  }

  /// Index of the unit closest to [imagePoint], or null if none is within
  /// [maxDist] image pixels.
  int? _nearestUnit(Offset imagePoint, {double maxDist = double.infinity}) {
    final b = _block;
    if (b == null) return null;
    int? best;
    var bestDist = double.infinity;
    for (var i = 0; i < b.units.length; i++) {
      final d = _distanceToRect(imagePoint, b.units[i].rect);
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return bestDist <= maxDist ? best : null;
  }

  /// Handle centers in widget coordinates, or null without a selection.
  (Offset, Offset)? _handleCenters(Size size) {
    final b = _block;
    if (b == null || _selStart == null || _selEnd == null) return null;
    if (_imageSize == null) return null;
    final f = b.units[_selStart!].rect;
    final l = b.units[_selEnd!].rect;
    if (b.vertical) {
      return (
        _toWidget(f.topRight, size) + const Offset(10, -2),
        _toWidget(l.bottomLeft, size) + const Offset(-10, 2),
      );
    }
    return (
      _toWidget(f.bottomLeft, size) + const Offset(-2, 10),
      _toWidget(l.bottomRight, size) + const Offset(2, 10),
    );
  }

  // --- gestures -----------------------------------------------------------

  void _onTap(Offset local, Size size) {
    if (_imageSize == null || _block == null) return;
    final idx = _nearestUnit(_toImage(local, size), maxDist: 12);
    setState(() {
      _stroke = [];
      _selStart = idx;
      _selEnd = idx;
    });
  }

  void _onPanStart(Offset pos, Size size) {
    final handles = _handleCenters(size);
    if (handles != null) {
      if ((pos - handles.$1).distance < 32) {
        setState(() => _drag = _Drag.start);
        return;
      }
      if ((pos - handles.$2).distance < 32) {
        setState(() => _drag = _Drag.end);
        return;
      }
    }
    setState(() {
      _drag = _Drag.lasso;
      _stroke = [pos];
    });
  }

  void _onPanUpdate(Offset pos, Size size) {
    switch (_drag) {
      case _Drag.lasso:
        setState(() => _stroke = [..._stroke, pos]);
      case _Drag.start || _Drag.end:
        final idx = _nearestUnit(_toImage(pos, size));
        if (idx == null) return;
        setState(() {
          if (_drag == _Drag.start) {
            if (idx > _selEnd!) {
              _selStart = _selEnd;
              _selEnd = idx;
              _drag = _Drag.end;
            } else {
              _selStart = idx;
            }
          } else {
            if (idx < _selStart!) {
              _selEnd = _selStart;
              _selStart = idx;
              _drag = _Drag.start;
            } else {
              _selEnd = idx;
            }
          }
        });
      case _Drag.none:
        break;
    }
  }

  void _onPanEnd(Size size) {
    final wasLasso = _drag == _Drag.lasso;
    _drag = _Drag.none;
    if (!wasLasso) {
      setState(() {});
      return;
    }
    final b = _block;
    if (_imageSize == null || b == null || _stroke.length < 2) {
      setState(() => _stroke = []);
      return;
    }
    final path = [for (final p in _stroke) _toImage(p, size)];

    int? lo;
    int? hi;
    for (var i = 0; i < b.units.length; i++) {
      final c = b.units[i].rect.center;
      // Scribbles/underlines enclose no area, so also accept characters
      // that the line passes close to.
      final reach = (b.units[i].rect.shortestSide * 0.5).clamp(6.0, 40.0);
      if (_pointInPolygon(c, path) || _distanceToPolyline(c, path) <= reach) {
        lo ??= i;
        hi = i;
      }
    }
    setState(() {
      _stroke = [];
      _selStart = lo;
      _selEnd = hi;
    });
    if (lo != null) {
      debugPrint("Selected: $_selectedText\nSentence: $_sentence");
    }
  }

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Copied $label'),
          duration: const Duration(seconds: 1),
        ),
      );
  }

  // --- OCR ----------------------------------------------------------------

  Future<RecognizedText> recognizeText(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final textRecognizer = TextRecognizer(script: _script);
    final RecognizedText recognizedText = await textRecognizer.processImage(
      inputImage,
    );
    await textRecognizer.close();

    debugPrint("Script: ${_script.name}");
    _dumpStructure(recognizedText);

    return recognizedText;
  }

  /// Prints the Block > Line > Element > Symbol hierarchy to the console.
  void _dumpStructure(RecognizedText recognized) {
    String rect(Rect r) =>
        "[l=${r.left.toStringAsFixed(0)} t=${r.top.toStringAsFixed(0)} "
        "r=${r.right.toStringAsFixed(0)} b=${r.bottom.toStringAsFixed(0)}]";
    String conf(double? c) => c == null ? "n/a" : c.toStringAsFixed(2);

    final buf = StringBuffer()
      ..writeln("RecognizedText: ${recognized.blocks.length} block(s)");

    for (var b = 0; b < recognized.blocks.length; b++) {
      final block = recognized.blocks[b];
      buf.writeln(
        "Block[$b] ${rect(block.boundingBox)} "
        "langs=${block.recognizedLanguages} "
        "corners=${block.cornerPoints} "
        "text=${block.text.replaceAll('\n', '\\n')}",
      );
      for (var l = 0; l < block.lines.length; l++) {
        final line = block.lines[l];
        buf.writeln(
          "  Line[$l] ${rect(line.boundingBox)} "
          "langs=${line.recognizedLanguages} "
          "conf=${conf(line.confidence)} angle=${line.angle} "
          "text=${line.text}",
        );
        for (var e = 0; e < line.elements.length; e++) {
          final el = line.elements[e];
          buf.writeln(
            "    Element[$e] ${rect(el.boundingBox)} "
            "conf=${conf(el.confidence)} "
            "symbols=${el.symbols.length} text=${el.text}",
          );
          for (var s = 0; s < el.symbols.length; s++) {
            final sym = el.symbols[s];
            buf.writeln(
              "      Symbol[$s] ${rect(sym.boundingBox)} "
              "conf=${conf(sym.confidence)} text=${sym.text}",
            );
          }
        }
      }
    }

    // debugPrint throttles output so long dumps aren't truncated by logcat.
    debugPrint(buf.toString());
  }

  // --- UI -----------------------------------------------------------------

  Widget _imagePane() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final b = _block;
        var selRects = <Rect>[];
        var sentRects = <Rect>[];
        if (b != null && _selStart != null && _selEnd != null) {
          selRects = _mergedRects(b.units.sublist(_selStart!, _selEnd! + 1));
          final span = _sentenceSpan!;
          sentRects = _mergedRects(
            b.units.where((u) => u.offset >= span.$1 && u.offset < span.$2),
          );
        }
        final handles = _handleCenters(size);

        // Floating action pill above the selection (widget coordinates).
        Widget? pill;
        if (selRects.isNotEmpty && _drag == _Drag.none && _stroke.isEmpty) {
          var bounds = Rect.fromPoints(
            _toWidget(selRects.first.topLeft, size),
            _toWidget(selRects.first.bottomRight, size),
          );
          for (final r in selRects.skip(1)) {
            bounds = bounds.expandToInclude(
              Rect.fromPoints(
                _toWidget(r.topLeft, size),
                _toWidget(r.bottomRight, size),
              ),
            );
          }
          const pillW = 220.0;
          final left = (bounds.center.dx - pillW / 2).clamp(
            0.0,
            (size.width - pillW).clamp(0.0, double.infinity),
          );
          final top = (bounds.top - 52).clamp(0.0, size.height - 44);
          pill = Positioned(
            left: left,
            top: top,
            child: Material(
              color: const Color(0xFF303134),
              borderRadius: BorderRadius.circular(24),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () => _copy(_selectedText!, 'text'),
                    child: const Text('Copy'),
                  ),
                  TextButton(
                    onPressed: () => _copy(_sentence!, 'sentence'),
                    child: const Text('Copy sentence'),
                  ),
                ],
              ),
            ),
          );
        }

        return GestureDetector(
          onTapUp: (d) => _onTap(d.localPosition, size),
          onPanStart: (d) => _onPanStart(d.localPosition, size),
          onPanUpdate: (d) => _onPanUpdate(d.localPosition, size),
          onPanEnd: (_) => _onPanEnd(size),
          onPanCancel: () => setState(() {
            _drag = _Drag.none;
            _stroke = [];
          }),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(_selectedImage!, fit: BoxFit.contain),
              if (_recognized != null && _imageSize != null)
                CustomPaint(
                  painter: _BoxesPainter(
                    recognized: _recognized!,
                    imageSize: _imageSize!,
                    showBlocks: _showBlocks,
                    showLines: _showLines,
                    showElements: _showElements,
                    sentenceRects: sentRects,
                    selectedRects: selRects,
                    handles: handles,
                    stroke: _stroke,
                  ),
                ),
              ?pill,
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MLKit OCR')),
      body: Container(
        margin: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_selectedImage != null) Expanded(flex: 3, child: _imagePane()),

            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Blocks'),
                  selected: _showBlocks,
                  selectedColor: Colors.red.withValues(alpha: 0.3),
                  onSelected: (v) => setState(() => _showBlocks = v),
                ),
                FilterChip(
                  label: const Text('Lines'),
                  selected: _showLines,
                  selectedColor: Colors.green.withValues(alpha: 0.3),
                  onSelected: (v) => setState(() => _showLines = v),
                ),
                FilterChip(
                  label: const Text('Elements'),
                  selected: _showElements,
                  selectedColor: Colors.blue.withValues(alpha: 0.3),
                  onSelected: (v) => setState(() => _showElements = v),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              direction: Axis.horizontal,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                  onPressed: () => _pickImage(ImageSource.camera),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.image),
                  label: const Text('Gallery'),
                  onPressed: () => _pickImage(ImageSource.gallery),
                ),
                DropdownMenu(
                  initialSelection: _script,
                  dropdownMenuEntries: TextRecognitionScript.values
                      .map((e) => DropdownMenuEntry(value: e, label: e.name))
                      .toList(),
                  onSelected: (value) => {_script = value!},
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Data:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              flex: 1,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: Column(
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Selected: ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: '$_selectedText\n'),
                          const TextSpan(
                            text: 'Sentence: ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: _sentence ?? ''),
                        ],
                      ),
                    ),
                    SelectionArea(child: Text(_result)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Draws the selection (merged per line, like text selection), handles, the
/// user's lasso stroke and, optionally, block/line/element debug boxes over
/// an image displayed with [BoxFit.contain].
class _BoxesPainter extends CustomPainter {
  _BoxesPainter({
    required this.recognized,
    required this.imageSize,
    required this.showBlocks,
    required this.showLines,
    required this.showElements,
    required this.sentenceRects,
    required this.selectedRects,
    required this.handles,
    required this.stroke,
  });

  final RecognizedText recognized;
  final Size imageSize;
  final bool showBlocks;
  final bool showLines;
  final bool showElements;
  final List<Rect> sentenceRects; // image pixels, one per line
  final List<Rect> selectedRects; // image pixels, one per line
  final (Offset, Offset)? handles; // widget coordinates
  final List<Offset> stroke; // widget coordinates

  static const _accent = Color(0xFF4285F4);

  @override
  void paint(Canvas canvas, Size size) {
    final dest = _imageDest(imageSize, size);
    final scale = dest.width / imageSize.width;

    Rect map(Rect r) => Rect.fromLTRB(
      dest.left + r.left * scale,
      dest.top + r.top * scale,
      dest.left + r.right * scale,
      dest.top + r.bottom * scale,
    );

    Paint outline(Color c, double w) => Paint()
      ..style = PaintingStyle.stroke
      ..color = c
      ..strokeWidth = w;

    // Sentence context first, selection on top.
    final sentenceFill = Paint()..color = Colors.yellow.withValues(alpha: 0.28);
    for (final r in sentenceRects) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(map(r).inflate(2), const Radius.circular(6)),
        sentenceFill,
      );
    }
    final selectedFill = Paint()..color = _accent.withValues(alpha: 0.4);
    for (final r in selectedRects) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(map(r).inflate(2), const Radius.circular(8)),
        selectedFill,
      );
    }

    // Optional debug boxes.
    final blockPaint = outline(Colors.red, 3);
    final linePaint = outline(Colors.green, 2);
    final elementPaint = outline(Colors.blue, 1);
    for (final block in recognized.blocks) {
      if (showBlocks) canvas.drawRect(map(block.boundingBox), blockPaint);
      for (final line in block.lines) {
        if (showLines) canvas.drawRect(map(line.boundingBox), linePaint);
        if (showElements) {
          for (final element in line.elements) {
            canvas.drawRect(map(element.boundingBox), elementPaint);
          }
        }
      }
    }

    // Selection handles.
    if (handles != null) {
      for (final c in [handles!.$1, handles!.$2]) {
        canvas.drawCircle(c, 11, Paint()..color = Colors.white);
        canvas.drawCircle(c, 8.5, Paint()..color = _accent);
      }
    }

    // The user's circle: soft glow underneath, crisp line on top.
    if (stroke.length > 1) {
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final p in stroke.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      final base = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(
        path,
        base
          ..color = Colors.lightBlueAccent.withValues(alpha: 0.35)
          ..strokeWidth = 14,
      );
      canvas.drawPath(
        path,
        base
          ..color = Colors.white
          ..strokeWidth = 4,
      );
    }
  }

  @override
  bool shouldRepaint(_BoxesPainter old) => true;
}

// --- geometry helpers -------------------------------------------------------

/// Where an image of [imageSize] ends up inside a [BoxFit.contain] box.
Rect _imageDest(Size imageSize, Size box) {
  final fitted = applyBoxFit(BoxFit.contain, imageSize, box);
  return Alignment.center.inscribe(fitted.destination, Offset.zero & box);
}

/// Ray-casting point-in-polygon test. The polygon is implicitly closed.
bool _pointInPolygon(Offset p, List<Offset> poly) {
  var inside = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final a = poly[i];
    final b = poly[j];
    final crosses =
        (a.dy > p.dy) != (b.dy > p.dy) &&
        p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx;
    if (crosses) inside = !inside;
  }
  return inside;
}

double _distanceToPolyline(Offset p, List<Offset> pts) {
  var best = double.infinity;
  for (var i = 0; i < pts.length - 1; i++) {
    final a = pts[i];
    final b = pts[i + 1];
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    final t = len2 == 0
        ? 0.0
        : (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2).clamp(
            0.0,
            1.0,
          );
    final d = (p - (a + ab * t)).distance;
    if (d < best) best = d;
  }
  return best;
}

double _distanceToRect(Offset p, Rect r) {
  final dx = p.dx < r.left
      ? r.left - p.dx
      : (p.dx > r.right ? p.dx - r.right : 0);
  final dy = p.dy < r.top
      ? r.top - p.dy
      : (p.dy > r.bottom ? p.dy - r.bottom : 0);
  return Offset(dx.toDouble(), dy.toDouble()).distance;
}

/// Unions the character boxes of each line into one rect per line, so the
/// selection renders as continuous highlights like text selection.
List<Rect> _mergedRects(Iterable<_CharUnit> units) {
  final byLine = <int, Rect>{};
  for (final u in units) {
    final existing = byLine[u.line];
    byLine[u.line] = existing == null
        ? u.rect
        : existing.expandToInclude(u.rect);
  }
  return byLine.values.toList();
}

// --- OCR model --------------------------------------------------------------

/// One recognized character with its box (image pixels), its position in the
/// page's joined text, and the reading-order line it belongs to.
class _CharUnit {
  _CharUnit(this.char, this.rect, this.block, this.offset, this.line);
  final String char;
  final Rect rect;
  final int block;
  final int offset;
  final int line;
}

class _BlockText {
  _BlockText(this.text, this.units, {required this.vertical});
  final String text;
  final List<_CharUnit> units; // in reading order
  final bool vertical;
}

bool _isAscii(String c) => c.codeUnitAt(0) < 0x80;

/// Flattens ML Kit output into one page-level string in *reading order*,
/// plus per-character boxes. ML Kit's own block/line order is ignored
/// because it is not reading order for vertical (right-to-left) text.
///
/// Uses real symbols when present (Android), otherwise splits each element's
/// box by character width (iOS has no symbols).
List<_BlockText> _buildBlocks(RecognizedText recognized) {
  final lines = <TextLine>[
    for (final block in recognized.blocks) ...block.lines,
  ];
  if (lines.isEmpty) return [];

  // Page orientation: majority vote of multi-character lines.
  var verticalCount = 0;
  var horizontalCount = 0;
  for (final l in lines) {
    if (l.text.length < 2) continue;
    final box = l.boundingBox;
    if (box.height > box.width) {
      verticalCount++;
    } else {
      horizontalCount++;
    }
  }
  final vertical = verticalCount > horizontalCount;

  // "cross" runs across lines (right-to-left columns, or top-to-bottom rows),
  // "along" runs inside a line.
  double cross(TextLine l) =>
      vertical ? -l.boundingBox.center.dx : l.boundingBox.center.dy;
  double along(TextLine l) =>
      vertical ? l.boundingBox.center.dy : l.boundingBox.center.dx;
  double thickness(TextLine l) =>
      vertical ? l.boundingBox.width : l.boundingBox.height;

  final thick = lines.map(thickness).toList()..sort();
  final median = thick[thick.length ~/ 2];

  // Cluster fragments that sit in the same column/row, then order inside.
  lines.sort((a, b) => cross(a).compareTo(cross(b)));
  final groups = <List<TextLine>>[];
  for (final l in lines) {
    if (groups.isNotEmpty &&
        (cross(l) - cross(groups.last.first)).abs() < median * 0.5) {
      groups.last.add(l);
    } else {
      groups.add([l]);
    }
  }
  for (final g in groups) {
    g.sort((a, b) => along(a).compareTo(along(b)));
  }
  final ordered = [for (final g in groups) ...g];

  final buf = StringBuffer();
  final units = <_CharUnit>[];
  String? last;
  var lineIndex = -1;

  void add(String ch, Rect rect) {
    units.add(_CharUnit(ch, rect, 0, buf.length, lineIndex));
    buf.write(ch);
    last = ch;
  }

  TextLine? prev;
  for (final line in ordered) {
    lineIndex++;
    // A large jump between lines is a paragraph/region break.
    if (prev != null && (cross(line) - cross(prev)).abs() > median * 2.2) {
      buf.write('\n');
      last = null;
    }
    prev = line;

    for (final el in line.elements) {
      if (el.text.isEmpty) continue;
      final first = String.fromCharCode(el.text.runes.first);
      // Latin words need a separator; Japanese text does not.
      if (last != null && _isAscii(last!) && _isAscii(first)) {
        buf.write(' ');
      }

      if (el.symbols.isNotEmpty) {
        for (final sym in el.symbols) {
          add(sym.text, sym.boundingBox);
        }
        continue;
      }

      final chars = el.text.runes.map(String.fromCharCode).toList();
      final weights = [for (final c in chars) _isAscii(c) ? 0.5 : 1.0];
      final total = weights.fold<double>(0, (a, w) => a + w);
      final box = el.boundingBox;
      final vert = chars.length > 1 && box.height > box.width * 1.5;
      var acc = 0.0;
      for (var i = 0; i < chars.length; i++) {
        final from = acc / total;
        final to = (acc + weights[i]) / total;
        acc += weights[i];
        final rect = vert
            ? Rect.fromLTRB(
                box.left,
                box.top + box.height * from,
                box.right,
                box.top + box.height * to,
              )
            : Rect.fromLTRB(
                box.left + box.width * from,
                box.top,
                box.left + box.width * to,
                box.bottom,
              );
        add(chars[i], rect);
      }
    }
  }
  debugPrint("Reading-order text (vertical=$vertical): ${buf.toString()}");
  return [_BlockText(buf.toString(), units, vertical: vertical)];
}

// --- sentence splitting -----------------------------------------------------

const _closers = '」』）)”’"';

bool _isSentenceEnd(String t, int i) {
  final c = t[i];
  if ('。！？!?'.contains(c)) return true;
  if (c == '.') return i + 1 >= t.length || t[i + 1] == ' ';
  return false;
}

/// [start, end) of the sentence containing [offset] in [text].
/// '\n' (a region break) always ends a sentence. Closing quotes stay with
/// their sentence, and runaway length is capped.
(int, int) _sentenceRange(String text, int offset) {
  bool stop(int i) => text[i] == '\n' || _isSentenceEnd(text, i);

  var start = offset;
  while (start > 0 && !stop(start - 1)) {
    start--;
  }
  while (start < offset && _closers.contains(text[start])) {
    start++;
  }
  var end = offset;
  while (end < text.length && !stop(end)) {
    end++;
  }
  if (end < text.length && text[end] != '\n') end++; // include terminator
  while (end < text.length && _closers.contains(text[end])) {
    end++;
  }
  // No terminators (titles, captions): don't return a whole page.
  const cap = 100;
  if (end - start > cap * 2) {
    start = (offset - cap).clamp(start, end);
    end = (offset + cap).clamp(start, end);
  }
  return (start, end);
}
