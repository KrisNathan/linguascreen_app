import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'loaded_image.dart';
import 'page_text.dart';
import 'script_rules.dart';

/// Turns a [LoadedImage] into [PageText]. No UI, no state between calls.
class OcrEngine {
  final _pageTextFactory = PageTextFactory();

  /// Null if no text was found.
  Future<PageText?> recognize(
    LoadedImage image,
    TextRecognitionScript script,
  ) async {
    final recognizer = TextRecognizer(script: script);
    try {
      final recognizedText = await recognizer.processImage(
        await image.toInputImage(),
      );
      // The recognizer and the rules must use the same script.
      return _pageTextFactory.build(recognizedText, rulesFor(script));
    } finally {
      await recognizer.close();
    }
  }
}
