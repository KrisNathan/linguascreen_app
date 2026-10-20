import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:lingua_screen/api/models.dart';

/// A non-2xx response, or a network failure ([statusCode] 0).
class ApiException implements Exception {
  final int statusCode;
  final String error;

  /// Safe-to-show detail from the server, e.g. "sentence is empty".
  final String? hint;

  const ApiException(this.statusCode, this.error, [this.hint]);

  bool get isUnauthorized => statusCode == 401;

  /// A message fit for a snackbar.
  String get userMessage => switch (statusCode) {
    0 => 'Could not reach the server. Check your connection.',
    401 => 'Your session has expired. Please sign in again.',
    429 => 'Too many requests. Please try again later.',
    502 => 'The AI service failed. Please try again.',
    _ => hint ?? error,
  };

  @override
  String toString() => 'ApiException($statusCode, $error, $hint)';
}

/// Talks to linguascreen-api-go v1.
///
/// Keeps the access and refresh tokens in secure storage. An expired access
/// token is refreshed once, transparently, and the request retried.
class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  final _storage = const FlutterSecureStorage();
  final _http = http.Client();

  String get baseUrl =>
      dotenv.env['LINGUASCREEN_API_URL'] ?? 'http://10.0.2.2:8080';

  String? _accessToken;

  /// The refresh in flight, shared by every request that hit a 401 meanwhile.
  /// Refresh tokens are single use: refreshing twice with the same one looks
  /// like token theft to the server and signs the user out everywhere.
  Future<bool>? _refreshing;

  // --- auth ---------------------------------------------------------------

  /// Whether a session was stored by an earlier sign in.
  Future<bool> hasSession() async {
    final refresh = await _storage.read(key: _refreshKey);
    return refresh != null && refresh.isNotEmpty;
  }

  /// Exchanges a Google ID token for a LinguaScreen session.
  Future<User> signInWithGoogle(String idToken) async {
    final json = await _send(
      'POST',
      '/auth/google',
      body: {'id_token': idToken},
      auth: false,
    );
    await _storeTokens(json);
    return User.fromJson(json['user'] as Map<String, dynamic>);
  }

  /// Revokes the refresh token and forgets the session. Never throws.
  Future<void> signOut() async {
    final refresh = await _storage.read(key: _refreshKey);
    if (refresh != null) {
      try {
        await _send(
          'POST',
          '/auth/sign-out',
          body: {'refresh_token': refresh},
          auth: false,
        );
      } on ApiException catch (e) {
        log('Sign out failed: $e');
      }
    }
    await clearSession();
  }

  Future<void> clearSession() async {
    _accessToken = null;
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }

  Future<void> _storeTokens(Map<String, dynamic> json) async {
    _accessToken = json['access_token'] as String;
    await _storage.write(key: _accessKey, value: _accessToken);
    await _storage.write(
      key: _refreshKey,
      value: json['refresh_token'] as String,
    );
  }

  Future<bool> _refresh() => _refreshing ??= _doRefresh().whenComplete(() {
    _refreshing = null;
  });

  Future<bool> _doRefresh() async {
    final refresh = await _storage.read(key: _refreshKey);
    if (refresh == null) return false;
    try {
      final json = await _send(
        'POST',
        '/auth/refresh',
        body: {'refresh_token': refresh},
        auth: false,
      );
      await _storeTokens(json);
      return true;
    } on ApiException catch (e) {
      log('Token refresh failed: $e');
      // Only a rejected token ends the session; keep it on network errors.
      if (e.isUnauthorized) await clearSession();
      return false;
    }
  }

  // --- courses ------------------------------------------------------------

  Future<List<Course>> listCourses() async {
    final json = await _send('GET', '/courses');
    return [
      for (final c in json['courses'] as List? ?? const [])
        Course.fromJson(c as Map<String, dynamic>),
    ];
  }

  Future<Course> createCourse({
    required String baseLanguage,
    required String learningLanguage,
  }) async {
    final json = await _send(
      'POST',
      '/courses',
      body: {
        'base_language': baseLanguage,
        'learning_language': learningLanguage,
      },
    );
    return Course.fromJson(json);
  }

  // --- sentences ----------------------------------------------------------

  /// Translates [sentence] and splits it into tokens.
  Future<Analysis> analyze(String courseId, String sentence) async {
    final json = await _send(
      'POST',
      '/analyze',
      body: {'course_id': courseId, 'sentence': sentence},
    );
    return Analysis.fromJson(json);
  }

  /// A markdown explanation of [analysis]'s sentence.
  Future<String> explain(String courseId, Analysis analysis) async {
    final json = await _send(
      'POST',
      '/explain',
      body: {
        'course_id': courseId,
        'sentence': analysis.sentence,
        'sentence_translation': analysis.translation,
      },
    );
    return json['explanation'] as String;
  }

  // --- vocabs -------------------------------------------------------------

  /// Saves the token or part at [span] of [analysis]'s sentence.
  Future<SavedVocab> saveVocab({
    required String courseId,
    required Analysis analysis,
    required Span span,
    required bool fromPart,
    required String dictForm,
    required String reading,
    required String translation,
  }) async {
    final json = await _send(
      'POST',
      '/vocabs',
      body: {
        'course_id': courseId,
        'sentence': analysis.sentence,
        'sentence_translation': analysis.translation,
        'span': [span.$1, span.$2],
        'from_part': fromPart,
        'dict_form': dictForm,
        'reading': reading,
        'translation': translation,
      },
    );
    return SavedVocab.fromJson(json);
  }

  /// One page of vocabs, last saved first. Pass the previous page's
  /// [VocabList.nextCursor] as [cursor] for the next one.
  Future<VocabList> listVocabs(
    String courseId, {
    int limit = 30,
    String? cursor,
  }) async {
    final json = await _send(
      'GET',
      '/courses/${Uri.encodeComponent(courseId)}/vocabs',
      query: {'limit': '$limit', 'cursor': ?cursor},
    );
    return VocabList.fromJson(json);
  }

  Future<VocabDetail> getVocab(String vocabId) async {
    final json = await _send('GET', '/vocabs/${Uri.encodeComponent(vocabId)}');
    return VocabDetail.fromJson(json);
  }

  Future<VocabItem> updateVocabTranslation(
    String vocabId,
    String translation,
  ) async {
    final json = await _send(
      'PATCH',
      '/vocabs/${Uri.encodeComponent(vocabId)}',
      body: {'translation': translation},
    );
    return VocabItem.fromJson(json);
  }

  Future<void> deleteVocab(String vocabId) async {
    await _send('DELETE', '/vocabs/${Uri.encodeComponent(vocabId)}');
  }

  // --- transport ----------------------------------------------------------

  /// Sends a JSON request and returns the decoded JSON object (empty for 204).
  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
    Map<String, String>? query,
    bool auth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);

    Future<http.Response> attempt() async {
      final request = http.Request(method, uri)
        ..headers['Content-Type'] = 'application/json';
      if (auth) {
        final token = _accessToken ??= await _storage.read(key: _accessKey);
        if (token != null) request.headers['Authorization'] = 'Bearer $token';
      }
      if (body != null) request.body = jsonEncode(body);
      return http.Response.fromStream(await _http.send(request));
    }

    http.Response response;
    try {
      response = await attempt();
      if (auth && response.statusCode == 401 && await _refresh()) {
        response = await attempt();
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      log('$method $path failed: $e');
      throw ApiException(0, 'network error');
    }

    final decoded = response.body.isEmpty
        ? const <String, dynamic>{}
        : _decode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }
    log('$method $path -> ${response.statusCode}: ${response.body}');
    throw ApiException(
      response.statusCode,
      decoded['error'] as String? ?? 'request failed',
      decoded['hint'] as String?,
    );
  }

  static Map<String, dynamic> _decode(String body) {
    try {
      final json = jsonDecode(body);
      return json is Map<String, dynamic> ? json : const {};
    } on FormatException {
      return const {};
    }
  }
}
