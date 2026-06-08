import 'dart:convert';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../data/datasources/local/local_database.dart';
import '../core/network/api_client.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final LocalDatabase _localDb = LocalDatabase.instance;
  final ApiClient _apiClient = ApiClient();
  StreamSubscription? _connectivitySubscription;
  bool _isSyncing = false;

  void start() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        syncPendingOperations();
      }
    });
  }

  void stop() {
    _connectivitySubscription?.cancel();
  }

  Future<void> syncPendingOperations() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final operations = await _localDb.getPendingOperations();

      for (final op in operations) {
        try {
          final data = op['data'] != null ? jsonDecode(op['data'] as String) : null;
          
          switch (op['operationType'] as String) {
            case 'POST':
              await _apiClient.post(op['endpoint'] as String, data: data);
              break;
            case 'PUT':
              await _apiClient.put(op['endpoint'] as String, data: data);
              break;
            case 'DELETE':
              await _apiClient.delete(op['endpoint'] as String);
              break;
          }

          await _localDb.removePendingOperation(op['id'] as int);
        } catch (e) {
          // Skip failed operations, try next time
          continue;
        }
      }
    } finally {
      _isSyncing = false;
    }
  }
}
