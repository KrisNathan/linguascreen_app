// THIS IS JUST EXAMPLE

import 'package:flutter/material.dart';
import 'package:lingua_screen/ocr/widgets/ocr_canvas.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import 'loaded_image.dart';
import 'ocr_controller.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _ocr = OcrController();

  final _camera = PickerOrigin(ImageSource.camera);
  final _gallery = PickerOrigin(ImageSource.gallery);

  @override
  void dispose() {
    _ocr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MLKit OCR')),
      body: Container(
        margin: EdgeInsets.all(16.0),
        child: ListenableBuilder(
          listenable: _ocr,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_ocr.image case final loaded?)
                Expanded(
                  child: OCRCanvas(
                    image: loaded.image,
                    page: _ocr.page,
                    selStart: _ocr.selStart,
                    selEnd: _ocr.selEnd,
                    onPick: (unit) => _ocr.select(unit, unit),
                    onAdjust: _ocr.select,
                    onAdjustEnd: () {},
                  ),
                ),
              if (_ocr.isBusy) const LinearProgressIndicator(),
              Wrap(
                direction: Axis.horizontal,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                    onPressed: () => _ocr.load(_camera),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.image),
                    label: const Text('Gallery'),
                    onPressed: () => _ocr.load(_gallery),
                  ),
                  DropdownMenu(
                    initialSelection: _ocr.script,
                    dropdownMenuEntries: TextRecognitionScript.values
                        .map((e) => DropdownMenuEntry(value: e, label: e.name))
                        .toList(),
                    onSelected: (value) {
                      if (value != null) _ocr.script = value;
                    },
                  ),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      if (_ocr.hasSelection) ...[
                        Text("Selection: ${_ocr.selectedText}"),
                        Text("Sentence: ${_ocr.selectedSentence}"),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
