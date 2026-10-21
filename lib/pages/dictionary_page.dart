import 'package:flutter/material.dart';
import 'package:lingua_screen/api/api_client.dart';
import 'package:lingua_screen/api/models.dart';
import 'package:lingua_screen/dates.dart';
import 'package:lingua_screen/session.dart';
import 'package:lingua_screen/theme.dart';
import 'package:lingua_screen/widgets/marked_text.dart';

/// The saved vocabs of the current course, last saved first and grouped by
/// the day they were saved.
class DictionaryPage extends StatefulWidget {
  const DictionaryPage({super.key});

  @override
  State<DictionaryPage> createState() => _DictionaryPageState();
}

class _DictionaryPageState extends State<DictionaryPage> {
  final _api = ApiClient.instance;
  final _scroll = ScrollController();

  final List<VocabItem> _items = [];
  String? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;
  String _query = '';

  /// Occurrences of expanded vocabs, by vocab id.
  final Map<String, Future<VocabDetail>> _details = {};

  String? get _courseId => Session.instance.course?.id;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) _loadMore();
    });
    _loadMore();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _details.clear();
      _cursor = null;
      _hasMore = true;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    final courseId = _courseId;
    if (_loading || !_hasMore || courseId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _api.listVocabs(courseId, cursor: _cursor);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.nextCursor != null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.userMessage);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Search only covers the loaded pages; the API has no search yet.
  List<VocabItem> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items
        .where(
          (v) =>
              v.dictForm.toLowerCase().contains(q) ||
              v.reading.toLowerCase().contains(q) ||
              v.translation.toLowerCase().contains(q),
        )
        .toList();
  }

  Future<void> _delete(VocabItem vocab) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete word'),
        content: Text(
          'Delete "${vocab.dictForm}" and its example sentences? Its practice '
          'history is lost too.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _api.deleteVocab(vocab.id);
      if (!mounted) return;
      setState(() {
        _items.removeWhere((v) => v.id == vocab.id);
        _details.remove(vocab.id);
      });
      _snack('Word deleted');
    } on ApiException catch (e) {
      _snack(e.userMessage);
    }
  }

  Future<void> _editTranslation(VocabItem vocab) async {
    final translation = await showDialog<String>(
      context: context,
      builder: (context) => _MeaningDialog(vocab: vocab),
    );
    if (translation == null ||
        translation.trim().isEmpty ||
        translation == vocab.translation) {
      return;
    }

    try {
      final updated = await _api.updateVocabTranslation(vocab.id, translation);
      if (!mounted) return;
      setState(() {
        final i = _items.indexWhere((v) => v.id == vocab.id);
        if (i >= 0) _items[i] = updated;
      });
    } on ApiException catch (e) {
      _snack(e.userMessage);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _filtered;
    final language = Session.instance.course?.learningLanguage;
    final count = '${_items.length}${_hasMore ? '+' : ''}';

    // Day headers between entries saved on different days.
    final rows = <Object>[];
    String? day;
    for (final v in items) {
      final d = savedOn(v.lastSavedAt);
      if (d != day) rows.add(day = d);
      rows.add(v);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: _items.isEmpty ? 'Search words' : 'Search $count words',
              prefixIcon: const Icon(Icons.search),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        if (_error != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
            color: theme.colorScheme.errorContainer,
            child: Row(
              children: [
                Expanded(child: Text(_error!)),
                TextButton(onPressed: _loadMore, child: const Text('Retry')),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: items.isEmpty && !_loading
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
                    children: [
                      Text(
                        _items.isEmpty ? 'No saved words yet' : 'No matches',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _items.isEmpty
                            ? 'Tap a word in a captured screen to save it.'
                            : 'Search covers the words loaded so far.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: rows.length + (_loading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == rows.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final row = rows[index];
                      if (row is String) return _DayHeader(row);
                      final vocab = row as VocabItem;
                      return _VocabEntry(
                        key: ValueKey(vocab.id),
                        vocab: vocab,
                        language: language,
                        detail: _details[vocab.id],
                        onExpand: (vocab) => setState(() {
                          _details[vocab.id] ??= _api.getVocab(vocab.id);
                        }),
                        onEdit: _editTranslation,
                        onDelete: _delete,
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// One dictionary entry: the word, its reading and meaning, and how well
/// it is known. Tapping it opens the sentences it was saved from.
class _VocabEntry extends StatefulWidget {
  const _VocabEntry({
    super.key,
    required this.vocab,
    required this.language,
    required this.detail,
    required this.onExpand,
    required this.onEdit,
    required this.onDelete,
  });

  final VocabItem vocab;
  final String? language;
  final Future<VocabDetail>? detail;
  final ValueChanged<VocabItem> onExpand;
  final ValueChanged<VocabItem> onEdit;
  final ValueChanged<VocabItem> onDelete;

  @override
  State<_VocabEntry> createState() => _VocabEntryState();
}

class _VocabEntryState extends State<_VocabEntry> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final soft = theme.colorScheme.onSurfaceVariant;
    final vocab = widget.vocab;
    final language = widget.language;

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Palette.rule)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() => _expanded = !_expanded);
              if (_expanded) widget.onExpand(vocab);
            },
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 4, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: vocab.dictForm,
                                style: learned(
                                  language,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (vocab.reading.isNotEmpty &&
                                  vocab.reading != vocab.dictForm)
                                TextSpan(
                                  text: '  ${vocab.reading}',
                                  style: learned(
                                    language,
                                    fontSize: 15,
                                    color: soft,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          vocab.translation,
                          style: theme.textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 6),
                        _StateMark(vocab),
                      ],
                    ),
                  ),
                  PopupMenuButton<void>(
                    tooltip: 'Word options',
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        onTap: () => widget.onEdit(vocab),
                        child: const Text('Edit meaning'),
                      ),
                      PopupMenuItem(
                        onTap: () => widget.onDelete(vocab),
                        child: Text(
                          'Delete',
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _expanded
                ? _examples(theme)
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _examples(ThemeData theme) {
    return FutureBuilder(
      future: widget.detail,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          final error = snapshot.error;
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              error is ApiException
                  ? error.userMessage
                  : 'Could not load the examples.',
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(
            children: [
              for (final o in snapshot.data!.occurrences)
                _OccurrenceTile(occurrence: o, language: widget.language),
            ],
          ),
        );
      },
    );
  }
}

/// How well the vocab is known, and how many sentences it was saved from.
class _StateMark extends StatelessWidget {
  const _StateMark(this.vocab);

  final VocabItem vocab;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final n = vocab.occurrenceCount;
    final examples = '$n sentence${n == 1 ? '' : 's'}';
    final (String label, Color dot) = switch (vocab.progress.state) {
      'known' => ('Known', Palette.leaf),
      'learning' => (
        vocab.progress.streak > 0
            ? 'Learning, ${vocab.progress.streak} in a row'
            : 'Learning',
        Palette.inkSoft,
      ),
      _ => ('New', Palette.outline),
    };
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            '$label · $examples',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _OccurrenceTile extends StatelessWidget {
  const _OccurrenceTile({required this.occurrence, required this.language});

  final Occurrence occurrence;
  final String? language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final soft = theme.colorScheme.onSurfaceVariant;
    final o = occurrence;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The saved word marked inside its sentence.
          Text.rich(
            markedSentence(o.sentence, [o.span]),
            style: learned(language, fontSize: 17, height: 1.6),
          ),
          if (o.sentenceTranslation.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              o.sentenceTranslation,
              style: theme.textTheme.bodyMedium?.copyWith(color: soft),
            ),
          ],
          if (o.translation.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Here: ${o.translation}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 13,
                color: soft,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Edits a vocab's meaning. Pops the new text, or null when cancelled.
///
/// Owns its controller, so the controller lives until the dialog's exit
/// animation is done.
class _MeaningDialog extends StatefulWidget {
  const _MeaningDialog({required this.vocab});

  final VocabItem vocab;

  @override
  State<_MeaningDialog> createState() => _MeaningDialogState();
}

class _MeaningDialogState extends State<_MeaningDialog> {
  late final _controller = TextEditingController(
    text: widget.vocab.translation,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.vocab.dictForm,
        style: learned(
          Session.instance.course?.learningLanguage,
          fontSize: 26,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 200,
        decoration: const InputDecoration(labelText: 'Meaning'),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
