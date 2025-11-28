# Offline AI Learning Platform

## 🎯 Features

- ✅ **100% Offline** - Works without internet connection
- ✅ **AI Tutor (RAG)** - Ask questions and get context-aware answers
- ✅ **Quiz Generation** - Auto-generate MCQ quizzes from lessons
- ✅ **Summarization** - Get quick revision summaries
- ✅ **Rich Content** - Lessons with markdown formatting
- ✅ **Lightweight** - Optimized for low-end devices

## 📂 Project Structure

```
lib/
├── main.dart              # App entry point
├── models/
│   └── lesson.dart        # Data models (Course, Lesson, Topic, Quiz)
├── services/
│   ├── database_helper.dart   # SQLite database operations
│   ├── ai_service.dart        # Llama model integration
│   └── vector_store.dart      # TF-IDF for RAG
├── providers/
│   └── course_provider.dart   # State management
└── screens/
    ├── home_screen.dart           # Course list
    ├── course_details_screen.dart # Lesson list
    ├── lesson_screen.dart         # Topic viewer
    ├── chat_screen.dart           # AI chatbot
    └── quiz_screen.dart           # Quiz interface

assets/
├── lessons/
│   ├── physics_101.json  # Physics course
│   └── math_basics.json  # Math course
└── models/
    └── model.gguf        # Llama model file (user must download)
```

## 🚀 Setup Instructions

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Download AI Model
Download **Llama-3.2-1B-Instruct-Q4_K_M.gguf** (~800 MB):
- **Direct Link**: [Download Model](https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf)
- **Rename** it to `model.gguf`
- **Place** it in `assets/models/model.gguf`

### 3. Run the App
```bash
flutter run
```

## 📚 Adding New Courses

### Step 1: Create JSON File
Create a new JSON file in `assets/lessons/` (e.g., `chemistry_101.json`):

```json
{
  "id": "chemistry_101",
  "title": "Basic Chemistry",
  "description": "Introduction to chemistry",
  "iconPath": "assets/icons/chemistry.png",
  "lessons": [
    {
      "id": "lesson_atoms",
      "title": "Atomic Structure",
      "description": "Understanding atoms",
      "orderIndex": 1,
      "topics": [
        {
          "id": "topic_atom_intro",
          "title": "What is an Atom?",
          "content": "# Atoms\n\nAtoms are the basic building blocks of matter...",
          "orderIndex": 1
        }
      ]
    }
  ]
}
```

### Step 2: Register in CourseProvider
Edit `lib/providers/course_provider.dart` and add your file to the list:

```dart
final courseFiles = [
  'assets/lessons/physics_101.json',
  'assets/lessons/math_basics.json',
  'assets/lessons/chemistry_101.json',  // <-- Add here
];
```

### Step 3: Restart App
```bash
flutter run
```

## 🎮 How to Use

### 1. View Lessons
- Open app → Select a course → Select a lesson
- Swipe left/right to navigate between topics

### 2. Ask AI Questions  
- While viewing a lesson, tap the **"Ask AI"** floating button
- Type your question and get AI-powered answers based on the lesson content

### 3. Take a Quiz
- In a lesson, tap the **Quiz icon** (top right)
- AI generates 3 questions based on the lesson
- Answer them and see your score

### 4. Get a Summary
- In a lesson, tap the **Summarize icon** (top right)
- Get bullet-point summary for quick revision

## 🔧 Troubleshooting

### No Courses Showing
- Check that JSON files exist in `assets/lessons/`
- Verify they're listed in `course_provider.dart`
- Check debug console for error messages

### AI Not Working
- Ensure `model.gguf` exists in `assets/models/`
- File must be exactly 800MB for Llama-3.2-1B-Q4_K_M
- Check app logs for "Model loaded" message

### Build Errors
```bash
flutter clean
flutter pub get
flutter run
```

## 📱 System Requirements

- **Flutter SDK**: 3.10.0 or higher
- **RAM**: Minimum 2GB (4GB+ recommended)
- **Storage**: ~1GB free space
- **Android**: API 21+ (Android 5.0+)
- **iOS**: iOS 12.0+

## 📝 Content Format Guidelines

The app supports two JSON formats:

### Format 1: Standard Lesson Format
```json
{
  "id": "course_id",
  "title": "Course Title",
  "lessons": [
    {
      "id": "lesson_id",
      "title": "Lesson Title",
      "topics": [...]
    }
  ]
}
```

### Format 2: NCERT Chapter Format (Your Format)
```json
{
  "Chapters": [
    {
      "chapter_number": "1",
      "chapter_title": "Title",
      "topics": [
        {
          "topic": "Topic Name",
          "content": "Full content..."
        }
      ]
    }
  ]
}
```

**Both formats work automatically!**

- Use **Markdown** for topic content
- Headings: `# H1`, `## H2`, `### H3`
- Bold: `**text**`
- Lists: `- item` or `1. item`
- Code: `` `code` ``

## 🤖 AI Model Info

**Recommended**: Llama-3.2-1B-Instruct (Q4_K_M)
- **Size**: ~800 MB
- **Quality**: Best for <1GB budget
- **Features**: Quiz generation, Q&A, Summarization

**Alternative**: Qwen2.5-0.5B (Q8_0)  
- **Size**: ~600 MB
- **Quality**: Good for very limited devices

## 🏆 Features Summary

| Feature | Status | Description |
|---------|--------|-------------|
| Offline Content | ✅ | All lessons stored in SQLite |
| AI Chat | ✅ | RAG-powered doubt solving |
| Quiz Gen | ✅ | Auto MCQ generation |
| Summarizer | ✅ | Key points extraction |
| Markdown | ✅ | Rich text formatting |
| Low-RAM | ✅ | Optimized for 2GB RAM |

## 🆘 Support

For issues:
1. Check this README
2. Review `walkthrough.md` in artifacts
3. Check Flutter logs: `flutter run --verbose`
