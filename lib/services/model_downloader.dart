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
  gemma,
  miniLM
}

class ModelDownloader extends ChangeNotifier {
  // Gemma 3 1B IT model - int4 quantized, optimized for mobile
  static const String GEMMA_MODEL_URL =
      'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/gemma3-1b-it-int4.task';
  static const String GEMMA_MODEL_FILENAME = 'model.task';
  static const int GEMMA_EXPECTED_SIZE_MB = 700;
  
  // MiniLM-L6-V2 TFLite model - quantized for embeddings
  static const String MINILM_MODEL_URL =
      'https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2/resolve/main/all-MiniLM-L6-v2-quant.tflite';
  static const String MINILM_MODEL_FILENAME = 'minilm.tflite';
  static const int MINILM_EXPECTED_SIZE_MB = 25;
  
  // Do NOT hard-code tokens. Provide the Hugging Face token via environment
  // variables or secure storage. For development you can set the environment
  // variable `HF_TOKEN`. On mobile, prefer a secure solution (flutter_dotenv
  // or secure storage) and never commit tokens to source control.
  String? get _hfToken {
    try {
      final token = Platform.environment['HF_TOKEN'];
      if (token != null && token.isNotEmpty) return token;
    } catch (_) {}
    return null;
  }

  DownloadStatus _gemmaStatus = DownloadStatus.notDownloaded;
  DownloadStatus _miniLMStatus = DownloadStatus.notDownloaded;
  
  double _gemmaProgress = 0.0;
  double _miniLMProgress = 0.0;
  
  String? _gemmaError;
  String? _miniLMError;
  
  CancelToken? _gemmaCancelToken;
  CancelToken? _miniLMCancelToken;

  // Gemma getters
  DownloadStatus get gemmaStatus => _gemmaStatus;
  double get gemmaProgress => _gemmaProgress;
  String? get gemmaError => _gemmaError;
  bool get isGemmaDownloading => _gemmaStatus == DownloadStatus.downloading;
  bool get isGemmaDownloaded => _gemmaStatus == DownloadStatus.downloaded;
  
  // MiniLM getters
  DownloadStatus get miniLMStatus => _miniLMStatus;
  double get miniLMProgress => _miniLMProgress;
  String? get miniLMError => _miniLMError;
  bool get isMiniLMDownloading => _miniLMStatus == DownloadStatus.downloading;
  bool get isMiniLMDownloaded => _miniLMStatus == DownloadStatus.downloaded;
  
  // Legacy compatibility
  DownloadStatus get status => _gemmaStatus;
  double get downloadProgress => _gemmaProgress;
  String? get errorMessage => _gemmaError;
  bool get isDownloading => isGemmaDownloading;
  bool get isDownloaded => isGemmaDownloaded;

  Future<String> getModelPath({ModelType type = ModelType.gemma}) async {
    final directory = await getApplicationDocumentsDirectory();
    final filename = type == ModelType.gemma ? GEMMA_MODEL_FILENAME : MINILM_MODEL_FILENAME;
    return '${directory.path}/$filename';
  }

  Future<bool> checkModelExists({ModelType type = ModelType.gemma}) async {
    try {
      final modelPath = await getModelPath(type: type);
      final file = File(modelPath);
      final exists = await file.exists();
      
      if (type == ModelType.gemma) {
        _gemmaStatus = exists ? DownloadStatus.downloaded : DownloadStatus.notDownloaded;
      } else {
        _miniLMStatus = exists ? DownloadStatus.downloaded : DownloadStatus.notDownloaded;
      }
      notifyListeners();
      
      return exists;
    } catch (e) {
      print('Error checking model: $e');
      return false;
    }
  }

