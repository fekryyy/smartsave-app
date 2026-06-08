import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../data/datasources/local/local_database.dart';
import '../core/network/result.dart';

/// Cache entry wrapper with TTL tracking.
class CacheEntry<T> {
  final T data;
  final DateTime cachedAt;
  final int ttlSeconds;

  const CacheEntry({
    required this.data,
    required this.cachedAt,
    required this.ttlSeconds,
  });

  /// Returns true if this entry has expired.
  bool get isExpired => DateTime.now().difference(cachedAt).inSeconds > ttlSeconds;

  Map<String, dynamic> toJson() => {
        'data': data,
        'cachedAt': cachedAt.toIso8601String(),
        'ttlSeconds': ttlSeconds,
      };

  factory CacheEntry.fromJson(Map<String, dynamic> json, T Function(dynamic) fromData) {
    return CacheEntry(
      data: fromData(json['data']),
      cachedAt: DateTime.parse(json['cachedAt'] as String),
      ttlSeconds: json['ttlSeconds'] as int,
    );
  }
}

/// Provides cache-first data access:
///   1. Return cached data immediately (if fresh)
///   2. Fetch from network in background
///   3. On network failure, serve stale cache
///
/// TTLs are configurable per resource type.
class CacheManager {
  static const _tableName = 'cache_entries';
  static final CacheManager _instance = CacheManager._init();
  factory CacheManager() => _instance;
  CacheManager._init();

  final LocalDatabase _db = LocalDatabase.instance;

  /// Default TTLs per resource type (in seconds).
  static const defaultTtls = {
    'transactions': 60, // 1 minute
    'budgets': 120, // 2 minutes
    'goals': 120,
    'analytics': 300, // 5 minutes
    'notifications': 60,
    'challenges': 120,
    'subscriptions': 300,
    'networth': 300,
    'recurring': 120,
    'autosave': 120,
    'reports': 600, // 10 minutes
    'profile': 600,
    'xp': 300,
  };

  /// Initialize the cache table.
  Future<void> init() async {
    final db = await _db.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_tableName (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        cachedAt TEXT NOT NULL,
        ttlSeconds INTEGER NOT NULL
      )
    ''');
  }

  /// Get a cached value by key.
  /// Returns `null` if not cached or expired.
  Future<CacheEntry<String>?> get(String key) async {
    try {
      final db = await _db.database;
      final rows = await db.query(
        _tableName,
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );
      if (rows.isEmpty) return null;

      final row = rows.first;
      final cachedAt = DateTime.parse(row['cachedAt'] as String);
      final ttlSeconds = row['ttlSeconds'] as int;

      return CacheEntry(
        data: row['value'] as String,
        cachedAt: cachedAt,
        ttlSeconds: ttlSeconds,
      );
    } catch (_) {
      return null;
    }
  }

  /// Get a typed cached value (decoded from JSON).
  Future<CacheEntry<dynamic>?> getJson(String key) async {
    final entry = await get(key);
    if (entry == null) return null;
    return CacheEntry(
      data: jsonDecode(entry.data),
      cachedAt: entry.cachedAt,
      ttlSeconds: entry.ttlSeconds,
    );
  }

  /// Store a value in the cache.
  Future<void> set(String key, dynamic value, {int? ttlSeconds}) async {
    try {
      final db = await _db.database;
      final serialized = value is String ? value : jsonEncode(value);
      final ttl = ttlSeconds ?? _resolveTtl(key);

      await db.insert(
        _tableName,
        {
          'key': key,
          'value': serialized,
          'cachedAt': DateTime.now().toIso8601String(),
          'ttlSeconds': ttl,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {
      // Cache write failures are non-critical
    }
  }

  /// Invalidate a specific cache key.
  Future<void> invalidate(String key) async {
    try {
      final db = await _db.database;
      await db.delete(_tableName, where: 'key = ?', whereArgs: [key]);
    } catch (_) {}
  }

  /// Invalidate all cache entries matching a prefix pattern.
  /// E.g., invalidatePrefix('transactions') clears all transaction caches.
  Future<void> invalidatePrefix(String prefix) async {
    try {
      final db = await _db.database;
      await db.delete(_tableName, where: 'key LIKE ?', whereArgs: ['$prefix%']);
    } catch (_) {}
  }

  /// Invalidate all cache entries.
  Future<void> invalidateAll() async {
    try {
      final db = await _db.database;
      await db.delete(_tableName);
    } catch (_) {}
  }

  /// Invalidate caches for a user after a write operation.
  /// Call this after POST/PUT/DELETE to ensure fresh data.
  Future<void> invalidateUserData(String userId) async {
    await Future.wait([
      invalidatePrefix('transactions:$userId'),
      invalidatePrefix('budgets:$userId'),
      invalidatePrefix('goals:$userId'),
      invalidatePrefix('analytics:$userId'),
      invalidatePrefix('notifications:$userId'),
      invalidatePrefix('challenges:$userId'),
      invalidatePrefix('subscriptions:$userId'),
      invalidatePrefix('networth:$userId'),
      invalidatePrefix('recurring:$userId'),
      invalidatePrefix('autosave:$userId'),
      invalidatePrefix('xp:$userId'),
      invalidatePrefix('profile:$userId'),
    ]);
  }

  /// Cache-first access pattern:
  ///   1. If cache hit and fresh → return cached data
  ///   2. If cache miss or expired → fetch from network via [fetcher]
  ///   3. On network success → update cache and return data
  ///   4. On network failure → serve stale cache if available, else propagate error
  ///
  /// Returns a [Result] with the data.
  Future<Result<T>> cacheFirst<T>({
    required String cacheKey,
    required Future<Result<T>> Function() fetcher,
    T Function(dynamic)? fromJson,
    int? ttlSeconds,
  }) async {
    // Step 1: Try cache
    final cached = await getJson(cacheKey);
    if (cached != null && !cached.isExpired) {
      final data = fromJson != null ? fromJson(cached.data) : cached.data as T;
      return Success(data);
    }

    // Step 2: Fetch from network
    try {
      final result = await fetcher();
      return result.map((data) {
        // Cache the successful response (only if it's a Success)
        set(cacheKey, data, ttlSeconds: ttlSeconds);
        return data;
      });
    } catch (_) {
      // Step 3: Network failed — serve stale cache
      if (cached != null) {
        final data = fromJson != null ? fromJson(cached.data) : cached.data as T;
        return Success(data);
      }
      rethrow;
    }
  }

  /// Network-first with cache fallback:
  ///   Try network first, fall back to cache on failure.
  ///   Good for write-heavy operations where freshness matters.
  Future<Result<T>> networkFirst<T>({
    required String cacheKey,
    required Future<Result<T>> Function() fetcher,
    T Function(dynamic)? fromJson,
    int? ttlSeconds,
  }) async {
    try {
      final result = await fetcher();
      return result.map((data) {
        set(cacheKey, data, ttlSeconds: ttlSeconds);
        return data;
      });
    } catch (_) {
      // Fall back to cache
      final cached = await getJson(cacheKey);
      if (cached != null) {
        final data = fromJson != null ? fromJson(cached.data) : cached.data as T;
        return Success(data);
      }
      rethrow;
    }
  }

  /// Resolve the TTL for a given cache key based on its prefix.
  int _resolveTtl(String key) {
    for (final entry in defaultTtls.entries) {
      if (key.startsWith(entry.key)) return entry.value;
    }
    return 120; // Default 2 minutes
  }
}
