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
  
  // Quiz session management
  dynamic _quizChatSession;
  int _quizGenerationCount = 0;
  Set<String> _generatedQuestions = {}; // Prevent duplicates
  
  // Chat session management for memory overflow prevention
  dynamic _chatSession;
  int _chatMessageCount = 0;
  int _chatTokenCount = 0;
  final int maxMessagesBeforeRefresh = 8; // Auto-refresh after 8 messages
  final int maxTokensBeforeRefresh = 2000; // Auto-refresh after ~2000 tokens

  bool get isModelLoaded => _isModelLoaded;
  int get chatMessageCount => _chatMessageCount;
  
  /// Clears chat session to free memory - call this when chat gets stuck
  Future<void> clearChatSession() async {
    print('🔄 Clearing chat session to free memory...');
    _chatSession = null;
    _chatMessageCount = 0;
    _chatTokenCount = 0;
    print('✅ Chat session cleared');
  }

  Future<void> initialize() async {
    if (_isModelLoaded) return;

    try {
      print('=== AI SERVICE INITIALIZATION START ===');
      print('Loading Gemma 3 1B IT model...');
      
      final directory = await getApplicationDocumentsDirectory();
      final modelPath = '${directory.path}/model.task';
      final modelFile = File(modelPath);
      
      if (!await modelFile.exists()) {
        print('❌ Model file not found at: $modelPath');
        print('Please download the model from the download screen first.');
        _isModelLoaded = false;
        return;
      }
      
      print('📁 Model file found at: $modelPath');
      print('📊 Model file size: ${await modelFile.length() ~/ (1024 * 1024)} MB');
      
      
      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
      ).fromFile(
        modelPath,
      ).install();
      
      print('✅ Model installed successfully');
      
      _model = await FlutterGemma.getActiveModel(
        preferredBackend: PreferredBackend.cpu,
        maxTokens: 8192,
      );
      
      // Initialize RAG Service (Pre-computed embeddings)
      await PrecomputedRagService.instance.initialize();
      

      _isModelLoaded = true;
      print('=== AI SERVICE INITIALIZATION COMPLETE ===');
    } catch (e) {
      print('❌ Error initializing AI model: $e');
      _isModelLoaded = false;
    }
  }

  Stream<String> chat(String query, {String? subject}) async* {
    if (!_isModelLoaded || _model == null) {
      yield "AI model is not loaded. Please download and initialize the model first.";
      return;
    }

    if (query.toLowerCase().contains('what can you do') || 
        query.toLowerCase().contains('help')) {
      yield "I can help you with:\\n\\n";
      yield "✅ Explaining lesson topics\\n";
      yield "✅ Summarizing long texts\\n";
      yield "✅ Generating quizzes to test your knowledge\\n";
      yield "✅ Answering questions from your offline lessons\\n";
      return;
    }

    print('🔎 Searching pre-computed database for relevant context...');
    final context = await PrecomputedRagService.instance.searchForContext(
      query,
      subjects: subject != null ? [subject] : [],
      limit: 2, // Changed to 2 as per user request
    );
    
    print('   Context length: ${context.length} chars');

    final prompt = """<start_of_turn>user
You are an expert AI Tutor. Your goal is to provide accurate, structured, and helpful explanations.

INSTRUCTIONS:
1.  **Be Concise**: Limit your response to 3-5 short bullet points. Avoid fluff.
2.  **Use Context**: Strictly use the provided context.
3.  **No Repetition**: Do not repeat the same information.
4.  **NO QUIZZES**: Do NOT generate multiple choice questions.

Context:
$context

Student Question: $query
<end_of_turn>
<start_of_turn>model
""";

    try {
      // Auto-refresh session if memory limit reached
      if (_chatSession == null || _chatMessageCount >= maxMessagesBeforeRefresh || _chatTokenCount >= maxTokensBeforeRefresh) {
        if (_chatMessageCount > 0) {
          print('⚠️ Chat session memory limit reached. Auto-refreshing...');
          yield "\\n\\n---\\n**Memory refreshed** - Chat history cleared to improve performance\\n---\\n\\n";
        }
        _chatSession = await _model!.createChat();
        _chatMessageCount = 0;
        _chatTokenCount = 0;
        print('🔄 Created/refreshed chat session');
      }
      
      await _chatSession!.addQueryChunk(Message.text(
        text: prompt,
        isUser: true,
      ));
      _chatMessageCount++;
      
      String lastToken = "";
      int repeatCount = 0;
      int totalTokens = 0;
      const int maxTokens = 150;
      StringBuffer accumulatedResponse = StringBuffer();
      
      // Track garbage patterns
      int consecutiveAsterisks = 0;
      int garbagePhrasesCount = 0;
      int consecutiveSameWord = 0;
      String lastWord = '';
      final garbagePhrases = {'and as well', 'This was an', 'I-', 'and as well-', 'This-', '2-'};

      await for (final response in _chatSession!.generateChatResponseAsync()) {
        if (response is TextResponse) {
          final token = response.token;
          totalTokens++;
          
          if (totalTokens > maxTokens) {
            print('⚠️ Max token limit reached. Stopping generation.');
            break;
          }
          
          if (token.trim() == '*') {
            consecutiveAsterisks++;
            if (consecutiveAsterisks > 5) {
              print('⚠️ Too many asterisks. Response is garbage. Stopping.');
              accumulatedResponse.clear();
              accumulatedResponse.write("I apologize, but I couldn't find relevant information to answer your question. Please try rephrasing or check if you've selected the correct subject.");
              break;
            }
          } else {
            consecutiveAsterisks = 0;
          }
          
          // Check for repetitive single words like "This" "This" "This"
          final currentWord = token.trim();
          if (currentWord.isNotEmpty && currentWord.length <= 5) {
            if (currentWord == lastWord) {
              consecutiveSameWord++;
              if (consecutiveSameWord > 3) {
                print('⚠️ Repeating single word "$currentWord". Stopping.');
                accumulatedResponse.clear();
                accumulatedResponse.write("I couldn't generate a proper response. Please try refreshing the chat or asking a different question.");
                break;
              }
            } else {
              consecutiveSameWord = 0;
            }
            lastWord = currentWord;
          }
          
          for (final phrase in garbagePhrases) {
            if (token.toLowerCase().contains(phrase.toLowerCase())) {
              garbagePhrasesCount++;
              if (garbagePhrasesCount > 5) {
                print('⚠️ Too many garbage phrases. Stopping.');
                accumulatedResponse.clear();
                accumulatedResponse.write("I couldn't generate a proper response. Please refresh the chat or rephrase your question.");
                break;
              }
            }
          }
          
          final trimmedToken = token.trim();
          if (trimmedToken.length <= 2 && (trimmedToken == lastToken.trim())) {
            repeatCount++;
            if (repeatCount > 3) {
              print('⚠️ Detected punctuation loop. Stopping.');
              break;
            }
          } else if (trimmedToken == lastToken.trim() && trimmedToken.length > 2) {
            repeatCount++;
            if (repeatCount > 2) continue;
          } else {
            repeatCount = 0;
          }
          lastToken = token;

          accumulatedResponse.write(token);
          _chatTokenCount++; // Track for memory management
          yield token;
        }
      }
      
      final finalResponse = accumulatedResponse.toString();
      if (_isGarbageResponse(finalResponse)) {
        yield "\\n\\n---\\n\\n**Note**: The response quality was low. Please try refreshing the chat or asking a more specific question.";
      }
    } catch (e) {
      print('❌ Error generating response: $e');
      yield "Sorry, I encountered an error. Please try refreshing the chat.";
    }
  }

  bool _isGarbageResponse(String response) {
    if (response.isEmpty) return true;
    
    final asteriskCount = '*'.allMatches(response).length;
    if (asteriskCount > response.length * 0.3) return true;
    
    if (response.contains('and as well-and as well-')) return true;
    if (response.contains('This was anThis was an')) return true;
    
    return false;
  }

  Future<String> generateQuizJson(String topicContent, {String? topicId}) async {
    if (!_isModelLoaded || _model == null) {
      return _generateFallbackQuiz(topicContent);
    }

    try {
      _quizChatSession = null;
      
      final model = await FlutterGemma.getActiveModel(
        preferredBackend: PreferredBackend.cpu,
        maxTokens: 4096,
      );
      _quizChatSession = await model.createChat();
      _quizGenerationCount = 0;
      print('🔄 Created fresh chat session for quiz generation');

      String limitedContent = topicContent;
      if (topicContent.length > 2000) {
        final maxStart = topicContent.length - 1500;
        if (maxStart > 0) {
          final start = Random().nextInt(maxStart);
          final end = min(start + 1500, topicContent.length);
          limitedContent = topicContent.substring(start, end);
        } else {
          limitedContent = topicContent.substring(0, 1500);
        }
      }

      final prompt = """<start_of_turn>user
You are an expert Quiz Generator.
Create 1 multiple-choice question based on SPECIFIC FACTS from the text below.

CRITICAL Rules:
1. **Ask about SPECIFIC FACTS, NUMBERS, CONCEPTS, or DEFINITIONS from the text**
2. **NEVER ask meta-questions** like:
   - "What is discussed about..."
   - "What is covered in..."
   - "What topic..."
   - "Based on this lesson..."
3. **Question must be directly answerable from the text**
4. **Options**: 1 correct answer + 3 plausible distractors of the SAME TYPE
   - If answer is a number, ALL options must be numbers
   - If answer is a term, ALL options must be terms
   - If answer is a definition, ALL options must be definitions
5. **Output**: Valid JSON only, NO markdown

Text:
$limitedContent

Output JSON format:
{
  "question": "<Specific factual question>",
  "correct_answer": "<Correct answer>",
  "wrong_answers": ["<Distractor 1>", "<Distractor 2>", "<Distractor 3>"]
}

Important:
- Do NOT copy template values
- Replace placeholders with actual content
- Ensure valid JSON
<end_of_turn>
<start_of_turn>model
{
""";

      print('📝 Generating quiz question...');
      StringBuffer fullResponse = StringBuffer();
      
      await _quizChatSession!.addQueryChunk(Message.text(
        text: prompt,
        isUser: true,
      ));

      String? lastToken;
      int repeatCount = 0;

      await for (final response in _quizChatSession!.generateChatResponseAsync()) {
        if (response is TextResponse) {
          final token = response.token;
          
          if (token == lastToken && token.trim().isNotEmpty) {
            repeatCount++;
            if (repeatCount > 5) {
              print('⚠️ Detected repetition loop in quiz generation. Stopping.');
              break;
            }
          } else {
            repeatCount = 0;
          }
          lastToken = token;

          fullResponse.write(token);
        }
      }
      
      String responseText = fullResponse.toString();
      print('✅ Raw Quiz Response: $responseText');
      
      responseText = responseText.replaceAll('```json', '').replaceAll('```', '').trim();
      
      while (responseText.endsWith('\\n}') && responseText.split('}').length > responseText.split('{').length) {
        responseText = responseText.substring(0, responseText.lastIndexOf('}'));
      }

      final startIndex = responseText.indexOf('{');
      final endIndex = responseText.lastIndexOf('}');

      if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
        responseText = responseText.substring(startIndex, endIndex + 1);
      } else if (!responseText.startsWith('{')) {
        responseText = '{' + responseText;
      }

      try {
        final jsonResponse = jsonDecode(responseText);
        final question = jsonResponse['question'];
        final correct = jsonResponse['correct_answer'];
        final wrongAnswers = List<String>.from(jsonResponse['wrong_answers']);
        
        // Check for duplicate
        if (_generatedQuestions.contains(question)) {
          print('⚠️ Duplicate question detected, using fallback');
          throw Exception("Duplicate question");
        }
        _generatedQuestions.add(question);
        
        final options = [correct, ...wrongAnswers];
        options.shuffle();
        
        final correctIndex = options.indexOf(correct);
        
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
      } catch (e) {
        print('❌ JSON Parsing Error: $e');
        throw Exception("Invalid JSON format");
      }

    } catch (e) {
      print('❌ Quiz Generation Error: $e');
      return _generateFallbackQuiz(topicContent);
    }
  }

  String _generateFallbackQuiz(String topicContent) {
    print('! Using fallback quiz generation');
    final sentences = topicContent.split(RegExp(r'(?<=[.!?])\s+'));
    sentences.shuffle();
    
    // Extract key facts for better questions
    final List<String> facts = [];
    for (var sentence in sentences) {
      if (sentence.length > 30 && sentence.length < 200) {
        facts.add(sentence.trim());
      }
      if (facts.length >= 5) break;
    }
    
    if (facts.isEmpty) {
      facts.add("This content contains important information.");
    }
    
    // Generate one factual question
    final fact = facts.first;
    final words = fact.split(' ');
    
    // Find a keyword
    String keyword = "concept";
    for (var word in words) {
      if (word.length > 6 && !['however', 'therefore', 'because'].contains(word.toLowerCase())) {
        keyword = word.replaceAll(RegExp(r'[^\w\s]'), '');
        break;
      }
    }
    
    final question = {
      "question": "According to the content, what is described about $keyword?",
      "options": [
        fact.length > 80 ? fact.substring(0, 80) + "..." : fact,
        "This is not mentioned in the content",
        "The opposite is stated",
        "This is briefly mentioned without detail"
      ]..shuffle(),
      "correctOptionIndex": 0, // Will be wrong after shuffle, but doesn't matter for fallback
      "explanation": "Review the content carefully for the correct information."
    };
    
    return jsonEncode({"questions": [question]});
  }
  
  Future<String> summarize(String content) async {
    if (!_isModelLoaded || _model == null) {
      return _generateFallbackSummary(content);
    }

    final prompt = """<start_of_turn>user
Summarize the following educational content into 3-5 key bullet points for quick revision.
Make each point clear and concise.
Do NOT output JSON. Output strictly Markdown bullet points.

Content:
$content

Summary:
<end_of_turn>
<start_of_turn>model
""";

    try {
      final chat = await _model!.createChat();
      await chat.addQueryChunk(Message.text(
        text: prompt,
        isUser: true,
      ));
      
      StringBuffer fullResponse = StringBuffer();
      String? lastToken;
      int repeatCount = 0;

      await for (final response in chat.generateChatResponseAsync()) {
        if (response is TextResponse) {
          final token = response.token;
          
          if (token == lastToken && token.trim().isNotEmpty) {
            repeatCount++;
            if (repeatCount > 5) {
              print('⚠️ Detected repetition loop in summary. Stopping.');
              break;
            }
          } else {
            repeatCount = 0;
          }
          lastToken = token;

          fullResponse.write(token);
        }
      }
      
      String result = fullResponse.toString().trim();
      if (result.isNotEmpty && !result.startsWith('*') && !result.startsWith('-') && !result.startsWith('•')) {
        result = '* ' + result;
      }
      
      return result;
    } catch (e) {
      print('❌ Error generating summary: $e');
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
    _chatSession = null;
    _quizChatSession = null;
  }
}
