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

  String? _translation;
  String? _explanation;
  bool _isTranslationLoading = false;
  bool _isExplanationLoading = false;

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

  Future<void> fetchTranslation(String sentence) async {
    setState(() {
      _isTranslationLoading = true;
    });

    const String translationUrl = 'http://10.0.2.2:8000/ai/translate';
    try {
      final response = await post(
        Uri.parse(translationUrl),
        body: jsonEncode({'sentences': sentence, 'to_language': 'en'}),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        // success
        log('Translation successful: ${response.body}');
        final Map<String, dynamic> json = jsonDecode(response.body);
        final String translation = json['result']['result'] as String;

        setState(() {
          _translation = translation;
        });

        _showTranslationBottomSheet();
      } else {
        // err
        log('Translation failed: ${response.body}');
      }
    } catch (e) {
      log('Error occured while trying to fetch translation: $e');
    } finally {
      setState(() {
        _isTranslationLoading = false;
      });
    }
  }

  void _showTranslationBottomSheet() {
    log('Showing translation bottom sheet');
    showModalBottomSheet<void>(
      context: context,
      // IMPORTANT: Allows the sheet to be taller
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: _translationBottomSheetBuilder,
    );
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
              onDragEnd: (details) {
                fetchTranslation(
                  _ocrWords
                      .where((word) => word.isSelected)
                      .map((word) => word.text)
                      .join(' '),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _translationBottomSheetBuilder(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.2,
      maxChildSize: 0.9,
      expand: false,
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: BoxDecoration(
            color:
                Theme.of(context).bottomSheetTheme.backgroundColor ??
                Colors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20.0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .1),
                blurRadius: 10,
                spreadRadius: 5,
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Translation'),
                    Container(
                      padding: const EdgeInsets.all(8.0),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Text(
                        _isTranslationLoading ? 'Loading...' : '$_translation',
                        style: const TextStyle(fontSize: 16.0),
                      ),
                    ),
                    SizedBox(height: 8.0),
                    const Divider(),
                    SizedBox(height: 8.0),
                    Text('Explanation'),
                    Container(
                      padding: const EdgeInsets.all(8.0),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Text(
                        _isExplanationLoading ? 'Loading...' : '$_explanation',
                        style: const TextStyle(fontSize: 16.0),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
