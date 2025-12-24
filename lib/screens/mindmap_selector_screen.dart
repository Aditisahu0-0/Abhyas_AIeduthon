import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/course_provider.dart';
import '../services/language_service.dart';
import '../utils/app_theme.dart';
import 'mindmap_screen.dart';

class MindMapSelectorScreen extends StatefulWidget {
  const MindMapSelectorScreen({Key? key}) : super(key: key);

  @override
  State<MindMapSelectorScreen> createState() => _MindMapSelectorScreenState();
}

class _MindMapSelectorScreenState extends State<MindMapSelectorScreen> {
  String? _selectedSubject;
  String? _selectedLessonId;
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final languageService = Provider.of<LanguageService>(context);
    final provider = Provider.of<CourseProvider>(context);

    // Get all courses (subjects)
    final courses = provider.courses;

    // Get lessons for selected subject
    final lessons = _selectedSubject != null
        ? provider.currentLessons.where((l) => l.courseId == _selectedSubject).toList()
        : <dynamic>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(languageService.translate('Mind Map Generator')),
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
                    languageService.translate('Generating mind map...'),
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
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.psychology_rounded,
                      size: 64,
                      color: Colors.purple,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  Text(
                    languageService.translate('Generate Mind Map'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    languageService.translate(
                        'Select a subject and chapter to generate a comprehensive mind map'),
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Subject Dropdown
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
                            _selectedLessonId = null; // Reset lesson selection
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

                  // Chapter/Lesson Dropdown
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

                  // Generate Button
                  SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _selectedLessonId == null
                          ? null
                          : () => _generateMindMap(context, provider, languageService),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        disabledBackgroundColor: Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.auto_awesome_rounded,
                          color: Colors.white),
                      label: Text(
                        languageService.translate('Generate Mind Map'),
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

  Future<void> _generateMindMap(
    BuildContext context,
    CourseProvider provider,
    LanguageService languageService,
  ) async {
    if (_selectedLessonId == null) return;

    setState(() => _isGenerating = true);

    try {
      // Load topics for the selected lesson
      await provider.loadTopics(_selectedLessonId!);
      final topics = provider.currentTopics;

      if (topics.isEmpty) {
        throw Exception('No topics found for this chapter');
      }

      // Combine all topic content
      final fullContent = topics.map((t) => t.content).join('\n\n');

      // Get lesson title
      final lesson = provider.currentLessons.firstWhere((l) => l.id == _selectedLessonId);

      // Generate mindmap JSON
      final mindmapJson = await provider.aiService.generateMindMap(
        fullContent,
      );

      if (context.mounted) {
        setState(() => _isGenerating = false);

        // Navigate to mindmap screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MindMapScreen(
              title: lesson.title,
              jsonData: mindmapJson,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${languageService.translate("Error generating mindmap:")} $e'),
          ),
        );
      }
    }
  }
}
