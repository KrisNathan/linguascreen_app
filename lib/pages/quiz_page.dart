import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Model classes for quiz data
class QuizItem {
  final String word;
  final String sentence;
  final String correctAnswer;
  final List<String> options;

  QuizItem({
    required this.word,
    required this.sentence,
    required this.correctAnswer,
    required this.options,
  });

  factory QuizItem.fromWordEntry(Map<String, dynamic> wordEntry) {
    final word = wordEntry['word'] ?? '';
    final sentences = wordEntry['sentences'] as List<dynamic>? ?? [];
    
    if (sentences.isEmpty) {
      return QuizItem(
        word: word,
        sentence: 'No sentence available',
        correctAnswer: 'No meaning available',
        options: ['No meaning available'],
      );
    }
    
    final firstSentence = sentences[0];
    final sentence = firstSentence['sentence'] ?? 'No sentence available';
    final correctAnswer = firstSentence['word_meaning'] ?? 'No meaning available';
    
    return QuizItem(
      word: word,
      sentence: sentence,
      correctAnswer: correctAnswer,
      options: [correctAnswer], // Will be populated with distractors later
    );
  }

  factory QuizItem.fromJson(Map<String, dynamic> json) {
    return QuizItem(
      word: json['word'] ?? '',
      sentence: json['sentence'] ?? '',
      correctAnswer: json['correct_answer'] ?? '',
      options: List<String>.from(json['options'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'word': word,
      'sentence': sentence,
      'correct_answer': correctAnswer,
      'options': options,
    };
  }
}

class QuizPage extends StatefulWidget {
  const QuizPage({super.key});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  List<QuizItem> quizData = [];
  List<String> allMeanings = []; // For generating distractors
  
  int currentQuestionIndex = 0;
  int? selectedOptionIndex;
  bool hasAnswered = false;
  int correctAnswers = 0;
  int totalQuestions = 0;
  bool quizCompleted = false;
  bool isLoading = true;
  String errorMessage = '';

  // API configuration
  static final String apiBaseUrl = dotenv.env['LINGUASCREEN_API_URL']  ?? 'http://10.0.2.2:8000';
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();

  // Default fallback quiz data
  final List<QuizItem> fallbackQuizData = [
    QuizItem(
      word: '猫',
      sentence: '黒天を見上げて猫はマオマオは溜息をついた。',
      correctAnswer: 'Cat - a small domesticated carnivorous mammal',
      options: [
        'Cat - a small domesticated carnivorous mammal',
        'Dog - a loyal companion animal',
        'Bird - a flying creature with wings',
        'Fish - an aquatic animal with gills'
      ],
    ),
    QuizItem(
      word: 'Flutter',
      sentence: 'Flutter makes it easy to build beautiful apps.',
      correctAnswer: 'UI toolkit for building applications',
      options: [
        'UI toolkit for building applications',
        'A type of butterfly movement',
        'A programming language',
        'A database management system'
      ],
    ),
    QuizItem(
      word: '学習',
      sentence: '毎日日本語を学習している。',
      correctAnswer: 'Learning/Study - acquiring knowledge',
      options: [
        'Learning/Study - acquiring knowledge',
        'Teaching - sharing knowledge',
        'Playing - recreational activity',
        'Working - professional activity'
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeQuiz();
  }

  Future<void> _initializeQuiz() async {
    await _fetchQuizData();
    if (mounted && quizData.isNotEmpty) {
      _generateDistractors();
      _shuffleOptions();
      setState(() {
        totalQuestions = quizData.length;
        isLoading = false;
      });
    } else if (mounted) {
      _useFallbackData();
    }
  }

  // Fetch quiz data from API
  Future<void> _fetchQuizData() async {
    if (!mounted) return;
    
    if (mounted) {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });
    }

    try {
      final token = await secureStorage.read(key: 'access_token');
      final response = await http.get(
        Uri.parse('$apiBaseUrl/sentence'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return; // Check mounted after async operation

      if (response.statusCode == 200) {
        final dynamic jsonData = jsonDecode(response.body);
        List<Map<String, dynamic>> wordsData = [];
        
        if (jsonData is List) {
          wordsData = List<Map<String, dynamic>>.from(jsonData);
        } else if (jsonData is Map<String, dynamic>) {
          final List<dynamic>? words = jsonData['words'] ?? jsonData['data'];
          if (words != null) {
            wordsData = List<Map<String, dynamic>>.from(words);
          }
        }

        if (wordsData.isNotEmpty) {
          // Convert word entries to quiz items
          List<QuizItem> fetchedQuizData = [];
          Set<String> meanings = {};
          
          for (var wordEntry in wordsData) {
            final quizItem = QuizItem.fromWordEntry(wordEntry);
            if (quizItem.correctAnswer != 'No meaning available' && 
                quizItem.sentence != 'No sentence available') {
              fetchedQuizData.add(quizItem);
              meanings.add(quizItem.correctAnswer);
            }
          }
          
          // Shuffle and limit to reasonable number for quiz
          fetchedQuizData.shuffle();
          
          if (mounted) {
            setState(() {
              quizData = fetchedQuizData.take(10).toList(); // Limit to 10 questions
              allMeanings = meanings.toList();
              isLoading = false;
            });
          }
        } else {
          throw Exception('No valid quiz data found');
        }
      } else {
        throw Exception('Failed to load quiz data: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = 'Error loading quiz: $e';
          isLoading = false;
        });
        _useFallbackData();
      }
    }
  }

  void _useFallbackData() {
    if (!mounted) return;
    
    if (mounted) {
    setState(() {
      quizData = List.from(fallbackQuizData);
      totalQuestions = quizData.length;
      isLoading = false;
      if (errorMessage.isEmpty) {
        errorMessage = 'Using offline quiz data';
      }
    });
    }
    _shuffleOptions();
  }

  void _generateDistractors() {
    final random = Random();
    
    for (int i = 0; i < quizData.length; i++) {
      final currentItem = quizData[i];
      final correctAnswer = currentItem.correctAnswer;
      
      // Get other meanings as distractors
      List<String> distractors = allMeanings
          .where((meaning) => meaning != correctAnswer)
          .toList();
      
      // Shuffle and take up to 3 distractors
      distractors.shuffle(random);
      distractors = distractors.take(3).toList();
      
      // If we don't have enough distractors, add some generic ones
      if (distractors.length < 3) {
        final genericDistractors = [
          'A type of food or cuisine',
          'A place or location',
          'An action or activity',
          'A feeling or emotion',
          'A tool or instrument',
          'A time or period',
          'A natural phenomenon',
          'A social concept',
        ];
        
        for (String generic in genericDistractors) {
          if (distractors.length >= 3) break;
          if (generic != correctAnswer && !distractors.contains(generic)) {
            distractors.add(generic);
          }
        }
      }
      
      // Create options list with correct answer and distractors
      List<String> options = [correctAnswer, ...distractors.take(3)];
      options.shuffle(random);
      
      // Update the quiz item with new options
      quizData[i] = QuizItem(
        word: currentItem.word,
        sentence: currentItem.sentence,
        correctAnswer: correctAnswer,
        options: options,
      );
    }
  }

  void _shuffleOptions() {
    final random = Random();
    for (var question in quizData) {
      question.options.shuffle(random);
    }
  }

  void _selectOption(int index) {
    if (hasAnswered || !mounted) return;
    
    if (mounted) {
    setState(() {
      selectedOptionIndex = index;
    });
    }
  }

  void _submitAnswer() {
    if (selectedOptionIndex == null || !mounted) return;

    if (mounted) {
    setState(() {
      hasAnswered = true;
      
      final currentQuestion = quizData[currentQuestionIndex];
      final selectedAnswer = currentQuestion.options[selectedOptionIndex!];
      
      if (selectedAnswer == currentQuestion.correctAnswer) {
        correctAnswers++;
      }
    });
    }
  }

  void _nextQuestion() {
    if (!mounted) return;
    
    if (currentQuestionIndex < quizData.length - 1) {
      if (mounted) {
      setState(() {
        currentQuestionIndex++;
        selectedOptionIndex = null;
        hasAnswered = false;
      });
      }
    } else {
      if (mounted) {
      setState(() {
        quizCompleted = true;
      });
      }
    }
  }

  void _restartQuiz() {
    if (!mounted) return;
    
    if (mounted) {
    setState(() {
      currentQuestionIndex = 0;
      selectedOptionIndex = null;
      hasAnswered = false;
      correctAnswers = 0;
      quizCompleted = false;
    });
    }
    _shuffleOptions();
  }

  Future<void> _refreshQuiz() async {
    if (!mounted) return;
    
    if (mounted) {
    setState(() {
      currentQuestionIndex = 0;
      selectedOptionIndex = null;
      hasAnswered = false;
      correctAnswers = 0;
      quizCompleted = false;
      quizData.clear();
      allMeanings.clear();
    });
    }
    await _initializeQuiz();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingScreen();
    }

    if (quizCompleted) {
      return _buildResultsScreen();
    }

    if (quizData.isEmpty) {
      return _buildErrorScreen();
    }

    final currentQuestion = quizData[currentQuestionIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshQuiz,
            tooltip: 'Refresh Quiz',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Text(
                '${currentQuestionIndex + 1}/$totalQuestions',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // TODO: uncomment when API is implemented
              // Error message
              // if (errorMessage.isNotEmpty)
              //   Container(
              //     width: double.infinity,
              //     margin: const EdgeInsets.only(bottom: 16.0),
              //     padding: const EdgeInsets.all(12.0),
              //     decoration: BoxDecoration(
              //       color: Colors.orange[100],
              //       borderRadius: BorderRadius.circular(8.0),
              //     ),
              //     child: Row(
              //       children: [
              //         Icon(Icons.info, color: Colors.orange[800]),
              //         const SizedBox(width: 8),
              //         Expanded(
              //           child: Text(
              //             errorMessage,
              //             style: TextStyle(color: Colors.orange[800]),
              //           ),
              //         ),
              //         TextButton(
              //           onPressed: () {
              //             if (mounted) {
              //               setState(() => errorMessage = '');
              //             }
              //           },
              //           child: const Text('Dismiss'),
              //         ),
              //       ],
              //     ),
              //   ),

              // Progress Bar
              Card.filled(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Progress',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('${((currentQuestionIndex + 1) / totalQuestions * 100).round()}%'),
                        ],
                      ),
                      const SizedBox(height: 8.0),
                      LinearProgressIndicator(
                        value: (currentQuestionIndex + 1) / totalQuestions,
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16.0),
              
              // Question Card
              Card.filled(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Word
                      Text(
                        'What does this word mean?',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Text(
                          currentQuestion.word,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      
                      const SizedBox(height: 16.0),
                      
                      // Sentence Context
                      Text(
                        'From sentence:',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          currentQuestion.sentence,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16.0),
              
              // Options
              ...currentQuestion.options.asMap().entries.map((entry) {
                final index = entry.key;
                final option = entry.value;
                final isSelected = selectedOptionIndex == index;
                final isCorrect = option == currentQuestion.correctAnswer;
                
                Color? cardColor;
                if (hasAnswered) {
                  if (isCorrect) {
                    cardColor = Colors.green.withOpacity(0.2);
                  } else if (isSelected && !isCorrect) {
                    cardColor = Colors.red.withOpacity(0.2);
                  }
                }
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Card.filled(
                    color: cardColor ?? (isSelected 
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                        : Theme.of(context).colorScheme.primaryContainer),
                    child: InkWell(
                      onTap: () => _selectOption(index),
                      borderRadius: BorderRadius.circular(12.0),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected 
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.surface,
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              ),
                              child: isSelected
                                  ? Icon(
                                      Icons.check,
                                      size: 16,
                                      color: Theme.of(context).colorScheme.onPrimary,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12.0),
                            Expanded(
                              child: Text(
                                '${String.fromCharCode(65 + index)}. $option',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                            if (hasAnswered && isCorrect)
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
              
              const SizedBox(height: 16.0),
              
              // Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: hasAnswered 
                      ? _nextQuestion 
                      : (selectedOptionIndex != null ? _submitAnswer : null),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16.0),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  child: Text(
                    hasAnswered 
                        ? (currentQuestionIndex < quizData.length - 1 ? 'NEXT' : 'FINISH')
                        : 'SUBMIT',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading quiz questions...'),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.quiz,
                size: 64,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              const Text(
                'No quiz questions available',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _refreshQuiz,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsScreen() {
    final percentage = totalQuestions > 0 ? (correctAnswers / totalQuestions * 100).round() : 0;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Results'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Card.filled(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Icon(
                      percentage >= 70 ? Icons.celebration : Icons.thumb_up,
                      size: 64,
                      color: percentage >= 70 ? Colors.green : Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16.0),
                    const Text(
                      'Quiz Completed!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    Text(
                      'Your Score',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    Text(
                      '$correctAnswers/$totalQuestions',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    Text(
                      '$percentage%',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 32.0),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _restartQuiz,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16.0),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: const Text(
                  'TAKE QUIZ AGAIN',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 8.0),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _refreshQuiz,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16.0),
                ),
                child: const Text(
                  'NEW QUIZ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 8.0),
            
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'BACK TO HOME',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}