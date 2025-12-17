import 'dart:async';
import 'package:llama_flutter_android/llama_flutter_android.dart';
import 'package:path_provider/path_provider.dart';
import 'precomputed_rag_service.dart';

/// AIService handles all AI model operations using llama_flutter_android
/// Supports chat, summarization, and quiz generation with streaming
class AIService {
  LlamaController? _controller;
  bool _isModelLoaded = false;
  String? _modelPath;

  bool get isModelLoaded => _isModelLoaded;

  /// Initialize the AI service by loading the Qwen GGUF model
  Future<void> initialize() async {
    try {
      print('🤖 Initializing AIService with llama_flutter_android...');

      // Get model path
      final directory = await getApplicationDocumentsDirectory();
      _modelPath = '${directory.path}/qwen2.5-1.5b-instruct-q4_k_m.gguf';

      print('📂 Model path: $_modelPath');

      // Initialize controller
      _controller = LlamaController();

      // Load the model with optimized settings
      await _controller!.loadModel(
        modelPath: _modelPath!,
        threads: 4, // Prevent CPU throttling
        contextSize: 8192, // Balanced context size for performance
      );

      _isModelLoaded = true;
      print('✅ AIService initialized successfully!');
    } catch (e) {
      _isModelLoaded = false;
      print('❌ Failed to initialize AIService: $e');
      rethrow;
    }
  }

  /// Reload the model to clear KV cache and prevent context accumulation
  /// This ensures consistent speed by starting with a clean slate
  Future<void> _reloadModel() async {
    if (_controller != null && _modelPath != null) {
      print('🔄 Reloading model to clear context...');
      try {
        // Dispose existing controller
        await _controller!.dispose();
        
        // Create fresh controller
        _controller = LlamaController();
        
        // Reload model with same optimized settings
        await _controller!.loadModel(
          modelPath: _modelPath!,
          threads: 4,
          contextSize: 8192,
        );
        
        print('✅ Model reloaded successfully');
      } catch (e) {
        print('❌ Error reloading model: $e');
        _isModelLoaded = false;
        rethrow;
      }
    }
  }

  /// Chat with the AI model using RAG context and streaming responses
  /// Returns a stream of tokens for real-time display
  Stream<String> chat(String userMessage, {String? subject, String? chapter}) async* {
    if (!_isModelLoaded || _controller == null) {
      yield '⚠️ AI model is not loaded. Please download the model first from the settings.';
      return;
    }

    final startTime = DateTime.now();
    int tokenCount = 0;
    String fullResponse = '';

    try {
      // Reload model to clear previous context and maintain consistent speed
      await _reloadModel();
      // Retrieve relevant context from RAG
      String context = '';
      try {
        final ragService = PrecomputedRagService.instance;
        context = await ragService.searchForContext(
          userMessage,
          subjects: subject != null ? [subject] : [],
        );
        print('📚 RAG context retrieved (${context.length} chars)');
      } catch (e) {
        print('⚠️ RAG query failed: $e');
        // Continue without context
      }

      // Build system prompt with context
      String systemPrompt = '''You are an expert Class 9 tutor. 
Be concise and clear. Give brief explanations with examples.
Keep answers under 100 words.

For math solutions - CRITICAL FORMATTING RULES:
- Each equation MUST be on its OWN separate line
- Use \$\$ equation \$\$ for display math (own line)
- Add blank line between steps
- Example:
  "Multiply by conjugate:
  
  \$\$\\frac{1}{7+3\\sqrt{3}} \\times \\frac{7-3\\sqrt{3}}{7-3\\sqrt{3}}\$\$
  
  Simplify denominator:
  
  \$\$\\frac{7-3\\sqrt{3}}{49-27}\$\$
  
  Final answer:
  
  \$\$\\frac{7-3\\sqrt{3}}{22}\$\$"

NEVER put multiple equations on the same line!''';


      if (context.isNotEmpty) {
        systemPrompt += '\n\nUse the following context from the textbook to answer questions:\n$context';
      }

      // Create chat messages in ChatML format
      final messages = [
        ChatMessage(role: 'system', content: systemPrompt),
        ChatMessage(role: 'user', content: userMessage),
      ];

      // Generate response with streaming
      await for (final token in _controller!.generateChat(
        messages: messages,
        template: 'chatml', // Qwen uses ChatML format
        temperature: 0.7, // Balanced creativity
        maxTokens: 256, // Shorter for faster response
        topP: 0.9,
        topK: 40,
        repeatPenalty: 1.1, // Reduce repetition
      )) {
        yield token;
        tokenCount++;
        fullResponse += token;
      }
      
      // Calculate metrics
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      final tokensPerSecond = tokenCount / duration.inSeconds;
      final qualityScore = _calculateQualityScore(fullResponse);
      final accuracyScore = _calculateAccuracyScore(fullResponse, context);
      
      // Log metrics
      print('📊 CHAT METRICS:');
      print('   ⏱️  Time: ${duration.inSeconds}s (${duration.inMilliseconds}ms)');
      print('   🔢 Tokens: $tokenCount');
      print('   ⚡ Speed: ${tokensPerSecond.toStringAsFixed(2)} tok/s');
      print('   ✨ Quality: ${qualityScore.toStringAsFixed(1)}%');
      print('   🎯 Accuracy: ${accuracyScore.toStringAsFixed(1)}%');
    } catch (e) {
      print('❌ Chat error: $e');
      yield '\n\n⚠️ Error generating response: $e';
    } finally {
      // Optional: Dispose after chat to ensure next query starts fresh
      // Uncomment if you want completely independent chat messages
      // await _reloadModel();
    }
  }

