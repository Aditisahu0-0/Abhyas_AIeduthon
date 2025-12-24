import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'tokenizer.dart';

/// RAG Service using Pre-computed Embeddings Database
///
/// This service provides semantic search using pre-computed embeddings
/// stored in knowledge_base.db.
/// Schema: id, subject, book_source, content_type, display_text, context_header, embedding
class PrecomputedRagService {
  static final PrecomputedRagService instance = PrecomputedRagService._();
  PrecomputedRagService._();

  Database? _db;
  Interpreter? _interpreter;
  WordPieceTokenizer? _tokenizer;
  bool _isInitialized = false;
  int _inputCount = 3;

  bool get isInitialized => _isInitialized;

  /// Initialize the service by loading the database and model
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print('=== PRECOMPUTED RAG INITIALIZATION START ===');

      // 1. Copy database from assets to app directory
      await _copyDatabaseFromAssets();

      // 2. Load Vocab
      await _loadVocab();

      // 3. Load TFLite Model
      await _loadModel();

      _isInitialized = true;
      print('✅ Pre-computed RAG initialized successfully!');
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

      // FORCE OVERWRITE: Always copy from assets to ensure latest DB version
      if (await dbFile.exists()) {
        print('🗑️ Deleting old database to ensure fresh copy...');
        await dbFile.delete();
      }

      print('📦 Copying knowledge_base.db from assets...');
      final ByteData data = await rootBundle.load('assets/knowledge_base.db');
      final List<int> bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      await dbFile.writeAsBytes(bytes, flush: true);
      print('✅ Database copied successfully');

      // Open database
      _db = await openDatabase(dbPath, readOnly: true);

