import 'dart:convert';
import 'dart:developer';

import 'package:lingua_screen/models/explanation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ExplainApi {
  static final String baseUrl =
      dotenv.env['LINGUASCREEN_API_URL'] ?? 'http://10.0.2.2:8000';

  static Future<Explanation?> fetchExplanation(
    String originalSentence,
    String translatedSentence,
    String originalLanguage,
    String targetLanguage,
  ) async {
    final String explanationUrl = '$baseUrl/ai/explain';
    try {
      final response = await http.post(
        Uri.parse(explanationUrl),
        body: jsonEncode({
          'original_sentence': originalSentence,
          'translated_sentence': translatedSentence,
          'original_lang': originalLanguage,
          'target_lang': targetLanguage,
        }),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final ExplanationApiResponse apiResponse =
            ExplanationApiResponse.fromJson(responseData);
        return apiResponse.result;
      } else {
        log('Failed to fetch explanation: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } catch (e) {
      log('Error occured while trying to fetch explanation: $e');
    }
    return null;
  }
}
