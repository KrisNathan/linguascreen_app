import 'package:flutter/material.dart';

class DictionaryPage extends StatefulWidget {
  const DictionaryPage({super.key});

  @override
  State<DictionaryPage> createState() => _DictionaryPageState();
}

class _DictionaryPageState extends State<DictionaryPage> {
  // Sample data structure based on your friend's specification
  final List<Map<String, dynamic>> words = [
    {
      'word': '猫',
      'sentences': [
        {
          'sentence': '黒天を見上げて猫はマオマオは溜息をついた。',
          'word_meaning': 'Cat - a small domesticated carnivorous mammal'
        },
        {
          'sentence': '隣の猫が毎日庭に来る。',
          'word_meaning': 'Cat - referring to a neighbor\'s pet'
        }
      ]
    },
    {
      'word': 'Lorem',
      'sentences': [
        {
          'sentence': 'Lorem ipsum dolor sit amet, consectetur adi',
          'word_meaning': 'Lorem - placeholder text used in printing'
        },
        {
          'sentence': 'Lorem text is commonly used in design.',
          'word_meaning': 'Lorem - dummy text for layout purposes'
        }
      ]
    },
    {
      'word': 'Flutter',
      'sentences': [
        {
          'sentence': 'Flutter makes it easy to build beautiful apps.',
          'word_meaning': 'Flutter - UI toolkit for building applications'
        },
        {
          'sentence': 'I learned Flutter for mobile development.',
          'word_meaning': 'Flutter - cross-platform development framework'
        }
      ]
    },
    {
      'word': '学習',
      'sentences': [
        {
          'sentence': '毎日日本語を学習している。',
          'word_meaning': 'Learning/Study - the process of acquiring knowledge'
        },
        {
          'sentence': '機械学習は面白い分野だ。',
          'word_meaning': 'Learning - in context of machine learning'
        }
      ]
    },
  ];

  Set<int> expandedItems = {};
  String searchQuery = '';

  List<Map<String, dynamic>> get filteredWords {
    if (searchQuery.isEmpty) return words;
    return words.where((wordData) {
      return wordData['word'].toLowerCase().contains(searchQuery.toLowerCase()) ||
          (wordData['sentences'] as List).any((sentence) =>
              sentence['sentence'].toLowerCase().contains(searchQuery.toLowerCase()));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dictionary'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search words or sentences...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
              ),
            ),
          ),
          
          // Words List
          Expanded(
            child: filteredWords.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No words found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: filteredWords.length,
                    itemBuilder: (context, index) {
                      final wordData = filteredWords[index];
                      final word = wordData['word'] as String;
                      final sentences = wordData['sentences'] as List;
                      final isExpanded = expandedItems.contains(index);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Card.filled(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          child: Column(
                            children: [
                              // Word Header
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    if (isExpanded) {
                                      expandedItems.remove(index);
                                    } else {
                                      expandedItems.add(index);
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(12.0),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          word,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        isExpanded
                                            ? Icons.keyboard_arrow_up
                                            : Icons.keyboard_arrow_down,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              
                              // Expandable Sentences
                              if (isExpanded) ...[
                                const Divider(height: 1),
                                ...sentences.asMap().entries.map((entry) {
                                  final sentenceIndex = entry.key;
                                  final sentenceData = entry.value;
                                  final sentence = sentenceData['sentence'] as String;
                                  final meaning = sentenceData['word_meaning'] as String;

                                  return Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16.0),
                                    decoration: BoxDecoration(
                                      color: sentenceIndex.isEven
                                          ? Colors.transparent
                                          : Theme.of(context).colorScheme.surface.withValues(alpha: 0.3),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Sentence
                                        Container(
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
                                        const SizedBox(height: 8.0),
                                        
                                        // Word Meaning
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Icon(
                                              Icons.lightbulb_outline,
                                              size: 16,
                                              color: Theme.of(context).colorScheme.primary,
                                            ),
                                            const SizedBox(width: 8.0),
                                            Expanded(
                                              child: Text(
                                                meaning,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                })//.toList(),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          
          // Words Count Summary
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Card.filled(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.book,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8.0),
                    Text(
                      '${filteredWords.length} words saved',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}