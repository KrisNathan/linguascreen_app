import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isPermissionGranted = false;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          MaterialBanner(
            margin: EdgeInsets.all(16.0),
            content: const Text(
              'Some permissions are not granted. LinguaScreen requires permissions to show shortcut button above other apps.',
              style: TextStyle(),
            ),
            leading: const Icon(Icons.warning),
            // backgroundColor: Colors.grey[850],
            actions: [
              TextButton(
                onPressed: () async {
                  final bool? res =
                      await FlutterOverlayWindow.requestPermission();
                  log('status: $res');
                },
                child: const Text('PERMISSIONS', style: TextStyle()),
              ),
              Container(), // empty to ensure material banner doesnt make it look ugly
            ],
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(children: [Text('Words Learned'), Text('100')]),
                    ),
                  ),
                ),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(children: [Text('Words Learned'), Text('100')]),
                    ),
                  ),
                ),
              ],
            ),
          ),

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
              final bool? res = await FlutterOverlayWindow.requestPermission();
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
    );
  }
}
