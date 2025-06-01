import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Assume your page imports are here:
// import 'package:overlay_test/dashboard.dart'; (Make sure DashboardWidget can accept a token)
// import 'package:overlay_test/pages/login_page.dart';

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
    // Add a small delay for visual effect of splash screen, optional
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

      // Process first launch
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
          false; // Or true if you want to show welcome on error
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
      // Use Theme.of(context) to ensure splash screen elements also respect the theme
      // backgroundColor: Theme.of(context).colorScheme.background,
      body: Center(
        child: CircularProgressIndicator(
          // color: Theme.of(context).colorScheme.primary, // This is good practice
        ),
      ),
    );
  }
}
