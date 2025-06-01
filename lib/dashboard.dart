import 'dart:developer';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:overlay_test/pages/dictionary_page.dart';
import 'package:overlay_test/pages/quiz_page.dart';
import 'package:overlay_test/pages/home_page.dart';
import 'package:overlay_test/pages/ocr_page.dart';

class DashboardWidget extends StatefulWidget {
  final String sessionToken;

  const DashboardWidget({super.key, required this.sessionToken});

  @override
  State<DashboardWidget> createState() => _DashboardWidgetState();
}

List<Widget> pages = [DictionaryPage(), HomePage(), QuizPage()];

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
      // Initiate the native flow. The actual screenshot path will come via a callback.
      await _platform.invokeMethod('startScreenCapture');
      log('startScreenCapture method invoked on native side.');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LinguaScreen')),
      body: pages.elementAt(_selectedIndex),

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
