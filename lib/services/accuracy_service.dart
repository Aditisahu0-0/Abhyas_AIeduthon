import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'tokenizer.dart';

class AccuracyService {
  static final AccuracyService instance = AccuracyService._();
  AccuracyService._();

  Interpreter? _interpreter;
  WordPieceTokenizer? _tokenizer;
  bool _isInitialized = false;
  int _inputCount = 3;

  bool get isInitialized => _isInitialized;

  /// Initialize the accuracy service (independent model loading)
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print('=== ACCURACY SERVICE INITIALIZATION START ===');
      await _loadVocab();
      await _loadModel();
      _isInitialized = true;
      print('✅ Accuracy Service initialized successfully');
    } catch (e) {
      print('❌ Error initializing Accuracy Service: $e');
    }
  }

  Future<void> _loadVocab() async {
    try {
      final vocabString = await rootBundle.loadString('assets/vocab.txt');
      final lines = vocabString.split('\n');
      final Map<String, int> vocabMap = {};
      for (int i = 0; i < lines.length; i++) {
        final word = lines[i].trim();
        if (word.isNotEmpty) vocabMap[word] = i;
      }
      _tokenizer = WordPieceTokenizer(vocab: vocabMap);
    } catch (e) {
      print('❌ AccuracyService: Error loading vocab: $e');
    }
  }

  Future<void> _loadModel() async {
    try {
      // Load independently to avoid conflicts
      final directory = await getApplicationDocumentsDirectory();
      final modelFile = File(p.join(directory.path, "mobile_embedding.tflite"));
      
      if (await modelFile.exists()) {
        _interpreter = await Interpreter.fromFile(modelFile);
      } else {
         _interpreter = await Interpreter.fromAsset('assets/mobile_embedding.tflite');
      }
      
      _inputCount = _interpreter!.getInputTensors().length;
    } catch (e) {
      print('❌ AccuracyService: Error loading model: $e');
    }
  }

  /// Fire-and-forget method to calculate and log scores
  Future<void> calculateAndLogScores(String query, String context, String response) async {
    if (!_isInitialized) await initialize();
    if (_interpreter == null || _tokenizer == null) return;

    // Run in background to not block UI
    Future.microtask(() async {
      try {
        final queryEmb = await _generateEmbedding(query);
        final contextEmb = await _generateEmbedding(context);
        final responseEmb = await _generateEmbedding(response);

        if (queryEmb == null || contextEmb == null || responseEmb == null) {
          print('⚠️ Could not generate embeddings for scoring');
          return;
        }

        // 1. Retrieval Score (Query vs Context)
        // How relevant is the retrieved context to the user's question?
        final retrievalScore = _cosineSimilarity(queryEmb, contextEmb);

        // 2. Faithfulness Score (Context vs Response)
        // How much of the response is grounded in the provided context?
        final faithfulnessScore = _cosineSimilarity(contextEmb, responseEmb);

        _logMetrics(retrievalScore, faithfulnessScore);

      } catch (e) {
        print('❌ Error calculating accuracy scores: $e');
      }
    });
  }

  Future<List<double>?> _generateEmbedding(String text) async {
    if (_interpreter == null || _tokenizer == null) return null;
    
    // Truncate text if too long to prevent errors, keep first 256 tokens approx
    if (text.length > 1000) text = text.substring(0, 1000);

    try {
      final inputIds = _tokenizer!.tokenize(text);
      if (inputIds.isEmpty) return null;

      // Pad or truncate to 256
      var paddedIds = List<int>.filled(256, 0);
      for (int i = 0; i < min(inputIds.length, 256); i++) {
        paddedIds[i] = inputIds[i];
      }

      final inputIdsTensor = Int32List.fromList(paddedIds).reshape([1, 256]);
      final inputMaskTensor = Int32List.fromList(List.filled(256, 1)).reshape([1, 256]);

      // Mask padding
      for (int i = inputIds.length; i < 256; i++) {
        (inputMaskTensor as dynamic)[0][i] = 0;
      }

      var output = Float32List(1 * 384).reshape([1, 384]);

      if(_inputCount == 2) {
        _interpreter!.runForMultipleInputs([inputIdsTensor, inputMaskTensor], {0: output});
      } else {
        final segmentIdsTensor = Int32List.fromList(List.filled(256, 0)).reshape([1, 256]);
        _interpreter!.runForMultipleInputs([inputIdsTensor, inputMaskTensor, segmentIdsTensor], {0: output});
      }

      return List<double>.from(output[0]);
    } catch (e) {
      print('⚠️ Embedding generation failed: $e');
      return null;
    }
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

  void _logMetrics(double retrieval, double faithfulness) {
    print('\n');
    print('╔════════════════════════════════════════════════════════╗');
    print('║         📊 ACCURACY & CONFIDENCE METRICS               ║');
    print('╠════════════════════════════════════════════════════════╣');
    print('║  🔍 Retrieval Score    : ${_formatScore(retrieval)}    ║');
    print('║  🤝 Faithfulness Score : ${_formatScore(faithfulness)}    ║');
    print('╚════════════════════════════════════════════════════════╝');
    print('\n');
  }

  String _formatScore(double score) {
    final percentage = (score * 100).toStringAsFixed(1) + '%';
    String label;
    // ADJUSTED THRESHOLDS FOR STRICTER SCORING
    if (score > 0.70) {
      label = '(High)  ';
    } else if (score > 0.50) {
      label = '(Medium)';
    } else {
      label = '(Low)   '; 
    }
    return '$percentage $label'.padRight(20);
  }
}
