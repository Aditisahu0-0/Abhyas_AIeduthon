"""
Generate Pre-computed Embeddings Database for ABHYAS App

This script:
1. Reads all JSON files from assets/lessons/
2. Extracts topic content
3. Generates embeddings using sentence-transformers
4. Stores in SQLite database with pre-computed embeddings

Requirements:
    pip install sentence-transformers numpy tqdm
"""

import json
import sqlite3
import struct
from pathlib import Path
from typing import List, Dict
import numpy as np
from sentence_transformers import SentenceTransformer
from tqdm import tqdm

# Configuration
ASSETS_DIR = Path("../assets/lessons")
OUTPUT_DB = Path("../assets/knowledge_base.db")
EMBEDDING_MODEL = "sentence-transformers/all-MiniLM-L6-v2"  # 384 dimensions

def load_json_files() -> List[Dict]:
    """Load all JSON files from assets/lessons directory"""
    json_files = list(ASSETS_DIR.glob("*.json"))
    print(f"📂 Found {len(json_files)} JSON files")
    
    all_topics = []
    
    for json_file in json_files:
        print(f"   Reading {json_file.name}...")
        try:
            with open(json_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            # Determine subject from filename
            filename = json_file.stem  # e.g., "class9_mathematics"
            parts = filename.split('_')
            subject = parts[1].capitalize() if len(parts) > 1 else "Unknown"
            
            # Extract chapters (handle both "Chapters" and "lessons" keys)
            chapters = data.get('Chapters') or data.get('lessons') or []
            
            for chapter in chapters:
                chapter_title = chapter.get('chapter_title') or chapter.get('title') or 'Unknown'
                chapter_num = chapter.get('chapter_number', '')
                
                # Extract topics
                topics = chapter.get('topics', [])
                
                for idx, topic in enumerate(topics):
                    topic_id = topic.get('id') or f"{filename}_{chapter_num}_{idx}"
                    topic_title = (
                        topic.get('section_title') or 
                        topic.get('title') or 
                        topic.get('topic') or 
                        f"Topic {idx + 1}"
                    )
                    content = topic.get('content', '')
                    
                    if content.strip():  # Only add if content exists
                        all_topics.append({
                            'id': topic_id,
                            'subject': subject,
                            'chapter_title': chapter_title,
                            'chapter_number': chapter_num,
                            'topic_title': topic_title,
                            'content': content,
                            'source_file': json_file.name
                        })
        
        except Exception as e:
            print(f"   ⚠️  Error reading {json_file.name}: {e}")
    
    print(f"✅ Extracted {len(all_topics)} topics total\n")
    return all_topics

def generate_embeddings(topics: List[Dict]) -> List[Dict]:
    """Generate embeddings for all topics"""
    print(f"🧠 Loading embedding model: {EMBEDDING_MODEL}")
    model = SentenceTransformer(EMBEDDING_MODEL)
    print(f"✅ Model loaded (Embedding dimension: {model.get_sentence_embedding_dimension()})\n")
    
    print("🔄 Generating embeddings...")
    contents = [topic['content'] for topic in topics]
    
    # Generate embeddings with progress bar
    embeddings = model.encode(
        contents,
        show_progress_bar=True,
        batch_size=32,
        convert_to_numpy=True
    )
    
    # Add embeddings to topics
    for topic, embedding in zip(topics, embeddings):
        topic['embedding'] = embedding
    
    print(f"✅ Generated {len(embeddings)} embeddings\n")
    return topics

def embedding_to_blob(embedding: np.ndarray) -> bytes:
    """Convert numpy array to binary blob (float32)"""
    return struct.pack(f'{len(embedding)}f', *embedding.astype(np.float32))

def create_database(topics: List[Dict], db_path: Path):
    """Create SQLite database with pre-computed embeddings"""
    
    # Delete old database if exists
    if db_path.exists():
        print(f"🗑️  Deleting old database: {db_path}")
        db_path.unlink()
    
    print(f"📦 Creating new database: {db_path}")
    db_path.parent.mkdir(parents=True, exist_ok=True)
    
    conn = sqlite3.connect(str(db_path))
    cursor = conn.cursor()
    
    # Create table
    cursor.execute('''
        CREATE TABLE knowledge_base (
            id TEXT PRIMARY KEY,
            subject TEXT,
            chapter_title TEXT,
            chapter_number TEXT,
            topic_title TEXT,
            content TEXT,
            display_text TEXT,
            embedding BLOB,
            source_file TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    # Create indexes for faster queries
    cursor.execute('CREATE INDEX idx_subject ON knowledge_base(subject)')
    cursor.execute('CREATE INDEX idx_chapter ON knowledge_base(chapter_title)')
    
    print("📝 Inserting topics into database...")
    
    for topic in tqdm(topics, desc="Inserting"):
        # Create display text for showing in results
        display_text = f"""SUBJECT: {topic['subject']}
CHAPTER: {topic['chapter_title']}
TOPIC: {topic['topic_title']}

{topic['content'][:500]}..."""
        
        cursor.execute('''
            INSERT OR REPLACE INTO knowledge_base (
                id, subject, chapter_title, chapter_number, 
                topic_title, content, display_text, embedding, source_file
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            topic['id'],
            topic['subject'],
            topic['chapter_title'],
            topic['chapter_number'],
            topic['topic_title'],
            topic['content'],
            display_text,
            embedding_to_blob(topic['embedding']),
            topic['source_file']
        ))
    
    conn.commit()
    
    # Print statistics
    cursor.execute('SELECT COUNT(*) FROM knowledge_base')
    total = cursor.fetchone()[0]
    
    cursor.execute('SELECT subject, COUNT(*) FROM knowledge_base GROUP BY subject')
    by_subject = cursor.fetchall()
    
    print(f"\n✅ Database created successfully!")
    print(f"📊 Statistics:")
    print(f"   Total topics: {total}")
    for subject, count in by_subject:
        print(f"   {subject}: {count} topics")
    
    # Get database size
    db_size_mb = db_path.stat().st_size / (1024 * 1024)
    print(f"   Database size: {db_size_mb:.2f} MB")
    
    conn.close()

def main():
    print("=" * 60)
    print("🚀 ABHYAS - Pre-computed Embeddings Database Generator")
    print("=" * 60)
    print()
    
    # Step 1: Load JSON files
    topics = load_json_files()
    
    if not topics:
        print("❌ No topics found! Please check your JSON files.")
        return
    
    # Step 2: Generate embeddings
    topics_with_embeddings = generate_embeddings(topics)
    
    # Step 3: Create database
    create_database(topics_with_embeddings, OUTPUT_DB)
    
    print("\n" + "=" * 60)
    print("🎉 SUCCESS! Database is ready to use.")
    print("=" * 60)
    print(f"\n📍 Location: {OUTPUT_DB.absolute()}")
    print("\nNext steps:")
    print("1. Copy the database to assets/ folder (if not already there)")
    print("2. Update Flutter code to use the new database")
    print("3. Remove old vector_store.dart and embedding_service.dart")

if __name__ == "__main__":
    main()
