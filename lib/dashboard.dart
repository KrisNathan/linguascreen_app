import 'dart:developer';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:lingua_screen/pages/dictionary_page.dart';
import 'package:lingua_screen/pages/practice_page.dart';
import 'package:lingua_screen/pages/home_page.dart';
import 'package:lingua_screen/pages/ocr_page.dart';
import 'package:lingua_screen/pages/course_page.dart';
import 'package:lingua_screen/session.dart';
import 'package:lingua_screen/api/models.dart';
import 'package:lingua_screen/widgets/paper_tab_bar.dart';

class DashboardWidget extends StatefulWidget {
  const DashboardWidget({super.key});

  @override
  State<DashboardWidget> createState() => _DashboardWidgetState();
}

class _DashboardWidgetState extends State<DashboardWidget>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;

  static const _tabs = ['Today', 'Words', 'Practice'];
  bool _isCapturing = false;

  Future<dynamic> _handleNativeMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'screenCaptureSuccess':
        final filePath = call.arguments as String?;
        setState(() {
          _isCapturing = false;
        });
        if (filePath != null) {
          _showOCRPage(filePath);
        }
        log('Screenshot success: $filePath');
        _showOverlayButton();

        log('INVOKING bringAppToForeground');
        try {
          await _platform.invokeMethod('bringAppToForeground');
        } on PlatformException catch (e) {
          log(
            'Platform Exception bringing app to foreground: ${e.code} - ${e.message}',
          );
        } catch (e) {
          log('Unexpected Error bringing app to foreground: $e');
        }

        break;
      case 'screenCaptureError':
        final Map<dynamic, dynamic> errorMap = call.arguments;
        final code = errorMap['code'];
        final message = errorMap['message'];
        setState(() {
          _isCapturing = false;
        });
        log('Screenshot error: $code - $message');
        _showOverlayButton();

        // The recording session ended (e.g. stopped from the system UI),
        // so the floating button can no longer capture anything.
        if (code == 'SESSION_STOPPED' &&
            await FlutterOverlayWindow.isActive()) {
          await FlutterOverlayWindow.closeOverlay();
        }
        break;
      default:
        log('Unhandled method: ${call.method}');
        break;
    }
  }

  Future<void> _takeScreenshot() async {
    if (_isCapturing) {
      log('Screenshot already in progress.');
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    try {
      // Grab the latest frame of the screen recording session that was started
      // when the floating button was enabled. The path will come via a callback.
      await _platform.invokeMethod('captureScreenshot');
      log('captureScreenshot method invoked on native side.');
      // The _screenshotStatus will be updated by _handleNativeMethodCall
    } on PlatformException catch (e) {
      log('Platform Exception initiating screenshot: ${e.code} - ${e.message}');
      setState(() {
        _isCapturing = false;
      });
      _showOverlayButton();
    } catch (e) {
      log('Unexpected Error initiating screenshot: $e');
      setState(() {
        _isCapturing = false;
      });
      _showOverlayButton();
    }
  }

  /// The floating button hides itself to stay out of the screenshot; this
  /// brings it back once the capture is over.
  void _showOverlayButton() => _sendToOverlay('overlay_show');

  /// The floating button stays out of the way while the app is in front, and
  /// is only shown over other apps.
  void _syncOverlayAway() {
    final inFront =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _sendToOverlay(inFront ? 'overlay_away' : 'overlay_back');
  }

  void _sendToOverlay(String message) {
    // Looked up each time: a reopened overlay registers a new port.
    _sendPort = IsolateNameServer.lookupPortByName(_kPortNameOverlay);
    _sendPort?.send(message);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Not on inactive: that is also a dialog or the notification shade over
    // the app.
    if (state == AppLifecycleState.resumed ||
        state == AppLifecycleState.hidden) {
      _syncOverlayAway();
    }
  }

  Future<void> _showOCRPage(String imagePath) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => OCRPage(imagePath: imagePath)),
    );
    // Leaving the OCR page returns to the app the screenshot was taken from,
    // not to our home page.
    try {
      await _platform.invokeMethod('moveTaskToBack');
    } on PlatformException catch (e) {
      log('Platform Exception moving task to back: ${e.code} - ${e.message}');
    }
  }

  static const String _kPortNameOverlay = 'OVERLAY';
  static const String _kPortNameHome = 'UI';
  final _receivePort = ReceivePort();
  SendPort? _sendPort;

  static final _platform = MethodChannel('com.example.overlay_test/helper');

  @override
  void initState() {
    super.initState();

    _platform.setMethodCallHandler(_handleNativeMethodCall);
    WidgetsBinding.instance.addObserver(this);

    // unregister existing old port:
    // dispose() may not be called properly in the previous session.
    IsolateNameServer.removePortNameMapping(_kPortNameHome);

    final portRegistrationRes = IsolateNameServer.registerPortWithName(
      _receivePort.sendPort,
      _kPortNameHome,
    );
    log('Register UI Port Success: $portRegistrationRes');

    _receivePort.listen((message) {
      log("message from OVERLAY: $message");
      if (message == 'overlay_activate') {
        _takeScreenshot();
      } else if (message == 'overlay_ready') {
        _syncOverlayAway();
      }
    });

    // homePort ??= IsolateNameServer.lookupPortByName(_kPortNameOverlay);
    // homePort?.send('Send to overlay: ${DateTime.now()}');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _receivePort.close();
    IsolateNameServer.removePortNameMapping(_kPortNameHome);

    log('Main exited');

    super.dispose();
  }

  Future<void> _signOut() async {
    if (await FlutterOverlayWindow.isActive()) {
      await FlutterOverlayWindow.closeOverlay();
    }
    await Session.instance.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  Widget _page(String? courseId) {
    // Keyed by course, so switching courses reloads the course's data.
    final key = ValueKey(courseId);
    return switch (_selectedIndex) {
      1 => DictionaryPage(key: key),
      2 => PracticePage(key: key),
      _ => HomePage(
        key: key,
        onOpenWords: () => setState(() => _selectedIndex = 1),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Session.instance,
      builder: (context, _) => _scaffold(Session.instance.course?.id),
    );
  }

  Widget _scaffold(String? courseId) {
    final course = Session.instance.course;
    return Scaffold(
      appBar: AppBar(
        title: Text(_tabs[_selectedIndex]),
        actions: [
          if (course != null)
            TextButton.icon(
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.expand_more, size: 20),
              label: Text(languageName(course.learningLanguage)),
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const CoursePage())),
            ),
          PopupMenuButton<void>(
            tooltip: 'More',
            itemBuilder: (context) => [
              PopupMenuItem(onTap: _signOut, child: const Text('Sign out')),
            ],
          ),
        ],
      ),
      body: _page(courseId),
      bottomNavigationBar: PaperTabBar(
        labels: _tabs,
        selectedIndex: _selectedIndex,
        onSelected: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }
}
