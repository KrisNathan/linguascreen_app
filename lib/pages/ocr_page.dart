import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:lingua_screen/api/api_client.dart';
import 'package:lingua_screen/ocr/loaded_image.dart';
import 'package:lingua_screen/ocr/ocr_controller.dart';
import 'package:lingua_screen/ocr/widgets/ocr_canvas.dart';
import 'package:lingua_screen/ocr/sentence_reader.dart';
import 'package:lingua_screen/session.dart';
import 'package:lingua_screen/widgets/sentence_sheet.dart';

/// Reads a screenshot on device. Tapping a sentence opens a popup with its
/// translation and words.
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
    analyze: (sentence) =>
        ApiClient.instance.analyze(_course!.id, sentence),
  );

  bool _loadFailed = false;

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
              builder: (context, _) => _canvas(),
            ),
    );
  }

  Widget _canvas() {
    final loaded = _ocr.image;
    if (loaded == null) {
      return _loadFailed
          ? const _Message('Could not read text from this screenshot.')
          : const Center(child: CircularProgressIndicator());
    }

    return OCRCanvas(
      image: loaded.image,
      page: _ocr.page,
      selStart: _ocr.selStart,
      selEnd: _ocr.selEnd,
      onPick: _pick,
    );
  }

  void _pick(int? unit) {
    _reader.pick(unit);
    if (_reader.sentence == null) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // keep the selected sentence visible above the sheet
      barrierColor: Colors.black26,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.45,
        minChildSize: 0.25,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SentenceSheet(
          reader: _reader,
          course: _course!,
          scrollController: scrollController,
        ),
      ),
    ).whenComplete(_reader.clear);
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
