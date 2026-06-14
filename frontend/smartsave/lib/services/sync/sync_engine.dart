import 'dart:async';
import 'dart:developer' as developer;
import '../../data/datasources/local/local_database.dart';
import '../../core/network/api_client.dart';
import '../../models/sync_models.dart';
import 'conflict_resolver.dart';
import 'sync_queue_manager.dart';

/// Orchestrates the full offline sync lifecycle:
///
/// 1. **Push** — upload all pending local operations to the server
/// 2. **Pull** — download server changes since last sync
/// 3. **Resolve** — detect and resolve conflicts between local and server state
/// 4. **Reconcile** — update local database with resolved state
///
/// Sync state is exposed via a [Stream] for UI observation.
class SyncEngine {
  static final SyncEngine _instance = SyncEngine._internal();
  factory SyncEngine() => _instance;

  final LocalDatabase _localDb = LocalDatabase.instance;
  final ApiClient _apiClient = ApiClient();
  final SyncQueueManager _queueManager = SyncQueueManager();
  final ConflictResolver _conflictResolver = ConflictResolver();

  // Stream controller for sync state observation
  final StreamController<SyncStatusInfo> _statusController =
      StreamController<SyncStatusInfo>.broadcast();
  late final SyncStatusInfo _currentStatus;

  // Periodic sync timer
  Timer? _periodicTimer;
  Duration _periodicInterval = const Duration(minutes: 5);

  // Sync lock to prevent concurrent syncs
  bool _isSyncing = false;

  SyncEngine._internal() : _currentStatus = SyncStatusInfo(
    lastSyncAt: DateTime.now(),
  );

  /// Stream of sync status updates (for UI observation).
  Stream<SyncStatusInfo> get statusStream => _statusController.stream;

  /// Current sync status snapshot.
  SyncStatusInfo get currentStatus => _currentStatus;

  /// Whether a sync cycle is currently in progress.
  bool get isSyncing => _isSyncing;

  /// Configure the periodic sync interval.
  void setPeriodicInterval(Duration interval) {
    _periodicInterval = interval;
    if (_periodicTimer != null && _periodicTimer!.isActive) {
      _periodicTimer?.cancel();
      _periodicTimer = Timer.periodic(_periodicInterval, (_) => sync());
    }
  }

