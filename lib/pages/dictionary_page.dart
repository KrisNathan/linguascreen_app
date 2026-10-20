import 'package:flutter/material.dart';
import 'package:lingua_screen/api/api_client.dart';
import 'package:lingua_screen/api/models.dart';
import 'package:lingua_screen/session.dart';

/// The saved vocabs of the current course, last saved first.
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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
    final controller = TextEditingController(text: vocab.translation);
    final translation = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(vocab.dictForm),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 200,
          decoration: const InputDecoration(labelText: 'Translation'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dictionary'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Search words or translations...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.3,
                ),
              ),
            ),
          ),
          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      children: [
                        const SizedBox(height: 80),
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _items.isEmpty
                              ? 'No saved words yet.\nTap a word in a screenshot to save it.'
                              : 'No words found',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: items.length + (_loading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == items.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        return _VocabCard(
                          key: ValueKey(items[index].id),
                          vocab: items[index],
                          detail: _details[items[index].id],
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card.filled(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.book, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      '${_items.length}${_hasMore ? '+' : ''} words saved',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VocabCard extends StatefulWidget {
  const _VocabCard({
    super.key,
    required this.vocab,
    required this.detail,
    required this.onExpand,
    required this.onEdit,
    required this.onDelete,
  });

  final VocabItem vocab;
  final Future<VocabDetail>? detail;
  final ValueChanged<VocabItem> onExpand;
  final ValueChanged<VocabItem> onEdit;
  final ValueChanged<VocabItem> onDelete;

  @override
  State<_VocabCard> createState() => _VocabCardState();
}

class _VocabCardState extends State<_VocabCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vocab = widget.vocab;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card.filled(
        color: theme.colorScheme.primaryContainer,
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() => _expanded = !_expanded);
                if (_expanded) widget.onExpand(vocab);
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
                child: Row(
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
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (vocab.reading.isNotEmpty &&
                                    vocab.reading != vocab.dictForm)
                                  TextSpan(
                                    text: '  ${vocab.reading}',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                              ],
                            ),
                          ),
                          Text(vocab.translation),
                          const SizedBox(height: 4),
                          Text(
                            _progressLabel(vocab),
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => widget.onEdit(vocab),
                      tooltip: 'Edit translation',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => widget.onDelete(vocab),
                      tooltip: 'Delete word',
                    ),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded) ...[
              const Divider(height: 1),
              FutureBuilder(
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
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        error is ApiException
                            ? error.userMessage
                            : 'Could not load the examples.',
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final o in snapshot.data!.occurrences)
                        _OccurrenceTile(occurrence: o),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _progressLabel(VocabItem vocab) {
    final examples =
        '${vocab.occurrenceCount} example${vocab.occurrenceCount == 1 ? '' : 's'}';
    return switch (vocab.progress.state) {
      'known' => 'Known · $examples',
      'learning' => 'Learning, streak ${vocab.progress.streak} · $examples',
      _ => 'New · $examples',
    };
  }
}

class _OccurrenceTile extends StatelessWidget {
  const _OccurrenceTile({required this.occurrence});

  final Occurrence occurrence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final o = occurrence;
    final runes = o.sentence.runes.toList();
    String slice(int a, int b) => String.fromCharCodes(runes.sublist(a, b));
    final validSpan =
        0 <= o.span.$1 && o.span.$1 < o.span.$2 && o.span.$2 <= runes.length;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The saved word highlighted inside its sentence.
          Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 16),
              children: validSpan
                  ? [
                      TextSpan(text: slice(0, o.span.$1)),
                      TextSpan(
                        text: slice(o.span.$1, o.span.$2),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          backgroundColor: theme.colorScheme.primaryContainer,
                        ),
                      ),
                      TextSpan(text: slice(o.span.$2, runes.length)),
                    ]
                  : [TextSpan(text: o.sentence)],
            ),
          ),
          if (o.sentenceTranslation.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              o.sentenceTranslation,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            '${o.surface} · ${o.translation}',
            style: theme.textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}
