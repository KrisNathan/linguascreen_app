import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lingua_screen/ocr/page_text.dart';
import 'package:lingua_screen/ocr/script_rules.dart';

/// One unit per character of [text], skipping spaces and line breaks like
/// PageTextBuilder does.
PageText page(String text, ScriptRules rules) {
  final units = <Unit>[];
  for (var i = 0; i < text.length; i++) {
    if (text[i] == ' ' || text[i] == '\n') continue;
    units.add(
      Unit(
        char: text[i],
        rect: Rect.fromLTWH(i * 10.0, 0, 10, 10),
        offset: i,
        lineIdx: 0,
        isVertical: false,
      ),
    );
  }
  return PageText(text: text, units: units, scriptRules: rules);
}

void main() {
  test('Latin sentences', () {
    final p = page('Hi there. How are you?\nNew region', LatinScriptRules());
    final sentences = [
      for (final (a, b) in p.sentenceUnitSpans()) p.textFor(a, b),
    ];
    expect(sentences, ['Hi there.', 'How are you?', 'New region']);
  });

  test('CJK sentences keep closing quotes', () {
    final p = page('「行こう。」と言った。本を読む', CjkScriptRules());
    final sentences = [
      for (final (a, b) in p.sentenceUnitSpans()) p.textFor(a, b),
    ];
    expect(sentences, ['「行こう。」', 'と言った。', '本を読む']);
  });
}
