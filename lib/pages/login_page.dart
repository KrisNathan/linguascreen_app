import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final FlutterSecureStorage secureStorage = FlutterSecureStorage();

  final _formKey = GlobalKey<FormState>();

  String _email = '';
  String _password = '';

  Future<String?> _postLoginRequest() async {
    final String baseUrl = dotenv.env['LINGUASCREEN_API_URL'] ?? 'http://10.0.2.2:8000';
    try {
      final String loginUrl = '$baseUrl/login';
      final response = await post(
        Uri.parse(loginUrl),
        body: jsonEncode({'email': _email, 'password': _password}),
        headers: {'Content-Type': 'application/json'},
      );

      final body = response.body;
      final Map<String, dynamic> json = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // success
        String? accessToken = json['result']['access_token'];
        log('Login successful: $body');
        await secureStorage.write(key: 'access_token', value: accessToken);
        return accessToken;
      } else {
        // error
        log('Login failed: $body');
        return null;
      }
    } catch (e) {
      log('Error occurred while trying to log in: $e');
      return null;
    }
  }

  void _handleLogin() {
    if (!(_formKey.currentState!.validate())) {
      log('Form is not valid');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please correct the errors.')),
      );
    }

    _formKey.currentState!.save(); // trigger all onSaved

    log('Attempting login (Form method)...');
    log('Email: $_email');
    log('Password: $_password');

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Logging in...')));

    _postLoginRequest().then((accessToken) {
      if (!mounted) return; // check if widget is still mounted
      if (accessToken != null) {
        Navigator.pushReplacementNamed(
          context,
          '/dash',
          arguments: accessToken,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login failed. Please try again.')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                Text(
                  'Log In',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                TextFormField(
                  keyboardType: TextInputType.emailAddress,
                  textCapitalization: TextCapitalization.none,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(
                    labelText: 'Email',
                    hintText: 'Email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    filled: true,
                    fillColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _email = value ?? '';
                  },
                ),
                const SizedBox(height: 24),

                TextFormField(
                  keyboardType: TextInputType.visiblePassword,
                  textCapitalization: TextCapitalization.none,
                  autofillHints: const [AutofillHints.password],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _password = value ?? '';
                  },
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    filled: true,
                    fillColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 36),

                ElevatedButton(
                  onPressed: _handleLogin,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  child: const Text('Log In'),
                ),
                const SizedBox(height: 16),

                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/signup');
                    },
                    child: const Text(
                      'Don\'t have an account? Sign Up',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
