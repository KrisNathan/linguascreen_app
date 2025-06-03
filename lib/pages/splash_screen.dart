import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _initializeAppAndNavigate();
  }

  Future<void> _initializeAppAndNavigate() async {
    // Optional delay for visual effect of splash screen
    // await Future.delayed(const Duration(seconds: 1));

    bool determinedFirstLaunch = false;
    bool determinedLoggedIn = false;
    String? determinedSessionToken;

    try {
      final results = await Future.wait([
        secureStorage.read(key: 'not_first_launch'),
        secureStorage.read(key: 'access_token'),
      ]);

      final notFirstLaunchValue = results[0];
      final accessTokenValue = results[1];

      if (notFirstLaunchValue == null || notFirstLaunchValue.isEmpty) {
        determinedFirstLaunch = true;
        // Write immediately, but don't necessarily wait if not critical for UI decision
        // If it's critical for the next screen, then await it.
        await secureStorage.write(key: 'not_first_launch', value: 'true');
      } else {
        determinedFirstLaunch = false;
      }

      // Process session token
      if (accessTokenValue == null || accessTokenValue.isEmpty) {
        determinedLoggedIn = false;
      } else {
        log("Access Token from storage (Splash): $accessTokenValue");
        determinedLoggedIn = true;
        determinedSessionToken = accessTokenValue;
      }
    } catch (e) {
      log("Error during secure storage access: $e");
      // Decide fallback behavior, e.g., go to login
      determinedFirstLaunch =
          false;
      determinedLoggedIn = false;
    }

    // Ensure the widget is still mounted before attempting to navigate
    if (!mounted) return;

    if (determinedFirstLaunch) {
      Navigator.pushReplacementNamed(context, '/login');
    } else if (!determinedLoggedIn) {
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      // Pass the session token as an argument to the dashboard
      Navigator.pushReplacementNamed(
        context,
        '/dash',
        arguments: determinedSessionToken,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(
        ),
      ),
    );
  }
}
