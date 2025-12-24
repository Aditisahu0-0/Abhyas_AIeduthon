import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/lesson.dart';
import '../providers/course_provider.dart';
import '../utils/app_theme.dart';
import '../services/language_service.dart';
import 'chat_screen.dart';
import 'quiz_screen.dart';
import 'mindmap_screen.dart';
import '../services/tts_service.dart';

class LessonScreen extends StatefulWidget {
  final Lesson lesson;

  const LessonScreen({super.key, required this.lesson});

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  int _currentPageIndex = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => Provider.of<CourseProvider>(
        context,
        listen: false,
      ).loadTopics(widget.lesson.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final languageService = Provider.of<LanguageService>(context);
    final ttsService = TtsService(); // Singleton instance

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lesson.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.quiz_rounded),
            tooltip: languageService.translate('Take Quiz'),
            onPressed: () {
              // Pass current topic content to quiz
              final provider = Provider.of<CourseProvider>(
                context,
                listen: false,
              );
              String? content;
              String? topicId;

              if (provider.currentTopics.isNotEmpty) {
                final topic = provider.currentTopics[_currentPageIndex];
                content = topic.content;
                topicId = topic.id;
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => QuizScreen(
                    lessonId: widget.lesson.id,
                    initialContent: content,
                    initialTopicId: topicId,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<CourseProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.currentTopics.isEmpty) {
            return Center(
              child: Text(languageService.translate('No content available for this lesson.')),
            );
          }

          return Column(
            children: [
              // Action Buttons Row
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.darkCard
                              : AppTheme.cyanSecondary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? AppTheme.darkCard
                                : AppTheme.cyanSecondary.withOpacity(0.3),
                          ),
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ChatScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: isDark
                                ? AppTheme.cyanAccent
                                : AppTheme.cyanSecondary,
                          ),
                          label: Text(
                            languageService.translate('Ask AI'),
                            style: TextStyle(
                              color: isDark
                                  ? AppTheme.cyanAccent
                                  : AppTheme.cyanSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.darkCard
                              : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? AppTheme.darkCard
                                : Colors.orange.withOpacity(0.3),
                          ),
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () {
                             if (provider.currentTopics.isNotEmpty) {
                                final content = provider.currentTopics[_currentPageIndex].content;
                                if (ttsService.isPlaying) {
                                  ttsService.stop();
                                } else {
                                  ttsService.speak(content);
                                }
                             }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.zero, // Reduce padding for 4 items
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: Icon(
                            ttsService.isPlaying ? Icons.stop_circle_outlined : Icons.volume_up_rounded,
                            color: isDark ? Colors.orangeAccent : Colors.orange,
                            size: 20,
                          ),
                          label: Text(
                            // Short label for space
                            languageService.translate(ttsService.isPlaying ? 'Stop' : 'Read'),
                            style: TextStyle(
                              color: isDark ? Colors.orangeAccent : Colors.orange,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppTheme.cyanAccent,
                              AppTheme.cyanSecondary,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.cyanAccent.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _showSummary(context, provider);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
                          ),
                          label: Text(
                            languageService.translate('Summarize'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: PageView.builder(
                  itemCount: provider.currentTopics.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPageIndex = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    final topic = provider.currentTopics[index];
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            topic.title,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 20),
                          MarkdownBody(
                            data: topic.content,
                            styleSheet:
                                MarkdownStyleSheet.fromTheme(
                                  Theme.of(context),
                                ).copyWith(
                                  p: Theme.of(context).textTheme.bodyLarge,
                                  h1: Theme.of(context).textTheme.headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                  h2: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                          ),
                          const SizedBox(
                            height: 100,
                          ), // Space for bottom button
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Bottom Quiz Button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Container(
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
                      // Pass current topic content to quiz
                      final topic = provider.currentTopics[_currentPageIndex];

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => QuizScreen(
                            lessonId: widget.lesson.id,
                            initialContent: topic.content,
                            initialTopicId: topic.id,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      languageService.translate('Take Quiz'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSummary(BuildContext context, CourseProvider provider) async {
    final languageService = Provider.of<LanguageService>(context, listen: false);
    final topics = provider.currentTopics;
    if (topics.isEmpty) return;

    final currentTopic = topics[_currentPageIndex];

    // Show bottom sheet with stateful content for accumulation
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (context) => _StreamingSummarySheet(
        stream: provider.aiService.summarize(
          currentTopic.content,
        ),
        title: '${languageService.translate("Quick Revision")}: ${currentTopic.title}',
        errorMessage: languageService.translate("Error generating summary:"),
      ),
    );
  }
}

// Stateful widget for streaming summary with proper text accumulation
class _StreamingSummarySheet extends StatefulWidget {
  final Stream<String> stream;
  final String title;
  final String errorMessage;

  const _StreamingSummarySheet({
    required this.stream,
    required this.title,
    required this.errorMessage,
  });

  @override
  State<_StreamingSummarySheet> createState() => _StreamingSummarySheetState();
}

class _StreamingSummarySheetState extends State<_StreamingSummarySheet> {
  String _accumulatedText = '';
  bool _isLoading = true;
  String? _error;
  StreamSubscription<String>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.stream.listen(
      (token) {
        setState(() {
          _accumulatedText += token;
          _isLoading = false;
        });
      },
      onError: (error) {
        setState(() {
          _error = error.toString();
          _isLoading = false;
        });
      },
      onDone: () {
        setState(() {
          _isLoading = false;
        });
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.darkSurface
            : Colors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.cyanAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppTheme.cyanAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _error != null
                ? Text(
                    '${widget.errorMessage} $_error',
                    style: const TextStyle(color: Colors.red),
                  )
                : _isLoading && _accumulatedText.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        child: MarkdownBody(
                          data: _accumulatedText,
                          styleSheet: MarkdownStyleSheet.fromTheme(
                            Theme.of(context),
                          ).copyWith(
                            p: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(height: 1.5),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _showMindMap(BuildContext context, CourseProvider provider) async {
    final languageService = Provider.of<LanguageService>(context, listen: false);
    final topics = provider.currentTopics;
    if (topics.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Generate mindmap for the current topic
      // final currentTopic = topics[_currentPageIndex];
      // Use FULL chapter content
      final fullContent = topics.map((t) => t.content).join('\n\n');

      // Generate JSON instead of Markdown
      final mindmapJson = await provider.aiService.generateMindMap(
        fullContent,
      );

      if (context.mounted) {
        Navigator.pop(context); // Pop loading

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                MindMapScreen(title: provider.currentTopics.first.lessonId, jsonData: mindmapJson),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Pop loading
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${languageService.translate("Error generating mindmap:")} $e')));
      }
    }
  }
}
