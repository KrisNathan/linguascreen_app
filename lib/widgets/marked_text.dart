import 'package:flutter/material.dart';
import 'package:lingua_screen/api/models.dart';
import 'package:lingua_screen/theme.dart';

/// [sentence] with the runes at each of [spans] highlighted, as if marked
/// with a highlighter. Invalid spans are ignored.
TextSpan markedSentence(String sentence, Iterable<Span> spans) {
  final runes = sentence.runes.toList();
  final valid = [
    for (final s in spans)
      if (0 <= s.$1 && s.$1 < s.$2 && s.$2 <= runes.length) s,
  ]..sort((a, b) => a.$1.compareTo(b.$1));

  String slice(int a, int b) => String.fromCharCodes(runes.sublist(a, b));
  final children = <TextSpan>[];
  var at = 0;
  for (final (start, end) in valid) {
    if (end <= at) continue; // inside the previous mark
    final from = start < at ? at : start;
    if (from > at) children.add(TextSpan(text: slice(at, from)));
    children.add(
      TextSpan(
        text: slice(from, end),
        // A shorter box than the line, so the mark hugs the glyphs.
        style: const TextStyle(
          backgroundColor: Palette.highlighter,
          height: 1.25,
        ),
      ),
    );
    at = end;
  }
  if (at < runes.length) children.add(TextSpan(text: slice(at, runes.length)));
  return TextSpan(children: children);
}

/// [child] with a highlighter stroke behind it that sweeps in from the left
/// when [marked] turns true, and wipes away when it turns false.
class Sweep extends StatelessWidget {
  const Sweep({super.key, required this.marked, required this.child});

  final bool marked;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: marked ? 1 : 0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: FractionallySizedBox(
                widthFactor: t,
                heightFactor: 0.8,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: Palette.highlighter,
                    borderRadius: BorderRadius.all(Radius.circular(3)),
                  ),
                ),
              ),
            ),
          ),
          child!,
        ],
      ),
      child: child,
    );
  }
}
