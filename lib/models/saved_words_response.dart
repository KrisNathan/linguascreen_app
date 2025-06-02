/*
{
  "message": "string",
  "result": [
    {
      "original": "string",
      "original_lang": "string",
      "translation": "string",
      "translation_lang": "string",
      "explanation": "string",
      "user_id": 0,
      "id": 0
    }
  ]
}
*/

import 'package:lingua_screen/models/saved_word.dart';

class SavedWordsResponse {
  final String message;
  final List<SavedWord> result;
  SavedWordsResponse({
    required this.message,
    required this.result,
  });
  factory SavedWordsResponse.fromJson(Map<String, dynamic> json) {
    return SavedWordsResponse(
      message: json['message'] ?? '',
      result: (json['result'] as List)
          .map((item) => SavedWord.fromJson(item))
          .toList(),
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'result': result.map((item) => item.toJson()).toList(),
    };
  }
}