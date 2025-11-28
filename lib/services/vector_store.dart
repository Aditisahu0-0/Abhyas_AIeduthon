
import 'dart:math';
import 'embedding_service.dart';

class VectorStore {
  // In-memory store for TF-IDF and semantic embeddings
  final Map<String, Map<String, double>> _documentVectors = {};
  final Map<String, double> _idf = {};
  final List<String> _documents = [];
  final Map<String, String> _docIds = {}; // content -> id
  final Map<String, String> _docMetadata = {}; // id -> metadata (title)
  
  // Semantic embeddings storage
  final Map<String, List<double>> _semanticEmbeddings = {}; // id -> embedding
  EmbeddingService? _embeddingService;

  // Stopwords list (abbreviated for brevity)
  static const Set<String> _stopWords = {
    'the', 'is', 'at', 'of', 'on', 'and', 'a', 'an', 'in', 'to', 'for', 'with', 'it', 'this', 'that'
  };
  
  // Hybrid search weights
  static const double tfidfWeight = 0.4;
  static const double semanticWeight = 0.6;

  void setEmbeddingService(EmbeddingService service) {
    _embeddingService = service;
  }

  Future<void> addDocument(String id, String content, {String? metadata, List<double>? embedding}) async {
    _documents.add(content);
    _docIds[content] = id;
    if (metadata != null) {
      _docMetadata[id] = metadata;
    }
    
    // Store semantic embedding if provided
    if (embedding != null) {
      _semanticEmbeddings[id] = embedding;
    }
    
    // Log every 50 documents
    if (_documents.length % 50 == 0) {
      print('📚 Vector Store: ${_documents.length} documents indexed');
    }
  }

  // Public method to trigger TF-IDF computation manually
  void recomputeTFIDF() {
    _computeTFIDF();
  }

  void _computeTFIDF() {
    _documentVectors.clear();
    _idf.clear();
    
    // 1. Calculate Term Frequencies (TF)
    Map<String, Map<String, int>> tf = {};
    Set<String> vocabulary = {};

    for (var doc in _documents) {
      tf[doc] = {};
      var tokens = _tokenize(doc);
      for (var token in tokens) {
        tf[doc]![token] = (tf[doc]![token] ?? 0) + 1;
        vocabulary.add(token);
      }
    }

    // 2. Calculate Inverse Document Frequency (IDF)
    int N = _documents.length;
    for (var term in vocabulary) {
      int docsWithTerm = 0;
      for (var doc in _documents) {
        if (tf[doc]!.containsKey(term)) {
          docsWithTerm++;
        }
      }
      _idf[term] = log(N / (docsWithTerm + 1));
    }

    // 3. Calculate TF-IDF Vectors
    for (var doc in _documents) {
      _documentVectors[doc] = {};
      for (var term in tf[doc]!.keys) {
        double tfVal = tf[doc]![term]! / tf[doc]!.length; // Normalized TF
        _documentVectors[doc]![term] = tfVal * _idf[term]!;
      }
    }
    
    print('🔢 TF-IDF computed: ${_documents.length} docs, ${vocabulary.length} unique terms');
  }

  List<String> _tokenize(String text) {
    return text.toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove punctuation
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && !_stopWords.contains(w))
        .toList();
  }

  Future<List<Map<String, String>>> searchWithMetadata(String query, {int limit = 3}) async {
    if (_documents.isEmpty) {
      return [];
    }
    
    return _tfidfSearch(query, limit);
  }
  
  List<Map<String, String>> _tfidfSearch(String query, int limit) {
    var queryTokens = _tokenize(query);
    Map<String, double> scores = {};

    for (var doc in _documents) {
      double score = 0.0;
      for (var token in queryTokens) {
        if (_documentVectors[doc]!.containsKey(token)) {
          score += _documentVectors[doc]![token]!;
        }
      }
      scores[doc] = score;
    }

    var sortedDocs = scores.keys.toList()
      ..sort((a, b) => scores[b]!.compareTo(scores[a]!));

    return sortedDocs.take(limit).map((doc) {
      final id = _docIds[doc]!;
      return {
        'content': doc,
        'metadata': _docMetadata[id] ?? '',
        'score': scores[doc]!.toString(),
      };
    }).toList();
  }

  Future<List<String>> search(String query, {int limit = 3}) async {
    final results = await searchWithMetadata(query, limit: limit);
    return results.map((e) => e['content']!).toList();
  }
  
  int get documentCount => _documents.length;
  int get semanticEmbeddingCount => _semanticEmbeddings.length;
}
