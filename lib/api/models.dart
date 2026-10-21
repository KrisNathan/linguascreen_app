// Response shapes of the LinguaScreen API (linguascreen-api-go v1).
//
// Spans are `[start, end)` in runes (Unicode code points) of `sentence`,
// i.e. indices into `sentence.runes`, not into the UTF-16 string.

typedef Span = (int, int);

Span _span(dynamic json) {
  final list = json as List;
  return ((list[0] as num).toInt(), (list[1] as num).toInt());
}

class User {
  final String id;
  final String email;
  final String name;

  const User({required this.id, required this.email, required this.name});

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as String,
    email: json['email'] as String,
    name: json['name'] as String,
  );
}

/// Languages the API supports, ISO 639-1 code to display name.
const supportedLanguages = {'en': 'English', 'ja': 'Japanese', 'zh': 'Chinese'};

String languageName(String code) => supportedLanguages[code] ?? code;

class Course {
  final String id;
  final String baseLanguage;
  final String learningLanguage;

  const Course({
    required this.id,
    required this.baseLanguage,
    required this.learningLanguage,
  });

  factory Course.fromJson(Map<String, dynamic> json) => Course(
    id: json['course_id'] as String,
    baseLanguage: json['base_language'] as String,
    learningLanguage: json['learning_language'] as String,
  );

  /// e.g. "Japanese (from English)"
  String get label =>
      '${languageName(learningLanguage)} (from ${languageName(baseLanguage)})';
}

/// A word inside a [Token] (e.g. 火车 in 火车站). Always saveable.
class Part {
  final String surface;
  final Span span;
  final String dictForm;
  final String reading;
  final String translation;

  const Part({
    required this.surface,
    required this.span,
    required this.dictForm,
    required this.reading,
    required this.translation,
  });

  factory Part.fromJson(Map<String, dynamic> json) => Part(
    surface: json['surface'] as String,
    span: _span(json['span']),
    dictForm: json['dict_form'] as String? ?? '',
    reading: json['reading'] as String? ?? '',
    translation: json['translation'] as String? ?? '',
  );
}

class Token {
  final String surface;
  final Span span;

  /// False for particles, punctuation, symbols and whitespace. Those only
  /// have [surface] and [span].
  final bool saveable;
  final String dictForm;
  final String reading;
  final String translation;
  final List<Part> parts;

  const Token({
    required this.surface,
    required this.span,
    required this.saveable,
    this.dictForm = '',
    this.reading = '',
    this.translation = '',
    this.parts = const [],
  });

  factory Token.fromJson(Map<String, dynamic> json) => Token(
    surface: json['surface'] as String,
    span: _span(json['span']),
    saveable: json['saveable'] as bool? ?? false,
    dictForm: json['dict_form'] as String? ?? '',
    reading: json['reading'] as String? ?? '',
    translation: json['translation'] as String? ?? '',
    parts: [
      for (final p in json['parts'] as List? ?? const [])
        Part.fromJson(p as Map<String, dynamic>),
    ],
  );
}

/// Result of `POST /analyze`.
class Analysis {
  /// The normalized sentence. Sent back unchanged to save and explain.
  final String sentence;
  final String translation;

  /// The sentence is not in the course's learning language.
  final bool languageMismatch;
  final List<Token> tokens;

  const Analysis({
    required this.sentence,
    required this.translation,
    required this.languageMismatch,
    required this.tokens,
  });

  factory Analysis.fromJson(Map<String, dynamic> json) => Analysis(
    sentence: json['sentence'] as String,
    translation: json['translation'] as String? ?? '',
    languageMismatch: json['language_mismatch'] as bool? ?? false,
    tokens: [
      for (final t in json['tokens'] as List? ?? const [])
        Token.fromJson(t as Map<String, dynamic>),
    ],
  );
}

/// Result of `POST /vocabs`.
class SavedVocab {
  final String vocabId;
  final String occurrenceId;
  final bool vocabCreated;
  final bool occurrenceCreated;

  const SavedVocab({
    required this.vocabId,
    required this.occurrenceId,
    required this.vocabCreated,
    required this.occurrenceCreated,
  });

