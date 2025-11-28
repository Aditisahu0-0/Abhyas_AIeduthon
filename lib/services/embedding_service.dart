import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
// import 'package:tflite_flutter/tflite_flutter.dart'; // Temporarily disabled due to Android Gradle compatibility

class EmbeddingService {
  // Interpreter? _interpreter; // Disabled - TFLite compatibility issue
  bool _isLoaded = false;
  
  // MiniLM produces 384-dimensional embeddings
  static const int embeddingDimension = 384;
  static const int maxSequenceLength = 128;
  
  // Simple vocabulary for basic tokenization
  // In production, you'd load vocab.txt from the model
  final Map<String, int> _vocab = {};
  
  bool get isLoaded => _isLoaded;
  
  Future<void> initialize() async {
    if (_isLoaded) return;
    
    try {
      print('=== EMBEDDING SERVICE INITIALIZATION START ===');
      print('⚠️ TFLite embeddings temporarily disabled due to package compatibility');
      print('   Using TF-IDF only for now (still works great!)');
      
      // Temporarily disabled until tflite_flutter package is fixed
      _isLoaded = false;
      
      print('=== EMBEDDING SERVICE: TF-IDF MODE ===');
      return;
      
      /* DISABLED CODE - Uncomment when tflite_flutter is fixed
      final directory = await getApplicationDocumentsDirectory();
      final modelPath = '${directory.path}/minilm.tflite';
      final modelFile = File(modelPath);
      
      if (!await modelFile.exists()) {
        print('❌ MiniLM model not found at: $modelPath');
        print('Embedding service will be disabled. Download from settings.');
        _isLoaded = false;
        return;
      }
      
      print('📁 MiniLM model found at: $modelPath');
      print('📊 Model size: ${await modelFile.length() ~/ (1024 * 1024)} MB');
      
      // Load TFLite model
      _interpreter = await Interpreter.fromFile(modelFile);
      
      print('✅ MiniLM model loaded successfully!');
      print('   Input shape: ${_interpreter!.getInputTensor(0).shape}');
      print('   Output shape: ${_interpreter!.getOutputTensor(0).shape}');
      
      // Initialize basic vocabulary (simplified for demo)
      _initializeVocab();
      
      _isLoaded = true;
      print('=== EMBEDDING SERVICE INITIALIZATION COMPLETE ===');
      */
    } catch (e) {
      print('❌ ERROR loading MiniLM model: $e');
      print('Stack trace: ${StackTrace.current}');
      _isLoaded = false;
    }
  }
  
  void _initializeVocab() {
    // Simplified tokenization - in production, load vocab from model files
    // For now, we'll use a basic word-level tokenization
    final commonWords = [
      '[PAD]', '[UNK]', '[CLS]', '[SEP]', 'the', 'a', 'an', 'and', 'or',
      'is', 'are', 'was', 'were', 'be', 'been', 'being', 'have', 'has',
      'had', 'do', 'does', 'did', 'will', 'would', 'should', 'could',
      'can', 'may', 'might', 'must', 'of', 'in', 'on', 'at', 'to', 'for',
      'with', 'by', 'from', 'about', 'as', 'into', 'like', 'through',
      'after', 'over', 'between', 'out', 'against', 'during', 'without',
      'before', 'under', 'around', 'among', 'this', 'that', 'these',
      'those', 'what', 'which', 'who', 'when', 'where', 'why', 'how',
    ];
    
    for (int i = 0; i < commonWords.length; i++) {
      _vocab[commonWords[i]] = i;
    }
  }
  
  List<int> _tokenize(String text) {
    // Simplified tokenization - splits on whitespace and punctuation
    final tokens = <int>[2]; // [CLS] token
    
    final words = text.toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    
    for (var word in words) {
      final tokenId = _vocab[word] ?? 1; // 1 = [UNK]
      tokens.add(tokenId);
      
      if (tokens.length >= maxSequenceLength - 1) break;
    }
    
    tokens.add(3); // [SEP] token
    
    // Pad to maxSequenceLength
    while (tokens.length < maxSequenceLength) {
      tokens.add(0); // [PAD] token
    }
    
    return tokens.take(maxSequenceLength).toList();
  }
  
  Future<List<double>?> generateEmbedding(String text) async {
    // Disabled until tflite_flutter package is fixed
    return null;
    
    /* DISABLED CODE
    if (!_isLoaded || _interpreter == null) {
      return null;
    }
    
    try {
      // Tokenize input
      final inputTokens = _tokenize(text);
      
      // Prepare input tensor [1, maxSequenceLength]
      final input = [inputTokens];
      
      // Prepare output tensor [1, embeddingDimension]
      final output = List.filled(1, List.filled(embeddingDimension, 0.0))
          .map((e) => List<double>.from(e))
          .toList();
      
      // Run inference
      _interpreter!.run(input, output);
      
      // Normalize embedding (L2 normalization)
      final embedding = output[0];
      final norm = sqrt(embedding.fold<double>(0.0, (sum, val) => sum + val * val));
      
      if (norm > 0) {
        return embedding.map((val) => val / norm).toList();
      }
      
      return embedding;
    } catch (e) {
      print('Error generating embedding: $e');
      return null;
    }
    */
  }
  
  double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) {
      throw ArgumentError('Vectors must have the same dimension');
    }
    
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    
    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    
    normA = sqrt(normA);
    normB = sqrt(normB);
    
    if (normA == 0 || normB == 0) return 0.0;
    
    return dotProduct / (normA * normB);
  }
  
  void dispose() {
    // _interpreter?.close(); // Disabled
    // _interpreter = null;
    _isLoaded = false;
  }
}
