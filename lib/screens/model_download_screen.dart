import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/model_downloader.dart';
import '../providers/course_provider.dart';

class ModelDownloadScreen extends StatelessWidget {
  const ModelDownloadScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Model Setup'),
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
                const Text(
                  'AI-Powered Learning',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Download the AI model to unlock:',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                _buildFeatureItem(Icons.chat, 'AI Doubt Solving', 'Ask questions and get instant answers'),
                _buildFeatureItem(Icons.quiz, 'Smart Quiz Generation', 'AI-generated questions from lessons'),
                _buildFeatureItem(Icons.summarize, 'Intelligent Summaries', 'Key points extraction with AI'),
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
                          const Text(
                            'Model Size:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('~${ModelDownloader.GEMMA_EXPECTED_SIZE_MB} MB'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'One-time download. Works offline after installation.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
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
                    child: const Text('Cancel Download'),
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
                    child: const Text('Retry Download', style: TextStyle(fontSize: 16)),
                  ),
                ] else if (downloader.status == DownloadStatus.downloaded) ...[
                  const Icon(Icons.check_circle, color: Colors.green, size: 60),
                  const SizedBox(height: 16),
                  const Text(
                    'Model Downloaded Successfully!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Initializing AI...',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
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
                    child: const Text('Continue to App', style: TextStyle(fontSize: 16)),
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
                    child: const Text('Download AI Model', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacementNamed('/');
                    },
                    child: const Text('Skip for Now (Limited Features)'),
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
