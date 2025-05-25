import 'dart:developer';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:overlay_test/app.dart';
import 'package:overlay_test/overlay/activation_overlay.dart';

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
  static const String _kPortNameOverlay = 'OVERLAY';
  static const String _kPortNameHome = 'UI';
  final _receivePort = ReceivePort();
  SendPort? _sendPort;
  String? _latestMessageFromOverlay;


  @override
  void initState() {
    super.initState();
    
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
      setState(() {
        _latestMessageFromOverlay = 'Latest Message From Overlay: $message';
      });
    });


    // homePort ??= IsolateNameServer.lookupPortByName(_kPortNameOverlay);
    // homePort?.send('Send to overlay: ${DateTime.now()}');
  }

  @override
  void dispose() {
    _receivePort.close();
    IsolateNameServer.removePortNameMapping(_kPortNameHome);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LinguaScreen',
      home: AppWidget(),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
    );
  }
}
