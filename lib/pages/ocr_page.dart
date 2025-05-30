import 'dart:developer';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:overlay_test/models/ocr_word.dart';
import 'package:overlay_test/widgets/word_selector.dart';

class OCRPage extends StatefulWidget {
  final String imagePath;

  const OCRPage({super.key, required this.imagePath});

  @override
  State<OCRPage> createState() => _OCRPageState();
}

class _OCRPageState extends State<OCRPage> {
  late final TransformationController _transformationController;

  List<OcrWord> _ocrWords = [];
  Size _originalSize = Size(0, 0);

  (List<OcrWord>, Size) parseOcrWordsFromString(String jsonStr) {
    final Map<String, dynamic> json = jsonDecode(jsonStr);

    log('$json');

    final List<OcrWord> words = [];

    Size originalSize = Size(
      (json['result']['metadata']['width'] as num).toDouble(),
      (json['result']['metadata']['height'] as num).toDouble(),
    );

    final blocks = json['result']['readResult']['blocks'] as List;
    for (final block in blocks) {
      final lines = block['lines'] as List;
      for (final line in lines) {
        final lineWords = line['words'] as List;
        for (final wordJson in lineWords) {
          words.add(OcrWord.fromJson(wordJson));
        }
      }
    }

    return (words, originalSize);
  }

  Future<void> fetchOcr() async {
    const String uploadUrl = 'http://10.0.2.2:8000/ai/ocr';
    String imagePath = widget.imagePath;

    try {
      var request = MultipartRequest('POST', Uri.parse(uploadUrl));
      request.files.add(await MultipartFile.fromPath('image', imagePath));

      StreamedResponse response = await request.send();
      final body = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        // success
        log('Upload successful: $body');

        setState(() {
          var (words, oriSize) = parseOcrWordsFromString(
            body,
          ); // from OCR response
          log('$_ocrWords');
          log('$_originalSize');
          _ocrWords = words;
          _originalSize = oriSize;
        });
      } else {
        // err
        log('Upload failed: $body');
      }
    } catch (e) {
      log('Error occured while trying to upload image: $e');
    }
  }

  void _setInitialZoom() {
    final screenSize = MediaQuery.of(context).size;

    // Fit to width
    final scale = screenSize.width / _originalSize.width;

    _transformationController.value = Matrix4.identity()..scale(scale);
  }

  @override
  void initState() {
    super.initState();

    fetchOcr().whenComplete(() {
      log('Fetch OCR Complete');
    });
    _transformationController = TransformationController();
    fetchOcr().whenComplete(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _setInitialZoom();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Captured Image',
          style: TextStyle(color: Colors.white),
        ),
        actions: [],
      ),
      body: InteractiveViewer(
        transformationController: _transformationController,
        constrained: false,
        boundaryMargin: const EdgeInsets.all(100),
        minScale: 0.5,
        maxScale: 5.0,
        child: Center(
          child: SizedBox(
            width: _originalSize.width,
            height: _originalSize.height,
            child: OcrWordSelector(
              words: _ocrWords,
              image: Image.file(File(widget.imagePath)),
              originalSize: _originalSize,
            ),
          ),
        ),
      ),
    );
  }
}
