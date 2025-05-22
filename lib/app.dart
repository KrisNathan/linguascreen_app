import 'package:flutter/material.dart';
import 'package:overlay_test/pages/home_page.dart';

class AppWidget extends StatelessWidget {
  const AppWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LinguaScreen')),
      body: HomePage(),
    );
  }
}
