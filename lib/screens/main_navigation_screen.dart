import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/course_provider.dart';
import '../services/tts_service.dart';
import '../services/language_service.dart';
import 'home_screen.dart';
import 'chat_screen.dart';
import 'progress_screen.dart';
import 'knowledge_centre_screen.dart';
import 'settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const ProgressScreen(),
    const ChatScreen(),
    const KnowledgeCentreScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (_currentIndex != index) {
            TtsService().stop();
          }
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed, // Ensure icons don't shift
        items: [
           BottomNavigationBarItem(
            icon: const Icon(Icons.home_rounded),
            label: languageService.translate('Home'),
          ),
           BottomNavigationBarItem(
            icon: const Icon(Icons.show_chart_rounded),
            label: languageService.translate('Progress'),
          ),
           BottomNavigationBarItem(
            icon: const Icon(Icons.chat_bubble_rounded),
            label: languageService.translate('AI Tutor'),
          ),
           BottomNavigationBarItem(
            icon: const Icon(Icons.grid_view_rounded),
            label: languageService.translate('Knowledge'),
          ),
           BottomNavigationBarItem(
            icon: const Icon(Icons.settings_rounded),
            label: languageService.translate('Settings'),
          ),
        ],
      ),
    );
  }
}
