/// Represents the sync state of a local record relative to the server.
enum SyncStatus {
  /// Record is in sync with the server (no local changes pending).
  synced,

  /// Record has local changes that haven't been pushed to the server yet.
  pending,

  /// Conflict detected — both local and server changed the same fields.
  /// Requires manual or automatic resolution.
  conflict;

  String toJson() => name;
  static SyncStatus fromJson(String json) =>
      SyncStatus.values.firstWhere((e) => e.name == json, orElse: () => SyncStatus.synced);
}

/// Entity types that support offline sync.
enum SyncEntityType {
  transaction,
  goal,
  budget,
  autoSaveRule,
  subscription,
  recurringTransaction,
  netWorthEntry;

  String toJson() => name;
  static SyncEntityType fromJson(String json) =>
      SyncEntityType.values.firstWhere((e) => e.name == json, orElse: () => SyncEntityType.transaction);
}

/// Strategy used to resolve a conflict.
enum ConflictResolutionStrategy {
  /// Server's version is authoritative (used for monetary fields).
  serverWins,

  /// Client's (local) version is authoritative.
  clientWins,

  /// The record with the most recent [updatedAt] timestamp wins.
  lastWriteWins,

  /// Fields that only changed on one side are merged;
  /// fields changed on both sides use server-wins fallback.
  autoMerge;

  String toJson() => name;
  static ConflictResolutionStrategy fromJson(String json) =>
      ConflictResolutionStrategy.values.firstWhere((e) => e.name == json, orElse: () => ConflictResolutionStrategy.serverWins);
}

/// Immutable record of a resolved conflict, stored for auditability.
class ConflictRecord {
  final String id;
  final SyncEntityType entityType;
  final String localId;
  final Map<String, dynamic> localSnapshot;
  final Map<String, dynamic> serverSnapshot;
  final Map<String, dynamic> resolvedSnapshot;
  final List<String> conflictingFields;
  final ConflictResolutionStrategy strategy;
  final bool autoResolved;
  final DateTime resolvedAt;

  const ConflictRecord({
    required this.id,
    required this.entityType,
    required this.localId,
    required this.localSnapshot,
    required this.serverSnapshot,
    required this.resolvedSnapshot,
    required this.conflictingFields,
    required this.strategy,
    required this.autoResolved,
    required this.resolvedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'entityType': entityType.toJson(),
        'localId': localId,
        'localSnapshot': localSnapshot,
        'serverSnapshot': serverSnapshot,
        'resolvedSnapshot': resolvedSnapshot,
        'conflictingFields': conflictingFields,
        'strategy': strategy.toJson(),
        'autoResolved': autoResolved,
        'resolvedAt': resolvedAt.toIso8601String(),
      };

  factory ConflictRecord.fromJson(Map<String, dynamic> json) => ConflictRecord(
        id: json['id'] as String,
        entityType: SyncEntityType.fromJson(json['entityType'] as String),
        localId: json['localId'] as String,
        localSnapshot: Map<String, dynamic>.from(json['localSnapshot'] as Map),
        serverSnapshot: Map<String, dynamic>.from(json['serverSnapshot'] as Map),
        resolvedSnapshot: Map<String, dynamic>.from(json['resolvedSnapshot'] as Map),
        conflictingFields: List<String>.from(json['conflictingFields'] as List),
        strategy: ConflictResolutionStrategy.fromJson(json['strategy'] as String),
        autoResolved: json['autoResolved'] as bool,
        resolvedAt: DateTime.parse(json['resolvedAt'] as String),
      );
}

/// Sync metadata stored per record in the local database.
class SyncMetadata {
  /// ISO-8601 timestamp of the last local modification.
  final DateTime updatedAt;

  /// Current sync status of this record.
  final SyncStatus syncStatus;

  /// Server's version timestamp as of last successful sync.
  /// Used to detect whether the server has moved on since we last synced.
  final DateTime? serverUpdatedAt;

  /// Number of times this record has failed to sync consecutively.
  final int retryCount;

  const SyncMetadata({
    required this.updatedAt,
    this.syncStatus = SyncStatus.synced,
    this.serverUpdatedAt,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'updatedAt': updatedAt.toIso8601String(),
        'syncStatus': syncStatus.toJson(),
        'serverUpdatedAt': serverUpdatedAt?.toIso8601String(),
        'retryCount': retryCount,
      };

  factory SyncMetadata.fromJson(Map<String, dynamic> json) => SyncMetadata(
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        syncStatus: SyncStatus.fromJson(json['syncStatus'] as String? ?? 'synced'),
        serverUpdatedAt: json['serverUpdatedAt'] != null ? DateTime.parse(json['serverUpdatedAt'] as String) : null,
        retryCount: json['retryCount'] as int? ?? 0,
      );

  SyncMetadata copyWith({
    DateTime? updatedAt,
    SyncStatus? syncStatus,
    DateTime? serverUpdatedAt,
    int? retryCount,
  }) =>
      SyncMetadata(
        updatedAt: updatedAt ?? this.updatedAt,
        syncStatus: syncStatus ?? this.syncStatus,
        serverUpdatedAt: serverUpdatedAt ?? this.serverUpdatedAt,
        retryCount: retryCount ?? this.retryCount,
      );
}

/// Tracks the overall sync state machine.
enum SyncState {
  /// Sync is idle (waiting for connectivity or timer).
  idle,

  /// Currently pushing local pending operations to the server.
  uploading,

  /// Currently pulling server changes to the local database.
  downloading,

  /// Conflict resolution phase.
  resolving,

  /// Sync completed successfully.
  completed,

  /// Sync encountered errors.
  failed,
}

/// Overall sync status exposed to UI layers.
class SyncStatusInfo {
  final SyncState state;
  final DateTime lastSyncAt;
  final int pendingOperations;
  final int conflictsCount;
  final String? errorMessage;

  const SyncStatusInfo({
    this.state = SyncState.idle,
    required this.lastSyncAt,
    this.pendingOperations = 0,
    this.conflictsCount = 0,
    this.errorMessage,
  });

  bool get isSyncing =>
      state == SyncState.uploading ||
      state == SyncState.downloading ||
      state == SyncState.resolving;
}
