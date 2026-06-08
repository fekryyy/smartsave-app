import '../../core/network/result.dart';
import '../../services/cache_manager.dart';

/// Mixin that adds cache-first data access patterns to repository implementations.
///
/// Usage:
/// ```dart
/// class GoalRepositoryImpl with CacheableRepository implements GoalRepository {
///   Future<List<GoalModel>> getGoals({String? status}) async {
///     final response = await cacheFirst(
///       cacheKey: 'goals:${_userId}:${status ?? "all"}',
///       fetcher: () => _apiClient.get('/goals', ...),
///     );
///     return (response['data'] as List).map((e) => GoalModel.fromJson(e)).toList();
///   }
/// }
/// ```
mixin CacheableRepository {
  final CacheManager _cache = CacheManager();

  /// Cache-first access: return cached data if fresh, fetch from network otherwise.
  /// On network failure, serves stale cache if available.
  ///
  /// Returns the decoded JSON map from the API response.
  Future<Map<String, dynamic>> cacheFirst({
    required String cacheKey,
    required Future<Map<String, dynamic>> Function() fetcher,
    int? ttlSeconds,
  }) async {
    final result = await _cache.cacheFirst<Map<String, dynamic>>(
      cacheKey: cacheKey,
      fetcher: () async {
        try {
          final data = await fetcher();
          return Success(data);
        } catch (e) {
          // Propagate as Failure to maintain Result contract
          rethrow;
        }
      },
      ttlSeconds: ttlSeconds,
    );
    return result.dataOrThrow;
  }

  /// Network-first access: fetch from network, fall back to cache on failure.
  Future<Map<String, dynamic>> networkFirst({
    required String cacheKey,
    required Future<Map<String, dynamic>> Function() fetcher,
    int? ttlSeconds,
  }) async {
    final result = await _cache.networkFirst<Map<String, dynamic>>(
      cacheKey: cacheKey,
      fetcher: () async {
        final data = await fetcher();
        return Success(data);
      },
      ttlSeconds: ttlSeconds,
    );
    return result.dataOrThrow;
  }

  /// Invalidate all cached data for a given user.
  Future<void> invalidateUserCache(String userId) async {
    await _cache.invalidateUserData(userId);
  }

  /// Invalidate a specific cache prefix.
  Future<void> invalidateCache(String prefix) async {
    await _cache.invalidatePrefix(prefix);
  }

  /// Invalidate all cache.
  Future<void> invalidateAllCache() async {
    await _cache.invalidateAll();
  }
}