      // Check record count
      final result = await _db!.rawQuery(
        'SELECT COUNT(*) as count FROM knowledge_base',
      );
      final count = result.first['count'];
      print('📊 Loaded database with $count topics');
    } catch (e) {
      print('❌ Error copying database: $e');
      rethrow;
    }
  }

  /// Load vocab.txt from assets
  Future<void> _loadVocab() async {
    try {
      final vocabString = await rootBundle.loadString('assets/vocab.txt');
      final lines = vocabString.split('\n');
      final Map<String, int> vocabMap = {};

      for (int i = 0; i < lines.length; i++) {
        final word = lines[i].trim();
        if (word.isNotEmpty) {
          vocabMap[word] = i;
        }
      }

      _tokenizer = WordPieceTokenizer(vocab: vocabMap);
    } catch (e) {
      print('❌ Error loading vocab: $e');
      rethrow;
    }
  }

  /// Load the TFLite model from assets
  Future<void> _loadModel() async {
    try {
      // Try loading from file system first
      final directory = await getApplicationDocumentsDirectory();
      final modelFile = File(p.join(directory.path, "mobile_embedding.tflite"));

      if (!await modelFile.exists()) {
        final ByteData data = await rootBundle.load(
          'assets/mobile_embedding.tflite',
        );
        final List<int> bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        await modelFile.writeAsBytes(bytes, flush: true);
      }

      _interpreter = await Interpreter.fromFile(modelFile);
      _inputCount = _interpreter!.getInputTensors().length;
    } catch (e) {
      print('❌ Error loading embedding model: $e');
      try {
        _interpreter = await Interpreter.fromAsset(
          'assets/mobile_embedding.tflite',
        );
        _inputCount = _interpreter!.getInputTensors().length;
      } catch (retryError) {
        print('❌ Retry failed: $retryError');
      }
    }
  }

  /// Search for relevant context using Vector Search (Cosine Similarity)
  Future<String> searchForContext(
    String query, {
    List<String> subjects = const [],
    int limit = 3,
  }) async {
    if (_db == null) return '';

    // 1. Try Vector Search
    if (_interpreter != null && _tokenizer != null) {
      try {
        return await _vectorSearch(query, subjects: subjects, limit: limit);
      } catch (e) {
        print('⚠️ Vector search failed: $e');
        print('Falling back to keyword search...');
      }
    }

    // 2. Fallback to Keyword Search
    return _keywordSearch(query, subjects: subjects, limit: limit);
  }

  /// Vector-based search
  Future<String> _vectorSearch(
    String query, {
    List<String> subjects = const [],
    int limit = 3,
  }) async {
    // 1. Generate Embedding for Query
    final queryEmbedding = await _generateEmbedding(query);
    if (queryEmbedding == null) {
      throw Exception("Failed to generate embedding");
    }

    // 2. Build WHERE clause for Subject Filtering
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (subjects.isNotEmpty) {
      // Use 'subject' column as per schema
      final conditions = subjects.map((_) => 'subject LIKE ?').join(' OR ');
      whereClause = 'WHERE ($conditions)';
      whereArgs.addAll(subjects.map((s) => '$s%'));
    }

    try {
      // Select exact columns from schema
      final rows = await _db!.rawQuery(
        'SELECT id, display_text, context_header, embedding FROM knowledge_base $whereClause',
        whereArgs,
      );

      if (rows.isEmpty) {
        print('⚠️ No documents found matching subjects: $subjects');
        return '';
      }

      // 3. Calculate Cosine Similarity
      List<Map<String, dynamic>> scoredResults = [];

      for (var row in rows) {
        final blob = row['embedding'] as List<int>;
        final embedding = _blobToFloatList(Uint8List.fromList(blob));

        if (embedding.length != queryEmbedding.length) continue;

        final score = _cosineSimilarity(queryEmbedding, embedding);

        scoredResults.add({'row': row, 'score': score});
      }

      // 4. Sort and Take Top K
      scoredResults.sort(
        (a, b) => (b['score'] as double).compareTo(a['score'] as double),
      );
      final topResults = scoredResults.take(limit).toList();

      return topResults
          .map((r) {
            final row = r['row'];
            // Use context_header for rich metadata
            final header = row['context_header'].toString();
            final text = row['display_text'].toString();
            return "$header\n$text";
          })
          .join('\n\n---\n\n');
    } catch (e) {
      print('❌ Error in Vector Search DB Query: $e');
      rethrow;
    }
  }

  /// Generate embedding using TFLite model and Tokenizer
  Future<List<double>?> _generateEmbedding(String text) async {
    if (_interpreter == null || _tokenizer == null) return null;

    try {
      final inputIds = _tokenizer!.tokenize(text);
      final inputIdsTensor = Int32List.fromList(inputIds).reshape([1, 256]);
      final inputMaskTensor = Int32List.fromList(
        List.filled(256, 1),
      ).reshape([1, 256]);

      for (int i = 0; i < inputIds.length; i++) {
        if (inputIds[i] == 0) (inputMaskTensor as dynamic)[0][i] = 0;
      }

      var output = Float32List(1 * 384).reshape([1, 384]);

      if (_inputCount == 2) {
        _interpreter!.runForMultipleInputs(
          [inputIdsTensor, inputMaskTensor],
          {0: output},
        );
      } else {
        final segmentIdsTensor = Int32List.fromList(
          List.filled(256, 0),
        ).reshape([1, 256]);
        _interpreter!.runForMultipleInputs(
          [inputIdsTensor, inputMaskTensor, segmentIdsTensor],
          {0: output},
        );
      }

      return List<double>.from(output[0]);
    } catch (e) {
      print('❌ RAG: Error generating embedding: $e');
      return null;
    }
  }

  List<double> _blobToFloatList(Uint8List blob) {
    final buffer = blob.buffer;
    final floatList = Float32List.view(buffer);
    return List<double>.from(floatList);
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA == 0 || normB == 0) return 0.0;
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  /// Keyword-based search through content (Fallback)
  Future<String> _keywordSearch(
    String query, {
    List<String> subjects = const [],
    int limit = 3,
  }) async {
    if (_db == null) return '';

    try {
      final stopWords = {
        'the',
        'is',
        'a',
        'an',
        'and',
        'or',
        'of',
        'to',
        'in',
        'on',
        'at',
        'for',
        'with',
        'by',
        'about',
        'what',
        'how',
        'why',
        'who',
        'when',
        'give',
        'mark',
        'answer',
        'question',
        'explain',
        'describe',
      };
      final keywords = query
          .toLowerCase()
          .replaceAll(RegExp(r'[^\w\s]'), '')
          .split(' ')
          .where((w) => w.length > 2 && !stopWords.contains(w))
          .toList();

      if (keywords.isEmpty) return '';

      // Build WHERE Query using 'display_text' and 'subject'
      String whereClauseAnd = 'WHERE (';
      List<dynamic> whereArgsAnd = [];

      for (int i = 0; i < keywords.length; i++) {
        if (i > 0) whereClauseAnd += ' AND ';
        whereClauseAnd += 'display_text LIKE ?';
        whereArgsAnd.add('%${keywords[i]}%');
      }
      whereClauseAnd += ')';

      if (subjects.isNotEmpty) {
        final conditions = subjects.map((_) => 'subject LIKE ?').join(' OR ');
        whereClauseAnd += ' AND ($conditions)';
        whereArgsAnd.addAll(subjects.map((s) => '$s%'));
      }

      var rows = await _db!.rawQuery(
        'SELECT display_text, context_header FROM knowledge_base $whereClauseAnd LIMIT $limit',
        whereArgsAnd,
      );

      // OR Search Fallback
      if (rows.length < limit) {
        String whereClauseOr = 'WHERE (';
        List<dynamic> whereArgsOr = [];

        for (int i = 0; i < keywords.length; i++) {
          if (i > 0) whereClauseOr += ' OR ';
          whereClauseOr += 'display_text LIKE ?';
          whereArgsOr.add('%${keywords[i]}%');
        }
        whereClauseOr += ')';

        if (subjects.isNotEmpty) {
          final conditions = subjects.map((_) => 'subject LIKE ?').join(' OR ');
          whereClauseOr += ' AND ($conditions)';
          whereArgsOr.addAll(subjects.map((s) => '$s%'));
        }

        final rowsOr = await _db!.rawQuery(
          'SELECT display_text, context_header FROM knowledge_base $whereClauseOr LIMIT $limit',
          whereArgsOr,
        );

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

      return rows
          .map((row) {
            final header = row['context_header'].toString();
            final text = row['display_text'].toString();
            return "$header\n$text";
          })
          .join('\n\n---\n\n');
    } catch (e) {
      print('Error in fallback search: $e');
      return '';
    }
  }

  /// Get a random topic for a specific chapter
  Future<String> getRandomChapterContext(
    String chapterTitle,
    String subject, {
    int maxLength = 500,
  }) async {
    if (_db == null) return '';

    try {
      final rows = await _db!.rawQuery(
        'SELECT display_text, context_header FROM knowledge_base WHERE context_header LIKE ? AND subject = ? ORDER BY RANDOM() LIMIT 1',
        ['%$chapterTitle%', subject],
      );

      if (rows.isEmpty) return '';

      final content = rows.first['display_text'].toString();
      final header = rows.first['context_header'].toString();

      final truncated = content.length > maxLength
          ? content.substring(0, maxLength) + '...'
          : content;

      return '$header\n\nCONTENT:\n$truncated';
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
        'SELECT DISTINCT context_header FROM knowledge_base WHERE subject = ? LIMIT 20',
        [subject],
      );

      return rows.map((row) => row['context_header'].toString()).toList();
    } catch (e) {
      print('Error getting chapters: $e');
      return [];
    }
  }

  /// Dispose resources
  void dispose() {
    _db?.close();
    _db = null;
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }
}
