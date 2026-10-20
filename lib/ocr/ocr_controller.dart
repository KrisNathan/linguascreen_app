import 'package:flutter/widgets.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'loaded_image.dart';
import 'ocr_engine.dart';
import 'page_text.dart';

/// The state of one OCR screen: the shown image, its text and the selection.
///
/// Owns the [LoadedImage] it shows and frees it when replaced or disposed.
/// Pair it with [OCRCanvas]; the rest of the UI is up to the app.
class OcrController extends ChangeNotifier {
  OcrController({
    OcrEngine? engine,
    this._script = TextRecognitionScript.latin,
  }) : _engine = engine ?? OcrEngine();

  final OcrEngine _engine;

  LoadedImage? _image;
  PageText? _page;
  int? _selStart;
  int? _selEnd;
  TextRecognitionScript _script;
  bool _isBusy = false;
  bool _disposed = false;

  /// Bumped on every [load]; a load whose number is no longer current lost
  /// the race to a newer one and its result is dropped.
  int _loadId = 0;

  LoadedImage? get image => _image;
  PageText? get page => _page;
  int? get selStart => _selStart;
  int? get selEnd => _selEnd;
  bool get isBusy => _isBusy;
  bool get hasSelection => _page != null && _selStart != null && _selEnd != null;

  /// Script used by the next [load]. Changing it does not re-run OCR.
  TextRecognitionScript get script => _script;
  set script(TextRecognitionScript value) {
    if (value == _script) return;
    _script = value;
    notifyListeners();
  }

  String? get selectedText =>
      hasSelection ? _page!.textFor(_selStart!, _selEnd!) : null;

  String? get selectedSentence =>
      hasSelection ? _page!.sentenceFor(_selStart!, _selEnd!) : null;

  /// Picks an image from [origin] and runs OCR on it.
  ///
  /// Does nothing if the user cancels. Errors from picking or OCR are rethrown
  /// and leave the current image and text as they were.
  Future<void> load(ImageOrigin origin) async {
    final loaded = await origin.pick();
    if (loaded == null) return;
    if (_disposed) {
      loaded.dispose();
      return;
    }
    final id = ++_loadId;

    // The script may change while OCR runs, so read it once.
    final script = _script;
    _setBusy(true);
    final PageText? page;
    try {
      page = await _engine.recognize(loaded, script);
    } catch (_) {
      loaded.dispose();
      rethrow;
    } finally {
      if (id == _loadId) _setBusy(false);
    }
    if (id != _loadId || _disposed) {
      loaded.dispose();
      return;
    }
    debugPrint("PageText (${script.name}): ${page?.text}");

    final previous = _image;
    _image = loaded;
    _page = page;
    _selStart = null;
    _selEnd = null;
    notifyListeners();
    _disposeAfterFrame(previous);
  }

  void select(int? start, int? end) {
    if (start == _selStart && end == _selEnd) return;
    _selStart = start;
    _selEnd = end;
    notifyListeners();
  }

  void clearSelection() => select(null, null);

  void _setBusy(bool value) {
    if (_disposed || value == _isBusy) return;
    _isBusy = value;
    notifyListeners();
  }

  /// Frees [image] only after the frame that stops showing it.
  void _disposeAfterFrame(LoadedImage? image) {
    if (image == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => image.dispose());
  }

  @override
  void dispose() {
    _disposed = true;
    _disposeAfterFrame(_image);
    _image = null;
    super.dispose();
  }
}
