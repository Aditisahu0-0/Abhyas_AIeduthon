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
  final String? initialContent;
  final String? initialTopicId;

  const QuizScreen({
    super.key,
    required this.lessonId,
    this.initialContent,
    this.initialTopicId,
  });

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
    
    // Determine which content to use
    String topicContent;
    String? topicId;

    // RULE 1: If it's the VERY FIRST question and we have initial content passed from the page, USE IT.
    if (_questionsAnswered == 0 && widget.initialContent != null) {
       topicContent = widget.initialContent!;
       topicId = widget.initialTopicId;
    } else {
       // RULE 2: Otherwise, pick a random topic from the lesson
       final topics = provider.currentTopics;
       if (topics.isEmpty) {
         setState(() => _isLoading = false);
         return;
       }
       final topic = topics[math.Random().nextInt(topics.length)];
       topicContent = topic.content;
       topicId = topic.id;
    }

    try {
      final jsonStr = await provider.aiService
          .generateQuizJson(topicContent, topicId: topicId)
          .timeout(const Duration(seconds: 60));

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

  Future<void> _submitAnswer(int optionIndex) async {
    if (_isAnswered) return;

    setState(() {
      _selectedOptionIndex = optionIndex;
      _isAnswered = true;
      _questionsAnswered++;
      if (optionIndex == _currentQuestion!.correctOptionIndex) {
        _score++;
      }
    });

    try {
      final provider = Provider.of<CourseProvider>(context, listen: false);
      await provider.recordQuizAttempt(
        lessonId: widget.lessonId,
        questionText: _currentQuestion!.question,
        options: _currentQuestion!.options,
        correctAnswer:
            _currentQuestion!.options[_currentQuestion!.correctOptionIndex],
        selectedAnswer: _currentQuestion!.options[optionIndex],
        isCorrect: optionIndex == _currentQuestion!.correctOptionIndex,
      );
    } catch (e) {
      print("Error saving attempt: $e");
    }
  }

  Future<void> _showResultsDialog() async {
    if (_questionsAnswered == 0) {
      Navigator.pop(context);
      return;
    }

    final provider = Provider.of<CourseProvider>(context, listen: false);

    // Save quiz attempt to database
    await provider.dbHelper.saveQuizAttempt(
      widget.lessonId,
      _score,
      _questionsAnswered,
    );

    final percentage = (_score / _questionsAnswered * 100).round();
    String message;
    IconData icon;
    Color color;

    if (percentage >= 80) {
      message = 'Excellent work! Keep it up! 🌟';
      icon = Icons.emoji_events;
      color = Colors.amber;
    } else if (percentage >= 60) {
      message = 'Good job! Practice makes perfect! 👍';
      icon = Icons.thumb_up;
      color = Colors.green;
    } else if (percentage >= 40) {
      message = 'Keep trying! You\'re getting there! 💪';
      icon = Icons.trending_up;
      color = Colors.orange;
    } else {
      message = 'Don\'t give up! Review and try again! 📚';
      icon = Icons.school;
      color = Colors.blue;
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Icon(icon, size: 64, color: color),
            const SizedBox(height: 16),
            const Text('Quiz Complete!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$_score / $_questionsAnswered',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text('$percentage%', style: TextStyle(fontSize: 24, color: color)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close quiz screen
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Quiz Practice ($_questionsAnswered Done)'),
        actions: [
          TextButton.icon(
            onPressed: _showResultsDialog,
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
          : SingleChildScrollView(
              child: Padding(
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
                          const Icon(
                            Icons.stars_rounded,
                            color: AppTheme.cyanAccent,
                          ),
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
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 32),

                    // Options
                    ...List.generate(_currentQuestion!.options.length, (index) {
                      final isSelected = _selectedOptionIndex == index;
                      final isCorrect =
                          index == _currentQuestion!.correctOptionIndex;

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
                          color:
                              backgroundColor ??
                              (isDark ? AppTheme.darkCard : Colors.white),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                borderColor ??
                                (isDark
                                    ? AppTheme.darkCard
                                    : Colors.grey.shade300),
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
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ),
                                if (_isAnswered && isCorrect)
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  ),
                                if (_isAnswered && isSelected && !isCorrect)
                                  const Icon(Icons.cancel, color: Colors.red),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 32),

                    // Explanation & Next Button
                    if (_isAnswered) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade100,
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
            ),
    );
  }
}
