import 'dart:convert';

// Helper function to decode the JSON string and create an ApiResponse object.
ExplanationApiResponse apiResponseFromJson(String str) => ExplanationApiResponse.fromJson(json.decode(str));

class ExplanationApiResponse {
    final String message;
    final Explanation result;

    ExplanationApiResponse({
        required this.message,
        required this.result,
    });

    factory ExplanationApiResponse.fromJson(Map<String, dynamic> json) => ExplanationApiResponse(
        message: json["message"],
        result: Explanation.fromJson(json["result"]),
    );
}

class Explanation {
    final List<WordsExplanation> wordsExplanation;
    final String entireExplanation;
    final String originalSentence;
    final String translatedSentence;
    final int promptTokens;
    final int completionTokens;

    Explanation({
        required this.wordsExplanation,
        required this.entireExplanation,
        required this.originalSentence,
        required this.translatedSentence,
        required this.promptTokens,
        required this.completionTokens,
    });

    factory Explanation.fromJson(Map<String, dynamic> json) => Explanation(
        wordsExplanation: List<WordsExplanation>.from(json["words_explanation"].map((x) => WordsExplanation.fromJson(x))),
        entireExplanation: json["entire_explanation"],
        originalSentence: json["original_sentence"],
        translatedSentence: json["translated_sentence"],
        promptTokens: json["prompt_tokens"],
        completionTokens: json["completion_tokens"],
    );
}

class WordsExplanation {
    final String originalWord;
    final String translatedWord;
    final String explanation;
    final String romanization;

    WordsExplanation({
        required this.originalWord,
        required this.translatedWord,
        required this.explanation,
        required this.romanization,
    });

    factory WordsExplanation.fromJson(Map<String, dynamic> json) => WordsExplanation(
        originalWord: json["original_word"],
        translatedWord: json["translated_word"],
        explanation: json["explanation"],
        romanization: json["romanization"],
    );
}