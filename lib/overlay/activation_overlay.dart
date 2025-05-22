import 'package:flutter/material.dart';

class ActivationOverlay extends StatelessWidget {
  const ActivationOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      elevation: 0.0,
      child: GestureDetector(
        onTap: () async {
          print('Activate!');
        },
        child: Container(
          height: MediaQuery.of(context).size.height,
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const FlutterLogo(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}