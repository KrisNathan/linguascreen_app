import 'package:flutter/material.dart';
import 'package:lingua_screen/api/api_client.dart';
import 'package:lingua_screen/api/models.dart';
import 'package:lingua_screen/ocr/sentence_reader.dart';
import 'package:lingua_screen/theme.dart';
import 'package:lingua_screen/widgets/marked_text.dart';
import 'package:lingua_screen/widgets/simple_markdown.dart';

/// The popup for the sentence picked in a [SentenceReader]: its words (as
/// tokenized by `/analyze`) to tap, its translation, the tapped word, and
/// actions to save the word or explain the sentence.
///
/// Meant for a [DraggableScrollableSheet], which provides [scrollController].
class SentenceSheet extends StatefulWidget {
  const SentenceSheet({
    super.key,
    required this.reader,
    required this.course,
    required this.scrollController,
  });

  final SentenceReader reader;
  final Course course;
  final ScrollController scrollController;

  @override
  State<SentenceSheet> createState() => _SentenceSheetState();
}

class _SentenceSheetState extends State<SentenceSheet> {
  /// Explanations asked for on this page, by normalized sentence.
  final _explanations = <String, Future<String>>{};

  /// Words saved on this page, see [_saveKey].
  final _saved = <String>{};
  bool _saving = false;

  /// The tapped token, and optionally one of its parts.
  int? _token;
  int? _part;

