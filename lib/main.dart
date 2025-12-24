import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/course_provider.dart';
import 'providers/theme_provider.dart';
import 'services/model_downloader.dart';
import 'services/auth_service.dart';
import 'services/sync_service.dart';
import 'services/language_service.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/model_download_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // llama_flutter_android doesn't require global initialization
  // Model initialization happens in AIService.initialize()
<<<<<<< HEAD

=======
  
>>>>>>> 5789a775d90edf4535bd98f15a65e5b44813027c
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CourseProvider()),
        ChangeNotifierProvider(create: (_) => ModelDownloader()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => SyncService()),
        ChangeNotifierProvider(create: (_) => LanguageService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, LanguageService>(
      builder: (context, themeProvider, languageService, child) {
        return MaterialApp(
          title: 'ABHYAS',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          home: const SplashScreen(),
          routes: {
            '/home': (context) => const MainNavigationScreen(),
            '/download': (context) => const ModelDownloadScreen(),
            '/login': (context) => const LoginScreen(),
            '/signup': (context) => const SignupScreen(),
          },
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final downloader = Provider.of<ModelDownloader>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    // Run checks in parallel to save time, or sequential if dependency needed
    final modelExists = await downloader.checkModelExists();
    final isAuthValid = await authService
        .checkAuthValidity(); // Checks expiry too

    // Small delay for splash effect
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    if (modelExists) {
      if (isAuthValid) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } else {
      // If model missing, prioritize download, BUT we might want Auth first?
      // For now, let's say Auth is prerequisites for everything except maybe public info.
      // But typically, download screen might need internet, so let's let them login first.

      if (isAuthValid) {
        Navigator.of(context).pushReplacementNamed('/download');
      } else {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [AppTheme.darkBackground, AppTheme.darkSurface]
                : [Colors.white, AppTheme.lightBackground],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ABHYAS Logo
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppTheme.cyanAccent, AppTheme.cyanSecondary],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.cyanAccent.withOpacity(0.3),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.school_rounded,
                  size: 80,
                  color: isDark ? Colors.black : Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              // ABHYAS Text
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [AppTheme.cyanAccent, AppTheme.cyanSecondary],
                ).createShader(bounds),
                child: Text(
                  Provider.of<LanguageService>(context).translate('ABHYAS'),
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                Provider.of<LanguageService>(context).translate('Learn. Practice. Excel.'),
                style: TextStyle(
                  fontSize: 16,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 48),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.cyanAccent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
