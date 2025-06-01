import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:overlay_test/dashboard.dart';
import 'package:overlay_test/overlay/activation_overlay.dart';
import 'package:overlay_test/pages/login_page.dart';
import 'package:overlay_test/pages/signup_page.dart';

void main() {
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
  final FlutterSecureStorage secureStorage = FlutterSecureStorage();

  bool firstLaunch = false;
  bool isLoggedIn = false;
  String? sessionToken;

  @override
  void initState() {
    super.initState();

    // check secure storage if its first time app is launched
    secureStorage.read(key: 'not_first_launch').then((value) {
      if (value == null || value.isEmpty) {
        // if first time, show welcome screen
        setState(() {
          firstLaunch = true;
        });

        secureStorage.write(key: 'not_first_launch', value: 'true');
      }
    });

    // check secure storage for session token
    secureStorage.read(key: 'session_token').then((value) {
      if (value == null || value.isEmpty) {
        // if no session token, user is not logged in
        setState(() {
          isLoggedIn = false;
        });
      } else {
        // if session token exists, user is logged in
        setState(() {
          isLoggedIn = true;
          sessionToken = value;
        });
      }
    });
  }

  final ThemeData appTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
  );

  @override
  Widget build(BuildContext context) {
    String initialRoute = '/dash';
    if (firstLaunch) {
      initialRoute = '/welcome';
    } else if (!isLoggedIn) {
      initialRoute = '/login';
    }

    return MaterialApp(
      title: 'LinguaScreen',
      theme: appTheme,
      initialRoute: initialRoute,
      routes: {
        '/welcome':
            (context) => Scaffold(
              body: Center(
                child: Text(
                  'Welcome to LinguaScreen! Please log in or sign up.',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignupPage(),
        '/dash': (context) => DashboardWidget(),
      },
    );
  }
}
