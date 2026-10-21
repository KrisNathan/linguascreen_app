import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:lingua_screen/api/api_client.dart';
import 'package:lingua_screen/dates.dart';
import 'package:lingua_screen/api/models.dart';
import 'package:lingua_screen/session.dart';
import 'package:lingua_screen/theme.dart';
import 'package:lingua_screen/widgets/marked_text.dart';

/// Today: the reading companion switch, and the latest sentences the user
/// saved words from.
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.onOpenWords});

  /// Switches to the Words tab.
  final VoidCallback onOpenWords;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _platform = MethodChannel('com.example.overlay_test/helper');

  bool isPermissionGranted = false;
  bool isOverlayEnabled = false;

  @override
  void initState() {
    super.initState();
    FlutterOverlayWindow.isPermissionGranted().then(
      (bool value) => setState(() {
        isPermissionGranted = value;
      }),
    );
    _syncOverlayState();
    _excerpts = _loadExcerpts();
  }

  /// How many of the latest vocabs to collect sentences from.
  static const _recentVocabs = 6;
  static const _maxExcerpts = 4;

  /// The staggered entrance only plays on the first load of the session.
  static bool _entered = false;

  late Future<List<_Excerpt>> _excerpts;

  /// The newest sentences among the latest vocabs' examples, each with every
  /// one of those vocabs it contains.
  Future<List<_Excerpt>> _loadExcerpts() async {
    final courseId = Session.instance.course?.id;
    if (courseId == null) return const [];
    final api = ApiClient.instance;
    final list = await api.listVocabs(courseId, limit: _recentVocabs);
    final details = await Future.wait(
      list.items.map((v) => api.getVocab(v.id)),
    );

    final bySentence = <String, _Excerpt>{};
    for (final d in details) {
      for (final o in d.occurrences) {
        final e = bySentence.putIfAbsent(
          o.sentence,
          () => _Excerpt(o.sentence, o.sentenceTranslation),
        );
        e.spans.add(o.span);
        e.notes.add(_Note(d.dictForm, d.reading, o.translation));
        if (o.createdAt.isAfter(e.savedAt)) e.savedAt = o.createdAt;
      }
    }
    final excerpts = bySentence.values.toList()
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return excerpts.take(_maxExcerpts).toList();
  }

  Future<void> _refresh() async {
    final next = _loadExcerpts();
    setState(() {
      _excerpts = next;
    });
    await next.catchError((_) => <_Excerpt>[]);
  }

  Future<void> _requestPermission() async {
    final res = await FlutterOverlayWindow.requestPermission();
    log('status: $res');
    final granted = await FlutterOverlayWindow.isPermissionGranted();
    if (mounted) setState(() => isPermissionGranted = granted);
  }

  Future<void> _toggleOverlay(bool value) async {
    if (!(await FlutterOverlayWindow.isPermissionGranted())) {
      setState(() {
        isPermissionGranted = false;
      });
    }
    if (await FlutterOverlayWindow.isActive()) {
      await FlutterOverlayWindow.closeOverlay();
      await _stopScreenCapture();
      setState(() {
        isOverlayEnabled = false;
      });
    } else {
      // Start screen recording before showing the
      // floating button, so taps can capture instantly.
      if (!(await _startScreenCapture())) {
        log('Screen capture permission denied.');
        return;
      }
      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        overlayTitle: 'Overlay',
        overlayContent: 'Overlay Enabled',
        flag: OverlayFlag.defaultFlag,
        visibility: NotificationVisibility.visibilityPublic,
        positionGravity: PositionGravity.none,
        height: 150,
        width: 150,
        startPosition: const OverlayPosition(0, -259),
      );
      setState(() {
        isOverlayEnabled = true;
      });
    }
  }

  /// The floating button is only useful while the screen recording session is
  /// running, so close it if the session has ended in the meantime.
  Future<void> _syncOverlayState() async {
    bool isActive = await FlutterOverlayWindow.isActive();
    if (isActive && !(await _isScreenCaptureRunning())) {
      await FlutterOverlayWindow.closeOverlay();
      isActive = false;
    }
    if (!mounted) return;
    setState(() {
      isOverlayEnabled = isActive;
    });
  }

  Future<bool> _isScreenCaptureRunning() async {
    try {
      return await _platform.invokeMethod<bool>('isScreenCaptureRunning') ??
          false;
    } on PlatformException catch (e) {
      log(
        'Platform Exception checking screen capture: ${e.code} - ${e.message}',
      );
      return false;
    }
  }

  /// Starts the screen recording session. Returns false if the user denied it.
  Future<bool> _startScreenCapture() async {
    try {
      return await _platform.invokeMethod<bool>('startScreenCapture') ?? false;
    } on PlatformException catch (e) {
      log(
        'Platform Exception starting screen capture: ${e.code} - ${e.message}',
      );
      return false;
    }
  }

  Future<void> _stopScreenCapture() async {
    try {
      await _platform.invokeMethod('stopScreenCapture');
    } on PlatformException catch (e) {
      log(
        'Platform Exception stopping screen capture: ${e.code} - ${e.message}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _companion(),
          const SizedBox(height: 32),
          Text(
            'From your reading',
            style: serif(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          FutureBuilder(future: _excerpts, builder: _reading),
        ],
      ),
    );
  }

  /// The switch for the floating button, or the permission it needs.
  Widget _companion() {
    final theme = Theme.of(context);
    final soft = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final title = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );

    if (!isPermissionGranted) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reading companion', style: title),
              const SizedBox(height: 4),
              Text(
                'To read what is on your screen, LinguaScreen needs to show '
                'a floating button over other apps.',
                style: soft,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _requestPermission,
                child: const Text('Allow floating button'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SwitchListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        value: isOverlayEnabled,
        onChanged: _toggleOverlay,
        title: Text('Reading companion', style: title),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            isOverlayEnabled
                ? 'On. Tap the floating button on any page you are reading.'
                : 'Turn on to read and save words from any app.',
            style: soft,
          ),
        ),
      ),
    );
  }

  Widget _reading(
    BuildContext context,
    AsyncSnapshot<List<_Excerpt>> snapshot,
  ) {
    final theme = Theme.of(context);
    final soft = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    if (snapshot.connectionState != ConnectionState.done) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (snapshot.hasError) {
      final error = snapshot.error;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              error is ApiException
                  ? error.userMessage
                  : 'Could not load your reading.',
              style: soft,
            ),
            TextButton(onPressed: _refresh, child: const Text('Try again')),
          ],
        ),
      );
    }

    final excerpts = snapshot.data!;
    if (excerpts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Nothing here yet. Turn on the reading companion, then tap the '
          'floating button while you read. The sentences you save words '
          'from will show up here.',
          style: soft,
        ),
      );
    }

    final animate = !_entered;
    _entered = true;
    final language = Session.instance.course?.learningLanguage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, e) in excerpts.indexed)
          _Appear(
            delay: animate ? Duration(milliseconds: 60 * i) : null,
            child: _ExcerptView(excerpt: e, language: language),
          ),
        const Divider(),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: widget.onOpenWords,
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text('All saved words'),
          ),
        ),
      ],
    );
  }
}

