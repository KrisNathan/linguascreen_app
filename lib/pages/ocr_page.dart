import 'dart:developer';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart';
import 'package:lingua_screen/models/explanation.dart';
import 'package:lingua_screen/models/ocr_line.dart';
import 'package:lingua_screen/models/selection_postprocess_response.dart';
import 'package:lingua_screen/widgets/word_selector.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:lingua_screen/api/explain.dart';

class APIs {
  static final String baseUrl =
      dotenv.env['LINGUASCREEN_API_URL'] ?? 'http://10.0.2.2:8000';

  static Future<String?> fetchSelectionText(List<OcrLine> lines) async {
    if (lines.isEmpty) {
      return null;
    }

    try {
      final response = await post(
        Uri.parse('$baseUrl/ai/ocr/selection/postprocess'),
        body: jsonEncode({
          'ocr_data': {'lines': lines.map((e) => e.toJson()).toList()},
        }),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        // success
        log('Selection text fetch successful: ${response.body}');
        final Map<String, dynamic> json = jsonDecode(response.body);
        final SelectionPostprocessResponse selectionResponse =
            SelectionPostprocessResponse.fromJson(json);
        return selectionResponse.result;
      } else {
        // err
        log('Selection text fetch failed: ${response.body}');
      }
    } catch (e) {
      log('Error occurred while trying to fetch selection text: $e');
    }
    return null;
  }

  static Future<Translation?> fetchTranslation(String sentence) async {
    final String translationUrl = '$baseUrl/ai/translate';
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

  /// Returns merged explanation strings.
  static Future<String?> fetchExplanation(
    String originalSent,
    String translatedSent,
    String originalLang,
    String targetLang,
  ) async {
    final String explanationUrl = '$baseUrl/ai/explain';
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
              final romanization = e['romanization'] ?? '';
              return '$original ($translated) $romanization: $explanation';
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

  /// Returns true if successful.
  static Future<bool> saveTranslation(
    Translation translation,
    FlutterSecureStorage secureStorage,
  ) async {
    final String saveUrl = '$baseUrl/ai/save';
    try {
      final token = await secureStorage.read(key: 'access_token');

      final response = await post(
        Uri.parse(saveUrl),
        body: jsonEncode({
          'original_sentence': translation.originalSentence,
          'translated_sentence': translation.translatedSentence,
          'original_lang': translation.originalLanguage,
          'target_lang': translation.targetLanguage,
        }),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return true;
      }
    } catch (e) {
      log('Error occured while trying to save translation: $e');
    }
    return false;
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

  List<OcrLine> _ocrLines = [];
  // List<OcrWord> _ocrWords = [];
  Size _originalSize = Size(0, 0);

  (List<OcrLine>, Size) parseOcrLinesFromString(String jsonStr) {
    final Map<String, dynamic> json = jsonDecode(jsonStr);

    log('$json');

    final List<OcrLine> linesList = [];

    Size originalSize = Size(
      (json['result']['metadata']['width'] as num).toDouble(),
      (json['result']['metadata']['height'] as num).toDouble(),
    );

    final blocks = json['result']['readResult']['blocks'] as List;
    for (final block in blocks) {
      final lines = block['lines'] as List;
      for (final lineJson in lines) {
        linesList.add(OcrLine.fromJson(lineJson));
      }
    }

    return (linesList, originalSize);
  }

  Future<void> _fetchOcr() async {
    final String uploadUrl = '${APIs.baseUrl}/ai/ocr';
    String imagePath = widget.imagePath;

    try {
      var request = MultipartRequest('POST', Uri.parse(uploadUrl));
      request.files.add(await MultipartFile.fromPath('image', imagePath));

      StreamedResponse response = await request.send();
      final body = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        // success
        log('Upload successful: $body');

        if (!mounted) {
          return;
        }
        setState(() {
          var (lines, oriSize) = parseOcrLinesFromString(
            body,
          ); // from OCR response
          _ocrLines = lines;
          // _ocrWords =
          //     lines
          //         .expand((line) => line.words)
          //         .toList(); // Flatten the list of words from all lines
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
    if (!mounted) return;
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
              words: _ocrLines.expand((line) => line.words).toList(),
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
          ocrLines: _ocrLines,
          scrollController: scrollController,
        );
      },
    );
  }
}

class TranslationSheetContent extends StatefulWidget {
  const TranslationSheetContent({
    super.key,
    required List<OcrLine> ocrLines,
    required ScrollController scrollController,
  }) : _ocrLines = ocrLines,
       _scrollController = scrollController;

  final List<OcrLine> _ocrLines;
  final ScrollController _scrollController;

  @override
  State<TranslationSheetContent> createState() =>
      _TranslationSheetContentState();
}

class _TranslationSheetContentState extends State<TranslationSheetContent> {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  String? _sentence;
  bool _isTranslationLoading = true;
  String? _translatedStr;
  Translation? _translation;

  Future<void> asyncInit() async {
    // Filter lines to only include those with selected words, and only keep selected words in each line
    List<OcrLine> filteredLines =
        widget._ocrLines
            .where((line) => line.words.any((word) => word.isSelected))
            .map((line) {
              return OcrLine(
                text: line.text,
                polygon: line.polygon,
                words: line.words.where((word) => word.isSelected).toList(),
                isSelected: line.isSelected,
              );
            })
            .toList();
    if (filteredLines.isEmpty) {
      log('No words selected for translation.');
      setState(() {
        _isTranslationLoading = false;
        _translatedStr = 'No words selected for translation.';
      });
      return;
    }
    log(
      'Filtered lines for translation: ${filteredLines.map((line) => line.toJson()).toList()}',
    );

    String? sentence = await APIs.fetchSelectionText(filteredLines);
    if (sentence == null || sentence.isEmpty) {
      log('No text selected for translation.');
      setState(() {
        _isTranslationLoading = false;
        _translatedStr = 'No text selected for translation.';
      });
      return;
    }

    Translation? translation = await APIs.fetchTranslation(sentence);

    if (translation != null) {
      bool isSaveSuccess = await APIs.saveTranslation(
        translation,
        _secureStorage,
      );
      if (!isSaveSuccess) {
        log('Failed to save translation!');
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _sentence = sentence;
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
                    _isTranslationLoading ? 'Loading...' : '$_sentence',
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
                // const Divider(),
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
  Future<Explanation?> asyncInit() async {
    Translation? translation = widget._translation;
    if (translation == null) {
      return null;
    } else {
      Explanation? explanation = await ExplainApi.fetchExplanation(
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
        FutureBuilder(
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

            if (snapshot.data == null) {
              return const Text(
                'No explanation available.',
                style: TextStyle(fontSize: 16.0),
              );
            }
            final Explanation explanation = snapshot.data!;

            return Column(
              children: [
                explanation.wordsExplanation.isNotEmpty
                    ? Container(
                      padding: const EdgeInsets.all(8.0),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (
                            int i = 0;
                            i < explanation.wordsExplanation.length;
                            i++
                          ) ...[
                            Text(
                              '${explanation.wordsExplanation[i].originalWord} (${explanation.wordsExplanation[i].romanization})',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              explanation.wordsExplanation[i].translatedWord,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              explanation.wordsExplanation[i].explanation,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),

                            if (i != explanation.wordsExplanation.length - 1)
                              const Divider(height: 16, thickness: 1),
                          ],
                        ],
                      ),
                    )
                    : const SizedBox.shrink(),

                const SizedBox(height: 8.0),

                Container(
                  padding: const EdgeInsets.all(8.0),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Text(
                    explanation.entireExplanation,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            );
          },
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
