import 'dart:developer';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:lingua_screen/pages/dictionary_page.dart';
import 'package:lingua_screen/pages/quiz_page.dart';
import 'package:lingua_screen/pages/home_page.dart';
import 'package:lingua_screen/pages/ocr_page.dart';
import 'package:lingua_screen/pages/course_page.dart';
import 'package:lingua_screen/session.dart';

class DashboardWidget extends StatefulWidget {
  const DashboardWidget({super.key});

  @override
  State<DashboardWidget> createState() => _DashboardWidgetState();
}

class _DashboardWidgetState extends State<DashboardWidget> {
  int _selectedIndex = 1;
  bool _isCapturing = false;

  Future<dynamic> _handleNativeMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'screenCaptureSuccess':
        final filePath = call.arguments as String?;
        setState(() {
          _isCapturing = false;
          if (filePath != null) {
            _showOCRPage(filePath);
          }
        });
        log('Screenshot success: $filePath');

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

        // The recording session ended (e.g. stopped from the system UI),
        // so the floating button can no longer capture anything.
        if (code == 'SESSION_STOPPED' && await FlutterOverlayWindow.isActive()) {
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
    } catch (e) {
      log('Unexpected Error initiating screenshot: $e');
      setState(() {
        _isCapturing = false;
      });
    }
  }

  void _showOCRPage(String imagePath) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => OCRPage(imagePath: imagePath)),
    );
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
      }
    });

    // homePort ??= IsolateNameServer.lookupPortByName(_kPortNameOverlay);
    // homePort?.send('Send to overlay: ${DateTime.now()}');
  }

  @override
  void dispose() {
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
    return switch (_selectedIndex) {
      0 => DictionaryPage(key: ValueKey(courseId)),
      2 => QuizPage(key: ValueKey(courseId)),
      _ => const HomePage(),
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
        title: const Text('LinguaScreen'),
        actions: [
          if (course != null)
            ActionChip(
              avatar: const Icon(Icons.translate, size: 18),
              label: Text(course.learningLanguage.toUpperCase()),
              tooltip: course.label,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CoursePage()),
              ),
            ),
          PopupMenuButton<void>(
            itemBuilder: (context) => [
              PopupMenuItem(onTap: _signOut, child: const Text('Sign out')),
            ],
          ),
        ],
      ),
      body: _page(courseId),

      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        selectedIndex: _selectedIndex,
        destinations: const <Widget>[
          NavigationDestination(
            selectedIcon: Icon(Icons.book),
            icon: Icon(Icons.book_outlined),
            label: 'Dictionary',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.home),
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.quiz),
            icon: Icon(Icons.quiz_outlined),
            label: 'Flashcards',
          ),
        ],
      ),
    );
  }
}
