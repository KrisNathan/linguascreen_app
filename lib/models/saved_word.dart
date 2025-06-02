/*
{
      "original": "string",
      "original_lang": "string",
      "translation": "string",
      "translation_lang": "string",
      "explanation": "string",
      "user_id": 0,
      "id": 0
    }
*/

class SavedWord {
  final String original;
  final String originalLang;
  final String translation;
  final String translationLang;
  final String explanation;
  final int userId;
  final int id;

  SavedWord({
    required this.original,
    required this.originalLang,
    required this.translation,
    required this.translationLang,
    required this.explanation,
    required this.userId,
    required this.id,
  });

  factory SavedWord.fromJson(Map<String, dynamic> json) {
    return SavedWord(
      original: json['original'],
      originalLang: json['original_lang'],
      translation: json['translation'],
      translationLang: json['translation_lang'],
      explanation: json['explanation'],
      userId: json['user_id'],
      id: json['id'],
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'original': original,
      'original_lang': originalLang,
      'translation': translation,
      'translation_lang': translationLang,
      'explanation': explanation,
      'user_id': userId,
      'id': id,
    };
  }
}
