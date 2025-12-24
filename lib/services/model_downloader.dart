import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

enum DownloadStatus { notDownloaded, downloading, downloaded, error, cancelled }

enum ModelType { qwen }

class ModelDownloader extends ChangeNotifier {
<<<<<<< HEAD
  // Qwen2.5-1.5B-Instruct Q4_K_M quantization from HuggingFace
  static const String QWEN_MODEL_URL =
      'https://huggingface.co/pranavsw/Qwen2.5-1.5B-Instruct-fine-tunned/resolve/main/qwen-1.5B-q4_k_m_finetuned.gguf?download=true';
  static const String QWEN_MODEL_FILENAME = 'qwen-1.5B-q4_k_m_finetuned.gguf';
  static const int QWEN_EXPECTED_SIZE_MB = 1000;
=======
  // Qwen 2.5 1.5B Instruct model - Q4_K_M quantized GGUF, optimized for mobile
  static const String QWEN_MODEL_URL =
      'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf?download=true';
  static const String QWEN_MODEL_FILENAME = 'qwen2.5-1.5b-instruct-q4_k_m.gguf';
  static const int QWEN_EXPECTED_SIZE_MB = 900;
>>>>>>> 5789a775d90edf4535bd98f15a65e5b44813027c

  // HuggingFace API token for downloading models
  String? get _hfToken {
    return 'HF_API_TOKEN_PLACEHOLDER'; // Replace with your actual token or fetch from secure storage
  }

  DownloadStatus _qwenStatus = DownloadStatus.notDownloaded;
  double _qwenProgress = 0.0;
  String? _qwenError;
  CancelToken? _qwenCancelToken;

  // Qwen getters
  DownloadStatus get qwenStatus => _qwenStatus;
  double get qwenProgress => _qwenProgress;
  String? get qwenError => _qwenError;
  bool get isQwenDownloading => _qwenStatus == DownloadStatus.downloading;
  bool get isQwenDownloaded => _qwenStatus == DownloadStatus.downloaded;

  // Legacy compatibility
  DownloadStatus get status => _qwenStatus;
  double get downloadProgress => _qwenProgress;
  String? get errorMessage => _qwenError;
  bool get isDownloading => isQwenDownloading;
  bool get isDownloaded => isQwenDownloaded;

  Future<String> getModelPath({ModelType type = ModelType.qwen}) async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$QWEN_MODEL_FILENAME';
  }

  Future<bool> checkModelExists({ModelType type = ModelType.qwen}) async {
    try {
      final modelPath = await getModelPath(type: type);
      final file = File(modelPath);
      final exists = await file.exists();

      _qwenStatus = exists
          ? DownloadStatus.downloaded
          : DownloadStatus.notDownloaded;
      notifyListeners();

      return exists;
    } catch (e) {
      print('Error checking model: $e');
      return false;
    }
  }

  Future<void> downloadModel({ModelType type = ModelType.qwen}) async {
    if (_qwenStatus == DownloadStatus.downloading) {
      print('Qwen download already in progress');
      return;
    }

    _qwenStatus = DownloadStatus.downloading;
    _qwenProgress = 0.0;
    _qwenError = null;
    _qwenCancelToken = CancelToken();
    notifyListeners();

    try {
      final modelPath = await getModelPath(type: type);
      final dio = Dio();

<<<<<<< HEAD
      print('🚀 Starting NCERT Model download from HuggingFace...');
      print('📦 Model: NCERT Q4_K_M (~$QWEN_EXPECTED_SIZE_MB MB)');
=======
      print('🚀 Starting Qwen download from HuggingFace...');
      print('📦 Model: Qwen 2.5 1.5B Instruct (~$QWEN_EXPECTED_SIZE_MB MB)');
>>>>>>> 5789a775d90edf4535bd98f15a65e5b44813027c

      await dio.download(
        QWEN_MODEL_URL,
        modelPath,
        cancelToken: _qwenCancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            final percentComplete = (progress * 100).toStringAsFixed(1);
            final receivedMB = (received / (1024 * 1024)).toStringAsFixed(1);
            final totalMB = (total / (1024 * 1024)).toStringAsFixed(1);

            _qwenProgress = progress;

<<<<<<< HEAD
            print(
              '📥 NCERT Model: $percentComplete% ($receivedMB MB / $totalMB MB)',
            );
=======
            print('📥 Qwen: $percentComplete% ($receivedMB MB / $totalMB MB)');
>>>>>>> 5789a775d90edf4535bd98f15a65e5b44813027c
            notifyListeners();
          }
        },
        options: Options(
          receiveTimeout: const Duration(minutes: 60),
          sendTimeout: const Duration(minutes: 60),
          headers: () {
            final token = _hfToken;
            if (token != null && token.isNotEmpty) {
              return {'Authorization': 'Bearer $token'};
            }
            return <String, String>{};
          }(),
        ),
      );

      // Verify file size
      final file = File(modelPath);
      final fileSize = await file.length();
      final fileSizeMB = fileSize / (1024 * 1024);
<<<<<<< HEAD
      print('✅ NCERT Model downloaded successfully!');
=======
      print('✅ Qwen downloaded successfully!');
>>>>>>> 5789a775d90edf4535bd98f15a65e5b44813027c
      print('📊 File size: ${fileSizeMB.toStringAsFixed(2)} MB');

      _qwenStatus = DownloadStatus.downloaded;
      _qwenProgress = 1.0;
      notifyListeners();
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        _qwenStatus = DownloadStatus.cancelled;
        _qwenError = 'Download cancelled';
      } else {
        _qwenStatus = DownloadStatus.error;
        _qwenError = 'Download failed: ${e.message}';
      }
<<<<<<< HEAD
      print('❌ NCERT Model download error: $e');
=======
      print('❌ Qwen download error: $e');
>>>>>>> 5789a775d90edf4535bd98f15a65e5b44813027c
      notifyListeners();
    } catch (e) {
      _qwenStatus = DownloadStatus.error;
      _qwenError = 'Unexpected error: $e';
<<<<<<< HEAD
      print('❌ NCERT Model unexpected error: $e');
=======
      print('❌ Qwen unexpected error: $e');
>>>>>>> 5789a775d90edf4535bd98f15a65e5b44813027c
      notifyListeners();
    }
  }

  void cancelDownload({ModelType type = ModelType.qwen}) {
    if (_qwenCancelToken != null && !_qwenCancelToken!.isCancelled) {
      _qwenCancelToken!.cancel('User cancelled');
    }
  }

  Future<void> deleteModel({ModelType type = ModelType.qwen}) async {
    try {
      final modelPath = await getModelPath(type: type);
      final file = File(modelPath);
      if (await file.exists()) {
        await file.delete();

        _qwenStatus = DownloadStatus.notDownloaded;
        _qwenProgress = 0.0;
        notifyListeners();

<<<<<<< HEAD
        print('🗑️ NCERT Model deleted successfully');
=======
        print('🗑️ Qwen model deleted successfully');
>>>>>>> 5789a775d90edf4535bd98f15a65e5b44813027c
      }
    } catch (e) {
      print('Error deleting model: $e');
    }
  }

  Future<int> getModelSize({ModelType type = ModelType.qwen}) async {
    try {
      final modelPath = await getModelPath(type: type);
      final file = File(modelPath);
      if (await file.exists()) {
        return await file.length();
      }
    } catch (e) {
      print('Error getting model size: $e');
    }
    return 0;
  }
}
