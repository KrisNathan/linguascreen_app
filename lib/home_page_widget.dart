import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class HomePageWidget extends StatefulWidget {
  const HomePageWidget({super.key});

  @override
  State<HomePageWidget> createState() => _HomePageWidgetState();
}

class _HomePageWidgetState extends State<HomePageWidget> {
  bool isPermissionGranted = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Overlay App')),
      body: Center(
        child: Column(
          children: [
            Text('Is permission granted: $isPermissionGranted'),
            TextButton(
              onPressed: () async {
                final status = await FlutterOverlayWindow.isPermissionGranted();
                log('status; $status');
                setState(() {
                  isPermissionGranted = status;
                });
              },
              child: Text('Check Permission'),
            ),
            TextButton(
              onPressed: () async {
                final bool? res =
                    await FlutterOverlayWindow.requestPermission();
                log('status: $res');
              },
              child: Text('Request Permission'),
            ),
            TextButton(
              onPressed: () async {
                if (await FlutterOverlayWindow.isActive()) return;
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
              },
              child: Text('Show Overlay'),
            ),
            TextButton(
              onPressed: () async {
                FlutterOverlayWindow.closeOverlay().then(
                  (value) => log('Stopped $value'),
                );
              },
              child: Text('Close Overlay'),
            ),
          ],
        ),
      ),
    );
  }
}
