import 'dart:convert';
import 'dart:developer'; // For log()
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();

  final _passwordController = TextEditingController();

  String _email = '';
  String _password = '';
  String _confirmPassword = '';

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<bool> _postSignupRequest() async {
    final String baseUrl = dotenv.env['LINGUASCREEN_API_URL'] ?? 'http://10.0.2.2:8000';
    try {
      final String signupUrl = '$baseUrl/register';
      final response = await post(
        Uri.parse(signupUrl),
        body: jsonEncode({
          'email': _email,
          'username': _email,
          'password': _password,
        }),
        headers: {'Content-Type': 'application/json'},
      );

      final body = response.body;

      if (response.statusCode == 201) {
        // success
        log('Sign up successful: $body');
        return true;
      } else {
        // error
        log('Sign up failed: $body');
        return false;
      }
    } catch (e) {
      log('Error occurred while trying to sign up: $e');
      return false;
    }
  }

  void _handleSignup() {
    if (!(_formKey.currentState!.validate())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please correct the errors in the form.')),
      );
      log('Form is not valid');
      return;
    }

    _formKey.currentState!.save();

    log('Sign Up attempt:');
    log('Email: $_email');
    log('Password: $_password');
    log('Confirm Password: $_confirmPassword');

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Processing sign up...')));

    _postSignupRequest().then((success) {
      if (!mounted) return; // check if widget is still mounted
      if (success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Sign up successful!')));

        Navigator.pushReplacementNamed(context, "/login");
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign up failed. Please try again.')),
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
                  'Sign Up',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                /// Email Field
                TextFormField(
                  keyboardType: TextInputType.emailAddress,
                  textCapitalization: TextCapitalization.none,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(
                    labelText: 'Email',
                    hintText: 'Enter your email',
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
                    if (!value.contains('@') || !value.contains('.')) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _email = value ?? '';
                  },
                ),
                const SizedBox(height: 24),

                /// Password Field
                TextFormField(
                  controller: _passwordController, // Assign the controller
                  keyboardType: TextInputType.visiblePassword,
                  textCapitalization: TextCapitalization.none,
                  autofillHints: const [AutofillHints.newPassword],
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
                    hintText: 'Enter your password',
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
                const SizedBox(height: 24),

                /// Confirm Password Field
                TextFormField(
                  keyboardType: TextInputType.visiblePassword,
                  textCapitalization: TextCapitalization.none,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      // The crucial check
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _confirmPassword = value ?? '';
                  },
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    hintText: 'Re-enter your password',
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
                  onPressed: _handleSignup,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  child: const Text('Create Account'),
                ),
                const SizedBox(height: 16),

                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Already have an account? Log in',
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
