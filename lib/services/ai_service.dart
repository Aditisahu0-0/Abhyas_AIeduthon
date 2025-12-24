import 'dart:async';
import 'dart:convert';
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

  /// Fix UTF-8 encoding issues from JNI bridge
  /// The llama_flutter_android package may return tokens with corrupted encoding
  /// This attempts to repair Devanagari (Hindi) characters
  String _fixUTF8(String token) {
    try {
      // Try to detect if the string is already corrupted (contains replacement chars)
      if (token.contains('\uFFFD') || token.contains('�')) {
        // Attempt to re-encode: treat as latin1, then decode as utf8
        final bytes = latin1.encode(token);
        return utf8.decode(bytes, allowMalformed: true);
      }
      return token;
    } catch (e) {
      // If fix fails, return original
      print('⚠️ UTF-8 fix failed for token, returning original');
      return token;
    }
  }

  /// Initialize the AI service by loading the Qwen GGUF model
  Future<void> initialize() async {
    if (_isModelLoaded) {
      print('⚠️ AIService already initialized (internal check)');
      return;
    }

    try {
      print('🤖 Initializing AIService with llama_flutter_android...');

      // Get model path
      final directory = await getApplicationDocumentsDirectory();
      _modelPath = '${directory.path}/qwen-1.5B-q4_k_m_finetuned.gguf';

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
      if (e.toString().contains('Model already loaded')) {
        print(
          '⚠️ Model was already loaded in native layer. Treating as success.',
        );
        _isModelLoaded = true;
      } else {
        _isModelLoaded = false;
        print('❌ Failed to initialize AIService: $e');
        rethrow;
      }
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

  // Mutex lock to prevent concurrent generation
  bool _isGenerating = false;

  /// Chat with the AI model using RAG context and streaming responses
  /// Returns a stream of tokens for real-time display
  Stream<String> chat(
    String userMessage, {
    String? subject,
    String? chapter,
  }) async* {
    if (!_isModelLoaded || _controller == null) {
      yield '⚠️ AI model is not loaded. Please download the model first from the settings.';
      return;
    }

    if (_isGenerating) {
      yield '⚠️ AI is already generating a response. Please wait.';
      return;
    }

    _isGenerating = true;

    final startTime = DateTime.now();
    int tokenCount = 0;
    String fullResponse = '';

    try {
      // Reload model to clear previous context and maintain consistent speed
      // await _reloadModel(); // Disabled for speed optimization
      // Retrieve relevant context from RAG
      String context = '';
      try {
        final ragService = PrecomputedRagService.instance;
        context = await ragService.searchForContext(
          userMessage,
          subjects: subject != null ? [subject] : [],
        );

        // Log the retrieved context for debugging
        if (context.isNotEmpty) {
          print('\n' + '=' * 60);
          print('📚 RETRIEVED RAG CONTEXT:');
          print('=' * 60);
          print(context);
          print('=' * 60 + '\n');
        } else {
          print('⚠️ No RAG context found for query');
        }
      } catch (e) {
        print('⚠️ RAG query failed: $e');
        // Continue without context
      }

      // Build system prompt with context
      String systemPrompt = '''You are an expert Class 9 tutor.

RESPONSE FORMAT (CRITICAL - MUST FOLLOW):
✅ ALWAYS use bullet points (- or 1. 2. 3.)
✅ Match length to question complexity:
  • Simple (what/define) → 2-3 points, 1-2 sentences each
  • Medium (explain/how) → 3-5 points, 2-3 sentences each  
  • Complex (analyze/compare) → 5-7 points, 2-4 sentences each
✅ Use **bold** for important keywords, concepts, and headings
✅ Be direct and concise - avoid unnecessary words
✅ Each point should be complete and self-contained

Example format:
- **Photosynthesis** is the process by which **green plants** make food.
- It occurs in **chloroplasts** containing **chlorophyll** (green pigment).
- The equation: CO₂ + H₂O + Sunlight → **Glucose** + O₂

IMPORTANT: Reply in English.
''';

      systemPrompt += '''\n\nFor math solutions - CRITICAL FORMATTING RULES:
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
        systemPrompt +=
            '\n\nUse the following context from the textbook to answer questions:\n$context';
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
        maxTokens: 300, // Shorter for faster response
        topP: 0.9,
        topK: 40,
        repeatPenalty: 1.1, // Reduce repetition
      )) {
        final fixedToken = _fixUTF8(token);
        yield fixedToken;
        tokenCount++;
        fullResponse += fixedToken;
      }

      // Calculate metrics
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      final tokensPerSecond = tokenCount / duration.inSeconds;
      final qualityScore = _calculateQualityScore(fullResponse);
      final accuracyScore = _calculateAccuracyScore(fullResponse, context);

      // Log metrics
      print('📊 CHAT METRICS:');
      print(
        '   ⏱️  Time: ${duration.inSeconds}s (${duration.inMilliseconds}ms)',
      );
      print('   🔢 Tokens: $tokenCount');
      print('   ⚡ Speed: ${tokensPerSecond.toStringAsFixed(2)} tok/s');
      print('   ✨ Quality: ${qualityScore.toStringAsFixed(1)}%');
      print('   🎯 Accuracy: ${accuracyScore.toStringAsFixed(1)}%');

      // Calculate RAG metrics (retrieval & faithfulness scores)
      // Commented out to reduce log noise
      // AccuracyService.instance.calculateAndLogScores(
      //   userMessage,
      //   context,
      //   fullResponse,
      // );
    } catch (e) {
      print('❌ Chat error: $e');
      yield '\n\n⚠️ Error generating response: $e';
    } finally {
      // Release mutex lock
      _isGenerating = false;

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
  /// Returns a stream of tokens for real-time display
  Stream<String> summarize(String lessonContent) async* {
    if (!_isModelLoaded || _controller == null) {
      yield '⚠️ AI model is not loaded. Please download the model first.';
      return;
    }

    final startTime = DateTime.now();
    int tokenCount = 0;

    try {
      // Reload model to clear previous context
      // await _reloadModel(); // Disabled for speed optimization

      print('📝 Generating summary...');

      String systemPrompt = '''You are an expert content summarizer.
Create 3-5 brief bullet points. Each bullet max 20 words.
Be concise and clear.''';

      String userPrompt =
          'Summarize this in 3-5 brief points:\n\n$lessonContent';

      final messages = [
        ChatMessage(role: 'system', content: systemPrompt),
        ChatMessage(role: 'user', content: userPrompt),
      ];

      String summary = '';
      await for (final token in _controller!.generateChat(
        messages: messages,
        template: 'chatml',
        temperature: 0.3,
        maxTokens: 200,
        topP: 0.9,
        repeatPenalty: 1.2,
      )) {
        final fixedToken = _fixUTF8(token);
        summary += fixedToken;
        tokenCount++;
        yield fixedToken;
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

      // Reload model after streaming completes
      await _reloadModel();
    } catch (e) {
      print('❌ Summarization error: $e');
      yield '\n\n⚠️ Error generating summary: $e';
      await _reloadModel();
    }
  }

  /// Summarize entire chapter content into comprehensive bullet points
  /// Returns a stream of tokens for real-time display
  Stream<String> summarizeChapter(String chapterContent) async* {
    if (!_isModelLoaded || _controller == null) {
      yield '⚠️ AI model is not loaded. Please download the model first.';
      return;
    }

    final startTime = DateTime.now();
    int tokenCount = 0;

    try {
      print('📝 Generating chapter summary...');

      String systemPrompt = '''You are an expert content summarizer.
Create 8-12 comprehensive bullet points covering all important topics.
Each bullet max 25 words.
Focus on key concepts, definitions, and facts.''';

      String chapterUserPrompt =
          'Summarize all important points from this chapter:\n\n$chapterContent';

      final messages = [
        ChatMessage(role: 'system', content: systemPrompt),
        ChatMessage(role: 'user', content: chapterUserPrompt),
      ];

      String summary = '';
      await for (final token in _controller!.generateChat(
        messages: messages,
        template: 'chatml',
        temperature: 0.3,
        maxTokens: 450, // Higher limit for chapter summaries
        topP: 0.9,
        repeatPenalty: 1.2,
      )) {
        final fixedToken = _fixUTF8(token);
        summary += fixedToken;
        tokenCount++;
        yield fixedToken;
      }

      // Calculate metrics
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      final tokensPerSecond = tokenCount / duration.inSeconds;
      final qualityScore = _calculateSummaryQuality(summary);

      // Log metrics
      print('📊 CHAPTER SUMMARY METRICS:');
      print('   ⏱️  Time: ${duration.inSeconds}s');
      print('   🔢 Tokens: $tokenCount');
      print('   ⚡ Speed: ${tokensPerSecond.toStringAsFixed(2)} tok/s');
      print('   ✨ Quality: ${qualityScore.toStringAsFixed(1)}%');

      print('✅ Chapter summary generated (${summary.length} chars)');

      // Reload model after streaming completes
      await _reloadModel();
    } catch (e) {
      print('❌ Chapter summarization error: $e');
      yield '\n\n⚠️ Error generating summary: $e';
      await _reloadModel();
    }
  }

  /// Generate a quiz in JSON format based on lesson content
  /// Returns JSON string with questions array
  Future<String> generateQuizJson(
    String lessonContent, {
    String? topicId,
  }) async {
    if (!_isModelLoaded || _controller == null) {
      return '{"error": "AI model is not loaded"}';
    }

    final startTime = DateTime.now();
    int tokenCount = 0;

    try {
      // Reload model to clear previous context
      // Reload model to clear previous context (Flush Cache per user request)
      await _reloadModel();

      print('📝 Generating quiz for topic: $topicId');

      // SANITIZATION: Remove specific numbers to prevent questions like "What is Theorem 10.1?"
      lessonContent = _sanitizeContent(lessonContent);

      // SALT: Add random variety instructions to force different questions for the same text
      final List<String> salts = [
        "Focus on the DEFINITIONS in the text.",
        "Create a SCENARIO-based question based on the concepts.",
        "Focus on the PROPERTIES or CHARACTERISTICS mentioned.",
        "Ask about the RELATIONSHIP between concepts.",
        "Focus on the latter half of the text.",
        "Ask a conceptual question about the 'WHY' or 'HOW'.",
      ];
      final String salt =
          salts[DateTime.now().millisecondsSinceEpoch % salts.length];
      print('🧂 Adding variety salt: "$salt"');

      String systemPrompt =
          '''You are a strict teacher creating a Multiple Choice Quiz.
Your goal is to test if the student truly understands the topic.

VARIETY INSTRUCTION: $salt

CRITICAL RULES FOR OPTIONS:
1. **ONE Correct Answer**: One option must be the **CORRECT ANSWER** (Factually True and from Context).
2. **THREE Distractors**: The other 3 options must be **WRONG**.
   - **MUST be Factually INCORRECT**.
   - **MUST NOT be from the provided content**.
   - They should be related to the topic but CLEARLY WRONG.
   - Example: If Context says "Earth is Blue", Distractor should be "Earth is Red" (Not "Earth is round" which is also true).
   - **Ensure there is ONLY ONE correct answer**.

CRITICAL RULES FOR FORMATTING:
1. **NO Option Labels**: Do NOT include "A.", "B.", "Option 1", etc. in the option text. Just the text.
2. **Independent Options**: Each option must be a COMPLETE sentence.
   - BAD: "It is..." (Dependent on question)
   - GOOD: "It is a planet." (Independent)
   - NEVER split a sentence across options!

CRITICAL RULES FOR QUESTIONS:
1. **NO Hardcoded Examples**: NEVER, EVER use the "Equal Chords" question or "Solar System" question from this prompt. Create a NEW question based *only* on the provided content.
2. **No Meta-References**: Do NOT ask "What is Theorem 10.1?". Ask "What is the theorem about chords?".
3. **FORBIDDEN WORDS**: The Question Text must NOT contain the words "Figure", "Fig", "Table", or "Theorem Number".

BAD EXAMPLE (DO NOT DO THIS):
Question: "The concept is..."
A. ...Option A.
B. ...Option B.
(Dependent options, labels included)

GOOD EXAMPLE (DO THIS):
Question: "Which concept explains the phenomenon?"
- This is a complete sentence explaining concept A. (Correct)
- This is a complete sentence explaining concept B. (Distractor)
- This is a complete sentence explaining concept C. (Distractor)
- This is a complete sentence explaining concept D. (Distractor)
(Independent sentences, no labels, clear distinction)

CRITICAL RULES FOR MATH & PHYSICS (LATEX):
1. Use LaTeX for all math formulas, wrapped in '\$'.
2. You MUST use double backslashes for LaTeX commands.

REQUIRED JSON FORMAT:
{
  "questions": [
    {
      "question": "Question text here?",
      "options": [
        "Correct Answer Value",
        "Distractor 1 Value",
        "Distractor 2 Value",
        "Distractor 3 Value"
      ],
      "correctOptionIndex": 0,
      "correctAnswer": "Correct Answer Value",
      "explanation": "Brief explanation."
    }
  ]
}''';

      String userInstruction =
          'Generate 1 multiple-choice question based on this content. Ensure the JSON is valid.';
      systemPrompt += '\nReply in English.';

      final messages = [
        ChatMessage(role: 'system', content: systemPrompt),
        ChatMessage(
          role: 'user',
          content: '$userInstruction\n\nContent:\n$lessonContent',
        ),
      ];

      String quizJson = '';
      await for (final token in _controller!.generateChat(
        messages: messages,
        template: 'chatml',
        temperature: 0.1, // Strict for JSON
        maxTokens: 512, // Allow enough space for JSON
        topP: 0.9, // Focused output
        repeatPenalty:
            1.1, // Lower penalty to allow repeated JSON charts like "
      )) {
        quizJson += token;
        tokenCount++;
      }

      // Clean up the response to extract JSON
      quizJson = quizJson.trim();

      print(
        '🔍 Raw AI response (first 100 chars): ${quizJson.substring(0, quizJson.length > 100 ? 100 : quizJson.length)}',
      );

      // STRATEGY: Find JSON object by looking for { and matching }
      // This is more reliable than parsing markdown code blocks
      // STRATEGY: Find JSON object by looking for { and matching }
      print('TRACE: Parsing markdown fallback');
      final jsonStart = quizJson.indexOf('{');

      if (jsonStart == -1) {
        // No JSON found - try to parse as markdown and construct JSON
        print(
          '⚠️ No JSON object found, attempting to parse markdown format...',
        );
        print('Full response: $quizJson');

        try {
          // Try to extract question and options from markdown format
          final Map<String, dynamic> parsedQuiz = _parseMarkdownQuiz(quizJson);
          if (parsedQuiz.containsKey('questions') &&
              parsedQuiz['questions'].isNotEmpty) {
            print('✅ Successfully parsed markdown into JSON');
            return jsonEncode(parsedQuiz);
          }
        } catch (e) {
          print('❌ Failed to parse markdown: $e');
        }

        return '{"questions": [], "error": "AI returned non-JSON response and parsing failed"}';
      }

      // Find the matching closing brace
      int braceCount = 0;
      int jsonEnd = -1;
      for (int i = jsonStart; i < quizJson.length; i++) {
        if (quizJson[i] == '{') braceCount++;
        if (quizJson[i] == '}') {
          braceCount--;
          if (braceCount == 0) {
            jsonEnd = i + 1;
            break;
          }
        }
      }

      if (jsonEnd == -1) {
        print('❌ Could not find matching closing brace');
        print(
          '⚠️ JSON was likely cut off by token limit. Consider increasing maxTokens.',
        );
        return '{"questions": [], "error": "Incomplete JSON - token limit reached"}';
      }

      print('TRACE: Found JSON start at $jsonStart, end at $jsonEnd');

      // Extract the JSON object
      quizJson = quizJson.substring(jsonStart, jsonEnd).trim();

      print('TRACE: Starting aggressive repair');
      // --- AGGRESSIVE JSON REPAIR ---

      StringBuffer cleanJson = StringBuffer();
      cleanJson.write('{'); // Start object

      print('TRACE: Checking "questions" key');
      if (quizJson.contains('"questions"')) {
        cleanJson.write('"questions": [');

        int startArr = quizJson.indexOf('[');
        int endArr = quizJson.lastIndexOf(']');

        print('TRACE: Found array bounds $startArr - $endArr');

        if (startArr != -1 && endArr != -1) {
          String arrayContent = quizJson.substring(startArr + 1, endArr);
          // Split by "}," to find individual objects (rough split)
          print('TRACE: Splitting objects');
          List<String> objects = arrayContent.split(RegExp(r'},\s*\{'));

          for (int i = 0; i < objects.length; i++) {
            print('TRACE: Processing object $i');
            String obj = objects[i];
            cleanJson.write('{');

            // Extract Question
            print('TRACE: Extracting question');
            String qText = _extractValue(obj, 'question');
            cleanJson.write('"question": "${_escapeJsonString(qText)}",');

            // Extract Options
            print('TRACE: Extracting options');
            cleanJson.write('"options": [');
            List<String> opts = _extractArrayRaw(
              obj,
            ); // helper to get ["A", "B"]
            print('TRACE: Options extracted: ${opts.length}');
            for (int j = 0; j < opts.length; j++) {
              cleanJson.write('"${_escapeJsonString(opts[j])}"');
              if (j < opts.length - 1) cleanJson.write(',');
            }
            cleanJson.write('],');

            // Extract Correct Index
            String idx = _extractValue(
              obj,
              'correctOptionIndex',
            ).replaceAll(RegExp(r'[^0-9]'), '');
            if (idx.isEmpty) idx = '0';
            cleanJson.write('"correctOptionIndex": $idx,');

            // Extract Correct Answer
            String ans = _extractValue(obj, 'correctAnswer');
            cleanJson.write('"correctAnswer": "${_escapeJsonString(ans)}",');

            // Extract Explanation
            String exp = _extractValue(obj, 'explanation');
            cleanJson.write('"explanation": "${_escapeJsonString(exp)}"');

            cleanJson.write('}');
            if (i < objects.length - 1) cleanJson.write(',');
          }
        }
        cleanJson.write(']');
      }

      cleanJson.write('}');

      String finalJson = cleanJson.toString();
      print('🛠️ Repaired JSON: $finalJson');

      // Log metrics and return
      print('✅ Extracted JSON (${finalJson.length} chars)');

      // Calculate metrics (using finalJson, not raw tokenCount since we repaired it)
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      final tokensPerSecond = tokenCount / duration.inSeconds;
      final qualityScore = _calculateQuizQuality(finalJson);

      print('📊 QUIZ METRICS:');
      print('   ⏱️  Time: ${duration.inSeconds}s');
      print('   🔢 Tokens: $tokenCount');
      print('   ⚡ Speed: ${tokensPerSecond.toStringAsFixed(2)} tok/s');
      print('   ✨ Quality: ${qualityScore.toStringAsFixed(1)}%');

      return finalJson;
    } catch (e) {
      print('❌ Quiz generation error: $e');
      return '{"questions": [], "error": "Failed to generate quiz: $e"}';
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
    if (response.length >= 50 && response.length <= 500)
      score += 20;
    else if (response.length > 500)
      score += 10;

    // Has proper sentences (ends with punctuation)
    if (response.contains('.') ||
        response.contains('!') ||
        response.contains('?'))
      score += 15;

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
    if (summary.contains('-') ||
        summary.contains('•') ||
        RegExp(r'\d+\.').hasMatch(summary)) {
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

  /// Generate a mindmap in JSON format for graph rendering
  Future<String> generateMindMap(String lessonContent) async {
    if (!_isModelLoaded || _controller == null) {
      return '{"error": "AI model is not loaded"}';
    }

    final startTime = DateTime.now();
    int tokenCount = 0;

    try {
      // Reload model to clear previous context
      // await _reloadModel(); // Disabled for speed optimization

      print('🧠 Generating mindmap JSON...');

      String systemPrompt = '''You are an expert educational content creator.
Create a hierarchical mindmap in STRICT JSON format.
Structure:
{
  "id": "root",
  "label": "Main Topic",
  "children": [
    {
      "id": "unique_id_1",
      "label": "Subtopic",
      "children": []
    }
  ]
}

CRITICAL RULES:
- Return ONLY valid JSON.
- IDs must be unique strings.
- Keep labels concise (1-5 words).
- limit depth to 3 levels.
- Do not include markdown code fences (like ```json), just the raw JSON.''';

      String userPrompt =
          'Create a mindmap for this content:\n\n$lessonContent';

      final messages = [
        ChatMessage(role: 'system', content: systemPrompt),
        ChatMessage(role: 'user', content: userPrompt),
      ];

      String mindmapJson = '';
      await for (final token in _controller!.generateChat(
        messages: messages,
        template: 'chatml',
        temperature: 0.3, // Lower temp for valid JSON
        maxTokens: 1000, // More tokens for JSON structure
        topP: 0.9,
        repeatPenalty: 1.1,
      )) {
        mindmapJson += token;
        tokenCount++;
      }

      // Clean up response
      mindmapJson = mindmapJson.trim();
      if (mindmapJson.contains('```json')) {
        final start = mindmapJson.indexOf('```json') + 7;
        final end = mindmapJson.indexOf('```', start);
        if (end != -1) {
          mindmapJson = mindmapJson.substring(start, end).trim();
        }
      } else if (mindmapJson.contains('```')) {
        final start = mindmapJson.indexOf('```') + 3;
        final end = mindmapJson.indexOf('```', start);
        if (end != -1) {
          mindmapJson = mindmapJson.substring(start, end).trim();
        }
      }

      // Calculate metrics
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      final tokensPerSecond = tokenCount / duration.inSeconds;

      // Log metrics
      print('📊 MINDMAP METRICS:');
      print('   ⏱️  Time: ${duration.inSeconds}s');
      print('   🔢 Tokens: $tokenCount');
      print('   ⚡ Speed: ${tokensPerSecond.toStringAsFixed(2)} tok/s');

      print('✅ Mindmap generated (${mindmapJson.length} chars)');
      return mindmapJson;
    } catch (e) {
      print('❌ Mindmap generation error: $e');
      return '{"error": "Failed to generate mindmap: $e"}';
    } finally {
      // Dispose after generation to free resources
      await _reloadModel();
    }
  }

  /// Parse markdown-formatted quiz into JSON structure
  /// Fallback when AI doesn't return JSON despite instructions
  Map<String, dynamic> _parseMarkdownQuiz(String markdown) {
    // Try to extract question and options from markdown format
    // Example format:
    // **Question:**
    // What are the characteristics...?
    // - Option 1
    // - Option 2
    // ...

    String? question;
    List<String> options = [];
    String? explanation;

    final lines = markdown
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Extract question (after "Question:" or similar)
      if (line.toLowerCase().contains('question') && line.contains(':')) {
        // Check next line for actual question
        if (i + 1 < lines.length && !lines[i + 1].startsWith('-')) {
          question = lines[i + 1];
        }
      }

      // Extract options (bullet points)
      if (line.startsWith('-') ||
          line.startsWith('•') ||
          RegExp(r'^\d+\.').hasMatch(line)) {
        // Remove bullet/number prefix
        String option = line.replaceFirst(RegExp(r'^[-•\d.]\s*'), '').trim();
        if (option.isNotEmpty && options.length < 4) {
          options.add(option);
        }
      }

      // Extract explanation (after "Explanation:" or similar)
      if (line.toLowerCase().contains('explanation') && line.contains(':')) {
        if (i + 1 < lines.length) {
          explanation = lines[i + 1];
        }
      }
    }

    // If we found a question and at least 2 options, construct JSON
    if (question != null && options.length >= 2) {
      // Pad options to 4 if needed
      while (options.length < 4) {
        options.add('N/A');
      }

      return {
        'questions': [
          {
            'question': question.length > 100
                ? question.substring(0, 100)
                : question,
            'options': options.take(4).toList(),
            'correctOptionIndex': 0, // Default to first option
            'explanation': explanation ?? 'Check your textbook for details',
          },
        ],
      };
    }

    // Parsing failed
    return {'questions': []};
  }
  // --- JSON REPAIR HELPERS ---

  String _extractValue(String jsonSnippet, String key) {
    // Looks for "key": "value" OR "key": value
    // Handles unquoted keys: key: "value"
    final escapedKey = RegExp.escape(key);

    // Pattern 1: Standard "key": "value" (captures value inside quotes)
    final pattern1 = RegExp('"$escapedKey"\\s*:\\s*"([^"]*)"');
    var match = pattern1.firstMatch(jsonSnippet);
    if (match != null) return match.group(1) ?? '';

    // Pattern 2: Unquoted value (digits/bools) "key": 123
    final pattern2 = RegExp('"$escapedKey"\\s*:\\s*([0-9.]+)');
    match = pattern2.firstMatch(jsonSnippet);
    if (match != null) return match.group(1) ?? '';

    // Pattern 3: Loose key (no quotes around key) key: "value"
    final pattern3 = RegExp('$escapedKey\\s*:\\s*"([^"]*)"');
    match = pattern3.firstMatch(jsonSnippet);
    if (match != null) return match.group(1) ?? '';

    // Pattern 4: Fallback for messy strings: "key": Some text here, (ends with , or })
    final pattern4 = RegExp('"$escapedKey"\\s*:\\s*([^,}]*)');
    match = pattern4.firstMatch(jsonSnippet);
    if (match != null) return match.group(1)?.trim().replaceAll('"', '') ?? '';

    return '';
  }

  List<String> _extractArrayRaw(String jsonSnippet) {
    // naive extraction of array items
    // looks for "options": [ ... ]
    int start = jsonSnippet.indexOf('[');
    int end = jsonSnippet.indexOf(']', start);
    if (start == -1 || end == -1) return [];

    String content = jsonSnippet.substring(start + 1, end);
    // Split by comma, but handle quotes
    List<String> items = [];

    // Simple split by comma is dangerous if commas are inside quotes
    // But for this distilled model, it usually outputs simple options
    List<String> rawItems = content.split(',');
    for (var item in rawItems) {
      String clean = item.trim();
      // Remove surrounding quotes if present (using strict regex to handle broken quotes)
      clean = clean.replaceAll(RegExp(r'^"|"$'), '').trim();
      clean = clean.replaceAll(RegExp(r"^'|'$"), '').trim();

      if (clean.isNotEmpty) items.add(clean);
    }
    return items;
  }

  String _escapeJsonString(String input) {
    return input
        .replaceAll(r'\', r'\\') // Backslash
        .replaceAll('"', r'\"') // Quote
        .replaceAll('\n', r'\n') // Newline
        .replaceAll('\r', '') // Carriage return
        .replaceAll('\t', r'\t'); // Tab
  }

  String _sanitizeContent(String content) {
    // BLIND the model to specific numbers so it can't ask "What is Theorem 10.1?"
    String clean = content;

    // REMOVE parenthetical figure references entirely: "(see Fig. 10.1)" -> ""
    clean = clean.replaceAll(
      RegExp(r'\s*\(see\s+Fig(ure)?\.?\s*\d+(\.\d+)?\)', caseSensitive: false),
      '',
    );
    clean = clean.replaceAll(
      RegExp(r'\s*\(Fig(ure)?\.?\s*\d+(\.\d+)?\)', caseSensitive: false),
      '',
    );

    // Remove "Figure 10.1" -> "The diagram" (Generic)
    clean = clean.replaceAll(
      RegExp(r'Figure\s+\d+(\.\d+)?', caseSensitive: false),
      'the diagram',
    );
    clean = clean.replaceAll(
      RegExp(r'Fig\.\s*\d+(\.\d+)?', caseSensitive: false),
      'the diagram',
    );

    // Remove "Theorem 10.1" -> "The theorem" (Keep content, hide number)
    clean = clean.replaceAll(
      RegExp(r'Theorem\s+\d+(\.\d+)?', caseSensitive: false),
      'The theorem',
    );

    // Remove "Table 10.1" -> "The table"
    clean = clean.replaceAll(
      RegExp(r'Table\s+\d+(\.\d+)?', caseSensitive: false),
      'The table',
    );

    // Remove "Activity 10.1" -> "The activity"
    clean = clean.replaceAll(
      RegExp(r'Activity\s+\d+(\.\d+)?', caseSensitive: false),
      'The activity',
    );

    return clean;
  }
}
