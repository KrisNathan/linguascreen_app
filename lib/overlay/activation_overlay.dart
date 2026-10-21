import 'dart:async';
import 'dart:developer';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:lingua_screen/theme.dart';

/// The floating button shown over other apps. Tapping it asks the app to
/// capture the screen.
///
/// The button hides itself before asking, so it is not in the screenshot,
/// and comes back when the app sends `overlay_show`. It also stays away while
/// the app itself is in front: the app sends `overlay_away` and
/// `overlay_back` as it comes and goes.
class ActivationOverlay extends StatefulWidget {
  const ActivationOverlay({super.key});

  @override
  State<ActivationOverlay> createState() => _ActivationOverlayState();
}

class _ActivationOverlayState extends State<ActivationOverlay> {
  static const String _kPortNameOverlay = 'OVERLAY';
  static const String _kPortNameHome = 'UI';
  final _receivePort = ReceivePort();

  /// Time for the screen recording to receive a frame without the button.
  static const _hideDelay = Duration(milliseconds: 150);

  /// Shows the button again if the app never answers, e.g. it was closed.
  static const _showTimeout = Duration(seconds: 4);

  bool _hidden = false;
  Timer? _showTimer;

  /// Whether the app is in front. Starts away until the app says otherwise,
  /// since the button is usually turned on from inside the app.
  bool _away = true;

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
      switch (message) {
        case 'overlay_show':
          _show();
        case 'overlay_away':
          _setAway(true);
        case 'overlay_back':
          _setAway(false);
      }
    });

    final home = IsolateNameServer.lookupPortByName(_kPortNameHome);
    if (home == null) {
      _away = false;
    } else {
      home.send('overlay_ready');
    }
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    _receivePort.close();
    IsolateNameServer.removePortNameMapping(_kPortNameOverlay);

    super.dispose();
  }

  Future<void> _setAway(bool away) async {
    // The flag is set even when already away: the window starts touchable.
    if (!mounted) return;
    setState(() {
      _away = away;
    });
    // An invisible window would still swallow taps meant for the app.
    await FlutterOverlayWindow.updateFlag(
      away ? OverlayFlag.clickThrough : OverlayFlag.defaultFlag,
    );
  }

  Future<void> _activate() async {
    if (_hidden || _away) return;
    log('Activate!!');
    setState(() => _hidden = true);
    _showTimer = Timer(_showTimeout, _show);

    // Wait until the hidden frame is drawn, then until the recording has it.
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(_hideDelay);

    final home = IsolateNameServer.lookupPortByName(_kPortNameHome);
    if (home == null) {
      _show();
      return;
    }
    home.send('overlay_activate');
  }

  void _show() {
    _showTimer?.cancel();
    _showTimer = null;
    if (mounted && _hidden) setState(() => _hidden = false);
  }

  @override
  Widget build(BuildContext context) {
    final gone = _hidden || _away;
    return Material(
      color: Colors.transparent,
      elevation: 0.0,
      // Not a GestureDetector: flutter_overlay_window 1.0.0 consumes the pointer
      // up of a drag, so the dragged pointer never ends and a tap recognizer
      // ignores every later tap. Only taps deliver a pointer up to Flutter.
      child: Listener(
        onPointerUp: (_) => _activate(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height,
          // Gone at once for the screenshot, then pops back in, which also
          // tells the user the capture happened.
          child: AnimatedOpacity(
            opacity: gone ? 0 : 1,
            duration: gone ? Duration.zero : const Duration(milliseconds: 160),
            child: AnimatedScale(
              scale: gone ? 0.6 : 1,
              duration: gone
                  ? Duration.zero
                  : const Duration(milliseconds: 320),
              curve: Curves.easeOutBack,
              // The app icon in miniature: paper, ink ring, the marked L.
              child: Card(
                color: Palette.paper,
                elevation: 3.0,
                shadowColor: Palette.ink,
                shape: const CircleBorder(
                  side: BorderSide(color: Palette.ink, width: 2),
                ),
                child: Center(
                  child: Image.asset('assets/logo_mark.png', width: 34),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
