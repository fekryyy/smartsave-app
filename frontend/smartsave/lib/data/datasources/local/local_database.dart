import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

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
      version: 1,
      onCreate: _createDB,
    );
  }

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
        createdAt TEXT
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
        createdAt TEXT
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
        isSynced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE pending_operations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operationType TEXT NOT NULL,
        endpoint TEXT NOT NULL,
        data TEXT,
        createdAt TEXT NOT NULL
      )
    ''');
  }

  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> query(String table, {String? where, List<dynamic>? whereArgs, String? orderBy}) async {
    final db = await database;
    return await db.query(table, where: where, whereArgs: whereArgs, orderBy: orderBy);
  }

  Future<int> update(String table, Map<String, dynamic> data, {String? where, List<dynamic>? whereArgs}) async {
    final db = await database;
    return await db.update(table, data, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(String table, {String? where, List<dynamic>? whereArgs}) async {
    final db = await database;
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<List<Map<String, dynamic>>> getPendingOperations() async {
    final db = await database;
    return await db.query('pending_operations', orderBy: 'createdAt ASC');
  }

  Future<int> addPendingOperation(String type, String endpoint, String data) async {
    final db = await database;
    return await db.insert('pending_operations', {
      'operationType': type,
      'endpoint': endpoint,
      'data': data,
      'createdAt': DateTime.now().toIso8601String(),
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

  /// Clears all user-scoped local data tables.
  ///
  /// Called during session changes (logout, user switch) to prevent data
  /// leakage between users. Clears:
  ///   - [transactions] — locally cached transactions
  ///   - [goals] — locally cached goals
  ///   - [budgets] — locally cached budgets
  ///   - [pending_operations] — queued sync operations for the old user
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
    ]);
  }
}