  Future<void> downloadModel({ModelType type = ModelType.gemma}) async {
    if (type == ModelType.gemma && _gemmaStatus == DownloadStatus.downloading) {
      print('Gemma download already in progress');
      return;
    }
    if (type == ModelType.miniLM && _miniLMStatus == DownloadStatus.downloading) {
      print('MiniLM download already in progress');
      return;
    }

    final modelUrl = type == ModelType.gemma ? GEMMA_MODEL_URL : MINILM_MODEL_URL;
    final modelName = type == ModelType.gemma ? 'Gemma3-1B-IT' : 'MiniLM-L6-V2';
    final expectedSize = type == ModelType.gemma ? GEMMA_EXPECTED_SIZE_MB : MINILM_EXPECTED_SIZE_MB;

    if (type == ModelType.gemma) {
      _gemmaStatus = DownloadStatus.downloading;
      _gemmaProgress = 0.0;
      _gemmaError = null;
      _gemmaCancelToken = CancelToken();
    } else {
      _miniLMStatus = DownloadStatus.downloading;
      _miniLMProgress = 0.0;
      _miniLMError = null;
      _miniLMCancelToken = CancelToken();
    }
    notifyListeners();

    try {
      final modelPath = await getModelPath(type: type);
      final dio = Dio();

      print('🚀 Starting $modelName download from HuggingFace...');
      print('📦 Model: $modelName (~$expectedSize MB)');

      await dio.download(
        modelUrl,
        modelPath,
        cancelToken: type == ModelType.gemma ? _gemmaCancelToken : _miniLMCancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            final percentComplete = (progress * 100).toStringAsFixed(1);
            final receivedMB = (received / (1024 * 1024)).toStringAsFixed(1);
            final totalMB = (total / (1024 * 1024)).toStringAsFixed(1);
            
            if (type == ModelType.gemma) {
              _gemmaProgress = progress;
            } else {
              _miniLMProgress = progress;
            }
            
            print('📥 $modelName: $percentComplete% ($receivedMB MB / $totalMB MB)');
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
      print('✅ $modelName downloaded successfully!');
      print('📊 File size: ${fileSizeMB.toStringAsFixed(2)} MB');

      if (type == ModelType.gemma) {
        _gemmaStatus = DownloadStatus.downloaded;
        _gemmaProgress = 1.0;
      } else {
        _miniLMStatus = DownloadStatus.downloaded;
        _miniLMProgress = 1.0;
      }
      notifyListeners();
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        if (type == ModelType.gemma) {
          _gemmaStatus = DownloadStatus.cancelled;
          _gemmaError = 'Download cancelled';
        } else {
          _miniLMStatus = DownloadStatus.cancelled;
          _miniLMError = 'Download cancelled';
        }
      } else {
        if (type == ModelType.gemma) {
          _gemmaStatus = DownloadStatus.error;
          _gemmaError = 'Download failed: ${e.message}';
        } else {
          _miniLMStatus = DownloadStatus.error;
          _miniLMError = 'Download failed: ${e.message}';
        }
      }
      print('❌ $modelName download error: $e');
      notifyListeners();
    } catch (e) {
      if (type == ModelType.gemma) {
        _gemmaStatus = DownloadStatus.error;
        _gemmaError = 'Unexpected error: $e';
      } else {
        _miniLMStatus = DownloadStatus.error;
        _miniLMError = 'Unexpected error: $e';
      }
      print('❌ $modelName unexpected error: $e');
      notifyListeners();
    }
  }

  void cancelDownload({ModelType type = ModelType.gemma}) {
    if (type == ModelType.gemma) {
      if (_gemmaCancelToken != null && !_gemmaCancelToken!.isCancelled) {
        _gemmaCancelToken!.cancel('User cancelled');
      }
    } else {
      if (_miniLMCancelToken != null && !_miniLMCancelToken!.isCancelled) {
        _miniLMCancelToken!.cancel('User cancelled');
      }
    }
  }

  Future<void> deleteModel({ModelType type = ModelType.gemma}) async {
    try {
      final modelPath = await getModelPath(type: type);
      final file = File(modelPath);
      if (await file.exists()) {
        await file.delete();
        
        if (type == ModelType.gemma) {
          _gemmaStatus = DownloadStatus.notDownloaded;
          _gemmaProgress = 0.0;
        } else {
          _miniLMStatus = DownloadStatus.notDownloaded;
          _miniLMProgress = 0.0;
        }
        notifyListeners();
        
        final modelName = type == ModelType.gemma ? 'Gemma' : 'MiniLM';
        print('🗑️ $modelName model deleted successfully');
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
