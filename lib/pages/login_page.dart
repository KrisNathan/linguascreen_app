import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:lingua_screen/api/api_client.dart';
import 'package:lingua_screen/pages/splash_screen.dart';
import 'package:lingua_screen/theme.dart';
import 'package:lingua_screen/widgets/marked_text.dart';

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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Image.asset('assets/logo_mark.png', height: 40),
                  const SizedBox(width: 12),
                  Text(
                    'LinguaScreen',
                    style: serif(fontSize: 28, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                'Learn languages from what you read.',
                style: serif(fontSize: 34, height: 1.2),
              ),
              const SizedBox(height: 32),
              const _Sample(
                language: 'ja',
                sentence: '本を読んで、新しい言葉を覚える。',
                word: '言葉',
                note: 'kotoba · words',
              ),
              const SizedBox(height: 16),
              const _Sample(
                language: 'zh',
                sentence: '我在书里学到了新的词语。',
                word: '词语',
                note: 'cíyǔ · words',
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _busy ? null : _signIn,
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

/// A sentence with one word marked and a margin note, as the app shows
/// the user's own reading.
class _Sample extends StatelessWidget {
  const _Sample({
    required this.language,
    required this.sentence,
    required this.word,
    required this.note,
  });

  final String language;
  final String sentence;
  final String word;
  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final runes = sentence.runes.toList();
    final length = word.runes.length;
    var start = -1;
    for (var i = 0; i + length <= runes.length; i++) {
      if (String.fromCharCodes(runes.sublist(i, i + length)) == word) {
        start = i;
        break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          markedSentence(sentence, [if (start >= 0) (start, start + length)]),
          style: learned(language, fontSize: 22, height: 1.6),
        ),
        Text(
          note,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
