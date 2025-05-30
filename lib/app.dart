import 'package:flutter/material.dart';
import 'package:overlay_test/pages/channel_page.dart';
import 'package:overlay_test/pages/dictionary_page.dart';
import 'package:overlay_test/pages/quiz_page.dart';
import 'package:overlay_test/pages/coming_soon_page.dart';
import 'package:overlay_test/pages/home_page.dart';

class AppWidget extends StatefulWidget {
  const AppWidget({super.key});

  @override
  State<AppWidget> createState() => _AppWidgetState();
}

List<Widget> pages = [DictionaryPage(), HomePage(), QuizPage()];

class _AppWidgetState extends State<AppWidget> {
  int _selectedIndex = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LinguaScreen')),
      body: pages.elementAt(_selectedIndex),

      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        selectedIndex: _selectedIndex,
        destinations: const <Widget>[
          NavigationDestination(
            selectedIcon: Icon(Icons.book),
            icon: Icon(Icons.book_outlined),
            label: 'Dictionary',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.home),
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.quiz),
            icon: Icon(Icons.quiz_outlined),
            label: 'Flashcards',
          ),
        ],
      ),
    );
  }
}
