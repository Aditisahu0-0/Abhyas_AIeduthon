import 'package:flutter/material.dart';

enum Language { en }

class LanguageService extends ChangeNotifier {
  Language _currentLanguage = Language.en;

  Language get currentLanguage => _currentLanguage;

  void setLanguage(Language language) {
    // No-op or allow redundant setting
    _currentLanguage = language;
    notifyListeners();
  }

  void toggleLanguage() {
    // No-op as only English is supported
    notifyListeners();
  }

  // Simplified to return the key itself as we are English-only now
  String translate(String key) {
    return key;
  }
}