  /// Start periodic background sync.
  void startPeriodicSync() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(_periodicInterval, (_) => sync());
  }

  /// Stop periodic background sync.
  void stopPeriodicSync() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  /// Trigger a full sync cycle.
  /// Returns `true` if sync completed without errors.
  Future<bool> sync() async {
    if (_isSyncing) return false;
    _isSyncing = true;

    try {
      await _updateStatus(SyncState.uploading);

      // Phase 1: Push pending operations
      final pushResult = await _pushPendingOperations();
      if (!pushResult) {
        await _updateStatus(
          SyncState.failed,
          errorMessage: 'Failed to push pending operations',
        );
        return false;
      }

      await _updateStatus(SyncState.downloading);

      // Phase 2: Pull server changes for each entity type
      final pullErrors = <String>[];
      for (final entityType in SyncEntityType.values) {
        try {
          await _pullEntityChanges(entityType);
        } catch (e) {
          pullErrors.add('$entityType: $e');
          developer.log('[SyncEngine] Pull failed for $entityType: $e');
        }
      }

      if (pullErrors.isNotEmpty) {
        await _updateStatus(
          SyncState.failed,
          errorMessage: 'Pull errors: ${pullErrors.join('; ')}',
        );
        return false;
      }

      await _updateStatus(SyncState.completed);
      return true;
    } catch (e) {
      developer.log('[SyncEngine] Sync failed: $e');
      await _updateStatus(SyncState.failed, errorMessage: e.toString());
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  /// Phase 1: Push all pending operations to the server.
  /// Resolves conflicts when they arise during push.
  Future<bool> _pushPendingOperations() async {
    final operations = await _queueManager.getPendingOperations();
    if (operations.isEmpty) return true;

    for (final op in operations) {
      final error = await _queueManager.executeOperation(op);

      if (error == null) {
        // Success — remove from queue
        await _queueManager.markCompleted(op);
      } else if (error.startsWith('CONFLICT:')) {
        // Conflict detected — resolve before retrying
        final resolved = await _resolveConflict(op);
        if (resolved) {
          await _queueManager.markCompleted(op);
        } else {
          final isDeadLetter = await _queueManager.markFailed(op, error);
          if (isDeadLetter) {
            await _queueManager.deadLetter(op, error);
          }
        }
      } else {
        // Transient failure — increment retry count
        final isDeadLetter = await _queueManager.markFailed(op, error);
        if (isDeadLetter) {
          await _queueManager.deadLetter(op, error);
        }
      }

      // Brief delay between operations to avoid overwhelming the server
      await Future.delayed(const Duration(milliseconds: 100));
    }

    return true;
  }

  /// Resolve a conflict that occurred during push.
  /// Fetches the current server state, resolves, and optionally retries.
  Future<bool> _resolveConflict(PendingOperation op) async {
    try {
      // Fetch the server's current state for this resource
      final getResult = await _apiClient.get(op.endpoint);
      final rawData = getResult.dataOrNull;
      if (rawData == null) {
        developer.log('[SyncEngine] Cannot resolve conflict — server record not found for ${op.endpoint}');
        return false;
      }
      final serverData = rawData['data'] as Map<String, dynamic>? ?? rawData;

      // The local data that failed to push
      final localData = op.data ?? {};

      // Infer entity type from endpoint
      final entityType = _inferEntityType(op.endpoint);
      final localId = serverData['_id'] as String? ?? serverData['id'] as String? ?? '';

      // Resolve the conflict
      final resolved = _conflictResolver.resolve(
        entityType: entityType,
        localId: localId,
        localRecord: localData,
        serverRecord: serverData,
      );

      // If server-wins was used, no need to push — just update local
      // If client values were chosen, push the resolved record
      final strategyUsed = _conflictResolver.resolvedConflicts.isNotEmpty
          ? _conflictResolver.resolvedConflicts.last.strategy
          : ConflictResolutionStrategy.serverWins;

      if (strategyUsed == ConflictResolutionStrategy.serverWins) {
        // Update local with server's version
        final tableName = _entityTypeToTable(entityType);
        await _localDb.upsertWithSyncMetadata(
          tableName,
          serverData,
          updatedAt: serverData['updatedAt'] as String? ?? DateTime.now().toIso8601String(),
          syncStatus: 'synced',
          serverUpdatedAt: serverData['updatedAt'] as String?,
        );
        return true;
      } else {
        // Push resolved record to server
        final putResult = await _apiClient.put(op.endpoint, data: resolved);
        return putResult.isSuccess;
      }
    } catch (e) {
      developer.log('[SyncEngine] Conflict resolution failed: $e');
      return false;
    }
  }

  /// Phase 2: Pull changes for a specific entity type from the server.
  Future<void> _pullEntityChanges(SyncEntityType entityType) async {
    final endpoint = _entityTypeToEndpoint(entityType);
    final tableName = _entityTypeToTable(entityType);

    // Get last sync timestamp for incremental pull
    final lastSync = await _localDb.getLastSyncTimestamp(tableName);
    final queryParams = <String, dynamic>{
      if (lastSync != null) 'updatedSince': lastSync.toIso8601String(),
      'limit': 100,
    };

    final result = await _apiClient.get(endpoint, queryParameters: queryParams);
    result.fold(
      (data) {
        final records = data['data'] as List<dynamic>? ?? [];
        for (final record in records) {
          if (record is! Map) continue;
          // Fire-and-forget each reconciliation; errors are logged inside _reconcileRecord
          _reconcileRecord(
            entityType: entityType,
            tableName: tableName,
            serverRecord: Map<String, dynamic>.from(record),
          );
        }
      },
      (_) {
        // If pull fails, we'll retry next sync cycle
        developer.log('[SyncEngine] Pull failed for $entityType — will retry next cycle');
      },
    );
  }

  /// Reconcile a server record with the local database.
  /// Detects conflicts and resolves them automatically.
  Future<void> _reconcileRecord({
    required SyncEntityType entityType,
    required String tableName,
    required Map<String, dynamic> serverRecord,
  }) async {
    final serverId = serverRecord['_id'] as String? ?? serverRecord['id'] as String?;
    if (serverId == null) return;

    // Normalize: use 'id' as primary key consistently
    final normalizedRecord = Map<String, dynamic>.from(serverRecord);
    if (normalizedRecord.containsKey('_id') && !normalizedRecord.containsKey('id')) {
      normalizedRecord['id'] = normalizedRecord['_id'];
    }

    // Check if we have a local copy
    final localRows = await _localDb.query(
      tableName,
      where: 'id = ?',
      whereArgs: [serverId],
      limit: 1,
    );

    if (localRows.isEmpty) {
      // New record from server — insert locally
      await _localDb.upsertWithSyncMetadata(
        tableName,
        normalizedRecord,
        updatedAt: normalizedRecord['updatedAt'] as String? ?? DateTime.now().toIso8601String(),
        syncStatus: 'synced',
        serverUpdatedAt: normalizedRecord['updatedAt'] as String?,
      );
    } else {
      // Existing local record — check sync status
      final localRow = localRows.first;
      final localSyncStatus = localRow['syncStatus'] as String? ?? 'synced';

      if (localSyncStatus == 'synced') {
        // Both synced — overwrite with server version (server is authoritative)
        await _localDb.upsertWithSyncMetadata(
          tableName,
          normalizedRecord,
          updatedAt: normalizedRecord['updatedAt'] as String? ?? DateTime.now().toIso8601String(),
          syncStatus: 'synced',
          serverUpdatedAt: normalizedRecord['updatedAt'] as String?,
        );
      } else if (localSyncStatus == 'pending') {
        // Local has pending changes — check for conflicts
        final conflicts = _conflictResolver.detectConflicts(
          localRecord: localRow,
          serverRecord: normalizedRecord,
        );

        if (conflicts.isEmpty) {
          // No actual conflict — server changes are on different fields.
          // Merge by applying pending local changes on top of server state.
          // Since the pending operation is in the queue, it will be pushed
          // and the server will apply it. For now, update local with server data.
          await _localDb.upsertWithSyncMetadata(
            tableName,
            normalizedRecord,
            updatedAt: localRow['updatedAt'] as String? ?? DateTime.now().toIso8601String(),
            syncStatus: 'pending',
            serverUpdatedAt: normalizedRecord['updatedAt'] as String?,
          );
        } else {
          // Real conflict — resolve automatically
          final serverUpdatedAt = normalizedRecord['updatedAt'] as String?;

          // Merge local pending data with server data for non-conflicting fields
          final resolved = _conflictResolver.resolve(
            entityType: entityType,
            localId: serverId,
            localRecord: localRow,
            serverRecord: normalizedRecord,
          );

          await _localDb.upsertWithSyncMetadata(
            tableName,
            resolved,
            updatedAt: resolved['updatedAt'] as String? ?? DateTime.now().toIso8601String(),
            syncStatus: 'synced',
            serverUpdatedAt: serverUpdatedAt ?? normalizedRecord['updatedAt'] as String?,
          );

          // If client values were preferred, push the resolved version
          final lastConflict = _conflictResolver.resolvedConflicts.isNotEmpty
              ? _conflictResolver.resolvedConflicts.last
              : null;
          if (lastConflict != null &&
              lastConflict.strategy != ConflictResolutionStrategy.serverWins) {
            await _queueManager.enqueue(
              operationType: 'PUT',
              endpoint: '${_entityTypeToEndpoint(entityType)}/$serverId',
              data: resolved,
            );
          }
        }
      } else if (localSyncStatus == 'conflict') {
        // Previously flagged conflict — resolve automatically
        final resolved = _conflictResolver.resolve(
          entityType: entityType,
          localId: serverId,
          localRecord: localRow,
          serverRecord: normalizedRecord,
        );

        await _localDb.upsertWithSyncMetadata(
          tableName,
          resolved,
          updatedAt: resolved['updatedAt'] as String? ?? DateTime.now().toIso8601String(),
          syncStatus: 'synced',
          serverUpdatedAt: normalizedRecord['updatedAt'] as String?,
        );
      }
    }
  }

  /// Update the sync status and notify listeners.
  Future<void> _updateStatus(SyncState state, {String? errorMessage}) async {
    final conflicts = _conflictResolver.resolvedConflicts;
    _currentStatus = SyncStatusInfo(
      state: state,
      lastSyncAt: state == SyncState.completed ? DateTime.now() : _currentStatus.lastSyncAt,
      pendingOperations: state == SyncState.completed ? 0 : _currentStatus.pendingOperations,
      conflictsCount: conflicts.length,
      errorMessage: errorMessage,
    );

    // Update pending count from queue
    _currentStatus = SyncStatusInfo(
      state: _currentStatus.state,
      lastSyncAt: _currentStatus.lastSyncAt,
      pendingOperations: await _queueManager.pendingCount(),
      conflictsCount: conflicts.length,
      errorMessage: errorMessage,
    );

    _statusController.add(_currentStatus);
  }

  /// Get the current conflict log.
  List<ConflictRecord> get conflictLog => _conflictResolver.resolvedConflicts;

  /// Clear the conflict log.
  void clearConflictLog() => _conflictResolver.clearLog();

  // ── Mapping Helpers ──

  /// Infer the entity type from an API endpoint path.
  SyncEntityType _inferEntityType(String endpoint) {
    if (endpoint.contains('/transactions')) return SyncEntityType.transaction;
    if (endpoint.contains('/goals')) return SyncEntityType.goal;
    if (endpoint.contains('/budgets')) return SyncEntityType.budget;
    if (endpoint.contains('/auto-save') || endpoint.contains('/autosave')) {
      return SyncEntityType.autoSaveRule;
    }
    if (endpoint.contains('/subscriptions')) return SyncEntityType.subscription;
    if (endpoint.contains('/recurring')) return SyncEntityType.recurringTransaction;
    if (endpoint.contains('/net-worth') || endpoint.contains('/networth')) {
      return SyncEntityType.netWorthEntry;
    }
    return SyncEntityType.transaction;
  }

  /// Map entity type to local database table name.
  String _entityTypeToTable(SyncEntityType type) {
    switch (type) {
      case SyncEntityType.transaction:
        return 'transactions';
      case SyncEntityType.goal:
        return 'goals';
      case SyncEntityType.budget:
        return 'budgets';
      case SyncEntityType.autoSaveRule:
      case SyncEntityType.subscription:
      case SyncEntityType.recurringTransaction:
      case SyncEntityType.netWorthEntry:
        // These entity types don't have dedicated tables yet —
        // they are cached via CacheManager. Return empty to skip table sync.
        return '';
    }
  }

  /// Map entity type to API endpoint.
  String _entityTypeToEndpoint(SyncEntityType type) {
    switch (type) {
      case SyncEntityType.transaction:
        return '/transactions';
      case SyncEntityType.goal:
        return '/goals';
      case SyncEntityType.budget:
        return '/budgets';
      case SyncEntityType.autoSaveRule:
        return '/auto-save/rules';
      case SyncEntityType.subscription:
        return '/subscriptions';
      case SyncEntityType.recurringTransaction:
        return '/recurring';
      case SyncEntityType.netWorthEntry:
        return '/net-worth';
    }
  }

  /// Dispose resources.
  void dispose() {
    stopPeriodicSync();
    _statusController.close();
  }
}
