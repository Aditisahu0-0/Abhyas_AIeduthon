import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/lesson.dart';
import '../services/ai_service.dart';
import '../services/database_helper.dart';
import '../services/sync_service.dart';
import '../services/precomputed_rag_service.dart';

class CourseProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final AIService _aiService = AIService();

  CourseProvider() {
    // Initialize services
    // Note: _aiService.initialize() is handled by initAI() which is called later.
    // SyncService needs to be initialized early to start listening for changes.
    SyncService().init();
  }

  BuildContext? _context;

  void setContext(BuildContext context) {
    _context = context;
  }

  List<Course> _courses = [];
  List<Lesson> _currentLessons = [];
  List<Topic> _currentTopics = [];
  Map<String, dynamic> _stats = {
    'total_questions': 0,
    'points': 0,
    'streak': 0,
    'daily_activity': List.filled(7, 0),
  };

  bool _isLoading = false;

  List<Course> get courses => _courses;
  List<Lesson> get currentLessons => _currentLessons;
  List<Topic> get currentTopics => _currentTopics;
  Map<String, dynamic> get stats => _stats;
  bool get isLoading => _isLoading;
  AIService get aiService => _aiService;
  DatabaseHelper get dbHelper => _dbHelper;

  Future<void> loadCourses() async {
    _isLoading = true;
    notifyListeners();

    _courses = await _dbHelper.getCourses();

    if (_courses.isNotEmpty) {
      print(
        '✅ Courses already loaded (${_courses.length} courses). Skipping JSON import.',
      );
      _isLoading = false;
      notifyListeners();
      return;
    }

    print('📦 First launch: Importing courses from JSON files...');

    // Only load the 3 files that actually exist
    final courseFiles = [
      'assets/lessons/class9_english.json',
      'assets/lessons/class9_mathematics.json',
      'assets/lessons/class9_science.json',
    ];

    try {
      for (var file in courseFiles) {
        try {
          String jsonString = await DefaultAssetBundle.of(
            _context!,
          ).loadString(file);
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
      print('❌ AI model failed to load');
      return;
    }

    print('✅ Model loaded successfully!');

    // NEW: Initialize pre-computed RAG service (NO INDEXING NEEDED!)
    print('=== Initializing Pre-computed RAG Service ===');
    await PrecomputedRagService.instance.initialize();

    print('=== AI IS READY FOR USE ===');
    notifyListeners();
  }

  Future<void> loadStats() async {
    final streak = await _dbHelper.getStreak();
    final dailyActivity = await _dbHelper.getDailyActivity();

    // For points, we can query the total correct answers * 10
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM quiz_question_attempts WHERE is_correct = 1',
    );
    final totalCorrect = result.first['count'] as int? ?? 0;

    final totalResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM quiz_question_attempts',
    );
    final totalQuestions = totalResult.first['count'] as int? ?? 0;

    _stats = {
      'total_questions': totalQuestions,
      'points': totalCorrect * 10,
      'streak': streak,
      'daily_activity': dailyActivity,
    };
    notifyListeners();
  }

  Future<void> recordQuizAttempt({
    required String lessonId,
    required String questionText,
    required List<String> options,
    required String correctAnswer,
    required String selectedAnswer,
    required bool isCorrect,
  }) async {
    await _dbHelper.saveQuestionAttempt(
      lessonId: lessonId,
      questionText: questionText,
      options: options,
      correctAnswer: correctAnswer,
      selectedAnswer: selectedAnswer,
      isCorrect: isCorrect,
    );
    // Auto-refresh stats so UI updates immediately
    await loadStats();
  }
}
