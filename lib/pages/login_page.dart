import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:lingua_screen/api/api_client.dart';
import 'package:lingua_screen/pages/splash_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  /// GoogleSignIn must be initialized exactly once per app run.
  static Future<void>? _googleReady;

  bool _busy = false;

  Future<void> _signIn() async {
    setState(() => _busy = true);
    String? error;
    try {
      await (_googleReady ??= GoogleSignIn.instance.initialize(
        // The web OAuth client ID, the audience the API checks
        // (GOOGLE_CLIENT_AUD). Without it Android issues no ID token.
        serverClientId: dotenv.env['GOOGLE_SERVER_CLIENT_ID'],
      ));
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) throw StateError('Google returned no ID token');

      await ApiClient.instance.signInWithGoogle(idToken);
      if (!mounted) return;
      await continueSignedIn(context);
      return;
    } on GoogleSignInException catch (e) {
      log('Google sign in failed: ${e.code} ${e.description}');
      if (e.code != GoogleSignInExceptionCode.canceled) {
        error = 'Google sign in failed. Please try again.';
      }
    } on ApiException catch (e) {
      error = e.userMessage;
    } catch (e) {
      log('Sign in failed: $e');
      error = 'Sign in failed. Please try again.';
    }

    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Image.asset('assets/icon.png', height: 96),
              const SizedBox(height: 24),
              Text(
                'LinguaScreen',
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Learn languages from what you read.',
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _busy ? null : _signIn,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login),
                label: const Text('Continue with Google'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
