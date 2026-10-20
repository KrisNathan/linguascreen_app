import 'package:flutter/material.dart';
import 'package:lingua_screen/api/api_client.dart';
import 'package:lingua_screen/api/models.dart';
import 'package:lingua_screen/session.dart';

/// Pick one of the user's courses, or create one.
///
/// Opened as the first screen after sign in when the user has no course
/// (route `/course`), or pushed from the dashboard to switch courses.
class CoursePage extends StatefulWidget {
  const CoursePage({super.key});

  @override
  State<CoursePage> createState() => _CoursePageState();
}

class _CoursePageState extends State<CoursePage> {
  late Future<List<Course>> _courses = ApiClient.instance.listCourses();

  String _learning = 'ja';
  String _base = 'en';
  bool _creating = false;

  Future<void> _choose(Course course) async {
    await Session.instance.setCourse(course);
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacementNamed('/dash');
    }
  }

  Future<void> _create() async {
    setState(() => _creating = true);
    try {
      final course = await ApiClient.instance.createCourse(
        baseLanguage: _base,
        learningLanguage: _learning,
      );
      await _choose(course);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.userMessage)));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = Session.instance.course;

    return Scaffold(
      appBar: AppBar(title: const Text('Courses')),
      body: FutureBuilder(
        future: _courses,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    error is ApiException
                        ? error.userMessage
                        : 'Could not load your courses.',
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _courses = ApiClient.instance.listCourses();
                    }),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final courses = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (courses.isNotEmpty) ...[
                Text('Your courses', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final course in courses)
                  Card.filled(
                    child: ListTile(
                      title: Text(course.label),
                      trailing: course.id == current?.id
                          ? const Icon(Icons.check)
                          : null,
                      onTap: () => _choose(course),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
              Text('New course', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              _languagePicker(
                label: 'I want to learn',
                value: _learning,
                onChanged: (v) => setState(() => _learning = v),
              ),
              const SizedBox(height: 12),
              _languagePicker(
                label: 'I speak',
                value: _base,
                onChanged: (v) => setState(() => _base = v),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _creating || _learning == _base ? null : _create,
                child: Text(
                  _learning == _base
                      ? 'Pick two different languages'
                      : 'Start learning ${languageName(_learning)}',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _languagePicker({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownMenu<String>(
      expandedInsets: EdgeInsets.zero,
      label: Text(label),
      initialSelection: value,
      dropdownMenuEntries: [
        for (final MapEntry(:key, :value) in supportedLanguages.entries)
          DropdownMenuEntry(value: key, label: value),
      ],
      onSelected: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
