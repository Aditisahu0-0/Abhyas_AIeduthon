import 'dart:convert';
import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import 'package:path/path.dart' as p;

void main() {
  print('🏗️  Building Knowledge Base Database...');

  // 1. Setup Paths
  final projectRoot = Directory.current.path;
  final assetsDir = Directory(p.join(projectRoot, 'assets', 'lessons'));
  final dbPath = p.join(projectRoot, 'assets', 'knowledge_base.db');

  if (!assetsDir.existsSync()) {
    print('❌ Assets directory not found: ${assetsDir.path}');
    exit(1);
  }

  // 2. Create/Reset Database
  final dbFile = File(dbPath);
  if (dbFile.existsSync()) {
    dbFile.deleteSync();
    print('🗑️  Deleted existing database');
  }

  print('📂 Opening database at: $dbPath');
  final db = sqlite3.open(dbPath);

  // 3. Create Table
  // We use FTS5 for full-text search if available, or just standard table with LIKE
  // FTS is better for "keyword search" speed.
  try {
    db.execute('''
      CREATE TABLE knowledge_base (
        id TEXT PRIMARY KEY,
        content TEXT,
        metadata TEXT,
        embedding BLOB
      );
    ''');
    // Create a simple index on content for LIKE queries if FTS isn't used
    // db.execute('CREATE INDEX idx_content ON knowledge_base(content);'); 
    print('✅ Table created');
  } catch (e) {
    print('❌ Error creating table: $e');
    exit(1);
  }

  // 4. Process JSON Files
  final jsonFiles = assetsDir.listSync().where((f) => f.path.endsWith('.json'));
  int totalTopics = 0;

  final insertStmt = db.prepare('INSERT INTO knowledge_base (id, content, metadata) VALUES (?, ?, ?)');

  for (var file in jsonFiles) {
    if (file is File) {
      print('📄 Processing: ${p.basename(file.path)}');
      try {
        final content = file.readAsStringSync();
        final data = jsonDecode(content);
        
        // Handle different JSON structures if needed (assuming standard structure based on previous files)
        // Structure: { "course": ..., "lessons": [ { "id":..., "topics": [ ... ] } ] }
        
        if (data['lessons'] != null) {
          for (var lesson in data['lessons']) {
            final lessonTitle = lesson['title'] ?? 'Unknown Lesson';
            if (lesson['topics'] != null) {
              for (var topic in lesson['topics']) {
                final topicId = topic['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
                final topicTitle = topic['title'] ?? 'Unknown Topic';
                final topicContent = topic['content'] ?? '';
                final metadata = '${data['title'] ?? 'Course'} - $lessonTitle - $topicTitle';

                if (topicContent.isNotEmpty) {
                  insertStmt.execute([topicId, topicContent, metadata]);
                  totalTopics++;
                }
              }
            }
          }
        }
      } catch (e) {
        print('⚠️  Error processing ${file.path}: $e');
      }
    }
  }

  insertStmt.dispose();
  db.dispose();

  print('🎉 Database built successfully!');
  print('📊 Total topics indexed: $totalTopics');
  print('💾 Database size: ${File(dbPath).lengthSync() / 1024} KB');
}
