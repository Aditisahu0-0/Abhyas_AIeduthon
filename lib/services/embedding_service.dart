import 'dart:math';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'bert_tokenizer.dart';

class EmbeddingService {
  static final EmbeddingService instance = EmbeddingService._();
  EmbeddingService._();

  Interpreter? _interpreter;
  final BertTokenizer _tokenizer = BertTokenizer();
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print('=== EMBEDDING SERVICE INITIALIZATION START ===');

      // Load Tokenizer
      print('🔤 Loading vocab...');
      await _tokenizer.loadVocabFile('assets/vocab.txt');

      // Load TFLite Model
      print('🧠 Loading MiniLM TFLite model...');
      final options = InterpreterOptions();

      _interpreter = await Interpreter.fromAsset(
        'assets/mobile_embedding.tflite',
        options: options,
      );

      final inputTensors = _interpreter!.getInputTensors();
      final outputTensors = _interpreter!.getOutputTensors();

      print('✅ Model loaded.');
      print('   Input count: ${inputTensors.length}');
      for (var i = 0; i < inputTensors.length; i++) {
        print(
          '   Input[$i]: ${inputTensors[i].name} shape: ${inputTensors[i].shape} type: ${inputTensors[i].type}',
        );
      }
      print('   Output count: ${outputTensors.length}');
      for (var i = 0; i < outputTensors.length; i++) {
        print(
          '   Output[$i]: ${outputTensors[i].name} shape: ${outputTensors[i].shape} type: ${outputTensors[i].type}',
        );
      }

      _isInitialized = true;
      print('=== EMBEDDING SERVICE INITIALIZATION COMPLETE ===');
    } catch (e) {
      print('❌ Error initializing Embedding Service: $e');
      _isInitialized = false;
    }
  }

  Future<List<double>> getEmbedding(String text) async {
    if (!_isInitialized || _interpreter == null) {
      print('⚠️ Embedding service not initialized');
      return [];
    }

    try {
      final tokenIds = _tokenizer.tokenize(text);

      // Standard BERT inputs
      var inputIds = List<int>.filled(256, 0);
      var attentionMask = List<int>.filled(256, 0);
      var tokenTypeIds = List<int>.filled(256, 0);

      for (int i = 0; i < 256; i++) {
        inputIds[i] = tokenIds[i];
        attentionMask[i] = tokenIds[i] != 0 ? 1 : 0;
      }

      final inputTensors = _interpreter!.getInputTensors();
      List<Object> inputs = [];

      // Dynamic input creation based on model signature
      if (inputTensors.length == 1) {
        // Some pruned models only take input_ids
        inputs = [
          [inputIds],
        ]; // [1, 256]
      } else if (inputTensors.length == 3) {
        // Standard: input_ids, attention_mask, token_type_ids
        // ORDER MATTERS: Usually ids, mask, types OR ids, types, mask.
        // We should ideally check names, but for now assuming standard TFLite export order:
        // 0: input_ids
        // 1: attention_mask
        // 2: token_type_ids
        // If names are available we could map them. Assuming standard for now.

        inputs = [
          [inputIds],
          [attentionMask],
          [tokenTypeIds],
        ];
      } else {
        print(
          '⚠️ Unexpected input count: ${inputTensors.length}. Trying simplified input.',
        );
        inputs = [
          [inputIds],
        ];
      }

      // Prepare output
      final outputTensor = _interpreter!.getOutputTensor(0);
      final outputShape = outputTensor.shape;
      final outputDim = outputShape.last;

      // Output buffer
      var outputBuffer = List.filled(
        1 * outputDim,
        0.0,
      ).reshape([1, outputDim]);
      Map<int, Object> outputs = {0: outputBuffer};

      _interpreter!.runForMultipleInputs(inputs, outputs);

      final rawVector = (outputs[0] as List)[0] as List<double>;
      return _normalize(rawVector);
    } catch (e) {
      print('❌ Error generating embedding: $e');
      return [];
    }
  }

  List<double> _normalize(List<double> vector) {
    double dot = 0.0;
    for (var v in vector) dot += v * v;
    final mag = sqrt(dot);
    if (mag == 0) return vector;
    return vector.map((v) => v / mag).toList();
  }

  void dispose() {
    _interpreter?.close();
    _isInitialized = false;
  }
}
