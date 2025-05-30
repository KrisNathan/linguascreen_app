import 'package:flutter/material.dart';
// import 'dart:math';

class QuizPage extends StatefulWidget {
  const QuizPage({super.key});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  // Sample quiz data
  final List<Map<String, dynamic>> quizData = [
    {
      'word': '猫',
      'sentence': '黒天を見上げて猫はマオマオは溜息をついた。',
      'correctAnswer': 'Cat - a small domesticated carnivorous mammal',
      'options': [
        'Cat - a small domesticated carnivorous mammal',
        'Dog - a loyal companion animal',
        'Bird - a flying creature with wings',
        'Fish - an aquatic animal with gills'
      ]
    },
    {
      'word': 'Flutter',
      'sentence': 'Flutter makes it easy to build beautiful apps.',
      'correctAnswer': 'UI toolkit for building applications',
      'options': [
        'UI toolkit for building applications',
        'A type of butterfly movement',
        'A programming language',
        'A database management system'
      ]
    },
    {
      'word': '学習',
      'sentence': '毎日日本語を学習している。',
      'correctAnswer': 'Learning/Study - acquiring knowledge',
      'options': [
        'Learning/Study - acquiring knowledge',
        'Teaching - sharing knowledge',
        'Playing - recreational activity',
        'Working - professional activity'
      ]
    },
    {
      'word': 'Lorem',
      'sentence': 'Lorem ipsum dolor sit amet, consectetur adi',
      'correctAnswer': 'Placeholder text used in printing',
      'options': [
        'Placeholder text used in printing',
        'A type of ancient language',
        'A mathematical formula',
        'A cooking ingredient'
      ]
    },
  ];

  int currentQuestionIndex = 0;
  int? selectedOptionIndex;
  bool hasAnswered = false;
  int correctAnswers = 0;
  int totalQuestions = 0;
  bool quizCompleted = false;

  @override
  void initState() {
    super.initState();
    totalQuestions = quizData.length;
    _shuffleOptions();
  }

  void _shuffleOptions() {
    // Shuffle the options for each question
    for (var question in quizData) {
      (question['options'] as List).shuffle();
    }
  }

  void _selectOption(int index) {
    if (hasAnswered) return;
    
    setState(() {
      selectedOptionIndex = index;
    });
  }

  void _submitAnswer() {
    if (selectedOptionIndex == null) return;

    setState(() {
      hasAnswered = true;
      
      final currentQuestion = quizData[currentQuestionIndex];
      final selectedAnswer = currentQuestion['options'][selectedOptionIndex!];
      
      if (selectedAnswer == currentQuestion['correctAnswer']) {
        correctAnswers++;
      }
    });
  }

  void _nextQuestion() {
    if (currentQuestionIndex < quizData.length - 1) {
      setState(() {
        currentQuestionIndex++;
        selectedOptionIndex = null;
        hasAnswered = false;
      });
    } else {
      setState(() {
        quizCompleted = true;
      });
    }
  }

  void _restartQuiz() {
    setState(() {
      currentQuestionIndex = 0;
      selectedOptionIndex = null;
      hasAnswered = false;
      correctAnswers = 0;
      quizCompleted = false;
    });
    _shuffleOptions();
  }

  @override
  Widget build(BuildContext context) {
    if (quizCompleted) {
      return _buildResultsScreen();
    }

    final currentQuestion = quizData[currentQuestionIndex];
    final word = currentQuestion['word'] as String;
    final sentence = currentQuestion['sentence'] as String;
    final options = currentQuestion['options'] as List<String>;
    final correctAnswer = currentQuestion['correctAnswer'] as String;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        actions: [
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
                          Text(
                            'Progress',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
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
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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
                          word,
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
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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
                            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          sentence,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16.0),
              
              // Options
              ...options.asMap().entries.map((entry) {
                final index = entry.key;
                final option = entry.value;
                final isSelected = selectedOptionIndex == index;
                final isCorrect = option == correctAnswer;
                
                Color? cardColor;
                if (hasAnswered) {
                  if (isCorrect) {
                    cardColor = Colors.green.withValues(alpha: 0.2);
                  } else if (isSelected && !isCorrect) {
                    cardColor = Colors.red.withValues(alpha: 0.2);
                  }
                }
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Card.filled(
                    color: cardColor ?? (isSelected 
                        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
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
                              Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
                              }), //.toList(),
              
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

  Widget _buildResultsScreen() {
    final percentage = (correctAnswers / totalQuestions * 100).round();
    
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
                    Text(
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
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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
                      style: TextStyle(
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