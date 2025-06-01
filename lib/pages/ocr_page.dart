import 'dart:developer';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:overlay_test/models/ocr_word.dart';
import 'package:overlay_test/widgets/word_selector.dart';

class APIs {
  static Future<Translation?> fetchTranslation(String sentence) async {
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

        return Translation.fromJson(json['result']);
      } else {
        // err
        log('Translation failed: ${response.body}');
      }
    } catch (e) {
      log('Error occured while trying to fetch translation: $e');
    }
    return null;
  }

  static Future<String?> fetchExplanation(
    String originalSent,
    String translatedSent,
    String originalLang,
    String targetLang,
  ) async {
    const String explanationUrl = 'http://10.0.2.2:8000/ai/explain';
    try {
      final response = await post(
        Uri.parse(explanationUrl),
        body: jsonEncode({
          'original_sentence': originalSent,
          'translated_sentence': translatedSent,
          'original_lang': originalLang,
          'target_lang': targetLang,
        }),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        // success
        log('Explanation successful: ${response.body}');
        final Map<String, dynamic> json = jsonDecode(response.body);
        final String entireExplanation =
            json['result']['entire_explanation'] as String;

        final List<dynamic> wordsExplanation =
            json['result']['words_explanation'] ?? [];
        final String wordsExplanationStr = wordsExplanation
            .map((e) {
              final original = e['original_word'] ?? '';
              final translated = e['translated_word'] ?? '';
              final explanation = e['explanation'] ?? '';
              return '$original ($translated): $explanation';
            })
            .join('\n');

        final String explanation = '$wordsExplanationStr\n$entireExplanation';

        return explanation;
      } else {
        // err
        log('Explanation failed: ${response.body}');
      }
    } catch (e) {
      log('Error occured while trying to fetch explanation: $e');
    }
    return null;
  }
}

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

  Future<void> _fetchOcr() async {
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

    _transformationController = TransformationController();
    _fetchOcr().whenComplete(() {
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
              onDragEnd: (details) async {
                _showTranslationBottomSheet();
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
        return TranslationSheetContent(
          sentence: _ocrWords
              .where((word) => word.isSelected)
              .map((word) => word.text)
              .join(' '),
          scrollController: scrollController,
        );
      },
    );
  }
}

class TranslationSheetContent extends StatefulWidget {
  const TranslationSheetContent({
    super.key,
    required String sentence,
    required ScrollController scrollController,
  }) : _sentence = sentence,
       _scrollController = scrollController;

  final String _sentence;
  final ScrollController _scrollController;

  @override
  State<TranslationSheetContent> createState() =>
      _TranslationSheetContentState();
}

class _TranslationSheetContentState extends State<TranslationSheetContent> {
  bool _isTranslationLoading = true;
  String? _translatedStr;
  Translation? _translation;

  Future<void> asyncInit() async {
    Translation? translation = await APIs.fetchTranslation(widget._sentence);
    setState(() {
      _translation = translation;
      if (translation == null) {
        _translatedStr = 'Translation failed. Please try again.';
      } else {
        _translatedStr = translation.translatedSentence;
      }
      _isTranslationLoading = false;
    });
  }

  @override
  void initState() {
    super.initState();

    asyncInit();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:
            Theme.of(context).bottomSheetTheme.backgroundColor ?? Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .1),
            blurRadius: 10,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ListView(
        controller: widget._scrollController,
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
                const SizedBox(height: 8.0),
                Container(
                  padding: const EdgeInsets.all(8.0),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Text(
                    widget._sentence,
                    style: const TextStyle(fontSize: 16.0),
                  ),
                ),
                const SizedBox(height: 8.0),
                Container(
                  padding: const EdgeInsets.all(8.0),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Text(
                    _isTranslationLoading ? 'Loading...' : '$_translatedStr',
                    style: const TextStyle(fontSize: 16.0),
                  ),
                ),
                const SizedBox(height: 8.0),
                const Divider(),
                const SizedBox(height: 8.0),
                TranslationExplanationWidget(translation: _translation),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TranslationExplanationWidget extends StatefulWidget {
  const TranslationExplanationWidget({
    super.key,
    required Translation? translation,
  }) : _translation = translation;

  final Translation? _translation;

  @override
  State<TranslationExplanationWidget> createState() =>
      _TranslationExplanationWidgetState();
}

class _TranslationExplanationWidgetState
    extends State<TranslationExplanationWidget> {
  Future<String?> asyncInit() async {
    Translation? translation = widget._translation;
    if (translation == null) {
      return 'Loading...';
    } else {
      String? explanation = await APIs.fetchExplanation(
        translation.originalSentence,
        translation.translatedSentence,
        translation.originalLanguage,
        translation.targetLanguage,
      );
      return explanation;
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Explanation'),
        const SizedBox(height: 8.0),
        Container(
          padding: const EdgeInsets.all(8.0),
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: FutureBuilder(
            future: asyncInit(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Text(
                  'Loading explanation...',
                  style: TextStyle(fontSize: 16.0),
                );
              } else if (snapshot.hasError) {
                return const Text(
                  'An error occurred while fetching explanation.',
                  style: TextStyle(fontSize: 16.0),
                );
              }
              return Text(
                snapshot.data ?? 'No explanation available.',
                style: const TextStyle(fontSize: 16.0),
              );
            },
          ),
        ),
      ],
    );
  }
}

class Translation {
  final String originalSentence;
  final String translatedSentence;
  final String originalLanguage;
  final String targetLanguage;

  Translation({
    required this.originalSentence,
    required this.translatedSentence,
    required this.originalLanguage,
    required this.targetLanguage,
  });

  Translation.fromJson(Map<String, dynamic> json)
    : originalSentence = json['raw'],
      translatedSentence = json['result'],
      originalLanguage = json['from_language'],
      targetLanguage = json['to_language'];
}
