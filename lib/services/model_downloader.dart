import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

enum DownloadStatus {
  notDownloaded,
  downloading,
  downloaded,
  error,
  cancelled
}

enum ModelType {
  gemma
}

class ModelDownloader extends ChangeNotifier {
  // Gemma 3 1B IT model - int4 quantized, optimized for mobile
  static const String GEMMA_MODEL_URL =
      'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/gemma3-1b-it-int4.task?download=true';
  static const String GEMMA_MODEL_FILENAME = 'model.task';
  static const int GEMMA_EXPECTED_SIZE_MB = 700;
  
  // HuggingFace API token for downloading models
  String? get _hfToken {
    return '';
  }

  DownloadStatus _gemmaStatus = DownloadStatus.notDownloaded;
  double _gemmaProgress = 0.0;
  String? _gemmaError;
  CancelToken? _gemmaCancelToken;

  // Gemma getters
  DownloadStatus get gemmaStatus => _gemmaStatus;
  double get gemmaProgress => _gemmaProgress;
  String? get gemmaError => _gemmaError;
  bool get isGemmaDownloading => _gemmaStatus == DownloadStatus.downloading;
  bool get isGemmaDownloaded => _gemmaStatus == DownloadStatus.downloaded;
  
  // Legacy compatibility
  DownloadStatus get status => _gemmaStatus;
  double get downloadProgress => _gemmaProgress;
  String? get errorMessage => _gemmaError;
  bool get isDownloading => isGemmaDownloading;
  bool get isDownloaded => isGemmaDownloaded;

  Future<String> getModelPath({ModelType type = ModelType.gemma}) async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$GEMMA_MODEL_FILENAME';
  }

  Future<bool> checkModelExists({ModelType type = ModelType.gemma}) async {
    try {
      final modelPath = await getModelPath(type: type);
      final file = File(modelPath);
      final exists = await file.exists();
      
      _gemmaStatus = exists ? DownloadStatus.downloaded : DownloadStatus.notDownloaded;
      notifyListeners();
      
      return exists;
    } catch (e) {
      print('Error checking model: $e');
      return false;
    }
  }

  Future<void> downloadModel({ModelType type = ModelType.gemma}) async {
    if (_gemmaStatus == DownloadStatus.downloading) {
      print('Gemma download already in progress');
      return;
    }

    _gemmaStatus = DownloadStatus.downloading;
    _gemmaProgress = 0.0;
    _gemmaError = null;
    _gemmaCancelToken = CancelToken();
    notifyListeners();

    try {
      final modelPath = await getModelPath(type: type);
      final dio = Dio();

      print('🚀 Starting Gemma download from HuggingFace...');
      print('📦 Model: Gemma3-1B-IT (~$GEMMA_EXPECTED_SIZE_MB MB)');

      await dio.download(
        GEMMA_MODEL_URL,
        modelPath,
        cancelToken: _gemmaCancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            final percentComplete = (progress * 100).toStringAsFixed(1);
            final receivedMB = (received / (1024 * 1024)).toStringAsFixed(1);
            final totalMB = (total / (1024 * 1024)).toStringAsFixed(1);
            
            _gemmaProgress = progress;
            
            print('📥 Gemma: $percentComplete% ($receivedMB MB / $totalMB MB)');
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
      print('✅ Gemma downloaded successfully!');
      print('📊 File size: ${fileSizeMB.toStringAsFixed(2)} MB');

      _gemmaStatus = DownloadStatus.downloaded;
      _gemmaProgress = 1.0;
      notifyListeners();
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        _gemmaStatus = DownloadStatus.cancelled;
        _gemmaError = 'Download cancelled';
      } else {
        _gemmaStatus = DownloadStatus.error;
        _gemmaError = 'Download failed: ${e.message}';
      }
      print('❌ Gemma download error: $e');
      notifyListeners();
    } catch (e) {
      _gemmaStatus = DownloadStatus.error;
      _gemmaError = 'Unexpected error: $e';
      print('❌ Gemma unexpected error: $e');
      notifyListeners();
    }
  }

  void cancelDownload({ModelType type = ModelType.gemma}) {
    if (_gemmaCancelToken != null && !_gemmaCancelToken!.isCancelled) {
      _gemmaCancelToken!.cancel('User cancelled');
    }
  }

  Future<void> deleteModel({ModelType type = ModelType.gemma}) async {
    try {
      final modelPath = await getModelPath(type: type);
      final file = File(modelPath);
      if (await file.exists()) {
        await file.delete();
        
        _gemmaStatus = DownloadStatus.notDownloaded;
        _gemmaProgress = 0.0;
        notifyListeners();
        
        print('🗑️ Gemma model deleted successfully');
      }
    } catch (e) {
      print('Error deleting model: $e');
    }
  }

  Future<int> getModelSize({ModelType type = ModelType.gemma}) async {
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
