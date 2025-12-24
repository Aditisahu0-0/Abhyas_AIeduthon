import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/model_downloader.dart';
import '../providers/course_provider.dart';
import '../services/language_service.dart';

class ModelDownloadScreen extends StatelessWidget {
  const ModelDownloadScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(languageService.translate('AI Model Setup')),
        centerTitle: true,
      ),
      body: Consumer<ModelDownloader>(
        builder: (context, downloader, child) {
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                const Icon(
                  Icons.psychology,
                  size: 100,
                  color: Colors.deepPurple,
                ),
                const SizedBox(height: 32),
                Text(
                  languageService.translate('AI-Powered Learning'),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  languageService.translate('Download the AI model to unlock:'),
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                _buildFeatureItem(Icons.chat, languageService.translate('AI Doubt Solving'), languageService.translate('Ask questions and get instant answers')),
                _buildFeatureItem(Icons.quiz, languageService.translate('Smart Quiz Generation'), languageService.translate('AI-generated questions from lessons')),
                _buildFeatureItem(Icons.summarize, languageService.translate('Intelligent Summaries'), languageService.translate('Key points extraction with AI')),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            languageService.translate('Model Size:'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('~${ModelDownloader.QWEN_EXPECTED_SIZE_MB} MB'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        languageService.translate('One-time download. Works offline after installation.'),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                if (downloader.status == DownloadStatus.downloading) ...[
                  LinearProgressIndicator(
                    value: downloader.downloadProgress,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${(downloader.downloadProgress * 100).toStringAsFixed(1)}%',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () {
                      downloader.cancelDownload();
                    },
                    child: Text(languageService.translate('Cancel Download')),
                  ),
                ] else if (downloader.status == DownloadStatus.error) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      downloader.errorMessage ?? 'Download failed',
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      downloader.downloadModel();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(languageService.translate('Retry Download'), style: const TextStyle(fontSize: 16)),
                  ),
                ] else if (downloader.status == DownloadStatus.downloaded) ...[
                  const Icon(Icons.check_circle, color: Colors.green, size: 60),
                  const SizedBox(height: 16),
                  Text(
                    languageService.translate('Model Downloaded Successfully!'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    languageService.translate('Initializing AI...'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      // Initialize AI service after download
                      final courseProvider = Provider.of<CourseProvider>(context, listen: false);
                      await courseProvider.initAI();
                      
                      if (!context.mounted) return;
                      Navigator.of(context).pushReplacementNamed('/home');
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(languageService.translate('Continue to App'), style: const TextStyle(fontSize: 16)),
                  ),
                ] else ...[
                  ElevatedButton(
                    onPressed: () {
                      downloader.downloadModel();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(languageService.translate('Download AI Model'), style: const TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 12),
                  


                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacementNamed('/');
                    },
                    child: Text(languageService.translate('Skip for Now (Limited Features)')),
                  ),
                ],
              ],
            ),
          ),
          );
        },
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.deepPurple),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
