import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

// Model classes for your dictionary data
class WordEntry {
  final String word;
  final List<SentenceData> sentences;

  WordEntry({required this.word, required this.sentences});

  factory WordEntry.fromJson(Map<String, dynamic> json) {
    return WordEntry(
      word: json['word'] ?? '',
      sentences: (json['sentences'] as List<dynamic>?)
          ?.map((s) => SentenceData.fromJson(s))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'word': word,
      'sentences': sentences.map((s) => s.toJson()).toList(),
    };
  }
}

class SentenceData {
  final String sentence;
  final String wordMeaning;

  SentenceData({required this.sentence, required this.wordMeaning});

  factory SentenceData.fromJson(Map<String, dynamic> json) {
    return SentenceData(
      sentence: json['sentence'] ?? '',
      wordMeaning: json['word_meaning'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sentence': sentence,
      'word_meaning': wordMeaning,
    };
  }
}

class DictionaryPage extends StatefulWidget {
  const DictionaryPage({super.key});

  @override
  State<DictionaryPage> createState() => _DictionaryPageState();
}

class _DictionaryPageState extends State<DictionaryPage> {
  List<WordEntry> words = [];
  Set<int> expandedItems = {};
  String searchQuery = '';
  bool isLoading = false;
  String errorMessage = '';

  // Replace with your actual API endpoint
  static const String apiBaseUrl = 'http://10.0.2.2:8000';
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    fetchWords(); // Load data when page opens
  }

  // Fetch words from API
  Future<void> fetchWords() async {
    // Check if widget is still mounted before starting
    if (!mounted) return;
    
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final token = await secureStorage.read(key: 'access_token');
      final response = await http.get(
        Uri.parse('$apiBaseUrl/sentence'), // Your API endpoint
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      // Check if widget is still mounted before calling setState
      if (!mounted) return;

      if (response.statusCode == 200) {
        // Fixed: Handle both List and Map responses
        final dynamic jsonData = jsonDecode(response.body);
        List<WordEntry> wordsList = [];
        
        if (jsonData is List) {
          wordsList = jsonData.map((json) => WordEntry.fromJson(json)).toList();
        } else if (jsonData is Map<String, dynamic>) {
          // If response is a map containing a list of words
          final List<dynamic>? wordsData = jsonData['words'] ?? jsonData['data'];
          if (wordsData != null) {
            wordsList = wordsData.map((json) => WordEntry.fromJson(json)).toList();
          }
        }
        
        setState(() {
          words = wordsList;
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load words: ${response.statusCode}');
      }
    } catch (e) {
      // Check if widget is still mounted before calling setState
      if (!mounted) return;
      
      setState(() {
        errorMessage = 'Error loading words: $e';
        isLoading = false;
        // Keep existing data if available
      });
    }
  }

  // Add new word via API
  Future<void> addWord(String word, String sentence, String meaning) async {
    try {
      final token = await secureStorage.read(key: 'access_token');
      final newWord = WordEntry(
        word: word,
        sentences: [
          SentenceData(sentence: sentence, wordMeaning: meaning),
        ],
      );

      final response = await http.post(
        Uri.parse('$apiBaseUrl/words'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: json.encode(newWord.toJson()),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        // Refresh the list after successful addition
        await fetchWords();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Word added successfully!')),
          );
        }
      } else {
        throw Exception('Failed to add word: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding word: $e')),
        );
      }
    }
  }

  // Delete word via API
  Future<void> deleteWord(int index) async {
    if (index >= filteredWords.length) return; // Fixed: use filteredWords instead of words
    
    final wordToDelete = filteredWords[index]; // Fixed: use filteredWords
    
    try {
      final token = await secureStorage.read(key: 'access_token');
      final response = await http.delete(
        Uri.parse('$apiBaseUrl/words/${Uri.encodeComponent(wordToDelete.word)}'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        // Refresh the entire list instead of removing by index
        await fetchWords();
        if (mounted) {
          setState(() {
            expandedItems.clear(); // Clear expanded items after refresh
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Word deleted successfully!')),
          );
        }
      } else {
        throw Exception('Failed to delete word: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting word: $e')),
        );
      }
    }
  }

  List<WordEntry> get filteredWords {
    if (searchQuery.isEmpty) return words;
    return words.where((wordData) {
      return wordData.word.toLowerCase().contains(searchQuery.toLowerCase()) ||
          wordData.sentences.any((sentence) =>
              sentence.sentence.toLowerCase().contains(searchQuery.toLowerCase()));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dictionary'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchWords,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddWordDialog,
            tooltip: 'Add Word',
          ),
        ],
      ),
      body: Column(
        children: [
          // Error message
          if (errorMessage.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              color: Colors.red[100],
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red[800]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      errorMessage,
                      style: TextStyle(color: Colors.red[800]),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => errorMessage = ''),
                    child: const Text('Dismiss'),
                  ),
                ],
              ),
            ),

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
                fillColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3), // Fixed: replaced withValues
              ),
            ),
          ),
          
          // Loading indicator
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
          
          // Words List
          Expanded(
            child: isLoading 
                ? const Center(child: CircularProgressIndicator())
                : filteredWords.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), // Fixed: replaced withValues
                            ),
                            const SizedBox(height: 16),
                            Text(
                              words.isEmpty ? 'No words available' : 'No words found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), // Fixed: replaced withValues
                              ),
                            ),
                            if (words.isEmpty) ...[
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: fetchWords,
                                child: const Text('Retry'),
                              ),
                            ],
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: fetchWords,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          itemCount: filteredWords.length,
                          itemBuilder: (context, index) {
                            final wordData = filteredWords[index];
                            final word = wordData.word;
                            final sentences = wordData.sentences;
                            // Fixed: Create unique key for expanded state based on word content
                            final wordKey = '${word}_${sentences.length}';
                            final isExpanded = expandedItems.contains(wordKey.hashCode);

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
                                            expandedItems.remove(wordKey.hashCode);
                                          } else {
                                            expandedItems.add(wordKey.hashCode);
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
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline),
                                              onPressed: () => _showDeleteConfirmation(index),
                                              tooltip: 'Delete word',
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
                                        final sentence = sentenceData.sentence;
                                        final meaning = sentenceData.wordMeaning;

                                        return Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(16.0),
                                          decoration: BoxDecoration(
                                            color: sentenceIndex.isEven
                                                ? Colors.transparent
                                                : Theme.of(context).colorScheme.surface.withOpacity(0.3), // Fixed: replaced withValues
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
                                                    color: Theme.of(context).colorScheme.outline.withOpacity(0.2), // Fixed: replaced withValues
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
                                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8), // Fixed: replaced withValues
                                                        fontStyle: FontStyle.italic,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
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

  // Dialog to add new word
  void _showAddWordDialog() {
    final wordController = TextEditingController();
    final sentenceController = TextEditingController();
    final meaningController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Word'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: wordController,
              decoration: const InputDecoration(labelText: 'Word'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: sentenceController,
              decoration: const InputDecoration(labelText: 'Sentence'),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: meaningController,
              decoration: const InputDecoration(labelText: 'Meaning'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (wordController.text.isNotEmpty && 
                  sentenceController.text.isNotEmpty &&
                  meaningController.text.isNotEmpty) {
                addWord(
                  wordController.text,
                  sentenceController.text,
                  meaningController.text,
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // Confirmation dialog for delete
  void _showDeleteConfirmation(int index) {
    final wordToDelete = filteredWords[index]; // Fixed: use filteredWords
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Word'),
        content: Text('Are you sure you want to delete "${wordToDelete.word}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              deleteWord(index);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}