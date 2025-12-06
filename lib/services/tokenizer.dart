
import 'dart:io';
import 'package:flutter/services.dart';

class WordPieceTokenizer {
  final Map<String, int> vocab;
  final int unkId;
  final int clsId;
  final int sepId;
  final int padId;

  WordPieceTokenizer({
    required this.vocab,
    this.unkId = 100,
    this.clsId = 101,
    this.sepId = 102,
    this.padId = 0,
  });

  /// Normalize text: lowercase, strip accents (simple)
  String _normalize(String text) {
    return text.toLowerCase().trim();
  }

  /// Tokenize a single word into subwords max matching the vocab
  List<int> _tokenizeWord(String word) {
    if (word.length > 100) return [unkId]; // Too long

    List<int> tokens = [];
    bool isBad = false;
    int start = 0;
    
    while (start < word.length) {
      int end = word.length;
      int? curId;
      
      while (start < end) {
        String substr = word.substring(start, end);
        if (start > 0) substr = "##$substr";
        
        if (vocab.containsKey(substr)) {
          curId = vocab[substr];
          break;
        }
        end--;
      }
      
      if (curId == null) {
        isBad = true;
        break;
      }
      
      tokens.add(curId);
      start = end;
    }
    
    if (isBad) return [unkId];
    return tokens;
  }

  List<int> tokenize(String text, {int maxLen = 256}) {
    String normalized = _normalize(text);
    
    // Basic whitespace splitting + punctuation handling
    // This regular expression splits by whitespace and punctuation, keeping punctuation
    // Note: A full BERT tokenizer is more complex, but this is a decent approximation for on-device simple English
    final RegExp exp = RegExp(r"\w+|[^\w\s]");
    final matches = exp.allMatches(normalized);
    
    List<int> ids = [];
    ids.add(clsId); // [CLS]
    
    for (final m in matches) {
      final token = m.group(0)!;
      ids.addAll(_tokenizeWord(token));
      if (ids.length >= maxLen - 1) break; // -1 for [SEP]
    }
    
    if (ids.length >= maxLen) {
      ids = ids.sublist(0, maxLen - 1); // Truncate to fit [SEP]
    }
    
    ids.add(sepId); // [SEP]
    
    // Padding
    while (ids.length < maxLen) {
      ids.add(padId);
    }
    
    return ids;
  }
}
