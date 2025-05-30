import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:overlay_test/models/ocr_word.dart';

class OcrWordSelector extends StatefulWidget {
  final List<OcrWord> words;
  final Widget image;
  final void Function(DragEndDetails details) onDragEnd;

  const OcrWordSelector({
    super.key,
    required this.words,
    required this.image,
    required this.onDragEnd,
  });

  @override
  State<OcrWordSelector> createState() => _OcrWordSelectorState();
}

class _OcrWordSelectorState extends State<OcrWordSelector> {
  final Set<OcrWord> selectedWords = {};

  void _handleDrag(Offset position) {
    for (var word in widget.words) {
      if (!word.isSelected && word.boundingBox.contains(position)) {
        setState(() {
          word.isSelected = true;
          selectedWords.add(word);
        });
      }
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    log(getSelectedText());
    widget.onDragEnd(details);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) {
        setState(() {
          for (var selectedWord in selectedWords) {
            selectedWord.isSelected = false;
          }
          selectedWords.clear();
        });
      },
      onPanUpdate: (details) {
        final RenderBox renderBox = context.findRenderObject() as RenderBox;
        final localPosition = renderBox.globalToLocal(details.globalPosition);
        _handleDrag(localPosition);
      },
      onPanEnd: _handleDragEnd,
      child: Stack(
        children: [
          widget.image,
          ...widget.words.map((word) {
            final rect = word.boundingBox;
            return Positioned(
              left: rect.left,
              top: rect.top,
              width: rect.width,
              height: rect.height,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(8.0)),
                  color:
                      word.isSelected
                          ? Colors.blue.withValues(alpha: .3)
                          : null,
                  border: Border.all(color: Colors.blue),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  String getSelectedText() {
    return widget.words
        .where((word) => word.isSelected)
        .map((w) => w.text)
        .join(' ');
  }
}
