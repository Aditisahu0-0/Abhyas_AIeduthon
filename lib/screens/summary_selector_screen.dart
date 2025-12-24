import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/course_provider.dart';
import '../services/language_service.dart';
import '../utils/app_theme.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class SummarySelectorScreen extends StatefulWidget {
  const SummarySelectorScreen({Key? key}) : super(key: key);

  @override
  State<SummarySelectorScreen> createState() => _SummarySelectorScreenState();
}

class _SummarySelectorScreenState extends State<SummarySelectorScreen> {
  String? _selectedSubject;
  String? _selectedLessonId;
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final languageService = Provider.of<LanguageService>(context);
    final provider = Provider.of<CourseProvider>(context);

    final courses = provider.courses;
    final lessons = _selectedSubject != null
        ? provider.currentLessons.where((l) => l.courseId == _selectedSubject).toList()
        : <dynamic>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(languageService.translate('Chapter Summary')),
        centerTitle: true,
      ),
      body: _isGenerating
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    languageService.translate('Generating summary...'),
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.cyan.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      size: 64,
                      color: Colors.cyan,
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    languageService.translate('Generate Chapter Summary'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    languageService.translate(
                        'Select a subject and chapter to view comprehensive summary in bullet points'),
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  Text(
                    languageService.translate('Subject'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? AppTheme.darkCard
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedSubject,
                        hint: Text(languageService.translate('Select Subject')),
                        items: courses.map((course) {
                          return DropdownMenuItem<String>(
                            value: course.id,
                            child: Text(course.title),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedSubject = value;
                            _selectedLessonId = null;
                          });
                          // Load lessons for the selected subject
                          if (value != null) {
                            provider.loadLessons(value);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    languageService.translate('Chapter'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? AppTheme.darkCard
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedLessonId,
                        hint: Text(languageService.translate('Select Chapter')),
                        items: lessons.map((lesson) {
                          return DropdownMenuItem<String>(
                            value: lesson.id,
                            child: Text(lesson.title),
                          );
                        }).toList(),
                        onChanged: _selectedSubject == null
                            ? null
                            : (value) {
                                setState(() {
                                  _selectedLessonId = value;
                                });
                              },
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _selectedLessonId == null
                          ? null
                          : () => _generateSummary(context, provider, languageService),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyan,
                        disabledBackgroundColor: Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.summarize_rounded,
                          color: Colors.white),
                      label: Text(
                        languageService.translate('Generate Summary'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _generateSummary(
    BuildContext context,
    CourseProvider provider,
    LanguageService languageService,
  ) async {
    if (_selectedLessonId == null) return;

    try {
      await provider.loadTopics(_selectedLessonId!);
      final topics = provider.currentTopics;

      if (topics.isEmpty) {
        throw Exception('No topics found for this chapter');
      }

      final fullContent = topics.map((t) => t.content).join('\n\n');
      final lesson = provider.currentLessons.firstWhere((l) => l.id == _selectedLessonId);

      if (context.mounted) {
        // Show streaming summary sheet
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          isDismissible: false,
          builder: (context) => _StreamingChapterSummarySheet(
            stream: provider.aiService.summarizeChapter(
              fullContent,
            ),
            title: lesson.title,
            errorMessage: languageService.translate("Error generating summary:"),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${languageService.translate("Error generating summary:")} $e'),
          ),
        );
      }
    }
  }
}

// Stateful widget for streaming chapter summary with proper text accumulation
class _StreamingChapterSummarySheet extends StatefulWidget {
  final Stream<String> stream;
  final String title;
  final String errorMessage;

  const _StreamingChapterSummarySheet({
    required this.stream,
    required this.title,
    required this.errorMessage,
  });

  @override
  State<_StreamingChapterSummarySheet> createState() =>
      _StreamingChapterSummarySheetState();
}

class _StreamingChapterSummarySheetState
    extends State<_StreamingChapterSummarySheet> {
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
      height: MediaQuery.of(context).size.height * 0.8,
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
                  color: Colors.cyan.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.cyan,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
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
}
