import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/course_provider.dart';
import '../services/language_service.dart';
import '../utils/app_theme.dart';
import 'quiz_screen.dart';

class QuizSelectorScreen extends StatefulWidget {
  const QuizSelectorScreen({Key? key}) : super(key: key);

  @override
  State<QuizSelectorScreen> createState() => _QuizSelectorScreenState();
}

class _QuizSelectorScreenState extends State<QuizSelectorScreen> {
  String? _selectedSubject;
  String? _selectedLessonId;

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
        title: Text(languageService.translate('Quiz Generator')),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.quiz_rounded,
                size: 64,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              languageService.translate('Take a Quiz'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              languageService.translate(
                  'Select a subject and chapter to start a random quiz from the entire chapter'),
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
                          // Need to load topics to ensure they are available for the quiz
                          // effectively "selecting" the chapter
                          if (value != null) {
                            provider.loadTopics(value);
                          }
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
                    : () async {
                        // Ensure topics are loaded for the selected lesson
                        await provider.loadTopics(_selectedLessonId!);
                        
                        if (context.mounted) {
                          // Navigate to QuizScreen with null content/topicId
                          // This triggers the random topic selection logic in QuizScreen
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => QuizScreen(
                                lessonId: _selectedLessonId!,
                                initialContent: null,
                                initialTopicId: null,
                              ),
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  disabledBackgroundColor: Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white),
                label: Text(
                  languageService.translate('Start Quiz'),
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
}
