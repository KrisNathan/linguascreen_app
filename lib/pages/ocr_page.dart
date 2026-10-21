import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:lingua_screen/api/api_client.dart';
import 'package:lingua_screen/api/models.dart';
import 'package:lingua_screen/ocr/loaded_image.dart';
import 'package:lingua_screen/ocr/ocr_controller.dart';
import 'package:lingua_screen/ocr/widgets/ocr_canvas.dart';
import 'package:lingua_screen/ocr/sentence_reader.dart';
import 'package:lingua_screen/session.dart';
import 'package:lingua_screen/widgets/sentence_sheet.dart';

/// Reads a screenshot on device. Tapping a sentence opens a sheet with its
/// translation and words; dragging the selection handles changes what is
/// translated. The sheet is not modal, so the image stays usable under it.
class OCRPage extends StatefulWidget {
  final String imagePath;

  const OCRPage({super.key, required this.imagePath});

  @override
  State<OCRPage> createState() => _OCRPageState();
}

class _OCRPageState extends State<OCRPage> {
  final _course = Session.instance.course;
  final _ocr = OcrController();
  late final _reader = SentenceReader(
    ocr: _ocr,
    analyze: (sentence) => ApiClient.instance.analyze(_course!.id, sentence),
  );

  bool _loadFailed = false;

  static const _sheetInitialSize = 0.45;

  /// How much of the body the sentence sheet covers, as it is dragged.
  double _sheetSize = _sheetInitialSize;

  @override
  void initState() {
    super.initState();
    final course = _course;
    if (course == null) return;

    _ocr.script = scriptFor(course.learningLanguage);
    _ocr.load(FileOrigin(widget.imagePath)).catchError((Object e) {
      log('OCR failed: $e');
      if (mounted) setState(() => _loadFailed = true);
    });
  }

  @override
  void dispose() {
    _reader.dispose();
    _ocr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final course = _course;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          course?.label ?? 'Captured Image',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: course == null
          ? const _Message('Choose a course first.')
          : ListenableBuilder(
              listenable: Listenable.merge([_ocr, _reader]),
              builder: (context, _) => PopScope(
                // back closes the sheet first
                canPop: _reader.sentence == null,
                onPopInvokedWithResult: (didPop, _) {
                  if (!didPop) _reader.clear();
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _canvas(),
                    if (_reader.sentence != null) _sheet(course),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _sheet(Course course) {
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (n) {
        setState(() => _sheetSize = n.extent);
        return false;
      },
      child: DraggableScrollableSheet(
        initialChildSize: _sheetInitialSize,
        minChildSize: 0.25,
        maxChildSize: 0.9,
        builder: (context, scrollController) => SentenceSheet(
          reader: _reader,
          course: course,
          scrollController: scrollController,
        ),
      ),
    );
  }

  Widget _canvas() {
    final loaded = _ocr.image;
    if (loaded == null) {
      return _loadFailed
          ? const _Message('Could not read text from this screenshot.')
          : const Center(
              // The theme's ink would vanish on this black page.
              child: CircularProgressIndicator(color: Colors.white),
            );
    }

    return OCRCanvas(
      image: loaded.image,
      page: _ocr.page,
      selStart: _ocr.selStart,
      selEnd: _ocr.selEnd,
      onPick: (unit) {
        // a reopened sheet starts at its initial size again
        if (_reader.sentence == null) _sheetSize = _sheetInitialSize;
        _reader.pick(unit);
      },
      coveredFraction: _reader.sentence == null ? 0 : _sheetSize,
      // live highlight only; analyzed once the handle is let go
      onAdjust: _ocr.select,
      onAdjustEnd: () {
        final start = _ocr.selStart;
        final end = _ocr.selEnd;
        if (start != null && end != null) _reader.selectRange(start, end);
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(text, style: const TextStyle(color: Colors.white)),
  );
}