  SentenceReader get _reader => widget.reader;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: ListenableBuilder(
        listenable: _reader,
        builder: (context, _) {
          final sentence = _reader.sentence;
          return ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (sentence != null)
                ...switch (sentence.status) {
                  AnalysisStatus.idle ||
                  AnalysisStatus.loading => _loading(sentence, theme),
                  AnalysisStatus.failed => _failed(sentence, theme),
                  AnalysisStatus.ready => _ready(sentence.analysis!, theme),
                },
            ],
          );
        },
      ),
    );
  }

  TextStyle get _sentenceStyle =>
      learned(widget.course.learningLanguage, fontSize: 24, height: 1.6);

  List<Widget> _loading(SentenceState sentence, ThemeData theme) => [
    Text(sentence.text, style: _sentenceStyle),
    const SizedBox(height: 12),
    const LinearProgressIndicator(),
    const SizedBox(height: 8),
    Text('Translating sentence…', style: theme.textTheme.bodySmall),
  ];

  List<Widget> _failed(SentenceState sentence, ThemeData theme) {
    final error = sentence.error;
    return [
      Text(sentence.text, style: _sentenceStyle),
      const SizedBox(height: 12),
      Text(
        error is ApiException
            ? error.userMessage
            : 'Something went wrong while translating.',
        style: TextStyle(color: theme.colorScheme.error),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: _reader.retry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ),
    ];
  }

  List<Widget> _ready(Analysis analysis, ThemeData theme) {
    final i = _token;
    final token = i == null ? null : analysis.tokens[i];
    return [
      if (analysis.languageMismatch)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _Banner(
            text:
                'This doesn\'t look like ${languageName(widget.course.learningLanguage)}.',
          ),
        ),
      _tokens(analysis, theme),
      const SizedBox(height: 8),
      Text(
        analysis.translation,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          height: 1.5,
        ),
      ),
      const Divider(height: 32),
      if (token != null)
        _word(analysis, token, theme)
      else
        Text(
          'Tap a word to see what it means.',
          style: theme.textTheme.bodyMedium,
        ),
      const SizedBox(height: 8),
      _explanation(analysis, theme),
    ];
  }

  /// The sentence, every saveable token tappable. The tapped one gets a
  /// highlighter stroke.
  Widget _tokens(Analysis analysis, ThemeData theme) {
    final style = _sentenceStyle;

    // Closing punctuation wraps with the word before it, so a line never
    // starts with 。 or ).
    final chunks = <List<Widget>>[];
    for (final (i, t) in analysis.tokens.indexed) {
      final word = t.saveable
          ? _wordToken(i, t, style)
          : Text(t.surface, style: style);
      if (!t.saveable && chunks.isNotEmpty && _closing.hasMatch(t.surface)) {
        chunks.last.add(word);
      } else {
        chunks.add([word]);
      }
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final chunk in chunks)
          chunk.length == 1
              ? chunk.single
              : Row(mainAxisSize: MainAxisSize.min, children: chunk),
      ],
    );
  }

  /// Only closing punctuation, which may not start a line.
  static final _closing = RegExp(r'^[、。，．,.!?！？:;：；)\]）］」』】〕〉》”’…・]+$');

  /// A tappable word, swept with the highlighter while selected.
  Widget _wordToken(int i, Token t, TextStyle style) => InkWell(
    borderRadius: BorderRadius.circular(4),
    onTap: () => setState(() {
      _token = i;
      _part = null;
    }),
    child: Sweep(
      marked: i == _token,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Palette.inkFaint, width: 2)),
        ),
        child: Text(t.surface, style: style),
      ),
    ),
  );

  /// The selected token, or one of its parts.
  Widget _word(Analysis analysis, Token token, ThemeData theme) {
    if (!token.saveable) {
      return Text(
        '“${token.surface}” is a grammar word, number or symbol, so it has no '
        'dictionary entry. Explain the sentence to learn how it is used.',
        style: theme.textTheme.bodyMedium,
      );
    }

    final p = _part;
    final part = p == null ? null : token.parts[p];
    final dictForm = part?.dictForm ?? token.dictForm;
    final reading = part?.reading ?? token.reading;
    final translation = part?.translation ?? token.translation;
    final surface = part?.surface ?? token.surface;
    final span = part?.span ?? token.span;
    final key = _saveKey(analysis, span, part != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dictForm,
                    style: learned(
                      widget.course.learningLanguage,
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (reading.isNotEmpty && reading != dictForm)
                    Text(
                      reading,
                      style: learned(
                        widget.course.learningLanguage,
                        fontSize: 17,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (surface != dictForm)
                    Text(
                      'as “$surface”',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(translation, style: theme.textTheme.bodyLarge),
                ],
              ),
            ),
            _saved.contains(key)
                ? FilledButton.tonalIcon(
                    onPressed: null,
                    icon: const Icon(Icons.check),
                    label: const Text('Saved'),
                  )
                : FilledButton.icon(
                    onPressed: _saving
                        ? null
                        : () => _save(
                            analysis,
                            span: span,
                            fromPart: part != null,
                            dictForm: dictForm,
                            reading: reading,
                            translation: translation,
                          ),
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.bookmark_add_outlined),
                    label: const Text('Save'),
                  ),
          ],
        ),
        if (token.parts.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ChoiceChip(
                label: Text(token.surface),
                selected: _part == null,
                onSelected: (_) => setState(() => _part = null),
              ),
              for (final (i, p) in token.parts.indexed)
                ChoiceChip(
                  label: Text('${p.surface} · ${p.translation}'),
                  selected: _part == i,
                  onSelected: (_) => setState(() => _part = i),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _explanation(Analysis analysis, ThemeData theme) {
    final future = _explanations[analysis.sentence];
    if (future == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () => setState(() {
            _explanations[analysis.sentence] = ApiClient.instance.explain(
              widget.course.id,
              analysis,
            );
          }),
          icon: const Icon(Icons.lightbulb_outline),
          label: const Text('Explain sentence'),
        ),
      );
    }

    return FutureBuilder(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Explaining… this can take a few seconds'),
              ],
            ),
          );
        }
        if (snapshot.hasError) {
          final error = snapshot.error;
          return Row(
            children: [
              Expanded(
                child: Text(
                  error is ApiException
                      ? error.userMessage
                      : 'Could not explain this sentence.',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _explanations.remove(analysis.sentence);
                }),
                child: const Text('Retry'),
              ),
            ],
          );
        }
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SimpleMarkdown(snapshot.data!),
        );
      },
    );
  }

  Future<void> _save(
    Analysis analysis, {
    required Span span,
    required bool fromPart,
    required String dictForm,
    required String reading,
    required String translation,
  }) async {
    final course = widget.course;
    if (analysis.languageMismatch && !await _confirmMismatch(course)) return;

    setState(() => _saving = true);
    String message;
    try {
      final saved = await ApiClient.instance.saveVocab(
        courseId: course.id,
        analysis: analysis,
        span: span,
        fromPart: fromPart,
        dictForm: dictForm,
        reading: reading,
        translation: translation,
      );
      _saved.add(_saveKey(analysis, span, fromPart));
      message = saved.message;
    } on ApiException catch (e) {
      message = e.userMessage;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirmMismatch(Course course) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save anyway?'),
        content: Text(
          'This sentence doesn\'t look like '
          '${languageName(course.learningLanguage)}. The word will be saved '
          'to your ${course.label} course.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  static String _saveKey(Analysis analysis, Span span, bool fromPart) =>
      '${analysis.sentence}|${span.$1}|${span.$2}|$fromPart';
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: scheme.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}