class _Note {
  _Note(this.dictForm, this.reading, this.meaning);

  final String dictForm;
  final String reading;
  final String meaning;
}

class _Excerpt {
  _Excerpt(this.sentence, this.translation);

  final String sentence;
  final String translation;
  final List<Span> spans = [];
  final List<_Note> notes = [];
  DateTime savedAt = DateTime.fromMillisecondsSinceEpoch(0);
}

/// One saved sentence: the words marked, its meaning, and a margin note per
/// word.
class _ExcerptView extends StatelessWidget {
  const _ExcerptView({required this.excerpt, required this.language});

  final _Excerpt excerpt;
  final String? language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final soft = theme.colorScheme.onSurfaceVariant;
    final e = excerpt;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Palette.rule)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            savedOn(e.savedAt),
            style: theme.textTheme.labelMedium?.copyWith(
              fontSize: 13,
              color: soft,
            ),
          ),
          const SizedBox(height: 8),
          Text.rich(
            markedSentence(e.sentence, e.spans),
            style: learned(language, fontSize: 21, height: 1.7),
          ),
          if (e.translation.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              e.translation,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: soft,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 12),
          for (final n in e.notes)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: n.dictForm,
                      style: learned(
                        language,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (n.reading.isNotEmpty && n.reading != n.dictForm)
                      TextSpan(
                        text: '  ${n.reading}',
                        style: learned(language, fontSize: 14, color: soft),
                      ),
                    TextSpan(
                      text: '   ${n.meaning}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Fades and lifts [child] in after [delay]. No delay shows it right away.
class _Appear extends StatefulWidget {
  const _Appear({required this.delay, required this.child});

  final Duration? delay;
  final Widget child;

  @override
  State<_Appear> createState() => _AppearState();
}

class _AppearState extends State<_Appear> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late final _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    final delay = widget.delay;
    if (delay == null) {
      _controller.value = 1;
    } else {
      Future.delayed(delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(_curve),
        child: widget.child,
      ),
    );
  }
}
