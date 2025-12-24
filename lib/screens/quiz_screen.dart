import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/course_provider.dart';
import '../models/lesson.dart';
import '../services/tts_service.dart';
import '../services/language_service.dart';
import '../utils/app_theme.dart';
import 'dart:math' as math;
import '../widgets/math_text.dart';

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
  void dispose() {
    TtsService().stop();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadNextQuestion();
  }

  Future<void> _loadNextQuestion() async {
    final languageService = Provider.of<LanguageService>(context, listen: false);

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
      
      // CRITICAL FIX: Ensure valid topics are loaded for *this* lesson
      // If currentTopics is empty or belongs to a different lesson, reload!
      if (provider.currentTopics.isEmpty || 
          provider.currentTopics.first.lessonId != widget.lessonId) {
         print('⚠️ Topic mismatch or empty. Loading topics for lesson: ${widget.lessonId}...');
         await provider.loadTopics(widget.lessonId);
      }

      final topics = provider.currentTopics;
      if (topics.isEmpty) {
        print('❌ No topics found for lesson ${widget.lessonId}');
        setState(() => _isLoading = false);
        return;
      }
      
      // Now safe to pick random topic
      final topic = topics[math.Random().nextInt(topics.length)];
      topicContent = topic.content;
      topicId = topic.id;
    }

    // Aggressively truncate content to max 850 chars (approx 200 tokens)
    // Combined with system prompt (~300 tokens), this keeps total input around 500 tokens
    if (topicContent.length > 850) {
      // Pick a random chunk to ensure variety (not just the start)
      final maxStartIndex = topicContent.length - 850;
      final startIndex = math.Random().nextInt(maxStartIndex + 1);
      
      print('⚠️ Content too long. Picking random chunk from $startIndex to ${startIndex + 850}');
      topicContent = topicContent.substring(startIndex, startIndex + 850);
    }
    
    print('📝 Content Length: ${topicContent.length} chars');
    print('📝 Content Preview: ${topicContent.substring(0, math.min(100, topicContent.length))}...');

    try {
      final jsonStr = await provider.aiService
          .generateQuizJson(
            topicContent,
            topicId: topicId,
          )
          .timeout(
            const Duration(seconds: 300),
          ); // 5 minutes for reload + generation

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
          question: languageService.translate('Failed to load question'),
          options: ['Option 1', 'Option 2', 'Option 3', 'Option 4'],
          correctOptionIndex: 0,
          explanation: languageService.translate('Failed to load question'),
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
    final languageService = Provider.of<LanguageService>(context, listen: false);

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
      message = languageService.translate('Excellent work! Keep it up! 🌟');
      icon = Icons.emoji_events;
      color = Colors.amber;
    } else if (percentage >= 60) {
      message = languageService.translate('Good job! Practice makes perfect! 👍');
      icon = Icons.thumb_up;
      color = Colors.green;
    } else if (percentage >= 40) {
      message = languageService.translate('Keep trying! You\'re getting there! 💪');
      icon = Icons.trending_up;
      color = Colors.orange;
    } else {
      message = languageService.translate('Don\'t give up! Review and try again! 📚');
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
            Text(languageService.translate('Quiz Complete!')),
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
            child: Text(languageService.translate('Done')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final languageService = Provider.of<LanguageService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('${languageService.translate("Quiz Practice")} ($_questionsAnswered ${languageService.translate("Done")})'),
        actions: [
          TextButton.icon(
            onPressed: _showResultsDialog,
            icon: const Icon(Icons.exit_to_app),
            label: Text(languageService.translate('Exit')),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(languageService.translate('Generating a unique question...')),
                ],
              ),
            )
          : _currentQuestion == null
          ? Center(child: Text(languageService.translate('Failed to load question')))
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
                            '${languageService.translate("Score")}: $_score / $_questionsAnswered',
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: MathText(
                            _currentQuestion!.question,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                          ),
                        ),
                        AnimatedBuilder(
                          animation: TtsService(),
                          builder: (context, _) {
                            final isPlayingQuestion =
                                TtsService().isPlaying &&
                                TtsService().currentText ==
                                    _currentQuestion!.question;

                            return IconButton(
                              onPressed: () {
                                if (isPlayingQuestion) {
                                  TtsService().stop();
                                } else {
                                  TtsService().speak(
                                    _currentQuestion!.question,
                                  );
                                }
                              },
                              icon: Icon(
                                isPlayingQuestion
                                    ? Icons.stop_rounded
                                    : Icons.volume_up_rounded,
                              ),
                              color: isPlayingQuestion
                                  ? Colors.redAccent
                                  : AppTheme.cyanAccent,
                              tooltip: isPlayingQuestion
                                  ? 'Stop Reading'
                                  : 'Read Question',
                            );
                          },
                        ),
                      ],
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
                                  child: MathText(
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  languageService.translate('Explanation'),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                AnimatedBuilder(
                                  animation: TtsService(),
                                  builder: (context, _) {
                                    final isPlayingExplanation =
                                        TtsService().isPlaying &&
                                        TtsService().currentText ==
                                            _currentQuestion!.explanation;

                                    return IconButton(
                                      onPressed: () {
                                        if (isPlayingExplanation) {
                                          TtsService().stop();
                                        } else {
                                          TtsService().speak(
                                            _currentQuestion!.explanation,
                                          );
                                        }
                                      },
                                      icon: Icon(
                                        isPlayingExplanation
                                            ? Icons.stop_rounded
                                            : Icons.volume_up_rounded,
                                        size: 20,
                                      ),
                                      color: isPlayingExplanation
                                          ? Colors.redAccent
                                          : AppTheme.cyanAccent,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      tooltip: isPlayingExplanation
                                          ? 'Stop Reading'
                                          : 'Read Explanation',
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            MathText(_currentQuestion!.explanation),
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
                          child: Text(
                            languageService.translate('Next Question'),
                            style: const TextStyle(
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
