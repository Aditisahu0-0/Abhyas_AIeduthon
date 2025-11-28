
import 'dart:convert';
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
  List<QuizQuestion> _questions = [];
  bool _isLoading = true;
  int _currentQuestionIndex = 0;
  int _score = 0;
  bool _showResult = false;
  Map<int, int> _selectedAnswers = {}; // questionIndex -> optionIndex
  String _selectedDifficulty = 'medium'; // Default difficulty
  bool _showDifficultySelector = true; // Show selector first

  @override
  void initState() {
    super.initState();
    // Don't generate quiz immediately, wait for difficulty selection
  }

  Future<void> _generateQuiz() async {
    final provider = Provider.of<CourseProvider>(context, listen: false);
    
    // Get content to generate quiz from
    // In a real app, we might pick a specific topic or the whole lesson summary
    // For now, let's grab the first topic's content if available
    final topics = provider.currentTopics;
    if (topics.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }
    
    final topic = topics.first;
    final content = topic.content;
    final topicId = topic.id;
    
    try {
      // Pass topicId for caching
      final jsonStr = await provider.aiService.generateQuizJson(
        content, 
        difficulty: _selectedDifficulty,
        topicId: topicId,
      );
      
      // Parse JSON
      // Expected format: {"questions": [...]}
      // If empty or invalid, we fallback to mock
      if (jsonStr.trim() == "{}") {
        _useMockQuiz();
      } else {
        try {
          final data = jsonDecode(jsonStr);
          final List<dynamic> qList = data['questions'];
          _questions = qList.map((q) => QuizQuestion.fromMap(q)).toList();
        } catch (e) {
          print("JSON Parse Error: $e");
          _useMockQuiz();
        }
      }
    } catch (e) {
      print("Quiz Gen Error: $e");
      _useMockQuiz();
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _useMockQuiz() {
    _questions = [
      QuizQuestion(
        id: '1',
        question: 'What is Newton\'s First Law also known as?',
        options: ['Law of Gravity', 'Law of Inertia', 'Law of Motion', 'Law of Force'],
        correctOptionIndex: 1,
        explanation: 'Newton\'s First Law is often called the Law of Inertia.',
      ),
      QuizQuestion(
        id: '2',
        question: 'Force is equal to?',
        options: ['Mass x Velocity', 'Mass x Acceleration', 'Mass / Acceleration', 'Velocity / Time'],
        correctOptionIndex: 1,
        explanation: 'F = ma',
      ),
    ];
  }

  void _submitAnswer(int optionIndex) {
    setState(() {
      _selectedAnswers[_currentQuestionIndex] = optionIndex;
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    } else {
      _calculateScore();
    }
  }

  void _calculateScore() {
    int correct = 0;
    _selectedAnswers.forEach((index, answer) {
      if (_questions[index].correctOptionIndex == answer) {
        correct++;
      }
    });
    setState(() {
      _score = correct;
      _showResult = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Generating Quiz...')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('AI is creating questions for you...'),
            ],
          ),
        ),
      );
    }

    // Show difficulty selector first
    if (_showDifficultySelector) {
      return Scaffold(
        appBar: AppBar(title: const Text('Select Quiz Difficulty')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Choose your difficulty level:',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              _buildDifficultyButton(
                context,
                'Easy',
                'easy',
                Icons.sentiment_satisfied,
                Colors.green,
                'Simple questions for beginners',
              ),
              const SizedBox(height: 16),
              _buildDifficultyButton(
                context,
                'Medium',
                'medium',
                Icons.sentiment_neutral,
                Colors.orange,
                'Moderate difficulty questions',
              ),
              const SizedBox(height: 16),
              _buildDifficultyButton(
                context,
                'Hard',
                'hard',
                Icons.sentiment_very_dissatisfied,
                Colors.red,
                'Challenging questions for experts',
              ),
            ],
          ),
        ),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quiz')),
        body: const Center(child: Text('Could not generate quiz.')),
      );
    }

    if (_showResult) {
      final percentage = ((_score / _questions.length) * 100).round();
      final isDark = Theme.of(context).brightness == Brightness.dark;
      
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [AppTheme.darkBackground, AppTheme.darkSurface]
                  : [Colors.white, AppTheme.lightBackground],
            ),
          ),
          child: SafeArea(
            child:  Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Celebration Icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppTheme.cyanAccent, AppTheme.cyanSecondary],
                      ),
                    ),
                    child: const Icon(
                      Icons.celebration_rounded,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Quiz Complete Title
                  const Text(
                    'Quiz Complete!',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Topic name would go here
                  Text(
                    'Your Results',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 48),
                  
                  // Circular Progress Indicator
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Background circle
                        SizedBox(
                          width: 200,
                          height: 200,
                          child: CircularProgressIndicator(
                            value: 1.0,
                            strokeWidth: 12,
                            backgroundColor: isDark ? AppTheme.darkCard : Colors.grey.shade300,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isDark ? AppTheme.darkCard : Colors.grey.shade300,
                            ),
                          ),
                        ),
                        // Progress circle
                        SizedBox(
                          width: 200,
                          height: 200,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0.0, end: percentage / 100),
                            duration: const Duration(milliseconds: 1500),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) {
                              return CircularProgressIndicator(
                                value: value,
                                strokeWidth: 12,
                                backgroundColor: Colors.transparent,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppTheme.cyanAccent,
                                ),
                              );
                            },
                          ),
                        ),
                        // Percentage text
                        TweenAnimationBuilder<int>(
                          tween: IntTween(begin: 0, end: percentage),
                          duration: const Duration(milliseconds: 1500),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Text(
                              '$value%',
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Score Details
                  Text(
                    'You scored $_score out of ${_questions.length}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    percentage >= 80
                        ? 'Excellent work!'
                        : percentage >= 60
                            ? 'Good job!'
                            : 'Keep practicing!',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    ),
                  ),
                  const Spacer(),
                  
                  // Finish Button
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.cyanAccent, AppTheme.cyanSecondary],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.cyanAccent.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Finish & Go to Lessons',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final question = _questions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / _questions.length;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Score: $_score',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.cyanAccent,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Progress Bar
          LinearProgressIndicator(
            value: progress,
            backgroundColor: isDark ? AppTheme.darkCard : Colors.grey.shade300,
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.cyanAccent),
            minHeight: 4,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  // Question Text
                  Text(
                    question.question,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Answer Options
                  ...List.generate(question.options.length, (index) {
                    final isSelected = _selectedAnswers[_currentQuestionIndex] == index;
                    
                    Color? backgroundColor;
                    Color? borderColor;
                    Color? textColor;
                    
                    if (isSelected) {
                      backgroundColor = AppTheme.cyanAccent.withOpacity(0.1);
                      borderColor = AppTheme.cyanAccent;
                      textColor = AppTheme.cyanAccent;
                    } else {
                      backgroundColor = isDark ? AppTheme.darkCard : Colors.white;
                      borderColor = isDark ? AppTheme.darkCard : Colors.grey.shade300;
                      textColor = null;
                    }
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12.0),
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: borderColor,
                          width: 2,
                        ),
                      ),
                      child: InkWell(
                        onTap: () => _submitAnswer(index),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            question.options[index],
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: textColor,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  const Spacer(),
                  // Next Button
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _selectedAnswers.containsKey(_currentQuestionIndex)
                            ? [AppTheme.cyanAccent, AppTheme.cyanSecondary]
                            : [Colors.grey.shade400, Colors.grey.shade500],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: _selectedAnswers.containsKey(_currentQuestionIndex)
                          ? [
                              BoxShadow(
                                color: AppTheme.cyanAccent.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [],
                    ),
                    child: ElevatedButton(
                      onPressed: _selectedAnswers.containsKey(_currentQuestionIndex)
                          ? _nextQuestion
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        disabledBackgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _currentQuestionIndex == _questions.length - 1 ? 'Finish' : 'Next',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultyButton(
    BuildContext context,
    String label,
    String difficulty,
    IconData icon,
    Color color,
    String description,
  ) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        padding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color, width: 2),
        ),
      ),
      onPressed: () {
        setState(() {
          _selectedDifficulty = difficulty;
          _showDifficultySelector = false;
          _isLoading = true;
        });
        _generateQuiz();
      },
      child: Row(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: color.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
