import 'dart:convert';
import 'dart:math';
import 'package:uuid/uuid.dart';
import '../../data/datasources/local/local_database.dart';
import '../../core/network/api_client.dart';
import '../../core/network/result.dart';
import '../../core/errors/failures.dart';

/// Represents a single pending operation in the sync queue.
class PendingOperation {
  final int? id;
  final String operationId; // idempotency key
  final String operationType; // POST | PUT | DELETE
  final String endpoint;
  final Map<String, dynamic>? data;
  final DateTime createdAt;
  final int retryCount;
  final String? lastError;
  final DateTime? lastAttemptAt;

  const PendingOperation({
    this.id,
    required this.operationId,
    required this.operationType,
    required this.endpoint,
    this.data,
    required this.createdAt,
    this.retryCount = 0,
    this.lastError,
    this.lastAttemptAt,
  });

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'operationId': operationId,
        'operationType': operationType,
        'endpoint': endpoint,
        'data': data != null ? jsonEncode(data) : null,
        'createdAt': createdAt.toIso8601String(),
        'retryCount': retryCount,
        'lastError': lastError,
        'lastAttemptAt': lastAttemptAt?.toIso8601String(),
      };

  factory PendingOperation.fromRow(Map<String, dynamic> row) => PendingOperation(
        id: row['id'] as int?,
        operationId: row['operationId'] as String? ?? '',
        operationType: row['operationType'] as String,
        endpoint: row['endpoint'] as String,
        data: row['data'] != null ? jsonDecode(row['data'] as String) as Map<String, dynamic>? : null,
        createdAt: DateTime.parse(row['createdAt'] as String),
        retryCount: row['retryCount'] as int? ?? 0,
        lastError: row['lastError'] as String?,
        lastAttemptAt: row['lastAttemptAt'] != null ? DateTime.tryParse(row['lastAttemptAt'] as String) : null,
      );

  PendingOperation copyWith({
    int? id,
    String? operationId,
    String? operationType,
    String? endpoint,
    Map<String, dynamic>? data,
    DateTime? createdAt,
    int? retryCount,
    String? lastError,
    DateTime? lastAttemptAt,
  }) =>
      PendingOperation(
        id: id ?? this.id,
        operationId: operationId ?? this.operationId,
        operationType: operationType ?? this.operationType,
        endpoint: endpoint ?? this.endpoint,
        data: data ?? this.data,
        createdAt: createdAt ?? this.createdAt,
        retryCount: retryCount ?? this.retryCount,
        lastError: lastError ?? this.lastError,
        lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      );
}

/// Manages the offline operation queue with:
/// - Idempotency keys for each operation
/// - Retry count tracking with exponential backoff
/// - Dead letter threshold (max retries before abandonment)
/// - Operation deduplication
class SyncQueueManager {
  static final SyncQueueManager _instance = SyncQueueManager._internal();
  factory SyncQueueManager() => _instance;
  SyncQueueManager._internal();

  final LocalDatabase _localDb = LocalDatabase.instance;
  final ApiClient _apiClient = ApiClient();

  /// Maximum number of retry attempts before an operation is dead-lettered.
  static const int maxRetries = 5;

  /// Base delay for exponential backoff (in seconds).
  static const int baseBackoffSeconds = 2;

  /// Maximum backoff delay (in seconds).
  static const int maxBackoffSeconds = 120;

  /// Enqueue a new pending operation.
  /// Generates a unique idempotency key if not provided.
  Future<int> enqueue({
    required String operationType,
    required String endpoint,
    Map<String, dynamic>? data,
    String? operationId,
  }) async {
    final opId = operationId ?? const Uuid().v4();

    // Deduplicate: if the exact same operationId exists, skip.
    final existing = await _localDb.query(
      'pending_operations',
      where: 'operationId = ?',
      whereArgs: [opId],
    );
    if (existing.isNotEmpty) {
      return existing.first['id'] as int;
    }

    return await _localDb.addPendingOperation(
      operationType,
      endpoint,
      jsonEncode(data),
      operationId: opId,
    );
  }