  factory SavedVocab.fromJson(Map<String, dynamic> json) => SavedVocab(
    vocabId: json['vocab_id'] as String,
    occurrenceId: json['occurrence_id'] as String,
    vocabCreated: json['vocab_created'] as bool,
    occurrenceCreated: json['occurrence_created'] as bool,
  );

  /// Feedback message, as specified by the Save Vocab use case.
  String get message {
    if (vocabCreated) return 'Saved';
    if (occurrenceCreated) return 'New example added';
    return 'Already saved';
  }
}

class Progress {
  /// `new`, `learning` or `known`.
  final String state;
  final int streak;
  final DateTime? dueAt;

  const Progress({required this.state, required this.streak, this.dueAt});

  factory Progress.fromJson(Map<String, dynamic> json) => Progress(
    state: json['state'] as String? ?? 'new',
    streak: (json['streak'] as num?)?.toInt() ?? 0,
    dueAt: json['due_at'] == null
        ? null
        : DateTime.parse(json['due_at'] as String),
  );
}

/// A vocab as shown in the vocab list.
class VocabItem {
  final String id;
  final String dictForm;
  final String reading;
  final String translation;
  final int occurrenceCount;
  final DateTime lastSavedAt;
  final Progress progress;

  const VocabItem({
    required this.id,
    required this.dictForm,
    required this.reading,
    required this.translation,
    required this.occurrenceCount,
    required this.lastSavedAt,
    required this.progress,
  });

  factory VocabItem.fromJson(Map<String, dynamic> json) => VocabItem(
    id: json['id'] as String,
    dictForm: json['dict_form'] as String,
    reading: json['reading'] as String? ?? '',
    translation: json['translation'] as String? ?? '',
    occurrenceCount: (json['occurrence_count'] as num?)?.toInt() ?? 0,
    lastSavedAt: DateTime.parse(json['last_saved_at'] as String),
    progress: Progress.fromJson(json['progress'] as Map<String, dynamic>),
  );
}

/// One page of `GET /courses/{id}/vocabs`.
class VocabList {
  final List<VocabItem> items;

  /// Null on the last page.
  final String? nextCursor;

  const VocabList({required this.items, this.nextCursor});

  factory VocabList.fromJson(Map<String, dynamic> json) => VocabList(
    items: [
      for (final i in json['items'] as List? ?? const [])
        VocabItem.fromJson(i as Map<String, dynamic>),
    ],
    nextCursor: json['next_cursor'] as String?,
  );
}

/// A vocab inside one saved sentence.
class Occurrence {
  final String id;
  final String sentence;
  final String sentenceTranslation;
  final String surface;
  final Span span;

  /// The meaning in this sentence.
  final String translation;
  final bool fromPart;
  final DateTime createdAt;

  const Occurrence({
    required this.id,
    required this.sentence,
    required this.sentenceTranslation,
    required this.surface,
    required this.span,
    required this.translation,
    required this.fromPart,
    required this.createdAt,
  });

