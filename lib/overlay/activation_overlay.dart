import 'dart:developer';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/material.dart';

class ActivationOverlay extends StatefulWidget {
  const ActivationOverlay({super.key});

  @override
  State<ActivationOverlay> createState() => _ActivationOverlayState();
}

class _ActivationOverlayState extends State<ActivationOverlay> {
  static const String _kPortNameOverlay = 'OVERLAY';
  static const String _kPortNameHome = 'UI';
  final _receivePort = ReceivePort();
  SendPort? _sendPort;
  String? _messageFromUI;

  @override
  void initState() {
    super.initState();

    // unregister existing old port:
    // dispose() may not be called properly in the previous session.
    IsolateNameServer.removePortNameMapping(_kPortNameOverlay);

    final portRegistrationRes = IsolateNameServer.registerPortWithName(
      _receivePort.sendPort,
      _kPortNameOverlay,
    );
    log('Register Overlay Port Success: $portRegistrationRes');

    _receivePort.listen((message) {
      log("message from UI: $message");
      setState(() {
        _messageFromUI = 'message from UI: $message';
      });
    });
  }

  @override
  void dispose() {
    _receivePort.close();
    IsolateNameServer.removePortNameMapping(_kPortNameOverlay);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      elevation: 0.0,
      child: GestureDetector(
        onTap: () async {
          log('Activate!!');
          _sendPort ??= IsolateNameServer.lookupPortByName(_kPortNameHome);
          _sendPort?.send('overlay_activate');
        },
        child: SizedBox(
          height: MediaQuery.of(context).size.height,
          child: Card(
            elevation: 1.0,
            shape: CircleBorder(),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [const FlutterLogo()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
