import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:lingua_screen/api/api_client.dart';
import 'package:lingua_screen/session.dart';

/// After signing in: restores the user's course and opens the dashboard, or
/// the course picker if they have none yet. Throws [ApiException].
Future<void> continueSignedIn(BuildContext context) async {
  final course = await Session.instance.restoreCourse();
  if (!context.mounted) return;
  Navigator.pushReplacementNamed(context, course == null ? '/course' : '/dash');
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() => _error = null);
    try {
      if (!await ApiClient.instance.hasSession()) {
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      if (mounted) await continueSignedIn(context);
    } on ApiException catch (e) {
      log('Restoring session failed: $e');
      if (!mounted) return;
      if (e.isUnauthorized) {
        await ApiClient.instance.clearSession();
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
      } else {
        setState(() => _error = e.userMessage);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return Scaffold(
      body: Center(
        child: error == null
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(error, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _start, child: const Text('Retry')),
                  ],
                ),
              ),
      ),
    );
  }
}
