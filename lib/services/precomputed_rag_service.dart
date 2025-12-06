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
/// stored in knowledge_base.db. Uses TFLite for on-device embedding generation.
class PrecomputedRagService {
  static final PrecomputedRagService instance = PrecomputedRagService._();
  PrecomputedRagService._();

  Database? _db;
  Interpreter? _interpreter;
  WordPieceTokenizer? _tokenizer;
  bool _isInitialized = false;
  String _textColumn = 'content'; 
  bool _hasMetadata = false;
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

      // Only copy if not exists
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

      // Check columns dynamically
      final columns = await _db!.rawQuery('PRAGMA table_info(knowledge_base)');
      final columnNames = columns.map((c) => c['name'].toString()).toSet();
      print('📝 Database Columns: $columnNames');
      
      if (columnNames.contains('display_text')) {
        _textColumn = 'display_text';
      } else {
        _textColumn = 'content';
      }
      
      _hasMetadata = columnNames.contains('metadata');
      
      print('✅ Using text column: $_textColumn');
      print('✅ Has metadata column: $_hasMetadata');

    } catch (e) {
      print('❌ Error copying database: $e');
      rethrow;
    }
  }

  /// Load vocab.txt from assets
  Future<void> _loadVocab() async {
    try {
      print('📖 Loading vocab.txt...');
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
      print('✅ Vocab loaded with ${vocabMap.length} tokens');
    } catch (e) {
      print('❌ Error loading vocab: $e');
      rethrow;
    }
  }

  /// Load the TFLite model from assets
  Future<void> _loadModel() async {
    try {
      print('🧠 Loading embedding model from assets...');
      
      // Check if it exists in assets first (via rootBundle for copying fallback)
      // But tflite_flutter prefers direct asset path or file path
      
      // Try loading from file system first (in case we copied it previously or need to)
      final directory = await getApplicationDocumentsDirectory();
      final modelFile = File(p.join(directory.path, "mobile_embedding.tflite"));
      
      if (!await modelFile.exists()) {
          print('📦 Copying mobile_embedding.tflite from assets...');
          final ByteData data = await rootBundle.load('assets/mobile_embedding.tflite');
          final List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
          await modelFile.writeAsBytes(bytes, flush: true);
      }
      
      _interpreter = await Interpreter.fromFile(modelFile);
      
      _inputCount = _interpreter!.getInputTensors().length;
      print('✅ Embedding model loaded. Expecting $_inputCount inputs.');
      
    } catch (e) {
      print('❌ Error loading embedding model: $e');
      print('⚠️ Retrying with direct asset load...');
      try {
         _interpreter = await Interpreter.fromAsset('assets/mobile_embedding.tflite');
         _inputCount = _interpreter!.getInputTensors().length;
         print('✅ Embedding model loaded from asset. Input count: $_inputCount');
      } catch (retryError) {
         print('❌ Retry failed: $retryError');
      }
    }
  }

  /// Search for relevant context using Vector Search (Cosine Similarity)
  /// Falls back to Keyword Search if model is not loaded.
  Future<String> searchForContext(
    String query, {
    List<String> subjects = const [],
    int limit = 3,
  }) async {
    print('🔍 RAG: searchForContext called for query: "$query"');
    if (_db == null) {
      print('❌ RAG: Database not initialized (db is null)');
      return '';
    }
    print('🔍 RAG: Interpreter: ${_interpreter != null ? "OK" : "NULL"}, Tokenizer: ${_tokenizer != null ? "OK" : "NULL"}');

    // 1. Try Vector Search
    if (_interpreter != null && _tokenizer != null) {
      try {
        return await _vectorSearch(query, subjects: subjects, limit: limit);
      } catch (e) {
        print('⚠️ Vector search failed: $e');
        print('stacktrace: ${StackTrace.current}');
        print('Falling back to keyword search...');
      }
    } else {
       print('⚠️ RAG: Skipping Vector Search because Interpreter or Tokenizer is NULL');
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
    print('🔍 Performing Vector Search for: "$query"');
    
    // 1. Generate Embedding for Query
    final queryEmbedding = await _generateEmbedding(query);
    if (queryEmbedding == null) {
      print('❌ RAG: Failed to generate query embedding (returned null)');
      throw Exception("Failed to generate embedding");
    }
    print('✅ RAG: Query embedding generated. Length: ${queryEmbedding.length}');

    // 2. Fetch all embeddings from DB (filtered by subject if needed)
    String whereClause = '';
    List<dynamic> whereArgs = [];
    
    if (subjects.isNotEmpty) {
      final conditions = subjects.map((_) => 'metadata LIKE ?').join(' OR ');
      whereClause = 'WHERE ($conditions)';
      whereArgs.addAll(subjects.map((s) => '$s%'));
    }

    try {
      // Use dynamic text column
      final selectColumns = _hasMetadata ? 'id, $_textColumn, metadata, embedding' : 'id, $_textColumn, embedding';
      
      final rows = await _db!.rawQuery(
        'SELECT $selectColumns FROM knowledge_base $whereClause',
        whereArgs,
      );

      print('📊 Comparing against ${rows.length} documents...');
      if (rows.isEmpty) {
        print('⚠️ No documents found matching subjects: $subjects');
        return '';
      }
      
      // Check first row embedding size
      if (rows.isNotEmpty) {
         final firstBlob = rows.first['embedding'] as List<dynamic>; // might be List<int> or Blob
         print('🔍 Sample embedding blob size: ${firstBlob.length}');
      }

      // 3. Calculate Cosine Similarity
      List<Map<String, dynamic>> scoredResults = [];

      for (var row in rows) {
        final blob = row['embedding'] as List<int>;
        final embedding = _blobToFloatList(Uint8List.fromList(blob));
        
        // Debug: check embedding size
        if (embedding.length != queryEmbedding.length) {
          // print('⚠️ Mismatch embedding size: DB=${embedding.length} vs Query=${queryEmbedding.length}');
          continue;
        }

        final score = _cosineSimilarity(queryEmbedding, embedding);
        
        scoredResults.add({
          'row': row,
          'score': score,
        });
      }

      // 4. Sort by Score (Descending)
      scoredResults.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));

      // 5. Take Top K
      final topResults = scoredResults.take(limit).toList();
      
      print('✅ Top results scores: ${topResults.map((r) => (r['score'] as double).toStringAsFixed(4)).toList()}');
      
      if (topResults.isEmpty) return '';

      return topResults.map((r) {
        final row = r['row'];
        final metadata = _hasMetadata ? (row['metadata'] as String? ?? 'Info') : 'Info';
        final text = row[_textColumn].toString();
        return "[$metadata]\n$text";
      }).join('\n\n---\n\n');
      
    } catch (e) {
      print('❌ Error in Vector Search DB Query: $e');
      rethrow;
    }
  }

  /// Generate embedding using TFLite model and Tokenizer
  Future<List<double>?> _generateEmbedding(String text) async {
    if (_interpreter == null || _tokenizer == null) return null;

    try {
      // 1. Tokenize
      final inputIds = _tokenizer!.tokenize(text);
      
      // 2. Prepare Tensors (Batch size 1, Sequence length 256)
      final inputIdsTensor = Int32List.fromList(inputIds).reshape([1, 256]);
      final inputMaskTensor = Int32List.fromList(List.filled(256, 1)).reshape([1, 256]);
      
      // Mask padding tokens (0)
      for(int i=0; i<inputIds.length; i++) {
        if(inputIds[i] == 0) (inputMaskTensor as dynamic)[0][i] = 0; 
      }
      
      // Output: [1, 384]
      var output = Float32List(1 * 384).reshape([1, 384]);
      
      // 3. Run Inference based on Input Count
      if(_inputCount == 2) {
          // Model expects [input_ids, attention_mask]
          _interpreter!.runForMultipleInputs(
            [inputIdsTensor, inputMaskTensor], 
            {0: output}
          );
      } else {
          // Model expects [input_ids, attention_mask, token_type_ids]
          final segmentIdsTensor = Int32List.fromList(List.filled(256, 0)).reshape([1, 256]); 
          _interpreter!.runForMultipleInputs(
            [inputIdsTensor, inputMaskTensor, segmentIdsTensor], 
            {0: output}
          );
      }

      final result = List<double>.from(output[0]);
      return result;
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
      // 1. Filter stop words
      final stopWords = {'the', 'is', 'a', 'an', 'and', 'or', 'of', 'to', 'in', 'on', 'at', 'for', 'with', 'by', 'about', 'what', 'how', 'why', 'who', 'when', 'give', 'mark', 'answer', 'question', 'explain', 'describe'};
      final keywords = query.toLowerCase()
          .replaceAll(RegExp(r'[^\w\s]'), '') // Remove punctuation
          .split(' ')
          .where((w) => w.length > 2 && !stopWords.contains(w))
          .toList();

      if (keywords.isEmpty) return '';

      // 2. Build dynamic WHERE clause
      String whereClauseAnd = 'WHERE (';
      List<dynamic> whereArgsAnd = [];
      
      for (int i = 0; i < keywords.length; i++) {
        if (i > 0) whereClauseAnd += ' AND ';
        whereClauseAnd += '$_textColumn LIKE ?';
        whereArgsAnd.add('%${keywords[i]}%');
      }
      whereClauseAnd += ')';
      
      if (subjects.isNotEmpty) {
        final conditions = subjects.map((_) => 'metadata LIKE ?').join(' OR ');
        whereClauseAnd += ' AND ($conditions)';
        whereArgsAnd.addAll(subjects.map((s) => '$s%'));
      }

      // Try AND search first
      final selectColumns = _hasMetadata ? '$_textColumn, metadata' : '$_textColumn';
      
      var rows = await _db!.rawQuery(
        'SELECT $selectColumns FROM knowledge_base $whereClauseAnd LIMIT $limit',
        whereArgsAnd,
      );

      // If not enough results, try OR search (Fallback)
      if (rows.length < limit) {
        String whereClauseOr = 'WHERE (';
        List<dynamic> whereArgsOr = [];
        
        for (int i = 0; i < keywords.length; i++) {
          if (i > 0) whereClauseOr += ' OR ';
          whereClauseOr += '$_textColumn LIKE ?';
          whereArgsOr.add('%${keywords[i]}%');
        }
        whereClauseOr += ')';
        
        if (subjects.isNotEmpty) {
          final conditions = subjects.map((_) => 'metadata LIKE ?').join(' OR ');
          whereClauseOr += ' AND ($conditions)';
          whereArgsOr.addAll(subjects.map((s) => '$s%'));
        }

        final rowsOr = await _db!.rawQuery(
          'SELECT $selectColumns FROM knowledge_base $whereClauseOr LIMIT $limit',
          whereArgsOr,
        );
        
        // Merge results
        final seen = rows.map((r) => r[_textColumn].toString()).toSet();
        final combined = List<Map<String, Object?>>.from(rows);
        
        for (var row in rowsOr) {
          if (combined.length >= limit) break;
          if (!seen.contains(row[_textColumn].toString())) {
            combined.add(row);
            seen.add(row[_textColumn].toString());
          }
        }
        rows = combined;
      }
      
      return rows.map((row) {
        final metadata = _hasMetadata ? (row['metadata'] as String? ?? 'Info') : 'Info';
        final text = row[_textColumn].toString();
        return "[$metadata]\n$text";
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
        'SELECT $_textColumn, topic_title FROM knowledge_base WHERE chapter_title = ? AND subject = ? ORDER BY RANDOM() LIMIT 1',
        [chapterTitle, subject],
      );
      
      if (rows.isEmpty) return '';
      
      final content = rows.first[_textColumn].toString();
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
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }
}