  factory Occurrence.fromJson(Map<String, dynamic> json) => Occurrence(
    id: json['id'] as String,
    sentence: json['sentence'] as String,
    sentenceTranslation: json['sentence_translation'] as String? ?? '',
    surface: json['surface'] as String,
    span: _span(json['span']),
    translation: json['translation'] as String? ?? '',
    fromPart: json['from_part'] as bool? ?? false,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

/// Result of `GET /vocabs/{id}`.
class VocabDetail {
  final String id;
  final String dictForm;
  final String reading;
  final String translation;
  final Progress progress;

  /// Newest first.
  final List<Occurrence> occurrences;

  const VocabDetail({
    required this.id,
    required this.dictForm,
    required this.reading,
    required this.translation,
    required this.progress,
    required this.occurrences,
  });

  factory VocabDetail.fromJson(Map<String, dynamic> json) => VocabDetail(
    id: json['id'] as String,
    dictForm: json['dict_form'] as String,
    reading: json['reading'] as String? ?? '',
    translation: json['translation'] as String? ?? '',
    progress: Progress.fromJson(json['progress'] as Map<String, dynamic>),
    occurrences: [
      for (final o in json['occurrences'] as List? ?? const [])
        Occurrence.fromJson(o as Map<String, dynamic>),
    ],
  );
}

class QuizScore {
  final int correct;
  final int answered;
  final int total;

  const QuizScore({
    required this.correct,
    required this.answered,
    required this.total,
  });

  factory QuizScore.fromJson(Map<String, dynamic> json) => QuizScore(
    correct: (json['correct'] as num?)?.toInt() ?? 0,
    answered: (json['answered'] as num?)?.toInt() ?? 0,
    total: (json['total'] as num?)?.toInt() ?? 0,
  );
}

/// `fill_blank`, `translation` or `reading`. Only the fields its type shows
/// are set. The correct option is never sent.
class QuizQuestion {
  final String id;
  final String type;

  /// `fill_blank`: the sentence, with the vocab at [span].
  final String sentence;
  final Span? span;

  /// `translation` and `reading`.
  final String dictForm;

  /// `translation` only.
  final String reading;
  final List<String> options;

  const QuizQuestion({
    required this.id,
    required this.type,
    this.sentence = '',
    this.span,
    this.dictForm = '',
    this.reading = '',
    required this.options,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) => QuizQuestion(
    id: json['id'] as String,
    type: json['type'] as String,
    sentence: json['sentence'] as String? ?? '',
    span: json['span'] == null ? null : _span(json['span']),
    dictForm: json['dict_form'] as String? ?? '',
    reading: json['reading'] as String? ?? '',
    options: [
      for (final o in json['options'] as List? ?? const []) o as String,
    ],
  );
}

/// Result of `POST /quiz/start`.
class QuizSession {
  /// Null when there is nothing to practice.
  final String? sessionId;
  final QuizScore score;

  /// The unanswered questions, in order. A resumed session only has the
  /// ones left.
  final List<QuizQuestion> questions;

  const QuizSession({
    this.sessionId,
    required this.score,
    required this.questions,
  });

  factory QuizSession.fromJson(Map<String, dynamic> json) => QuizSession(
    sessionId: json['session_id'] as String?,
    score: QuizScore.fromJson(
      json['score'] as Map<String, dynamic>? ?? const {},
    ),
    questions: [
      for (final q in json['questions'] as List? ?? const [])
        QuizQuestion.fromJson(q as Map<String, dynamic>),
    ],
  );
}

/// Result of `POST /quiz/submit`.
class QuizAnswer {
  final bool correct;
  final int correctIndex;
  final String dictForm;
  final String reading;
  final String translation;

  /// `fill_blank` only.
  final String? sentenceTranslation;
  final QuizScore score;
  final bool sessionCompleted;

  const QuizAnswer({
    required this.correct,
    required this.correctIndex,
    required this.dictForm,
    required this.reading,
    required this.translation,
    this.sentenceTranslation,
    required this.score,
    required this.sessionCompleted,
  });

  factory QuizAnswer.fromJson(Map<String, dynamic> json) {
    final vocab = json['vocab'] as Map<String, dynamic>? ?? const {};
    return QuizAnswer(
      correct: json['correct'] as bool,
      correctIndex: (json['correct_index'] as num).toInt(),
      dictForm: vocab['dict_form'] as String? ?? '',
      reading: vocab['reading'] as String? ?? '',
      translation: vocab['translation'] as String? ?? '',
      sentenceTranslation: json['sentence_translation'] as String?,
      score: QuizScore.fromJson(json['score'] as Map<String, dynamic>),
      sessionCompleted: json['session_completed'] as bool? ?? false,
    );
  }
}

/// One card of `POST /flash-card/start`. The back is included.
class FlashCard {
  final String vocabId;
  final String dictForm;
  final String reading;
  final String translation;

  const FlashCard({
    required this.vocabId,
    required this.dictForm,
    required this.reading,
    required this.translation,
  });

  factory FlashCard.fromJson(Map<String, dynamic> json) => FlashCard(
    vocabId: json['vocab_id'] as String,
    dictForm: json['dict_form'] as String,
    reading: json['reading'] as String? ?? '',
    translation: json['translation'] as String? ?? '',
  );
}
