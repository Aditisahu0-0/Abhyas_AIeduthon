#!/usr/bin/env python3
"""
Database Builder for Offline Learning App
Generates a pre-computed SQLite database from JSON lesson files
"""

import sqlite3
import json
import os
from pathlib import Path

def main():
    print("🏗️  Building Knowledge Base Database...")
    
    # 1. Setup Paths
    project_root = Path(__file__).parent.parent
    assets_dir = project_root / "assets" / "lessons"
    db_path = project_root / "assets" / "knowledge_base.db"
    
    if not assets_dir.exists():
        print(f"❌ Assets directory not found: {assets_dir}")
        return
    
    # 2. Create/Reset Database
    if db_path.exists():
        db_path.unlink()
        print("🗑️  Deleted existing database")
    
    print(f"📂 Creating database at: {db_path}")
    conn = sqlite3.connect(str(db_path))
    cursor = conn.cursor()
    
    # 3. Create Table
    cursor.execute('''
        CREATE TABLE knowledge_base (
            id TEXT PRIMARY KEY,
            content TEXT,
            metadata TEXT,
            embedding BLOB
        )
    ''')
    print("✅ Table created")
    
    # 4. Process JSON Files
    json_files = list(assets_dir.glob("*.json"))
    total_topics = 0
    
    for json_file in json_files:
        print(f"📄 Processing: {json_file.name}")
        try:
            with open(json_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            course_title = data.get('title', 'Course')
            
            # Handle both "lessons" and "Chapters" format
            lessons = data.get('lessons') or data.get('Chapters') or []
            
            for lesson in lessons:
                lesson_title = lesson.get('title') or lesson.get('chapter_title') or 'Unknown Lesson'
                topics = lesson.get('topics', [])
                
                for topic in topics:
                    topic_id = topic.get('id', f'topic_{total_topics}')
                    topic_title = topic.get('title') or topic.get('topic') or 'Unknown Topic'
                    topic_content = topic.get('content', '')
                    metadata = f"{course_title} - {lesson_title} - {topic_title}"
                    
                    if topic_content:
                        cursor.execute(
                            'INSERT INTO knowledge_base (id, content, metadata) VALUES (?, ?, ?)',
                            (topic_id, topic_content, metadata)
                        )
                        total_topics += 1
        
        except Exception as e:
            print(f"⚠️  Error processing {json_file.name}: {e}")
    
    conn.commit()
    conn.close()
    
    # 5. Report Success
    print("\n🎉 Database built successfully!")
    print(f"📊 Total topics indexed: {total_topics}")
    print(f"💾 Database size: {db_path.stat().st_size / 1024:.2f} KB")
    print(f"📍 Location: {db_path}")

if __name__ == "__main__":
    main()