  /// Clear chat session (for llama_flutter_android, we don't need explicit session management)
  /// Each generateChat call is independent
  Future<void> clearChatSession() async {
    // No-op for llama_flutter_android - each generateChat is stateless
    print('🔄 Chat session cleared (stateless implementation)');
  }

  /// Summarize lesson content into concise bullet points
  Future<String> summarize(String lessonContent) async {
    if (!_isModelLoaded || _controller == null) {
      return '⚠️ AI model is not loaded. Please download the model first.';
    }

    final startTime = DateTime.now();
    int tokenCount = 0;

    try {
      // Reload model to clear previous context
      await _reloadModel();
      
      print('📝 Generating summary...');

      final messages = [
        ChatMessage(
          role: 'system',
          content: '''You are an expert content summarizer.
Create 3-5 brief bullet points. Each bullet max 20 words.
Be concise and clear.''',
        ),
        ChatMessage(
          role: 'user',
          content: 'Summarize this in 3-5 brief points:\n\n$lessonContent',
        ),
      ];

      String summary = '';
      await for (final token in _controller!.generateChat(
        messages: messages,
        template: 'chatml',
        temperature: 0.3, // Lower temp for more focused summaries
        maxTokens: 200, // Shorter summaries
        topP: 0.9,
        repeatPenalty: 1.2,
      )) {
        summary += token;
        tokenCount++;
      }

      // Calculate metrics
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      final tokensPerSecond = tokenCount / duration.inSeconds;
      final qualityScore = _calculateSummaryQuality(summary);
      
      // Log metrics
      print('📊 SUMMARY METRICS:');
      print('   ⏱️  Time: ${duration.inSeconds}s');
      print('   🔢 Tokens: $tokenCount');
      print('   ⚡ Speed: ${tokensPerSecond.toStringAsFixed(2)} tok/s');
      print('   ✨ Quality: ${qualityScore.toStringAsFixed(1)}%');

      print('✅ Summary generated (${summary.length} chars)');
      return summary;
    } catch (e) {
      print('❌ Summarization error: $e');
      return '⚠️ Error generating summary: $e';
    } finally {
      // Dispose after summary generation to free resources
      await _reloadModel();
    }
  }

