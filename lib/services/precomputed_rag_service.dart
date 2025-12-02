import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// RAG Service using Pre-computed Embeddings Database
/// 
/// This service provides semantic search using pre-computed embeddings
/// stored in knowledge_base.db. Uses keyword-based search for queries.
class PrecomputedRagService {
  static final PrecomputedRagService instance = PrecomputedRagService._();
  PrecomputedRagService._();

  Database? _db;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Initialize the service by loading the database
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print('=== PRECOMPUTED RAG INITIALIZATION START ===');
      
      // Copy database from assets to app directory
      await _copyDatabaseFromAssets();
      
      _isInitialized = true;
      print('✅ Pre-computed RAG initialized successfully!');
      print('=== PRECOMPUTED RAG INITIALIZATION COMPLETE ===');
    } catch (e) {
      print('❌ ERROR initializing RAG: $e');
      _isInitialized = false;
    }
  }

  /// Copy database from assets to app documents directory
  Future<void> _copyDatabaseFromAssets() async {
    try {
      final dbPath = p.join(await getDatabasesPath(), 'knowledge_base.db');
      final dbFile = File(dbPath);

      // Only copy if not exists or force update
      if (!await dbFile.exists()) {
        print('📦 Copying knowledge_base.db from assets...');
        final ByteData data = await rootBundle.load('assets/knowledge_base.db');
        final List<int> bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        await dbFile.writeAsBytes(bytes, flush: true);
        print('✅ Database copied successfully');
      } else {
        print('✅ Database already exists');
      }

      // Open database
      _db = await openDatabase(dbPath, readOnly: true);
      
      // Check record count
      final result = await _db!.rawQuery('SELECT COUNT(*) as count FROM knowledge_base');
      final count = result.first['count'];
      print('📊 Loaded database with $count topics');
    } catch (e) {
      print('❌ Error copying database: $e');
      rethrow;
    }
  }



  /// Search for relevant context using keyword matching
  /// 
  /// [query] - User's question
  /// [subjects] - Optional list of subjects to filter by (e.g., ["English", "Science"])
  /// [limit] - Maximum number of results to return
  Future<String> searchForContext(
    String query, {
    List<String> subjects = const [],
    int limit = 3,
  }) async {
    if (_db == null) {
      print('❌ Database not initialized');
      return '';
    }

    try {
      // Use keyword-based search directly
      return _keywordSearch(query, subjects: subjects, limit: limit);
    } catch (e) {
      print('Error searching: $e');
      return '';
    }
  }

  /// Keyword-based search through content
  Future<String> _keywordSearch(
    String query, {
    List<String> subjects = const [],
    int limit = 3,
  }) async {
    if (_db == null) return '';

    try {
      // 1. Filter stop words
      final stopWords = {'the', 'is', 'a', 'an', 'and', 'or', 'of', 'to', 'in', 'on', 'at', 'for', 'with', 'by', 'about', 'what', 'how', 'why', 'who', 'when', 'give', 'mark', 'answer', 'question', 'explain', 'describe'};
      final keywords = query.toLowerCase()
          .replaceAll(RegExp(r'[^\w\s]'), '') // Remove punctuation
          .split(' ')
          .where((w) => w.length > 2 && !stopWords.contains(w))
          .toList();

      if (keywords.isEmpty) return '';

      // 2. Build dynamic WHERE clause
      // STRATEGY: First try to find rows containing ALL keywords (AND logic) for high precision.
      // If that returns too few results, fallback to ANY keyword (OR logic).

      String whereClauseAnd = 'WHERE (';
      List<dynamic> whereArgsAnd = [];
      
      for (int i = 0; i < keywords.length; i++) {
        if (i > 0) whereClauseAnd += ' AND ';
        whereClauseAnd += 'content LIKE ?';
        whereArgsAnd.add('%${keywords[i]}%');
      }
      whereClauseAnd += ')';
      
      if (subjects.isNotEmpty) {
        final placeholders = List.filled(subjects.length, '?').join(',');
        whereClauseAnd += ' AND subject IN ($placeholders)';
        whereArgsAnd.addAll(subjects);
      }

      // Try AND search first
      var rows = await _db!.rawQuery(
        'SELECT display_text, subject, topic FROM knowledge_base $whereClauseAnd LIMIT $limit',
        whereArgsAnd,
      );

      // If not enough results, try OR search (Fallback)
      if (rows.length < limit) {
        String whereClauseOr = 'WHERE (';
        List<dynamic> whereArgsOr = [];
        
        for (int i = 0; i < keywords.length; i++) {
          if (i > 0) whereClauseOr += ' OR ';
          whereClauseOr += 'content LIKE ?';
          whereArgsOr.add('%${keywords[i]}%');
        }
        whereClauseOr += ')';
        
        // Exclude already found rows to avoid duplicates? 
        // For simplicity, just run the OR query and deduplicate in Dart if needed, 
        // or just accept that OR might return the same ones (which is fine, we can Set them).
        
        if (subjects.isNotEmpty) {
          final placeholders = List.filled(subjects.length, '?').join(',');
          whereClauseOr += ' AND subject IN ($placeholders)';
          whereArgsOr.addAll(subjects);
        }

        final rowsOr = await _db!.rawQuery(
          'SELECT display_text, subject, topic FROM knowledge_base $whereClauseOr LIMIT $limit',
          whereArgsOr,
        );
        
        // Merge results, prioritizing AND results
        // Use a Set of display_text to avoid duplicates
        final seen = rows.map((r) => r['display_text'].toString()).toSet();
        final combined = List<Map<String, Object?>>.from(rows);
        
        for (var row in rowsOr) {
          if (combined.length >= limit) break;
          if (!seen.contains(row['display_text'].toString())) {
            combined.add(row);
            seen.add(row['display_text'].toString());
          }
        }
        rows = combined;
      }
      
      return rows.map((row) {
        final subject = row['subject'] ?? 'General';
        final topic = row['topic'] ?? 'Unknown';
        final text = row['display_text'].toString();
        return "[$subject - $topic]\n$text";
      }).join('\n\n---\n\n');
    } catch (e) {
      print('Error in fallback search: $e');
      return '';
    }
  }

  /// Get a random topic for a specific chapter (for quiz generation)
  Future<String> getRandomChapterContext(
    String chapterTitle,
    String subject, {
    int maxLength = 500,
  }) async {
    if (_db == null) return '';

    try {
      final rows = await _db!.rawQuery(
        'SELECT content, topic_title FROM knowledge_base WHERE chapter_title = ? AND subject = ? ORDER BY RANDOM() LIMIT 1',
        [chapterTitle, subject],
      );
      
      if (rows.isEmpty) return '';
      
      final content = rows.first['content'].toString();
      final topicTitle = rows.first['topic_title'].toString();
      
      // Truncate if too long
      final truncated = content.length > maxLength
          ? content.substring(0, maxLength) + '...'
          : content;
      
      return 'SUBJECT: $subject\nCHAPTER: $chapterTitle\nTOPIC: $topicTitle\n\nCONTENT:\n$truncated';
    } catch (e) {
      print('Error getting chapter context: $e');
      return '';
    }
  }

  /// Get list of chapters for a subject
  Future<List<String>> getChaptersForSubject(String subject) async {
    if (_db == null) return [];

    try {
      final rows = await _db!.rawQuery(
        'SELECT DISTINCT chapter_title FROM knowledge_base WHERE subject = ? ORDER BY chapter_number',
        [subject],
      );
      
      return rows.map((row) => row['chapter_title'].toString()).toList();
    } catch (e) {
      print('Error getting chapters: $e');
      return [];
    }
  }

  /// Dispose resources
  void dispose() {
    _db?.close();
    _db = null;
    _isInitialized = false;
  }
}
