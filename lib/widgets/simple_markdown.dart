import 'package:flutter/material.dart';

/// Renders the small markdown subset the explain endpoint returns:
/// `#` headings, `-`/`*` bullets, `**bold**`, and paragraphs.
class SimpleMarkdown extends StatelessWidget {
  const SimpleMarkdown(this.markdown, {super.key});

  final String markdown;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final children = <Widget>[];

    for (final raw in markdown.split('\n')) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        children.add(const SizedBox(height: 6));
      } else if (line.startsWith('#')) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 2),
            child: Text(
              line.replaceFirst(RegExp(r'^#+\s*'), ''),
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        );
      } else if (RegExp(r'^\s*[-*]\s+').hasMatch(line)) {
        final indent = line.length - line.trimLeft().length;
        children.add(
          Padding(
            padding: EdgeInsets.only(left: 4.0 + indent * 4, bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  '),
                Expanded(
                  child: _inline(
                    line.replaceFirst(RegExp(r'^\s*[-*]\s+'), ''),
                    text.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        children.add(_inline(line, text.bodyMedium));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  /// `**bold**` spans; other markers are shown as is.
  Widget _inline(String line, TextStyle? style) {
    final parts = line.split('**');
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          for (final (i, part) in parts.indexed)
            TextSpan(
              text: part,
              style: i.isOdd ? const TextStyle(fontWeight: FontWeight.bold) : null,
            ),
        ],
      ),
    );
  }
}
