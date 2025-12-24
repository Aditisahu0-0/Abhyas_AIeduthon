import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService extends ChangeNotifier {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  late FlutterTts _flutterTts;
  bool _isInitialized = false;

  bool _isPlaying = false;
  String? _currentText;

  bool get isPlaying => _isPlaying;
  String? get currentText => _currentText;

  Future<void> init() async {
    if (_isInitialized) return;

    _flutterTts = FlutterTts();

    // Default settings
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    // Completion handler
    _flutterTts.setCompletionHandler(() {
      _isPlaying = false;
      _currentText = null;
      notifyListeners();
    });

    // Cancel handler (Android)
    _flutterTts.setCancelHandler(() {
      _isPlaying = false;
      _currentText = null;
      notifyListeners();
    });

    // Wait for completion (optional, depends on platform)
    await _flutterTts.awaitSpeakCompletion(true);

    _isInitialized = true;
  }

  Future<void> speak(String text) async {
    if (!_isInitialized) await init();

    // If already playing the SAME text, stop it (toggle behavior)
    if (_isPlaying && _currentText == text) {
      await stop();
      return;
    }

    // If playing DIFFERENT text, stop previous first
    if (_isPlaying) {
      await stop();
    }

    // Clean text (remove common markdown)
    final cleanText = _cleanText(text);

    if (cleanText.isNotEmpty) {
      _currentText = text; // Store original text for identity check
      _isPlaying = true;
      notifyListeners();

      await _flutterTts.speak(cleanText);
    }
  }

  Future<void> stop() async {
    if (!_isInitialized) return;
    await _flutterTts.stop();
    _isPlaying = false;
    _currentText = null;
    notifyListeners();
  }

  String _cleanText(String text) {
    // 1. Remove markdown formatting
    String clean = text
        .replaceAll('**', '')
        .replaceAll('*', '') // Note: This might remove multiplication *, but usually we want "times"
        .replaceAll('__', '')
        .replaceAll('_', '') // This might affect subscripts like x_1
        .replaceAll('`', '')
        .replaceAll('#', ''); // Remove headers

    // 2. Remove LaTeX delimiters
    clean = clean.replaceAll(r'$$', '').replaceAll(r'$', '');

    // 3. Common Math Symbols
    clean = clean.replaceAll(r'\times', ' times ');
    clean = clean.replaceAll(r'\cdot', ' times ');
    clean = clean.replaceAll(r'\div', ' divided by ');
    clean = clean.replaceAll(r'\pm', ' plus or minus ');
    clean = clean.replaceAll(r'\approx', ' approximately ');
    clean = clean.replaceAll(r'\neq', ' not equal to ');
    clean = clean.replaceAll(r'\leq', ' less than or equal to ');
    clean = clean.replaceAll(r'\geq', ' greater than or equal to ');
    clean = clean.replaceAll(r'\pi', ' pi ');
    clean = clean.replaceAll(r'\theta', ' theta ');
    clean = clean.replaceAll(r'\infty', ' infinity ');

    // 4. Fractions: \frac{a}{b} -> a over b
    // Simple non-nested fractions
    clean = clean.replaceAllMapped(
      RegExp(r'\\frac\{([^}]+)\}\{([^}]+)\}'), 
      (match) => '${match.group(1)} over ${match.group(2)}'
    );

    // 5. Square Root: \sqrt{x} -> square root of x
    clean = clean.replaceAllMapped(
      RegExp(r'\\sqrt\{([^}]+)\}'), 
      (match) => 'square root of ${match.group(1)}'
    );

    // 6. Exponents
    // ^2 -> squared
    clean = clean.replaceAll(RegExp(r'\^2\b'), ' squared');
    clean = clean.replaceAll(r'^{2}', ' squared');
    
    // ^3 -> cubed
    clean = clean.replaceAll(RegExp(r'\^3\b'), ' cubed');
    clean = clean.replaceAll(r'^{3}', ' cubed');

    // ^{n} -> to the power of n
    clean = clean.replaceAllMapped(
      RegExp(r'\^\{([^}]+)\}'), 
      (match) => ' to the power of ${match.group(1)}'
    );
    
    // Simple ^n (single digit)
    clean = clean.replaceAllMapped(
      RegExp(r'\^(\d)'), 
      (match) => ' to the power of ${match.group(1)}'
    );

    return clean;
  }
}
