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
  bool isOverlayEnabled = false;

  @override
  void initState() {
    super.initState();
    FlutterOverlayWindow.isPermissionGranted().then(
      (bool value) => setState(() {
        isPermissionGranted = value;
      }),
    );
    FlutterOverlayWindow.isActive().then(
      (bool value) => setState(() {
        isOverlayEnabled = value;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Ready to continue learning?',
                style: TextStyle(fontSize: 32.0),
              ),
            ),
            SizedBox(height: 8.0),
            !isPermissionGranted
                ? Card.filled(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning),
                            SizedBox(width: 16.0),
                            Expanded(
                              child: Text(
                                'Some permissions are not granted. LinguaScreen requires permissions to show shortcut button above other apps.',
                                style: TextStyle(),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Spacer(),
                            TextButton(
                              onPressed: () async {
                                final bool? res =
                                    await FlutterOverlayWindow.requestPermission();
                                log('status: $res');
                              },
                              child: const Text(
                                'PERMISSIONS',
                                style: TextStyle(),
                              ),
                            ),
                            IconButton(
                              onPressed: () async {
                                bool isGranted =
                                    await FlutterOverlayWindow.isPermissionGranted();
                                setState(() {
                                  isPermissionGranted = isGranted;
                                });
                              },
                              icon: const Icon(Icons.refresh),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
                : SizedBox(),
            SizedBox(height: 8.0),
            Card.filled(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Text('Shortcut Overlay'),
                    Spacer(),
                    Switch(
                      value: isOverlayEnabled,
                      onChanged:
                          isPermissionGranted
                              ? (bool value) async {
                                if (!(await FlutterOverlayWindow.isPermissionGranted())) {
                                  setState(() {
                                    isPermissionGranted = false;
                                  });
                                }
                                if (await FlutterOverlayWindow.isActive()) {
                                  await FlutterOverlayWindow.closeOverlay();
                                  setState(() {
                                    isOverlayEnabled = false;
                                  });
                                } else {
                                  await FlutterOverlayWindow.showOverlay(
                                    enableDrag: true,
                                    overlayTitle: 'Overlay',
                                    overlayContent: 'Overlay Enabled',
                                    flag: OverlayFlag.defaultFlag,
                                    visibility:
                                        NotificationVisibility.visibilityPublic,
                                    positionGravity: PositionGravity.none,
                                    height: 150,
                                    width: 150,
                                    startPosition: const OverlayPosition(
                                      0,
                                      -259,
                                    ),
                                  );
                                  setState(() {
                                    isOverlayEnabled = true;
                                  });
                                }
                              }
                              : null,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 8.0),
            // Learning Summary
            Row(
              children: [
                Expanded(
                  child: Card.filled(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text(
                            'Words Learned',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('100'),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.0),
                Expanded(
                  child: Card.filled(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text(
                            'Words Reviewed',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('10'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Text('DEBUG'),
            // Text('Is permission granted: $isPermissionGranted'),
            // TextButton(
            //   onPressed: () async {
            //     final status = await FlutterOverlayWindow.isPermissionGranted();
            //     log('status; $status');
            //     setState(() {
            //       isPermissionGranted = status;
            //     });
            //   },
            //   child: Text('Check Permission'),
            // ),
            // TextButton(
            //   onPressed: () async {
            //     final bool? res = await FlutterOverlayWindow.requestPermission();
            //     log('status: $res');
            //   },
            //   child: Text('Request Permission'),
            // ),
            // TextButton(
            //   onPressed: () async {
            //     if (await FlutterOverlayWindow.isActive()) return;
            //     await FlutterOverlayWindow.showOverlay(
            //       enableDrag: true,
            //       overlayTitle: 'Overlay',
            //       overlayContent: 'Overlay Enabled',
            //       flag: OverlayFlag.defaultFlag,
            //       visibility: NotificationVisibility.visibilityPublic,
            //       positionGravity: PositionGravity.none,
            //       height: 150,
            //       width: 150,
            //       startPosition: const OverlayPosition(0, -259),
            //     );
            //   },
            //   child: Text('Show Overlay'),
            // ),
            // TextButton(
            //   onPressed: () async {
            //     FlutterOverlayWindow.closeOverlay().then(
            //       (value) => log('Stopped $value'),
            //     );
            //   },
            //   child: Text('Close Overlay'),
            // ),
          ],
        ),
      ),
    );
  }
}
