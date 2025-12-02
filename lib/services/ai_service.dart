import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';
import 'database_helper.dart';
import 'precomputed_rag_service.dart';

class AIService {
  InferenceModel? _model;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isModelLoaded = false;
  dynamic _quizChatSession;
  int _quizGenerationCount = 0;

  bool get isModelLoaded => _isModelLoaded;

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
      
      // Create model instance with CPU backend (Matching reference code for stability)
      _model = await FlutterGemma.getActiveModel(
        maxTokens: 4096,  // Increased to 4096 to prevent "max sequence length" errors
        preferredBackend: PreferredBackend.cpu,
      );
      
      _isModelLoaded = true;
      print('✅ Gemma 3 1B model loaded successfully (CPU Backend)!');
      
      print('=== AI SERVICE INITIALIZATION COMPLETE ===');
    } catch (e) {
      print('❌ ERROR loading Gemma 3 model: $e');
      print('Stack trace: ${StackTrace.current}');
      _isModelLoaded = false;
    }
  }



  // Chat with RAG
  Stream<String> chat(String query) async* {
    print('💬 Chat request: "$query"');
    print('   Model loaded: $_isModelLoaded');
    
    if (!_isModelLoaded || _model == null) {
      yield "📚 **AI Model Not Available**\\n\\n";
      yield "The offline AI model is not loaded.\\n\\n";
      yield "Please download the model from the download screen first.\\n\\n";
      yield "**In the meantime**, you can:\\n";
      yield "✅ Read all lesson content\\n";
      yield "✅ Take quizzes (rule-based)\\n";
      yield "✅ Get summaries (extractive)\\n";
      return;
    }

    // Check for "capabilities" query (simple rule-based response)
    if (query.toLowerCase().contains('what can you do') || 
        query.toLowerCase().contains('help')) {
      yield "I can help you with:\\n\\n";
      yield "✅ Explaining lesson topics\\n";
      yield "✅ Summarizing long texts\\n";
      yield "✅ Generating quizzes to test your knowledge\\n";
      yield "✅ Answering questions from your offline lessons\\n";
      return;
    }

    // NEW: Use pre-computed RAG service for faster, semantic search
    print('🔎 Searching pre-computed database for relevant context...');
    final context = await PrecomputedRagService.instance.searchForContext(
      query,
      subjects: [], // Can be filtered by subjects if needed
      limit: 2,
    );
    
    print('   Context length: ${context.length} chars');

    final prompt = """You are a helpful and knowledgeable tutor.
Use the provided context to answer the student's question clearly and concisely.
The context may contain information from different subjects. Pay attention to the [Subject - Topic] headers.
If the context doesn't have the answer, use your general knowledge to help.

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


  Future<String> generateQuizJson(String topicContent, {String? topicId}) async {
    if (!_isModelLoaded || _model == null) {
      return _generateFallbackQuiz(topicContent);
    }

    try {
      // 1. Manage Session - ALWAYS create fresh session for quiz generation
      _quizChatSession = null;
      
      final model = await FlutterGemma.getActiveModel(
        preferredBackend: PreferredBackend.cpu,
        maxTokens: 4096,
      );
      _quizChatSession = await model.createChat();
      _quizGenerationCount = 0;
      print('🔄 Created fresh chat session for quiz generation');

      // 2. Limit Content - STRICT limit to prevent token overflow
      String limitedContent = topicContent;
      if (topicContent.length > 600) {
        final maxStart = topicContent.length - 600;
        final start = Random().nextInt(maxStart);
        limitedContent = topicContent.substring(start, start + 600);
      }

      // 3. Construct Prompt
      final prompt = """Create 1 multiple-choice question based strictly on the text above.
The question must have a clear, unambiguous answer in the text.
Do not refer to "the text" or "the provided text" in the question itself.

Format the output EXACTLY as follows (pipe-separated):
Question|Correct Answer|Wrong Option 1|Wrong Option 2|Wrong Option 3

Example:
What is the capital of France?|Paris|London|Berlin|Madrid

Text:
$limitedContent

Output:""";

      // 4. Send to Model
      print('📝 Generating quiz question...');
      String fullResponse = "";
      
      await _quizChatSession!.addQueryChunk(Message.text(
        text: prompt,
        isUser: true,
      ));

      await for (final response in _quizChatSession!.generateChatResponseAsync()) {
        if (response is TextResponse) {
          fullResponse += response.token;
        }
      }
      
      print('✅ Raw Quiz Response: $fullResponse');

      // 5. Parse Response
      final parts = fullResponse.split('|').map((s) => s.trim()).toList();
      
      if (parts.length >= 5) {
        final question = parts[0];
        final correct = parts[1];
        final wrong1 = parts[2];
        final wrong2 = parts[3];
        final wrong3 = parts[4];
        
        final options = [correct, wrong1, wrong2, wrong3];
        final correctOption = correct; 
        options.shuffle();
        
        final correctIndex = options.indexOf(correctOption);
        
        final quizMap = {
          "questions": [
            {
              "question": question,
              "options": options,
              "correctOptionIndex": correctIndex,
              "explanation": "Correct answer: $correct"
            }
          ]
        };
        
        return jsonEncode(quizMap);
      } else {
        throw Exception("Invalid format");
      }

    } catch (e) {
      print('❌ Quiz Generation Error: $e');
      return _generateFallbackQuiz(topicContent);
    }
  }

  String _generateFallbackQuiz(String topicContent) {
    print('⚠️ Using fallback quiz generation');
    final sentences = topicContent.split(RegExp(r'(?<=[.!?])\s+'));
    
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
        "correctOptionIndex": 0,
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
        "correctOptionIndex": 0,
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
    _isModelLoaded = false;
  }
}
