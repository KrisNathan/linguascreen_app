import 'package:flutter/foundation.dart';
import 'package:lingua_screen/api/models.dart';

import 'ocr_controller.dart';
import 'page_text.dart';

enum AnalysisStatus { idle, loading, ready, failed }

/// One sentence of the page (or a range picked by hand) and its analysis.
class SentenceState {
  /// The sentence's units, inclusive.
  final (int, int) units;
  final String text;

  AnalysisStatus status = AnalysisStatus.idle;
  Analysis? analysis;
  Object? error;

  SentenceState({required this.units, required this.text});
}

/// Sentence selection on top of an [OcrController].
///
/// Picking a unit selects its whole sentence (mirrored into the controller's
/// selection, so [OCRCanvas] draws it) and has it analyzed. [selectRange]
/// does the same for any range, for when the guessed sentence is wrong.
/// Analyses are kept per page, so picking a sentence again costs nothing.
class SentenceReader extends ChangeNotifier {
  SentenceReader({required this.ocr, required this.analyze}) {
    ocr.addListener(_onOcrChanged);
  }

  final OcrController ocr;
  final Future<Analysis> Function(String sentence) analyze;

  final Map<(int, int), SentenceState> _sentences = {}; // by units
  PageText? _page;

  /// The page's sentences, the same ones [OCRCanvas] outlines.
  List<(int, int)> _spans = const [];
  SentenceState? _current;

  /// The selected sentence.
  SentenceState? get sentence => _current;

  /// Selects the sentence containing [unit], or clears the selection if null.
  void pick(int? unit) {
    final page = ocr.page;
    if (unit == null || page == null) {
      clear();
      return;
    }

    final (first, last) = _spans.firstWhere(
      (s) => s.$1 <= unit && unit <= s.$2,
      orElse: () => page.sentenceUnitSpan(unit, unit),
    );
    selectRange(first, last);
  }

  /// Selects units [first]..[last] (inclusive) and has them analyzed.
  void selectRange(int first, int last) {
    final page = ocr.page;
    if (page == null) return;

    final state = _sentences[(first, last)] ??= SentenceState(
      units: (first, last),
      text: page.textFor(first, last),
    );
    _current = state;
    ocr.select(first, last);
    notifyListeners();

    if (state.status == AnalysisStatus.idle) _analyze(state);
  }

  /// Analyzes the selected sentence again after a failure.
  void retry() {
    final state = _current;
    if (state != null && state.status == AnalysisStatus.failed) {
      _analyze(state);
    }
  }

  void clear() {
    if (_current == null) return;
    _current = null;
    ocr.clearSelection();
    notifyListeners();
  }

  Future<void> _analyze(SentenceState state) async {
    final page = ocr.page;
    state
      ..status = AnalysisStatus.loading
      ..error = null;
    notifyListeners();

    try {
      final analysis = await analyze(state.text);
      if (page != _page) return; // a new image was loaded meanwhile
      state
        ..analysis = analysis
        ..status = AnalysisStatus.ready;
    } catch (e) {
      if (page != _page) return;
      state
        ..error = e
        ..status = AnalysisStatus.failed;
    }
    notifyListeners();
  }

  void _onOcrChanged() {
    if (ocr.page == _page) return;
    _page = ocr.page;
    _spans = _page?.sentenceUnitSpans() ?? const [];
    _sentences.clear();
    _current = null;
    notifyListeners();
  }

  @override
  void dispose() {
    ocr.removeListener(_onOcrChanged);
    super.dispose();
  }
}
