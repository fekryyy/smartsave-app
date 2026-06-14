import 'dart:async';
import 'dart:developer' as developer;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../data/datasources/local/local_database.dart';
import '../models/sync_models.dart';
import 'sync/sync_engine.dart';
import 'sync/sync_queue_manager.dart';

/// Facade service that manages offline sync lifecycle:
///
/// - Listens for connectivity changes (reconnects trigger sync)
/// - Exposes sync status via a [Stream] for UI observation
/// - Delegates to [SyncEngine] for full sync orchestration
/// - Delegates to [SyncQueueManager] for queue management
///
/// Usage:
/// ```dart
/// final syncService = SyncService();
/// syncService.start();
///
/// // Observe sync status in UI:
/// syncService.statusStream.listen((status) { ... });
///
/// // Enqueue an offline operation:
/// await syncService.enqueuePending('POST', '/transactions', data);
/// ```
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final LocalDatabase _localDb = LocalDatabase.instance;
  final SyncEngine _engine = SyncEngine();
  final SyncQueueManager _queueManager = SyncQueueManager();
  final Connectivity _connectivity = Connectivity();

  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _isStarted = false;

  // ── Lifecycle ──

  /// Start the sync service.
  ///
  /// Initializes connectivity listeners and periodic background sync.
  /// Safe to call multiple times — subsequent calls are no-ops.
  void start() {
    if (_isStarted) return;
    _isStarted = true;

    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);

    // Start periodic background sync
    _engine.startPeriodicSync();

    // Attempt initial sync if online
    _checkAndSync();

    developer.log('[SyncService] Started — periodic sync enabled');
  }

  /// Stop the sync service.
  ///
  /// Cancels connectivity listeners and periodic sync timer.
  void stop() {
    if (!_isStarted) return;
    _isStarted = false;

    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _engine.stopPeriodicSync();

    developer.log('[SyncService] Stopped');
  }

  /// Whether the sync service is running.
  bool get isStarted => _isStarted;

  // ── Connectivity Handling ──

  void _onConnectivityChanged(ConnectivityResult result) {
    final isConnected = result != ConnectivityResult.none;

    if (isConnected) {
      developer.log('[SyncService] Connectivity restored — triggering sync');
      _engine.sync();
    } else {
      developer.log('[SyncService] Connectivity lost');
    }
  }

  Future<void> _checkAndSync() async {
    try {
      final result = await _connectivity.checkConnectivity();
      if (result != ConnectivityResult.none) {
        _engine.sync();
      }
    } catch (_) {
      // Connectivity check failed — will retry on next event
    }
  }

  // ── Public API ──

  /// Trigger a full sync cycle immediately.
  /// Returns `true` if sync completed successfully.
  Future<bool> syncNow() => _engine.sync();

  /// Enqueue a pending operation for offline sync.
  ///
  /// The operation will be persisted locally and synced when connectivity
  /// is available. An idempotency key is auto-generated for deduplication.
  Future<int> enqueuePending(
    String operationType,
    String endpoint,
    Map<String, dynamic>? data,
  ) async {
    final id = await _queueManager.enqueue(
      operationType: operationType,
      endpoint: endpoint,
      data: data,
    );

    developer.log('[SyncService] Enqueued $operationType $endpoint (id=$id)');
    return id;
  }

  /// Mark a local record as having pending (unsynced) changes.
  Future<void> markRecordPending(String table, String id) async {
    await _localDb.markPending(table, id);
  }

  /// Mark a local record as successfully synced.
  Future<void> markRecordSynced(String table, String id, {String? serverUpdatedAt}) async {
    await _localDb.markSynced(table, id, serverUpdatedAt: serverUpdatedAt);
  }

  /// Get the current count of pending operations.
  Future<int> pendingOperationCount() => _queueManager.pendingCount();

  /// Get the current sync status.
  SyncStatusInfo get currentStatus => _engine.currentStatus;

  /// Stream of sync status updates (for UI observation).
  Stream<SyncStatusInfo> get statusStream => _engine.statusStream;

  /// Whether a sync cycle is currently in progress.
  bool get isSyncing => _engine.isSyncing;

  /// Get the conflict log from the last sync cycle.
  List<ConflictRecord> get conflictLog => _engine.conflictLog;

  /// Clear the conflict log.
  void clearConflictLog() => _engine.clearConflictLog();

  /// Set the periodic sync interval.
  void setPeriodicInterval(Duration interval) {
    _engine.setPeriodicInterval(interval);
  }

  /// Clear all pending operations.
  Future<void> clearPendingOperations() => _queueManager.clearAll();

  /// Dispose resources.
  void dispose() {
    stop();
    _engine.dispose();
  }
}
