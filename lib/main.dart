import 'dart:developer';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:overlay_test/app.dart';
import 'package:overlay_test/overlay/activation_overlay.dart';
import 'package:overlay_test/pages/ocr_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ActivationOverlay(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isCapturing = false;
  String? _lastScreenshotPath;

  Future<dynamic> _handleNativeMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'screenCaptureSuccess':
        final filePath = call.arguments as String?;
        setState(() {
          _isCapturing = false;
          _lastScreenshotPath = filePath;
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

  // I don't know why this doesn't work.
  void _showFullScreenImage(String imagePath) {
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
    return MaterialApp(
      title: 'LinguaScreen',
      home:
          _lastScreenshotPath != null
              ? OCRPage(imagePath: _lastScreenshotPath!)
              : AppWidget(),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
    );
  }
}
