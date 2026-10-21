import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lingua_screen/api/api_client.dart';
import 'package:lingua_screen/api/models.dart';
import 'package:lingua_screen/session.dart';
import 'package:lingua_screen/theme.dart';
import 'package:lingua_screen/widgets/message_view.dart';
import 'package:lingua_screen/widgets/progress_bar.dart';
import 'package:lingua_screen/widgets/score_view.dart';

/// Multiple choice questions about the saved vocabs. The server keeps the
/// session and grades every answer, so leaving and coming back resumes it.
class QuizPage extends StatefulWidget {
  const QuizPage({super.key});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final _api = ApiClient.instance;

  bool _loading = true;
  String? _error;

  List<QuizQuestion> _questions = [];
  QuizScore _score = const QuizScore(correct: 0, answered: 0, total: 0);
  int _index = 0;
  int? _selected;
  bool _submitting = false;

  /// The graded answer to the current question, null until submitted.
  QuizAnswer? _answer;

  bool get _completed => _questions.isNotEmpty && _index >= _questions.length;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final courseId = Session.instance.course?.id;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (courseId == null) throw const ApiException(0, 'no course selected');
      final session = await _api.startQuiz(courseId);
      if (!mounted) return;
      setState(() {
        _questions = session.questions;
        _score = session.score;
        _index = 0;
        _selected = null;
        _answer = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.userMessage);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final selected = _selected;
    if (selected == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      final answer = await _api.submitQuiz(_questions[_index].id, selected);
      if (!mounted) return;
      answer.correct
          ? HapticFeedback.lightImpact()
          : HapticFeedback.mediumImpact();
      setState(() {
        _answer = answer;
        _score = answer.score;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      // 409: the session expired (24 hours), only a new one can continue.
      if (e.statusCode == 409) {
        setState(() => _error = 'This quiz has expired. Start a new one.');
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.userMessage)));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _next() {
    setState(() {
      _index++;
      _selected = null;
      _answer = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz'),
        actions: [
          if (!_loading &&
              _error == null &&
              _questions.isNotEmpty &&
              !_completed)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_score.answered}/${_score.total}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return MessageView(
        icon: Icons.error_outline,
        text: _error!,
        action: 'Try again',
        onAction: _start,
      );
    }
    if (_questions.isEmpty) {
      return const MessageView(
        icon: Icons.quiz_outlined,
        text: 'Nothing to practice yet.\nSave some words first.',
      );
    }
    if (_completed) return _results();
    return _question(_questions[_index]);
  }

  Widget _question(QuizQuestion q) {
    final answer = _answer;
    final total = _score.total == 0 ? 1 : _score.total;

    return SafeArea(
      top: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: ProgressBar(value: _score.answered / total),
          ),
          Expanded(
            // The next question slides in from the right, the answered one
            // leaves to the left.
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              reverseDuration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final incoming = child.key == ValueKey(q.id);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(
                      begin: Offset(incoming ? 0.15 : -0.15, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: ListView(
                key: ValueKey(q.id),
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                      child: _prompt(q),
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final (i, option) in q.options.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _OptionTile(
                        letter: String.fromCharCode(65 + i),
                        label: option,
                        // Meaning options are in the user's own language.
                        language: q.type == 'translation' ? null : _language,
                        selected: _selected == i,
                        // Colors only once graded.
                        correct: answer == null
                            ? null
                            : i == answer.correctIndex,
                        onTap: answer == null && !_submitting
                            ? () {
                                HapticFeedback.selectionClick();
                                setState(() => _selected = i);
                              }
                            : null,
                      ),
                    ),
                  if (answer != null) ...[
                    const SizedBox(height: 8),
                    _Feedback(answer: answer, type: q.type),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                onPressed: answer != null
                    ? _next
                    : (_selected != null && !_submitting ? _submit : null),
                child: Text(
                  answer == null
                      ? 'Check'
                      : (answer.sessionCompleted ? 'See results' : 'Next'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? get _language => Session.instance.course?.learningLanguage;

  Widget _prompt(QuizQuestion q) {
    final theme = Theme.of(context);
    final hint = TextStyle(color: theme.colorScheme.onSurfaceVariant);
    final big = learned(_language, fontSize: 34, fontWeight: FontWeight.w600);

    return switch (q.type) {
      'fill_blank' => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Which word fills the blank?', style: hint),
          const SizedBox(height: 12),
          Text.rich(
            _blanked(
              q.sentence,
              q.span,
              revealed: _answer != null,
              highlight: const TextStyle(backgroundColor: Palette.highlighter),
            ),
            style: learned(_language, fontSize: 22, height: 1.7),
          ),
        ],
      ),
      'reading' => Column(
        children: [
          Text('How is this word read?', style: hint),
          const SizedBox(height: 12),
          Text(q.dictForm, style: big, textAlign: TextAlign.center),
        ],
      ),
      _ => Column(
        children: [
          Text('What does this word mean?', style: hint),
          const SizedBox(height: 12),
          Text(q.dictForm, style: big, textAlign: TextAlign.center),
          if (q.reading.isNotEmpty && q.reading != q.dictForm)
            Text(
              q.reading,
              style: learned(
                _language,
                fontSize: 17,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    };
  }

  /// [sentence] with the runes at [span] replaced by a blank, until
  /// [revealed], then set in [highlight].
  static TextSpan _blanked(
    String sentence,
    Span? span, {
    required bool revealed,
    required TextStyle highlight,
  }) {
    final runes = sentence.runes.toList();
    if (span == null ||
        span.$1 < 0 ||
        span.$1 >= span.$2 ||
        span.$2 > runes.length) {
      return TextSpan(text: sentence);
    }
    final before = String.fromCharCodes(runes.sublist(0, span.$1));
    final word = String.fromCharCodes(runes.sublist(span.$1, span.$2));
    final after = String.fromCharCodes(runes.sublist(span.$2));
    return TextSpan(
      children: [
        TextSpan(text: before),
        revealed
            ? TextSpan(text: word, style: highlight)
            // One unbreakable slot, so the blank never wraps on its own.
            : const WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: Text('\u00A0＿＿＿\u00A0'),
              ),
        TextSpan(text: after),
      ],
    );
  }

  Widget _results() {
    return ScoreView(
      title: 'Quiz complete',
      correct: _score.correct,
      total: _score.total,
      caption: 'answered correctly',
      action: 'New quiz',
      onAction: _start,
    );
  }
}

const _success = Palette.leaf;
const _successContainer = Palette.leafWash;

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.letter,
    required this.label,
    required this.language,
    required this.selected,
    required this.correct,
    required this.onTap,
  });

  final String letter;
  final String label;

  /// Set when [label] is in the language being learned.
  final String? language;
  final bool selected;

  /// Null until graded.
  final bool? correct;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final graded = correct != null;
    final wrong = correct == false && selected;

    final (
      Color fill,
      Color edge,
      Color badge,
      Color onBadge,
    ) = switch (correct) {
      true => (_successContainer, _success, _success, Palette.raised),
      false when selected => (
        scheme.errorContainer,
        scheme.error,
        scheme.error,
        scheme.onError,
      ),
      // Yellow is for words; a picked option is marked in ink.
      _ when selected => (
        scheme.surfaceContainerLowest,
        scheme.primary,
        scheme.primary,
        scheme.onPrimary,
      ),
      _ => (
        scheme.surfaceContainerLowest,
        scheme.outlineVariant,
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
    };
    final emphasized = selected || correct == true;
    final edgeWidth = emphasized ? 2.0 : 1.0;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: edge, width: edgeWidth),
    );

    return AnimatedOpacity(
      // Once graded, the options that don't matter step back.
      opacity: graded && !emphasized ? 0.7 : 1,
      duration: const Duration(milliseconds: 200),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: ShapeDecoration(color: fill, shape: shape),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            customBorder: shape,
            child: Padding(
              // Absorbs the thicker edge, so the content doesn't shift.
              padding: EdgeInsets.symmetric(
                horizontal: 13 - edgeWidth,
                vertical: 15 - edgeWidth,
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: badge,
                      shape: BoxShape.circle,
                    ),
                    child: correct == true
                        ? Icon(Icons.check, size: 20, color: onBadge)
                        : wrong
                        ? Icon(Icons.close, size: 20, color: onBadge)
                        : Text(
                            letter,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: onBadge,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: language == null
                          ? const TextStyle(fontSize: 16)
                          : learned(language, fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The verdict, plus what the options didn't already show: the vocab for
/// reading and fill in the blank questions, and the sentence's meaning.
class _Feedback extends StatelessWidget {
  const _Feedback({required this.answer, required this.type});

  final QuizAnswer answer;
  final String type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final a = answer;
    final color = a.correct ? _success : scheme.error;
    final showVocab = type != 'translation';
    final sentence = a.sentenceTranslation ?? '';
    final bare = !showVocab && sentence.isEmpty;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - t)),
          child: child,
        ),
      ),
      // Just the verdict needs no box around it.
      child: Container(
        padding: bare
            ? const EdgeInsets.symmetric(horizontal: 4, vertical: 4)
            : const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bare ? null : scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  a.correct ? Icons.check_circle : Icons.cancel,
                  size: 20,
                  color: color,
                ),
                const SizedBox(width: 8),
                Text(
                  a.correct ? 'Correct' : 'Not quite',
                  style: theme.textTheme.titleSmall?.copyWith(color: color),
                ),
              ],
            ),
            if (showVocab) ...[
              const SizedBox(height: 12),
              Text(
                a.reading.isNotEmpty && a.reading != a.dictForm
                    ? '${a.dictForm} · ${a.reading}'
                    : a.dictForm,
                style: learned(
                  Session.instance.course?.learningLanguage,
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(a.translation, style: theme.textTheme.bodyLarge),
            ],
            if (sentence.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                sentence,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
