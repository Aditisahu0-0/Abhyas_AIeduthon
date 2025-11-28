import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/lesson.dart';
import '../services/database_helper.dart';
import '../services/ai_service.dart';

class CourseProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final AIService _aiService = AIService();
  BuildContext? _context;

  void setContext(BuildContext context) {
    _context = context;
  }
  
  List<Course> _courses = [];
  List<Lesson> _currentLessons = [];
  List<Topic> _currentTopics = [];
  
  bool _isLoading = false;

  List<Course> get courses => _courses;
  List<Lesson> get currentLessons => _currentLessons;
  List<Topic> get currentTopics => _currentTopics;
  bool get isLoading => _isLoading;
  AIService get aiService => _aiService;

  Future<void> loadCourses() async {
    _isLoading = true;
    notifyListeners();
    
    _courses = await _dbHelper.getCourses();
    
    if (_courses.isNotEmpty) {
      print('✅ Courses already loaded (${_courses.length} courses). Skipping JSON import.');
      _isLoading = false;
      notifyListeners();
      return;
    }
    
    print('📦 First launch: Importing courses from JSON files...');
    
    final courseFiles = [
      'assets/lessons/class9_english.json',
      'assets/lessons/class9_english_2.json',
      'assets/lessons/class9_english_3.json',
      'assets/lessons/class9_ict.json',
      'assets/lessons/class9_mathematics.json',
      'assets/lessons/class9_science.json',
      'assets/lessons/class9_social_sicence.json',
      'assets/lessons/class9_social_sicence_3.json',
      'assets/lessons/class9_social_sicence_6.json',
      'assets/lessons/class9_social_sicence_7.json',
    ];
    
    try {
      for (var file in courseFiles) {
        try {
          String jsonString = await DefaultAssetBundle.of(_context!).loadString(file);
          Map<String, dynamic> jsonData = json.decode(jsonString);
          await _dbHelper.importCourseFromJson(jsonData, file);
          print('Successfully loaded: $file');
        } catch (e) {
          print('Error loading $file: $e');
        }
      }
    } catch (e) {
      print("Error in loadCourses: $e");
    }

    _courses = await _dbHelper.getCourses();
    print('✅ JSON import complete! Total courses loaded: ${_courses.length}');
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadLessons(String courseId) async {
    _isLoading = true;
    notifyListeners();
    _currentLessons = await _dbHelper.getLessons(courseId);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadTopics(String lessonId) async {
    _isLoading = true;
    notifyListeners();
    _currentTopics = await _dbHelper.getTopics(lessonId);
    _isLoading = false;
    notifyListeners();
  }
  
  Future<void> initAI() async {
    print('=== initAI() CALLED ===');
    
    if (_aiService.isModelLoaded) {
      print('⚠️ AI already initialized - skipping');
      return;
    }
    
    print('Starting AI initialization...');
    await _aiService.initialize();
    
    if (!_aiService.isModelLoaded) {
      print('❌ AI model failed to load - cannot index content');
      return;
    }
    
    print('✅ Model loaded successfully!');
    
    if (_aiService.vectorStore.documentCount > 50) {
       print('✅ Content already indexed (${_aiService.vectorStore.documentCount} docs). Skipping full re-index.');
       notifyListeners();
       return;
    }
    
    print('=== Starting content indexing for RAG ===');
    print('Total courses to index: ${_courses.length}');
    
    int totalTopics = 0;
    for (var course in _courses) {
      print('Indexing course: ${course.title}');
      final lessons = await _dbHelper.getLessons(course.id);
      
      for (var lesson in lessons) {
        final topics = await _dbHelper.getTopics(lesson.id);
        
        for (var topic in topics) {
          await _aiService.indexContent(
            topic.id, 
            topic.content,
            metadata: '${course.title} - ${lesson.title} - ${topic.title}',
          );
          totalTopics++;
          
          if (totalTopics % 5 == 0) {
            await Future.delayed(Duration.zero);
          }
        }
      }
      await Future.delayed(Duration(milliseconds: 50));
    }
    
    print('🔄 Computing TF-IDF vectors for all content...');
    _aiService.vectorStore.recomputeTFIDF();
    
    print('✅ Indexing complete! Total topics indexed: $totalTopics');
    print('=== AI IS READY FOR USE ===');
    notifyListeners();
  }
}
