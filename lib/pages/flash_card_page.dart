import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lingua_screen/api/api_client.dart';
import 'package:lingua_screen/api/models.dart';
import 'package:lingua_screen/session.dart';
import 'package:lingua_screen/theme.dart';
import 'package:lingua_screen/widgets/message_view.dart';
import 'package:lingua_screen/widgets/progress_bar.dart';
import 'package:lingua_screen/widgets/score_view.dart';

/// Self-graded recall of the saved vocabs. The server picks the deck and
/// records each grade; this page keeps the deck.
class FlashCardPage extends StatefulWidget {
  const FlashCardPage({super.key});

  @override
  State<FlashCardPage> createState() => _FlashCardPageState();
}

class _FlashCardPageState extends State<FlashCardPage> {
  final _api = ApiClient.instance;

  bool _loading = true;
  String? _error;

  /// Cards left to show. Missed cards go back to the end.
  final List<FlashCard> _queue = [];
  int _deckSize = 0;

  /// Vocab ids graded at least once. Only the first grade is sent, so
  /// re-showing a missed card doesn't count it twice.
  final Set<String> _graded = {};
  int _gotFirstTry = 0;
  bool _flipped = false;

  /// Counts shown cards, so a missed card coming back is still a new card.
  int _turn = 0;

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
      final cards = await _api.startFlashCards(courseId);
      if (!mounted) return;
      setState(() {
        _queue
          ..clear()
          ..addAll(cards);
        _deckSize = cards.length;
        _graded.clear();
        _gotFirstTry = 0;
        _flipped = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.userMessage);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _grade({required bool correct}) {
    final card = _queue.removeAt(0);
    if (_graded.add(card.vocabId)) {
      if (correct) _gotFirstTry++;
      // Not awaited, so grading feels instant. A lost grade only costs the
      // vocab one scheduling update.
      _api.submitFlashCard(card.vocabId, correct: correct).catchError((
        Object e,
      ) {
        if (mounted && e is ApiException) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.userMessage)));
        }
      });
    }
    if (!correct) _queue.add(card);
    setState(() {
      _flipped = false;
      _turn++;
    });
  }

  void _flip() {
    HapticFeedback.selectionClick();
    setState(() => _flipped = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flashcards'),
        actions: [
          if (!_loading && _error == null && _queue.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_deckSize - _queue.length}/$_deckSize',
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
    if (_deckSize == 0) {
      return const MessageView(
        icon: Icons.style_outlined,
        text: 'Nothing to practice yet.\nSave some words first.',
      );
    }
    if (_queue.isEmpty) {
      return ScoreView(
        title: 'Deck done',
        correct: _gotFirstTry,
        total: _deckSize,
        caption: 'remembered on the first try',
        action: 'New deck',
        onAction: _start,
      );
    }
    return _card(_queue.first);
  }

  Widget _card(FlashCard card) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          children: [
            ProgressBar(value: (_deckSize - _queue.length) / _deckSize),
            const SizedBox(height: 16),
            Expanded(
              // A graded card leaves to the left as the next one comes in.
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                reverseDuration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final incoming = child.key == ValueKey(_turn);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(
                        begin: Offset(incoming ? 0.25 : -0.25, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: _FlipCard(
                  key: ValueKey(_turn),
                  card: card,
                  flipped: _flipped,
                  onTap: _flipped ? null : _flip,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!_flipped)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                  onPressed: _flip,
                  child: const Text('Show answer'),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                      icon: const Icon(Icons.close),
                      label: const Text('Missed'),
                      onPressed: () => _grade(correct: false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                      icon: const Icon(Icons.check),
                      label: const Text('Got it'),
                      onPressed: () => _grade(correct: true),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// A card that turns over to show the answer. The word sits at the same
/// spot on both faces, so turning reads as one card.
class _FlipCard extends StatelessWidget {
  const _FlipCard({
    super.key,
    required this.card,
    required this.flipped,
    required this.onTap,
  });

  final FlashCard card;
  final bool flipped;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // No begin: a new card starts face up without turning.
    return TweenAnimationBuilder<double>(
      tween: Tween(end: flipped ? 1 : 0),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
      builder: (context, t, _) {
        final back = t > 0.5;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0005)
            ..rotateY(t * pi),
          child: back
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.rotationY(pi),
                  child: _face(context, back: true),
                )
              : _face(context, back: false),
        );
      },
    );
  }

  Widget _face(BuildContext context, {required bool back}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final language = Session.instance.course?.learningLanguage;
    final showReading =
        card.reading.isNotEmpty && card.reading != card.dictForm;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            // The back is ruled like an index card. Not red: red means
            // wrong in this app.
            if (back)
              const Positioned(
                top: 56,
                left: 0,
                right: 0,
                child: Divider(color: Palette.outline, thickness: 1.5),
              ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Text(
                        card.dictForm,
                        textAlign: TextAlign.center,
                        style: learned(
                          language,
                          fontSize: 48,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: back
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (showReading) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    card.reading,
                                    textAlign: TextAlign.center,
                                    style: learned(
                                      language,
                                      fontSize: 20,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 20,
                                  ),
                                  child: SizedBox(
                                    width: 48,
                                    child: Divider(
                                      color: scheme.outlineVariant,
                                    ),
                                  ),
                                ),
                                Text(
                                  card.translation,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(height: 1.3),
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
