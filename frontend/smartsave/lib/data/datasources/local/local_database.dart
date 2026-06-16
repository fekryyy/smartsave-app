import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Local SQLite database for offline storage and sync queue management.
///
/// Schema versions:
///   v1 — initial schema with transactions, goals, budgets, pending_operations
///   v2 — adds updatedAt/syncStatus/serverVersion columns, dead_letter_operations table,
///         and operationId/retry tracking fields on pending_operations
class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;

  LocalDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('smartsave.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  // ── Schema Creation (v2 — fresh install) ──

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        description TEXT,
        date TEXT NOT NULL,
        paymentMethod TEXT,
        currency TEXT DEFAULT 'USD',
        isSynced INTEGER DEFAULT 0,
        createdAt TEXT,
        updatedAt TEXT,
        syncStatus TEXT DEFAULT 'synced',
        serverUpdatedAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE goals (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        targetAmount REAL NOT NULL,
        currentAmount REAL DEFAULT 0,
        targetDate TEXT,
        category TEXT,
        status TEXT DEFAULT 'active',
        monthlyContribution REAL DEFAULT 0,
        isSynced INTEGER DEFAULT 0,
        createdAt TEXT,
        updatedAt TEXT,
        syncStatus TEXT DEFAULT 'synced',
        serverUpdatedAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE budgets (
        id TEXT PRIMARY KEY,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        spent REAL DEFAULT 0,
        month INTEGER NOT NULL,
        year INTEGER NOT NULL,
        isSynced INTEGER DEFAULT 0,
        updatedAt TEXT,
        syncStatus TEXT DEFAULT 'synced',
        serverUpdatedAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE pending_operations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operationId TEXT NOT NULL,
        operationType TEXT NOT NULL,
        endpoint TEXT NOT NULL,
        data TEXT,
        createdAt TEXT NOT NULL,
        retryCount INTEGER DEFAULT 0,
        lastError TEXT,
        lastAttemptAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE dead_letter_operations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operationId TEXT NOT NULL,
        operationType TEXT NOT NULL,
        endpoint TEXT NOT NULL,
        data TEXT,
        retryCount INTEGER DEFAULT 0,
        lastError TEXT,
        createdAt TEXT NOT NULL,
        deadLetteredAt TEXT NOT NULL
      )
    ''');
  }

  // ── Schema Migration (v1 → v2) ──

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add sync tracking columns to transactions
      await _addColumnIfNotExists(db, 'transactions', 'updatedAt', 'TEXT');
      await _addColumnIfNotExists(db, 'transactions', 'syncStatus', "TEXT DEFAULT 'synced'");
      await _addColumnIfNotExists(db, 'transactions', 'serverUpdatedAt', 'TEXT');

      // Add sync tracking columns to goals
      await _addColumnIfNotExists(db, 'goals', 'updatedAt', 'TEXT');
      await _addColumnIfNotExists(db, 'goals', 'syncStatus', "TEXT DEFAULT 'synced'");
      await _addColumnIfNotExists(db, 'goals', 'serverUpdatedAt', 'TEXT');

      // Add sync tracking columns to budgets
      await _addColumnIfNotExists(db, 'budgets', 'updatedAt', 'TEXT');
      await _addColumnIfNotExists(db, 'budgets', 'syncStatus', "TEXT DEFAULT 'synced'");
      await _addColumnIfNotExists(db, 'budgets', 'serverUpdatedAt', 'TEXT');

      // Add retry tracking columns to pending_operations
      await _addColumnIfNotExists(db, 'pending_operations', 'operationId', 'TEXT');
      await _addColumnIfNotExists(db, 'pending_operations', 'retryCount', 'INTEGER DEFAULT 0');
      await _addColumnIfNotExists(db, 'pending_operations', 'lastError', 'TEXT');
      await _addColumnIfNotExists(db, 'pending_operations', 'lastAttemptAt', 'TEXT');

      // Populate operationId for existing rows that may have NULL
      await db.execute('''
        UPDATE pending_operations 
        SET operationId = 'legacy-' || id 
        WHERE operationId IS NULL OR operationId = ''
      ''');

      // Create dead_letter_operations table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS dead_letter_operations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          operationId TEXT NOT NULL,
          operationType TEXT NOT NULL,
          endpoint TEXT NOT NULL,
          data TEXT,
          retryCount INTEGER DEFAULT 0,
          lastError TEXT,
          createdAt TEXT NOT NULL,
          deadLetteredAt TEXT NOT NULL
        )
      ''');
    }

    // Backfill updatedAt from createdAt for existing records
    await db.execute('''
      UPDATE transactions SET updatedAt = createdAt WHERE updatedAt IS NULL
    ''');
    await db.execute('''
      UPDATE goals SET updatedAt = createdAt WHERE updatedAt IS NULL
    ''');
    await db.execute('''
      UPDATE budgets SET updatedAt = datetime('now') WHERE updatedAt IS NULL
    ''');
  }

  /// Safely add a column to a table if it doesn't already exist.
  /// SQLite doesn't support IF NOT EXISTS for ALTER TABLE ADD COLUMN,
  /// so we catch the error.
  Future<void> _addColumnIfNotExists(Database db, String table, String column, String columnDef) async {
    try {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $columnDef');
    } catch (_) {
      // Column already exists — ignore
    }
  }

  // ── CRUD Operations ──

  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> query(String table, {String? where, List<dynamic>? whereArgs, String? orderBy, int? limit}) async {
    final db = await database;
    return await db.query(table, where: where, whereArgs: whereArgs, orderBy: orderBy, limit: limit);
  }

  Future<int> update(String table, Map<String, dynamic> data, {String? where, List<dynamic>? whereArgs}) async {
    final db = await database;
    return await db.update(table, data, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(String table, {String? where, List<dynamic>? whereArgs}) async {
    final db = await database;
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  // ── Pending Operations Queue ──

  Future<List<Map<String, dynamic>>> getPendingOperations() async {
    final db = await database;
    return await db.query('pending_operations', orderBy: 'createdAt ASC');
  }

  Future<int> addPendingOperation(
    String type,
    String endpoint,
    String data, {
    String? operationId,
  }) async {
    final db = await database;
    return await db.insert('pending_operations', {
      'operationId': operationId ?? '',
      'operationType': type,
      'endpoint': endpoint,
      'data': data,
      'createdAt': DateTime.now().toIso8601String(),
      'retryCount': 0,
    });
  }

  Future<void> removePendingOperation(int id) async {
    final db = await database;
    await db.delete('pending_operations', where: 'id = ?', whereArgs: [id]);
  }

  /// Clears all pending sync operations from the queue.
  Future<void> clearUnsynced() async {
    final db = await database;
    await db.delete('pending_operations');
  }

  // ── Dead Letter Operations ──

  Future<List<Map<String, dynamic>>> getDeadLetteredOperations() async {
    final db = await database;
    return await db.query('dead_letter_operations', orderBy: 'deadLetteredAt DESC');
  }

  Future<void> clearDeadLetterOps() async {
    final db = await database;
    await db.delete('dead_letter_operations');
  }

  // ── Sync Metadata Helpers ──

  /// Upsert a record with sync metadata (insert or replace).
  ///
  /// Automatically filters out fields that don't have corresponding columns
  /// in the target table, preventing SQLite errors from server-only fields.
  Future<void> upsertWithSyncMetadata(
    String table,
    Map<String, dynamic> record, {
    required String updatedAt,
    String syncStatus = 'synced',
    String? serverUpdatedAt,
  }) async {
    final db = await database;
    final data = Map<String, dynamic>.from(record)
      ..['updatedAt'] = updatedAt
      ..['syncStatus'] = syncStatus
      ..['serverUpdatedAt'] = serverUpdatedAt;
    // Strip fields not present in the target table schema
    final filtered = await filterRecordForTable(table, data);
    await db.insert(table, filtered, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Mark a local record as having pending (unsynced) changes.
  Future<void> markPending(String table, String id) async {
    final db = await database;
    await db.update(
      table,
      {
        'syncStatus': 'pending',
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Mark a local record as synced (up to date with server).
  Future<void> markSynced(String table, String id, {String? serverUpdatedAt}) async {
    final db = await database;
    final data = <String, dynamic>{
      'syncStatus': 'synced',
      'updatedAt': serverUpdatedAt ?? DateTime.now().toIso8601String(),
    };
    if (serverUpdatedAt != null) {
      data['serverUpdatedAt'] = serverUpdatedAt;
    }
    await db.update(table, data, where: 'id = ?', whereArgs: [id]);
  }

  /// Mark a local record as having a conflict.
  Future<void> markConflict(String table, String id) async {
    final db = await database;
    await db.update(
      table,
      {'syncStatus': 'conflict'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get all records in a table that have pending or conflict status.
  Future<List<Map<String, dynamic>>> getUnsyncedRecords(String table) async {
    final db = await database;
    return await db.query(
      table,
      where: 'syncStatus = ? OR syncStatus = ?',
      whereArgs: ['pending', 'conflict'],
    );
  }

  /// Get the latest serverUpdatedAt across all synced records in a table.
  /// Used as the "since" timestamp for incremental sync pulls.
  Future<DateTime?> getLastSyncTimestamp(String table) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT MAX(serverUpdatedAt) as lastSync FROM $table WHERE syncStatus = ?',
      ['synced'],
    );
    final value = result.first['lastSync'] as String?;
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  // ── Schema Helpers ──

  /// Cache of table column names, keyed by table name.
  final Map<String, Set<String>> _tableColumnCache = {};

  /// Get the set of column names for a given table by querying PRAGMA table_info.
  /// Results are cached in memory for the lifetime of the database connection.
  Future<Set<String>> getTableColumns(String table) async {
    if (_tableColumnCache.containsKey(table)) {
      return _tableColumnCache[table]!;
    }
    final db = await database;
    final result = await db.rawQuery('PRAGMA table_info($table)');
    final columns = result.map((row) => row['name'] as String).toSet();
    _tableColumnCache[table] = columns;
    return columns;
  }

  /// Filter a record map to only include keys that match the table's columns.
  /// This prevents SQLite errors when server records contain fields (like
  /// Mongoose `_id`, `__v`, `priority`, `icon`, etc.) that don't have
  /// corresponding columns in the local table.
  Future<Map<String, dynamic>> filterRecordForTable(String table, Map<String, dynamic> record) async {
    final columns = await getTableColumns(table);
    return Map.fromEntries(
      record.entries.where((e) => columns.contains(e.key)),
    );
  }

  // ── Session Management ──

  /// Clears all user-scoped local data tables.
  ///
  /// Called during session changes (logout, user switch) to prevent data
  /// leakage between users. Clears:
  ///   - [transactions] — locally cached transactions
  ///   - [goals] — locally cached goals
  ///   - [budgets] — locally cached budgets
  ///   - [pending_operations] — queued sync operations for the old user
  ///   - [dead_letter_operations] — dead-lettered operations for audit
  ///
  /// Does NOT clear the shared [cache_entries] table — that is managed
  /// separately by [CacheManager.invalidateAll].
  Future<void> clearAllUserData() async {
    final db = await database;
    // Clear all user-scoped tables in parallel
    await Future.wait([
      db.delete('transactions'),
      db.delete('goals'),
      db.delete('budgets'),
      db.delete('pending_operations'),
      db.delete('dead_letter_operations'),
    ]);
  }
}
