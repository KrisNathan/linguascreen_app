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
  SendPort? homePort;
  String? messageFromOverlay;

  @override
  void initState() {
    super.initState();

    if (homePort != null) return;
    final res = IsolateNameServer.registerPortWithName(
      _receivePort.sendPort,
      _kPortNameOverlay,
    );
    log("$res : HOME");
    _receivePort.listen((message) {
      log("message from UI: $message");
      setState(() {
        messageFromOverlay = 'message from UI: $message';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      elevation: 0.0,
      child: GestureDetector(
        onTap: () async {
          log('Activate!!');
          homePort ??= IsolateNameServer.lookupPortByName(_kPortNameHome);
          homePort?.send('From Overlay!!!');
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
