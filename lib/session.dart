import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:lingua_screen/api/api_client.dart';
import 'package:lingua_screen/api/models.dart';

/// The course the user is studying. Every vocab, analysis and quiz belongs
/// to one, so pages read it from here.
class Session extends ChangeNotifier {
  Session._();

  static final Session instance = Session._();

  static const _courseKey = 'course_id';
  final _storage = const FlutterSecureStorage();

  Course? _course;
  Course? get course => _course;

  /// Restores the last used course. Falls back to the first one, or null if
  /// the user has none yet.
  Future<Course?> restoreCourse() async {
    final courses = await ApiClient.instance.listCourses();
    final savedId = await _storage.read(key: _courseKey);
    final course =
        courses.where((c) => c.id == savedId).firstOrNull ??
        courses.firstOrNull;
    if (course != null) await setCourse(course);
    return course;
  }

  Future<void> setCourse(Course course) async {
    _course = course;
    await _storage.write(key: _courseKey, value: course.id);
    notifyListeners();
  }

  Future<void> signOut() async {
    await ApiClient.instance.signOut();
    await _storage.delete(key: _courseKey);
    _course = null;
    notifyListeners();
  }
}

/// The ML Kit script that reads [languageCode].
TextRecognitionScript scriptFor(String languageCode) => switch (languageCode) {
  'ja' => TextRecognitionScript.japanese,
  'zh' => TextRecognitionScript.chinese,
  _ => TextRecognitionScript.latin,
};
