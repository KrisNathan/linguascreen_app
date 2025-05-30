import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:overlay_test/models/ocr_word.dart';

class OcrWordSelector extends StatefulWidget {
  final List<OcrWord> words;
  final Widget image;
  final Size originalSize;

  const OcrWordSelector({
    super.key,
    required this.words,
    required this.image,
    required this.originalSize,
  });

  @override
  State<OcrWordSelector> createState() => _OcrWordSelectorState();
}

class _OcrWordSelectorState extends State<OcrWordSelector> {
  final List<OcrWord> selectedWords = [];

  void toggleSelection(OcrWord word) {
    setState(() {
      word.isSelected = !word.isSelected;
      if (word.isSelected) {
        selectedWords.add(word);
      } else {
        selectedWords.remove(word);
      }
    });

    for (var word in selectedWords) {
      log(word.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.image,
        ...widget.words.map((word) {
          final rect = word.boundingBox;

          return Positioned(
            left: rect.left,
            top: rect.top,
            width: rect.width,
            height: rect.height,
            child: GestureDetector(
              onTap: () => toggleSelection(word),
              child: Container(
                decoration: BoxDecoration(
                  color: word.isSelected ? Colors.blue.withOpacity(0.3) : null,
                  border: Border.all(color: Colors.blue),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  String getSelectedText() {
    return selectedWords.map((w) => w.text).join('');
  }
}
