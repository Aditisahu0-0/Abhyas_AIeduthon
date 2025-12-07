import 'package:flutter/services.dart';

class BertTokenizer {
  static const int maxSeqLen = 256;
  Map<String, int>? _vocab;
  bool _isLowercase = true;

  Future<void> loadVocabFile(String vocabPath) async {
    try {
      final vocabString = await rootBundle.loadString(vocabPath);
      final lines = vocabString.split('\n');
      _vocab = {};
      for (int i = 0; i < lines.length; i++) {
        final token = lines[i].trim();
        if (token.isNotEmpty) {
          _vocab![token] = i;
        }
      }
      print('✅ Loaded vocabulary with ${_vocab!.length} tokens');
    } catch (e) {
      print('❌ Error loading vocab: $e');
      throw Exception('Failed to load vocabulary');
    }
  }

  List<int> tokenize(String text) {
    if (_vocab == null) {
      throw Exception('Vocabulary not loaded');
    }

    final tokens = _tokenize(text);

    // Add [CLS] and [SEP]
    // Assuming [CLS] = 101, [SEP] = 102 for standard BERT/MiniLM
    // If your vocab is different, standard keys are often '[CLS]' and '[SEP]'

    final clsId = _vocab!['[CLS]'] ?? 101;
    final sepId = _vocab!['[SEP]'] ?? 102;

    List<int> ids = [clsId];
    for (var token in tokens) {
      if (_vocab!.containsKey(token)) {
        ids.add(_vocab![token]!);
      } else {
        ids.add(_vocab!['[UNK]'] ?? 100);
      }
    }
    ids.add(sepId);

    // Truncate or Pad
    if (ids.length > maxSeqLen) {
      ids = ids.sublist(0, maxSeqLen);
      // Ensure last token is SEP if truncated?
      // Strictly speaking, standard implementation truncates and adds SEP.
      ids[maxSeqLen - 1] = sepId;
    } else {
      while (ids.length < maxSeqLen) {
        ids.add(0); // [PAD] usually 0
      }
    }

    return ids;
  }

  List<String> _tokenize(String text) {
    List<String> tokens = [];
    // Insert spaces around punctuation to ensure they are tokenized separately
    // This matches standard BERT tokenizer behavior (mostly)
    final cleanText = _isLowercase ? text.toLowerCase() : text;
    final textWithPunct = cleanText.replaceAllMapped(
      RegExp(r'([^\w\s])'),
      (match) => ' ${match.group(1)} ',
    );

    // Simple whitespace tokenization
    final words = textWithPunct.split(RegExp(r'\s+'));

    for (var word in words) {
      if (word.isEmpty) continue;

      // WordPiece Algorithm
      // Find longest substring that matches a token in vocab
      if (_vocab!.containsKey(word)) {
        tokens.add(word);
        continue;
      }

      // Sub-word tokenization
      int start = 0;
      while (start < word.length) {
        int end = word.length;
        String curSubStr = '';
        bool found = false;

        while (start < end) {
          String subStr = word.substring(start, end);
          if (start > 0) {
            subStr = '##$subStr';
          }

          if (_vocab!.containsKey(subStr)) {
            curSubStr = subStr;
            found = true;
            break;
          }
          end--;
        }

        if (found) {
          tokens.add(curSubStr);
          start = end;
        } else {
          tokens.add('[UNK]');
          break;
        }
      }
    }
    return tokens;
  }
}
