import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/course_provider.dart';
import '../models/lesson.dart';
import '../utils/app_theme.dart';
import 'dart:math' as math;

class QuizScreen extends StatefulWidget {
  final String lessonId;

  const QuizScreen({super.key, required this.lessonId});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  QuizQuestion? _currentQuestion;
  bool _isLoading = true;
  bool _isGeneratingNext = false;
  int _questionsAnswered = 0;
  int _score = 0;
  int? _selectedOptionIndex;
  bool _isAnswered = false;

  @override
  void initState() {
    super.initState();
    _loadNextQuestion();
  }

  Future<void> _loadNextQuestion() async {
    setState(() {
      _isLoading = true;
      _selectedOptionIndex = null;
      _isAnswered = false;
    });

    final provider = Provider.of<CourseProvider>(context, listen: false);
    final topics = provider.currentTopics;
    
    if (topics.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    // Pick a random topic for variety
    final topic = topics[math.Random().nextInt(topics.length)];
    
    try {
      final jsonStr = await provider.aiService.generateQuizJson(
        topic.content, 
        topicId: topic.id,
      ).timeout(const Duration(seconds: 60)); // 60s timeout for single question

      final data = jsonDecode(jsonStr);
      final List<dynamic> qList = data['questions'];
      if (qList.isNotEmpty) {
        setState(() {
          _currentQuestion = QuizQuestion.fromMap(qList.first);
          _isLoading = false;
        });
      } else {
        throw Exception("Empty question list");
      }
    } catch (e) {
      print("❌ Quiz Error: $e");
      // Fallback mock question if AI fails
      setState(() {
        _currentQuestion = QuizQuestion(
          id: 'mock',
          question: 'What is the primary topic of this lesson?',
          options: ['Science', 'History', 'Math', 'Art'],
          correctOptionIndex: 0,
          explanation: 'This is a fallback question.',
        );
        _isLoading = false;
      });
    }
  }

  void _submitAnswer(int optionIndex) {
    if (_isAnswered) return;

    setState(() {
      _selectedOptionIndex = optionIndex;
      _isAnswered = true;
      _questionsAnswered++;
      if (optionIndex == _currentQuestion!.correctOptionIndex) {
        _score++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Quiz Practice ($_questionsAnswered Done)'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.exit_to_app),
            label: const Text('Exit'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Generating a unique question...'),
                ],
              ),
            )
          : _currentQuestion == null
              ? const Center(child: Text('Failed to load question'))
              : Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Score Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.cyanAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.stars_rounded, color: AppTheme.cyanAccent),
                            const SizedBox(width: 8),
                            Text(
                              'Score: $_score / $_questionsAnswered',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.cyanAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Question
                      Text(
                        _currentQuestion!.question,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Options
                      ...List.generate(_currentQuestion!.options.length, (index) {
                        final isSelected = _selectedOptionIndex == index;
                        final isCorrect = index == _currentQuestion!.correctOptionIndex;
                        
                        Color? backgroundColor;
                        Color? borderColor;
                        
                        if (_isAnswered) {
                          if (isCorrect) {
                            backgroundColor = Colors.green.withOpacity(0.2);
                            borderColor = Colors.green;
                          } else if (isSelected) {
                            backgroundColor = Colors.red.withOpacity(0.2);
                            borderColor = Colors.red;
                          }
                        } else if (isSelected) {
                          backgroundColor = AppTheme.cyanAccent.withOpacity(0.1);
                          borderColor = AppTheme.cyanAccent;
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: backgroundColor ?? (isDark ? AppTheme.darkCard : Colors.white),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: borderColor ?? (isDark ? AppTheme.darkCard : Colors.grey.shade300),
                              width: 2,
                            ),
                          ),
                          child: InkWell(
                            onTap: () => _submitAnswer(index),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _currentQuestion!.options[index],
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                  ),
                                  if (_isAnswered && isCorrect)
                                    const Icon(Icons.check_circle, color: Colors.green),
                                  if (_isAnswered && isSelected && !isCorrect)
                                    const Icon(Icons.cancel, color: Colors.red),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      
                      const Spacer(),
                      
                      // Explanation & Next Button
                      if (_isAnswered) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Explanation:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(_currentQuestion!.explanation),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _loadNextQuestion,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.cyanAccent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Next Question',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}
