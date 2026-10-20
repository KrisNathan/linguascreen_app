
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

abstract class ScriptRules {
  bool get canBeVertical;
  bool get needsSpace;

  /// In vertical text, do the columns run right to left? (Japanese, Chinese)
  bool get verticalColumnsRightToLeft;

  /// get sentence containing [offset] then return sentence's start and end index in [text]
  /// [offset] is an index in [text]
  (int, int) sentenceRange(String text, int offset);
}

class LatinScriptRules implements ScriptRules {
  @override
  bool get canBeVertical {
    return false;
  }

  @override
  bool get needsSpace {
    return true;
  }

  @override
  bool get verticalColumnsRightToLeft {
    return false; // never vertical (canBeVertical is false), so unused
  }

  @override
  (int, int) sentenceRange(String text, int offset) {
    return findSentenceRange(
      text,
      offset,
      enders: ".。！？!?",
      closers: "」』）)”’\"' ",
    );
  }
}

/// Japanese and Chinese: no spaces, vertical text possible, columns run
/// right to left.
class CjkScriptRules implements ScriptRules {
  @override
  bool get canBeVertical => true;

  @override
  bool get needsSpace => false;

  @override
  bool get verticalColumnsRightToLeft => true;

  @override
  (int, int) sentenceRange(String text, int offset) {
    return findSentenceRange(
      text,
      offset,
      enders: "。！？!?",
      closers: "」』）)”’\"'",
    );
  }
}

/// Picks the rules for the script the OCR was run with.
ScriptRules rulesFor(TextRecognitionScript script) => switch (script) {
  // TODO: Devanagari ends sentences with '।', which Latin rules don't know.
  TextRecognitionScript.latin ||
  TextRecognitionScript.korean ||
  TextRecognitionScript.devanagiri => LatinScriptRules(),
  TextRecognitionScript.chinese ||
  TextRecognitionScript.japanese => CjkScriptRules(),
};


/// Shared sentence algorithm; scripts only differ in their [enders] and
/// [closers]. Returns [start, end) of the sentence containing [offset].
(int, int) findSentenceRange(
  String text,
  int offset, {
  required String enders,
  required String closers,
}) {
  // '\n' separates regions, so a sentence never crosses it.
  bool stops(String c) => c == '\n' || enders.contains(c);

  // walk back to just after the previous sentence's ender
  var start = offset;
  while (start > 0 && !stops(text[start - 1])) {
    start--;
  }
  // a closer right after that ender (e.g. 」) belongs to the previous sentence
  while (start < offset && closers.contains(text[start])) {
    start++;
  }

  // walk forward to this sentence's ender
  var end = offset;
  while (end < text.length && !stops(text[end])) {
    end++;
  }
  if (end < text.length && text[end] != '\n') end++; // include the ender itself
  // closers that follow it belong to this sentence
  while (end < text.length && closers.contains(text[end])) {
    end++;
  }

  return (start, end);
}
