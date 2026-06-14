import 'package:uuid/uuid.dart';
import '../../models/sync_models.dart';

/// Field names that represent monetary or financial values.
/// For these fields, [ConflictResolutionStrategy.serverWins] is ALWAYS used
/// to guarantee financial correctness (rule #1 of the engineering charter).
const _financialFields = <String>{
  'amount',
  'targetAmount',
  'currentAmount',
  'spent',
  'monthlyContribution',
  'totalContributed',
  'contributionAmount',
  'percentage',
  'balance',
  'minimumBalance',
  'interestRate',
  'fee',
  'price',
  'value',
  'netWorth',
  'totalAssets',
  'totalLiabilities',
  'estimatedValue',
};

/// Field names that are always safe to auto-merge (non-conflicting metadata).
const _mergeableFields = <String>{
  'description',
  'note',
  'tags',
  'color',
  'icon',
  'isActive',
  'isFavorite',
  'order',
  'displayOrder',
};

/// Resolves conflicts between local and server records during offline sync.
///
/// Strategy (following the engineering charter priority):
/// 1. **Financial correctness** — monetary fields ALWAYS use server-wins.
/// 2. **Metadata** — last-write-wins (LWW) based on [updatedAt].
/// 3. **Auto-merge** — fields that only changed on one side are merged;
///    fields changed on both sides use LWW fallback.
///
/// All conflicts are logged as [ConflictRecord] for audit trail compliance.
class ConflictResolver {
  final List<ConflictRecord> _resolvedConflicts = [];

  /// Returns the list of conflicts resolved during the last sync cycle.
  List<ConflictRecord> get resolvedConflicts => List.unmodifiable(_resolvedConflicts);

  /// Clears the conflict log (call after reporting conflicts to the user).
  void clearLog() => _resolvedConflicts.clear();

  /// Resolve a conflict between a [localRecord] and a [serverRecord]
  /// for the given [entityType] and [localId].
  ///
  /// Returns a merged record that can be safely stored locally and pushed
  /// back to the server.
  Map<String, dynamic> resolve({
    required SyncEntityType entityType,
    required String localId,
    required Map<String, dynamic> localRecord,
    required Map<String, dynamic> serverRecord,
  }) {
    final conflictId = const Uuid().v4();
    final resolved = <String, dynamic>{};
    final conflictingFields = <String>[];
    final mergedFields = <String>{};

    // Determine which fields differ between local and server.
    final allKeys = <String>{...localRecord.keys, ...serverRecord.keys};

    for (final key in allKeys) {
      // Skip internal sync metadata fields.
      if (key == 'syncStatus' || key == 'serverUpdatedAt' || key == 'retryCount' || key == 'updatedAt') {
        continue;
      }

      final localVal = localRecord[key];
      final serverVal = serverRecord[key];

      // If both are identical, keep the value.
      if (_deepEquals(localVal, serverVal)) {
        resolved[key] = localVal ?? serverVal;
        continue;
      }

      // Only local has this field → keep local.
      if (!serverRecord.containsKey(key)) {
        resolved[key] = localVal;
        mergedFields.add(key);
        continue;
      }

      // Only server has this field → take server.
      if (!localRecord.containsKey(key)) {
        resolved[key] = serverVal;
        mergedFields.add(key);
        continue;
      }

      // Both sides have this field but differ → conflict resolution needed.
      if (_financialFields.contains(key)) {
        // FINANCIAL CORRECTNESS: Always trust the server for money fields.
        resolved[key] = serverVal;
        conflictingFields.add(key);
      } else if (_mergeableFields.contains(key)) {
        // Metadata fields: last-write-wins based on updatedAt.
        final localTime = _parseTimestamp(localRecord['updatedAt']);
        final serverTime = _parseTimestamp(serverRecord['updatedAt']);
        if (localTime != null && serverTime != null) {
          resolved[key] = localTime.isAfter(serverTime) ? localVal : serverVal;
        } else {
          resolved[key] = serverVal; // default to server if timestamps missing
        }
        mergedFields.add(key);
      } else {
        // Generic fields: last-write-wins.
        final localTime = _parseTimestamp(localRecord['updatedAt']);
        final serverTime = _parseTimestamp(serverRecord['updatedAt']);
        if (localTime != null && serverTime != null) {
          resolved[key] = localTime.isAfter(serverTime) ? localVal : serverVal;
        } else {
          resolved[key] = serverVal;
        }
        conflictingFields.add(key);
      }
    }

    // Ensure updatedAt reflects the resolution time.
    resolved['updatedAt'] = DateTime.now().toIso8601String();

    final strategy = conflictingFields.every((f) => _financialFields.contains(f))
        ? ConflictResolutionStrategy.serverWins
        : (conflictingFields.isEmpty
            ? ConflictResolutionStrategy.autoMerge
            : ConflictResolutionStrategy.lastWriteWins);

    final autoResolved = conflictingFields.every((f) => _financialFields.contains(f)) ||
        conflictingFields.isEmpty;

    final conflictRecord = ConflictRecord(
      id: conflictId,
      entityType: entityType,
      localId: localId,
      localSnapshot: Map.from(localRecord),
      serverSnapshot: Map.from(serverRecord),
      resolvedSnapshot: Map.from(resolved),
      conflictingFields: conflictingFields,
      strategy: strategy,
      autoResolved: autoResolved,
      resolvedAt: DateTime.now(),
    );

    _resolvedConflicts.add(conflictRecord);

    return resolved;
  }

  /// Detect whether a conflict exists between local and server state.
  /// Returns the list of fields that differ and are not trivially mergeable.
  List<String> detectConflicts({
    required Map<String, dynamic> localRecord,
    required Map<String, dynamic> serverRecord,
  }) {
    final conflicts = <String>[];
    final allKeys = <String>{...localRecord.keys, ...serverRecord.keys};

    for (final key in allKeys) {
      if (key == 'syncStatus' || key == 'serverUpdatedAt' || key == 'retryCount') {
        continue;
      }
      if (_deepEquals(localRecord[key], serverRecord[key])) continue;
      if (key == 'updatedAt') continue;

      // If only one side has the field, it's not a true conflict — it's mergeable.
      if (!localRecord.containsKey(key) || !serverRecord.containsKey(key)) continue;

      conflicts.add(key);
    }

    return conflicts;
  }

  DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  bool _deepEquals(dynamic a, dynamic b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_deepEquals(a[i], b[i])) return false;
      }
      return true;
    }
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!_deepEquals(a[key], b[key])) return false;
      }
      return true;
    }
    return a == b;
  }
}
