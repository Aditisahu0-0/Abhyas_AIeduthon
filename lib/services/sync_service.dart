import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';

enum SyncStatus { idle, syncing, success, error }

class SyncService extends ChangeNotifier {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final Dio _dio = Dio();
  final String _serverUrl = 'https://abhyas.teampavbhaji.dedyn.io';

  SyncStatus _status = SyncStatus.idle;
  DateTime? _lastSyncTime;
  String? _lastError;

  SyncStatus get status => _status;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get lastError => _lastError;

  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  Future<void> init() async {
    // Load last sync time
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt('last_sync_timestamp');
    if (timestamp != null) {
      _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    }

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      result,
    ) {
      if (result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet) {
        // Internet restored!
        triggerSync();
      }
    });

    notifyListeners();
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> triggerSync() async {
    if (_status == SyncStatus.syncing) return;

    // Double check connection
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) return;

    _status = SyncStatus.syncing;
    notifyListeners();

    if (kDebugMode) print("🔄 Starting Smart Sync...");

    try {
      final db = DatabaseHelper();
      final unsyncedAttempts = await db.getUnsyncedQuizAttempts();

      if (unsyncedAttempts.isEmpty) {
        if (kDebugMode) print("✅ Nothing to sync.");
        _status = SyncStatus.idle;
        notifyListeners();
        return;
      }

      if (kDebugMode) print("🚀 Syncing ${unsyncedAttempts.length} items...");

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        if (kDebugMode)
          print("❌ Sync failed: Not authenticated (No token found)");
        _status = SyncStatus.error;
        _lastError = "Not authenticated";
        notifyListeners();
        return;
      }

      // In a real app, you might batch these or send one by one.
      // Let's send a batch.
      final response = await _dio.post(
        '$_serverUrl/api/sync/progress',
        data: {'quiz_attempts': unsyncedAttempts},
        options: Options(
          validateStatus: (status) => status! < 500,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ), // Accept 400s to read errors
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Success! Mark as synced.
        final ids = unsyncedAttempts.map((e) => e['id'] as int).toList();
        await db.markQuizAttemptsAsSynced(ids);

        // Update timestamp
        _lastSyncTime = DateTime.now();
        await prefs.setInt(
          'last_sync_timestamp',
          _lastSyncTime!.millisecondsSinceEpoch,
        );

        _status = SyncStatus.success;
        if (kDebugMode) print("✅ Sync successful! ${ids.length} items synced.");

        // Reset to idle after a delay so the UI can show "Success" briefly
        Future.delayed(const Duration(seconds: 3), () {
          if (_status == SyncStatus.success) {
            // Keep status as success to show "Last synced just now"
            // or we could revert to idle. Let's keep success state or rely on lastSyncTime.
            notifyListeners();
          }
        });
      } else {
        if (kDebugMode)
          print("❌ Sync failed: ${response.statusCode} - ${response.data}");
        _status = SyncStatus.error;
        _lastError = "Server check failed: ${response.statusCode}";
      }
    } catch (e) {
      if (kDebugMode) print("❌ Sync error: $e");
      _status = SyncStatus.error;
      _lastError = e.toString();
    } finally {
      if (_status != SyncStatus.success && _status != SyncStatus.error) {
        _status = SyncStatus.idle;
      }
      notifyListeners();
    }
  }
}
