import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class TrueCallerOverlay extends StatefulWidget {
  const TrueCallerOverlay({super.key});

  @override
  State<TrueCallerOverlay> createState() => _TrueCallerOverlayState();
}

class _TrueCallerOverlayState extends State<TrueCallerOverlay> {
  bool isPermissionGranted = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          width: double.infinity,
          child: GestureDetector(
            onTap: () {
              FlutterOverlayWindow.getOverlayPosition().then((value) {
                log('Overlay position: $value');
              });
            },
            child: Center(
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black,
                          offset: Offset(0.0, 0.0),
                          blurRadius: 2.0,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [Text('LinguaScreen'), Text('Tung Tung Tung')],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
