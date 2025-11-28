import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';
import 'vector_store.dart';
import 'embedding_service.dart';
import 'database_helper.dart';

class AIService {
  InferenceModel? _model;
  final VectorStore _vectorStore = VectorStore();
  final EmbeddingService _embeddingService = EmbeddingService();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isModelLoaded = false;

  bool get isModelLoaded => _isModelLoaded;
  VectorStore get vectorStore => _vectorStore;

  Future<void> initialize() async {
    if (_isModelLoaded) return;

    try {
      print('=== AI SERVICE INITIALIZATION START ===');
      print('Loading Gemma 3 1B IT model...');
      
      // Get model file path
      final directory = await getApplicationDocumentsDirectory();
      final modelPath = '${directory.path}/model.task';
      final modelFile = File(modelPath);
      
      // Check if model file exists
      if (!await modelFile.exists()) {
        print('❌ Model file not found at: $modelPath');
        print('Please download the model from the download screen first.');
        _isModelLoaded = false;
        return;
      }
      
      print('📁 Model file found at: $modelPath');
      print('📊 Model file size: ${await modelFile.length() ~/ (1024 * 1024)} MB');
      
      // Install model from file
      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
      ).fromFile(
        modelPath,
      ).install();
      
      print('✅ Model installed successfully');
      
      // Create model instance with GPU backend for phones
      _model = await FlutterGemma.getActiveModel(
        maxTokens: 2048,  // Increased to 2048 to prevent OUT_OF_RANGE errors
        preferredBackend: PreferredBackend.gpu,  // GPU for Android phones
      );
      
      _isModelLoaded = true;
      print('✅ Gemma 3 1B model loaded successfully!');
      
      // Initialize embedding service (MiniLM)
      print('Loading MiniLM embedding model...');
      await _embeddingService.initialize();
      
      if (_embeddingService.isLoaded) {
        _vectorStore.setEmbeddingService(_embeddingService);
        print('✅ Hybrid search enabled (TF-IDF + Semantic)');
      } else {
        print('⚠️ MiniLM not loaded, using TF-IDF only');
      }
      
      print('=== AI SERVICE INITIALIZATION COMPLETE ===');
    } catch (e) {
      print('❌ ERROR loading Gemma 3 model: $e');
      print('Stack trace: ${StackTrace.current}');
      _isModelLoaded = false;
    }
  }

  // RAG: Index content
  Future<void> indexContent(String id, String content, {String? metadata}) async {
    // Generate semantic embedding if available
    List<double>? embedding;
    if (_embeddingService.isLoaded) {
      embedding = await _embeddingService.generateEmbedding(content);
    }
    
    await _vectorStore.addDocument(id, content, metadata: metadata, embedding: embedding);
  }

  // Chat with RAG
  Stream<String> chat(String query) async* {
    print('💬 Chat request: "$query"');
    print('   Model loaded: $_isModelLoaded');
    print('   Vector store docs: ${_vectorStore.documentCount}');
    
    if (!_isModelLoaded || _model == null) {
      yield "📚 **AI Model Not Available**\n\n";
      yield "The offline AI model is not loaded.\n\n";
      yield "Please download the model from the download screen first.\n\n";
      yield "**In the meantime**, you can:\n";
      yield "✅ Read all lesson content\n";
      yield "✅ Take quizzes (rule-based)\n";
      yield "✅ Get summaries (extractive)\n";
      return;
    }

    // Check for "capabilities" query (simple rule-based response)
    if (query.toLowerCase().contains('what can you do') || 
        query.toLowerCase().contains('help')) {
      yield "I can help you with:\n\n";
      yield "✅ Explaining lesson topics\n";
      yield "✅ Summarizing long texts\n";
      yield "✅ Generating quizzes to test your knowledge\n";
      yield "✅ Answering questions from your offline lessons\n";
      return;
    }

    // RAG: Retrieve context (now uses hybrid search if available)
    print('🔎 Searching vector store for relevant context...');
    // Reduce limit to 2 to save tokens, preventing OUT_OF_RANGE errors
    final relevantDocs = await _vectorStore.search(query, limit: 2);
    final context = relevantDocs.join("\n\n");
    
    print('   Retrieved ${relevantDocs.length} documents');
    print('   Context length: ${context.length} chars');

    final prompt = """You are a helpful tutor for students. Use the following context to answer the student's question.
If the answer is not in the context, answer based on general knowledge but mention you're unsure.

Context:
$context

Student: $query
Tutor:
""";

    try {
      final chat = await _model!.createChat();
      await chat.addQueryChunk(Message.text(
        text: prompt,
        isUser: true,
      ));
      
      // Use streaming API for real-time responses
      await for (final response in chat.generateChatResponseAsync()) {
        if (response is TextResponse) {
          yield response.token;  // Yield tokens as they arrive
        }
      }
    } catch (e) {
      print('❌ Error generating response: $e');
      yield "Sorry, I encountered an error generating the response. Please try again.";
    }
  }



  Future<String> generateQuizJson(String topicContent, {String difficulty = 'medium', String? topicId}) async {
    // Check cache first
    if (topicId != null) {
      final cached = await _dbHelper.getQuizCache(topicId, difficulty);
      if (cached != null) {
        print('📦 Using cached quiz for topic $topicId ($difficulty)');
        return cached;
      }
    }
    
    if (!_isModelLoaded || _model == null) {
      final fallback = _generateFallbackQuiz(topicContent, difficulty: difficulty);
      if (topicId != null) await _dbHelper.saveQuizCache(topicId, difficulty, fallback);
      return fallback;
    }

    // Optimized prompt for speed and reliability
    final prompt = """Context:
$topicContent

Task: Generate 3 multiple-choice questions based on the text above.
Difficulty: $difficulty

Output strictly in JSON format:
{
  "questions": [
    {
      "question": "Question text",
      "options": ["Correct Answer", "Wrong 1", "Wrong 2", "Wrong 3"],
      "correctIndex": 0,
      "explanation": "Brief explanation"
    }
  ]
}
Ensure options are shuffled so correct answer is not always first. Do not add markdown.""";

    try {
      final chat = await _model!.createChat();
      await chat.addQueryChunk(Message.text(text: prompt, isUser: true));
      
      StringBuffer fullResponse = StringBuffer();
      await for (final response in chat.generateChatResponseAsync()) {
        if (response is TextResponse) fullResponse.write(response.token);
      }
      
      String cleanJson = fullResponse.toString().trim()
          .replaceAll('```json', '').replaceAll('```', '').trim();
      
      // Attempt to fix common JSON errors if any
      if (!cleanJson.startsWith('{')) cleanJson = cleanJson.substring(cleanJson.indexOf('{'));
      if (!cleanJson.endsWith('}')) cleanJson = cleanJson.substring(0, cleanJson.lastIndexOf('}') + 1);

      jsonDecode(cleanJson); // Validate
      
      if (topicId != null) await _dbHelper.saveQuizCache(topicId, difficulty, cleanJson);
      return cleanJson;
    } catch (e) {
      print('Error generating quiz: $e');
      final fallback = _generateFallbackQuiz(topicContent, difficulty: difficulty);
      if (topicId != null) await _dbHelper.saveQuizCache(topicId, difficulty, fallback);
      return fallback;
    }
  }
  
  String _generateFallbackQuiz(String content, {String difficulty = 'medium'}) {
    final sentences = content.split('.').where((s) => s.trim().isNotEmpty).toList();
    
    // Shuffle sentences for variety each time
    sentences.shuffle();
    
    List<Map<String, dynamic>> questions = [];
    
    for (int i = 0; i < 3 && i < sentences.length; i++) {
      final sentence = sentences[i].trim();
      if (sentence.length < 20) continue;
      
      final words = sentence.split(' ').where((w) => w.length > 5).toList();
      if (words.isEmpty) continue;
      
      final keyWord = words.first;
      
      questions.add({
        "question": "What is discussed about ${keyWord.toLowerCase()} in this topic?",
        "options": [
          sentence.substring(0, sentence.length > 50 ? 50 : sentence.length) + "...",
          "This concept is not mentioned",
          "It is explained differently",
          "The topic does not cover this"
        ],
        "correctIndex": 0,
        "explanation": "The correct answer is based on the content provided."
      });
      
      if (questions.length >= 3) break;
    }
    
    while (questions.length < 3) {
      questions.add({
        "question": "Based on this lesson, which statement is correct?",
        "options": [
          "The content explains the topic clearly",
          "The topic is not covered",
          "This is about a different subject",
          "None of the above"
        ],
        "correctIndex": 0,
        "explanation": "Review the lesson content for accurate information."
      });
    }
    
    return jsonEncode({"questions": questions});
  }
  
  Future<String> summarize(String content) async {
    if (!_isModelLoaded || _model == null) {
      return _generateFallbackSummary(content);
    }

    final prompt = """Summarize the following educational content into 3-5 key bullet points for quick revision.
Make each point clear and concise.

Content:
$content

Summary (as bullet points):""";

    try {
      final chat = await _model!.createChat();
      await chat.addQueryChunk(Message.text(
        text: prompt,
        isUser: true,
      ));
      
      // Collect full response
      StringBuffer fullResponse = StringBuffer();
      await for (final response in chat.generateChatResponseAsync()) {
        if (response is TextResponse) {
          fullResponse.write(response.token);
        }
      }
      
      return fullResponse.toString().trim();
    } catch (e) {
      print('Error generating summary: $e');
      return _generateFallbackSummary(content);
    }
  }
  
  String _generateFallbackSummary(String content) {
    final sentences = content.split('.').where((s) => s.trim().isNotEmpty).toList();
    
    List<String> keyPoints = [];
    
    if (sentences.isNotEmpty) {
      keyPoints.add("• ${sentences.first.trim()}");
    }
    
    for (var sentence in sentences) {
      if (keyPoints.length >= 5) break;
      
      final lower = sentence.toLowerCase();
      if (lower.contains('important') || 
          lower.contains('key') || 
          lower.contains('main') ||
          lower.contains('first') ||
          lower.contains('second') ||
          lower.contains('therefore') ||
          lower.contains('thus')) {
        keyPoints.add("• ${sentence.trim()}");
      }
    }
    
    int index = 0;
    while (keyPoints.length < 3 && index < sentences.length) {
      final sentence = sentences[index].trim();
      if (sentence.isNotEmpty && !keyPoints.any((p) => p.contains(sentence))) {
        keyPoints.add("• $sentence");
      }
      index++;
    }
    
    return "**Quick Summary:**\\n\\n" + keyPoints.join("\\n\\n");
  }

  void dispose() {
    _model?.close();
    _model = null;
    _embeddingService.dispose();
    _isModelLoaded = false;
  }
}