  /// Get all pending operations ordered by creation time (FIFO).
  Future<List<PendingOperation>> getPendingOperations() async {
    final rows = await _localDb.getPendingOperations();
    return rows.map(PendingOperation.fromRow).toList();
  }

  /// Get the count of pending operations.
  Future<int> pendingCount() async {
    final ops = await getPendingOperations();
    return ops.length;
  }

  /// Attempt to execute a single pending operation.
  /// Returns `null` on success, or an error message string on failure.
  Future<String?> executeOperation(PendingOperation op) async {
    try {
      final headers = <String, dynamic>{
        'X-Idempotency-Key': op.operationId,
      };

      // Add entity-tag for optimistic concurrency on PUT
      if (op.operationType == 'PUT' && op.data != null && op.data!.containsKey('updatedAt')) {
        headers['X-Client-Version'] = op.data!['updatedAt'] as String;
      }

      Result<Map<String, dynamic>> result;

      switch (op.operationType) {
        case 'POST':
          result = await _apiClient.post(op.endpoint, data: op.data);
          break;
        case 'PUT':
          result = await _apiClient.put(op.endpoint, data: op.data);
          break;
        case 'DELETE':
          result = await _apiClient.delete(op.endpoint);
          break;
        default:
          return 'Unknown operation type: ${op.operationType}';
      }

      if (result.isSuccess) return null; // success

      final failure = result.failureOrNull;
      if (failure is ConflictFailure) {
        return 'CONFLICT:${failure.message}';
      }
      return failure?.message ?? 'Unknown error';
    } catch (e) {
      return e.toString();
    }
  }

  /// Mark an operation as failed: increment retry count and record error.
  /// Returns `true` if the operation has exceeded max retries (dead letter).
  Future<bool> markFailed(PendingOperation op, String error) async {
    final newRetryCount = op.retryCount + 1;
    final isDeadLetter = newRetryCount >= maxRetries;

    final db = await _localDb.database;
    await db.update(
      'pending_operations',
      {
        'retryCount': newRetryCount,
        'lastError': error,
        'lastAttemptAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [op.id],
    );

    return isDeadLetter;
  }

  /// Remove a successfully executed operation from the queue.
  Future<void> markCompleted(PendingOperation op) async {
    if (op.id != null) {
      await _localDb.removePendingOperation(op.id!);
    }
  }

  /// Dead-letter an operation (remove from active queue after max retries).
  /// The operation data is preserved in a dead-letter log for audit.
  Future<void> deadLetter(PendingOperation op, String error) async {
    // Log the dead-lettered operation in a dedicated table for audit.
    final db = await _localDb.database;
    await db.insert('dead_letter_operations', {
      'operationId': op.operationId,
      'operationType': op.operationType,
      'endpoint': op.endpoint,
      'data': op.data != null ? jsonEncode(op.data) : null,
      'retryCount': op.retryCount,
      'lastError': error,
      'createdAt': op.createdAt.toIso8601String(),
      'deadLetteredAt': DateTime.now().toIso8601String(),
    });

    // Remove from active queue.
    if (op.id != null) {
      await _localDb.removePendingOperation(op.id!);
    }
  }

  /// Calculate the backoff delay for a given retry count.
  Duration backoffDelay(int retryCount) {
    final seconds = min(
      maxBackoffSeconds,
      baseBackoffSeconds * pow(2, retryCount).toInt(),
    );
    // Add jitter: ±25% random variation
    final jitter = Random().nextInt((seconds * 0.5).ceil()) - (seconds * 0.25).ceil();
    return Duration(seconds: max(1, seconds + jitter));
  }

  /// Clear all pending operations.
  Future<void> clearAll() async {
    await _localDb.clearUnsynced();
  }
}