  /// Generate a quiz in JSON format based on lesson content
  /// Returns JSON string with questions array
  Future<String> generateQuizJson(String lessonContent, {String? topicId}) async {
    if (!_isModelLoaded || _controller == null) {
      return '{"error": "AI model is not loaded"}';
    }

    final startTime = DateTime.now();
    int tokenCount = 0;

    try {
      // Reload model to clear previous context
      await _reloadModel();
      
      print('📝 Generating quiz for topic: $topicId');

      final messages = [
        ChatMessage(
          role: 'system',
          content: '''Generate 1 quiz question in STRICT JSON format.

EXAMPLE OUTPUT (copy this structure EXACTLY):
{
  "questions": [
    {
      "question": "What is the smallest unit of matter?",
      "options": ["Atom", "Molecule", "Electron", "Proton"],
      "correctOptionIndex": 0,
      "explanation": "Atoms are basic building blocks"
    }
  ]
}

CRITICAL RULES:
- ALWAYS provide EXACTLY 4 options
- correctOptionIndex must be 0, 1, 2, or 3 (the index of the correct option in the options array)
- Options must be short (1-5 words each)
- Explanation max 15 words
- Return ONLY valid JSON, no markdown
- Double-check that correctOptionIndex points to the correct option!''',
        ),
        ChatMessage(
          role: 'user',
          content: 'Generate a quiz based on this content:\n\n$lessonContent',
        ),
      ];

      String quizJson = '';
      await for (final token in _controller!.generateChat(
        messages: messages,
        template: 'chatml',
        temperature: 0.5, // Lower temp for consistent format
        maxTokens: 200, // Reduced for faster generation
        topP: 0.9,
        repeatPenalty: 1.3, // Encourage question variety
      )) {
        quizJson += token;
        tokenCount++;
      }

      // Clean up the response to extract JSON
      quizJson = quizJson.trim();
      
      // Try to find JSON block in markdown code fence if present
      if (quizJson.contains('```json')) {
        final start = quizJson.indexOf('```json') + 7;
        final end = quizJson.indexOf('```', start);
        if (end != -1) {
          quizJson = quizJson.substring(start, end).trim();
        }
      } else if (quizJson.contains('```')) {
        final start = quizJson.indexOf('```') + 3;
        final end = quizJson.indexOf('```', start);
        if (end != -1) {
          quizJson = quizJson.substring(start, end).trim();
        }
      }

      // Calculate metrics
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      final tokensPerSecond = tokenCount / duration.inSeconds;
      final qualityScore = _calculateQuizQuality(quizJson);
      
      // Log metrics
      print('📊 QUIZ METRICS:');
      print('   ⏱️  Time: ${duration.inSeconds}s');
      print('   🔢 Tokens: $tokenCount');
      print('   ⚡ Speed: ${tokensPerSecond.toStringAsFixed(2)} tok/s');
      print('   ✨ Quality: ${qualityScore.toStringAsFixed(1)}%');

      print('✅ Quiz generated (${quizJson.length} chars)');
      return quizJson;
    } catch (e) {
      print('❌ Quiz generation error: $e');
      return '{"error": "Failed to generate quiz: $e"}';
    } finally {
      // Dispose after quiz generation to free resources
      await _reloadModel();
    }
  }

  /// Dispose of resources
  Future<void> dispose() async {
    if (_controller != null) {
      await _controller!.dispose();
      _controller = null;
      _isModelLoaded = false;
      print('🔄 AIService disposed');
    }
  }

  /// Calculate quality score based on response characteristics
  double _calculateQualityScore(String response) {
    double score = 50.0; // Base score
    
    // Length check (50-500 chars ideal for brief responses)
    if (response.length >= 50 && response.length <= 500) score += 20;
    else if (response.length > 500) score += 10;
    
    // Has proper sentences (ends with punctuation)
    if (response.contains('.') || response.contains('!') || response.contains('?')) score += 15;
    
    // Not too repetitive (simple check)
    final words = response.toLowerCase().split(' ');
    final uniqueWords = words.toSet();
    if (uniqueWords.length / words.length > 0.5) score += 15;
    
    return score.clamp(0, 100);
  }

  /// Calculate accuracy score based on RAG context usage
  double _calculateAccuracyScore(String response, String ragContext) {
    if (ragContext.isEmpty) return 75.0; // No context to compare
    
    double score = 50.0;
    
    // Extract key terms from RAG context
    final contextWords = ragContext.toLowerCase().split(RegExp(r'\s+'));
    final contextKeywords = contextWords.where((w) => w.length > 4).toSet();
    
    // Check how many context keywords appear in response
    final responseLower = response.toLowerCase();
    int matchCount = 0;
    for (var keyword in contextKeywords.take(20)) {
      if (responseLower.contains(keyword)) matchCount++;
    }
    
    if (contextKeywords.isNotEmpty) {
      score += (matchCount / contextKeywords.take(20).length) * 50;
    }
    
    return score.clamp(0, 100);
  }

  /// Calculate summary quality (bullet points, brevity)
  double _calculateSummaryQuality(String summary) {
    double score = 40.0;
    
    // Has bullet points or numbered list
    if (summary.contains('-') || summary.contains('•') || RegExp(r'\d+\.').hasMatch(summary)) {
      score += 30;
    }
    
    // Reasonable length (100-400 chars)
    if (summary.length >= 100 && summary.length <= 400) score += 20;
    
    // Multiple points (split by newlines)
    final lines = summary.split('\n').where((l) => l.trim().isNotEmpty).length;
    if (lines >= 3 && lines <= 7) score += 10;
    
    return score.clamp(0, 100);
  }

  /// Calculate quiz quality (valid JSON, 4 options)
  double _calculateQuizQuality(String quizJson) {
    double score = 30.0;
    
    try {
      // Valid JSON structure
      if (quizJson.contains('{') && quizJson.contains('}')) score += 20;
      if (quizJson.contains('"questions"')) score += 20;
      if (quizJson.contains('"options"')) score += 15;
      
      // Has 4 options (rough check)
      final optionMatches = RegExp(r'"[^"]+"').allMatches(quizJson).length;
      if (optionMatches >= 6) score += 15; // question + 4 options + answer
      
    } catch (e) {
      score = 20.0; // Failed parsing
    }
    
    return score.clamp(0, 100);
  }
}
