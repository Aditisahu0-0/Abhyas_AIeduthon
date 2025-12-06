import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/lesson.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'offline_learning.db');
    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      var result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='quiz_cache'"
      );
      
      if (result.isEmpty) {
        await db.execute('''
          CREATE TABLE quiz_cache(
            topic_id TEXT,
            difficulty TEXT,
            quiz_json TEXT,
            created_at INTEGER,
            PRIMARY KEY (topic_id, difficulty)
          )
        ''');
      }
    }
    
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS quiz_progress(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          lesson_id TEXT,
          score INTEGER,
          total_questions INTEGER,
          timestamp INTEGER
        )
      ''');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE courses(
        id TEXT PRIMARY KEY,
        title TEXT,
        description TEXT,
        iconPath TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE lessons(
        id TEXT PRIMARY KEY,
        courseId TEXT,
        title TEXT,
        description TEXT,
        orderIndex INTEGER,
        FOREIGN KEY(courseId) REFERENCES courses(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE topics(
        id TEXT PRIMARY KEY,
        lessonId TEXT,
        title TEXT,
        content TEXT,
        orderIndex INTEGER,
        FOREIGN KEY(lessonId) REFERENCES lessons(id)
      )
    ''');
    
await db.execute('''
      CREATE TABLE quiz_cache(
        topic_id TEXT,
        difficulty TEXT,
        quiz_json TEXT,
        created_at INTEGER,
        PRIMARY KEY (topic_id, difficulty)
      )
    ''');
    
    await db.execute('''
      CREATE TABLE quiz_progress(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lesson_id TEXT,
        score INTEGER,
        total_questions INTEGER,
        timestamp INTEGER
      )
    ''');
  }

  Future<void> importCourseFromJson(Map<String, dynamic> jsonData, String filename) async {
    final db = await database;
    
    String courseId = filename.replaceAll('.json', '').replaceAll('assets/lessons/', '');
    String courseTitle = _beautifyCourseName(courseId);
    String courseDescription = jsonData['description'] ?? 'NCERT $courseTitle for Class 9';
    
    await db.insert('courses', {
      'id': courseId,
      'title': courseTitle,
      'description': courseDescription,
      'iconPath': jsonData['iconPath'] ?? 'assets/icons/default.png'
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    final List<dynamic> lessonsOrChapters = jsonData['lessons'] ?? jsonData['Chapters'] ?? [];
    
    for (int i = 0; i < lessonsOrChapters.length; i++) {
      var lessonData = lessonsOrChapters[i];
      
      String lessonId = lessonData['id'] ?? '${courseId}_lesson_${lessonData['chapter_number'] ?? i}';
      String lessonTitle = lessonData['title'] ?? lessonData['chapter_title'] ?? 'Lesson ${i + 1}';
      String lessonDescription = lessonData['description'] ?? 'Chapter ${lessonData['chapter_number'] ?? i + 1}';
      int orderIndex = lessonData['orderIndex'] ?? int.tryParse(lessonData['chapter_number']?.toString() ?? '${i + 1}') ?? i + 1;
      
      await db.insert('lessons', {
        'id': lessonId,
        'courseId': courseId,
        'title': lessonTitle,
        'description': lessonDescription,
        'orderIndex': orderIndex
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final List<dynamic> topics = lessonData['topics'] ?? [];
      for (int j = 0; j < topics.length; j++) {
        var topicData = topics[j];
        
        String topicId = topicData['id'] ?? '${lessonId}_topic_$j';
        String topicTitle = topicData['title'] ?? topicData['topic'] ?? 'Topic ${j + 1}';
        String topicContent = topicData['content'] ?? '';
        int topicOrder = topicData['orderIndex'] ?? int.tryParse(topicData['section_number']?.toString() ?? '${j + 1}') ?? j + 1;
        
        await db.insert('topics', {
          'id': topicId,
          'lessonId': lessonId,
          'title': topicTitle,
          'content': topicContent,
          'orderIndex': topicOrder
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
  }
  
  String _beautifyCourseName(String filename) {
    final parts = filename.split('_');
    final name = parts.where((p) => !p.contains('class') && !RegExp(r'^\d+$').hasMatch(p)).join(' ');
    return name.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  Future<List<Course>> getCourses() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('courses');
    return List.generate(maps.length, (i) {
      return Course.fromMap(maps[i]);
    });
  }

  Future<List<Lesson>> getLessons(String courseId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'lessons',
      where: 'courseId = ?',
      whereArgs: [courseId],
      orderBy: 'orderIndex ASC',
    );
    return List.generate(maps.length, (i) {
      return Lesson.fromMap(maps[i]);
    });
  }

  Future<List<Topic>> getTopics(String lessonId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'topics',
      where: 'lessonId = ?',
      whereArgs: [lessonId],
      orderBy: 'orderIndex ASC',
    );
    return List.generate(maps.length, (i) {
      return Topic.fromMap(maps[i]);
    });
  }
  
  Future<Topic?> getTopic(String topicId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'topics',
      where: 'id = ?',
      whereArgs: [topicId],
    );
    if (maps.isNotEmpty) {
      return Topic.fromMap(maps.first);
    }
    return null;
  }
  
  Future<void> saveQuizCache(String topicId, String difficulty, String quizJson) async {
    final db = await database;
    await db.insert(
      'quiz_cache',
      {
        'topic_id': topicId,
        'difficulty': difficulty,
        'quiz_json': quizJson,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  Future<String?> getQuizCache(String topicId, String difficulty, {int maxAgeDays = 7}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'quiz_cache',
      where: 'topic_id = ? AND difficulty = ?',
      whereArgs: [topicId, difficulty],
    );
    
    if (maps.isEmpty) return null;
    
    final cached = maps.first;
    final createdAt = cached['created_at'] as int;
    final ageInDays = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(createdAt)
    ).inDays;
    
    if (ageInDays > maxAgeDays) {
      await db.delete(
        'quiz_cache',
        where: 'topic_id = ? AND difficulty = ?',
        whereArgs: [topicId, difficulty],
      );
      return null;
    }
    
    return cached['quiz_json'] as String;
  }
  
  // Quiz Progress Methods
  Future<void> saveQuizAttempt(String lessonId, int score, int totalQuestions) async {
    final db = await database;
    await db.insert(
      'quiz_progress',
      {
        'lesson_id': lessonId,
        'score': score,
        'total_questions': totalQuestions,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }
  
  Future<List<Map<String, dynamic>>> getQuizHistory(String lessonId, {int limit = 10}) async {
    final db = await database;
    return await db.query(
      'quiz_progress',
      where: 'lesson_id = ?',
      whereArgs: [lessonId],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
  }
  
  Future<Map<String, dynamic>> getQuizStats(String lessonId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_attempts,
        AVG(CAST(score AS REAL) / CAST(total_questions AS REAL) * 100) as average_percentage,
        MAX(CAST(score AS REAL) / CAST(total_questions AS REAL) * 100) as best_percentage
      FROM quiz_progress
      WHERE lesson_id = ?
    ''', [lessonId]);
    
    if (result.isEmpty) {
      return {'total_attempts': 0, 'average_percentage': 0.0, 'best_percentage': 0.0};
    }
    
    return result.first;
  }
}
