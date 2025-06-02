import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:overlay_test/dashboard.dart';
import 'package:overlay_test/overlay/activation_overlay.dart';
import 'package:overlay_test/pages/login_page.dart';
import 'package:overlay_test/pages/signup_page.dart';
import 'package:overlay_test/pages/splash_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future main() async {
  await dotenv.load(fileName: ".env");
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ActivationOverlay(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // No longer need FlutterSecureStorage instance here for initial checks
  // No longer need these state variables for initial routing
  // bool _isLoading = true;
  // bool firstLaunch = false;
  // bool isLoggedIn = false;
  // String? sessionToken;

  // _checkAppStates method is removed, SplashScreen handles this.

  @override
  void initState() {
    super.initState();
    // Initial checks are now done in SplashScreen
  }

  final ThemeData appTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
  );

  @override
  Widget build(BuildContext context) {
    // The initialRoute is now always the splash screen.
    // The logic to determine the actual first page is inside SplashScreen.
    return MaterialApp(
      title: 'LinguaScreen',
      theme: appTheme,
      debugShowCheckedModeBanner: false,
      initialRoute:
          '/', // Or any other name you give to your splash route like '/splash'
      routes: {
        '/':
            (context) =>
                const SplashScreen(), // Route for your new SplashScreen
        '/welcome':
            (context) => Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Welcome to LinguaScreen! Please log in or sign up.',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignupPage(),
        '/dash': (context) {
          final token = ModalRoute.of(context)?.settings.arguments as String?;
          if (token == null) {
            // This case should ideally be prevented by SplashScreen's logic
            // (i.e., don't navigate to /dash if token is null).
            // Fallback to login if token is unexpectedly null.
            log(
              "Error: Navigated to /dash without a token. Redirecting to /login.",
            );
            // It's better to ensure SplashScreen logic is robust than to rely heavily on this fallback.
            // For instance, you could throw an error or navigate to an error page.
            // For now, redirecting to login might be a safe default.
            // WidgetsBinding.instance.addPostFrameCallback((_) {
            //   Navigator.pushReplacementNamed(context, '/login');
            // });
            // return const Scaffold(body: Center(child: Text("Error: Missing token.")));
            // A more direct approach for fallback within the builder:
            return const LoginPage(); // Or a dedicated error screen
          }
          return DashboardWidget(sessionToken: token);
        },
      },
    );
  }
}
