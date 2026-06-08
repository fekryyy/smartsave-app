const Redis = require('ioredis');
const logger = require('../utils/logger');

const REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379';
const DEFAULT_TTL = 300; // 5 minutes in seconds

let redis = null;
let isConnected = false;

/**
 * Initialize Redis connection. Call once at server startup.
 */
function connect() {
  if (redis) return redis;

  redis = new Redis(REDIS_URL, {
    retryStrategy(times) {
      const delay = Math.min(times * 50, 2000);
      return delay;
    },
    maxRetriesPerRequest: 3,
    enableOfflineQueue: false,
  });

  redis.on('connect', () => {
    isConnected = true;
    logger.info('Redis connected');
  });

  redis.on('error', (err) => {
    isConnected = false;
    logger.error(`Redis error: ${err.message}`);
  });

  redis.on('close', () => {
    isConnected = false;
    logger.warn('Redis connection closed');
  });

  redis.on('reconnecting', () => {
    logger.info('Redis reconnecting...');
  });

  return redis;
}

/**
 * Get Redis client instance.
 */
function getClient() {
  return redis;
}

/**
 * Check if Redis is connected and ready.
 */
function isReady() {
  return isConnected && redis && redis.status === 'ready';
}

/**
 * Get a cached value by key.
 * Returns parsed JSON or null if not found.
 */
async function get(key) {
  if (!isReady()) return null;
  try {
    const value = await redis.get(key);
    if (!value) return null;
    return JSON.parse(value);
  } catch (err) {
    logger.error(`Redis get error for key "${key}": ${err.message}`);
    return null; // Fail open — return null on error, don't crash
  }
}

/**
 * Set a cached value with optional TTL.
 * @param {string} key
 * @param {*} value — will be JSON.stringify'd
 * @param {number} ttl — seconds (default: DEFAULT_TTL)
 */
async function set(key, value, ttl = DEFAULT_TTL) {
  if (!isReady()) return;
  try {
    const serialized = JSON.stringify(value);
    if (ttl > 0) {
      await redis.setex(key, ttl, serialized);
    } else {
      await redis.set(key, serialized);
    }
  } catch (err) {
    logger.error(`Redis set error for key "${key}": ${err.message}`);
  }
}

/**
 * Delete one or more cache keys.
 * @param {string|string[]} keys
 */
async function del(keys) {
  if (!isReady()) return;
  try {
    const keyArray = Array.isArray(keys) ? keys : [keys];
    if (keyArray.length > 0) {
      await redis.del(...keyArray);
    }
  } catch (err) {
    logger.error(`Redis del error: ${err.message}`);
  }
}

/**
 * Invalidate all cache entries matching a pattern.
 * E.g., flushPattern('transactions:*') clears all transaction caches.
 * @param {string} pattern — glob-style pattern (e.g., 'transactions:*')
 */
async function flushPattern(pattern) {
  if (!isReady()) return;
  try {
    const stream = redis.scanStream({ match: pattern, count: 100 });
    let pipeline = redis.pipeline();
    let keysCount = 0;

    stream.on('data', (keys) => {
      if (keys.length > 0) {
        keys.forEach((key) => pipeline.del(key));
        keysCount += keys.length;
      }
    });

    return new Promise((resolve, reject) => {
      stream.on('end', () => {
        if (keysCount > 0) {
          pipeline.exec().catch((err) => logger.error(`Redis flushPipeline error: ${err.message}`));
        }
        logger.debug(`Redis flushed ${keysCount} keys matching "${pattern}"`);
        resolve(keysCount);
      });
      stream.on('error', (err) => {
        logger.error(`Redis scanStream error: ${err.message}`);
        reject(err);
      });
    });
  } catch (err) {
    logger.error(`Redis flushPattern error: ${err.message}`);
  }
}

/**
 * Build a cache key from parts (e.g., cacheKey('transactions', userId, 'page=1')).
 */
function cacheKey(...parts) {
  return parts.filter(Boolean).join(':');
}

/**
 * Express middleware: cache GET responses.
 * Only caches 2xx responses. Skips if Redis is down.
 *
 * Usage: router.get('/', cacheMiddleware(60), controller.getAll)
 *
 * @param {number} ttl — TTL in seconds
 */
function cacheMiddleware(ttl = DEFAULT_TTL) {
  return async (req, res, next) => {
    // Only cache GET requests
    if (req.method !== 'GET') return next();

    // Skip if Redis is not ready
    if (!isReady()) return next();

    // Use full URL as cache key (includes query params)
    const key = cacheKey('api', req.originalUrl);

    try {
      const cached = await redis.get(key);
      if (cached) {
        const parsed = JSON.parse(cached);
        return res.json(parsed);
      }
    } catch {
      // Fail open — proceed without cache
      return next();
    }

    // Override res.json to cache the response
    const originalJson = res.json.bind(res);
    res.json = function (body) {
      // Only cache successful responses
      if (res.statusCode >= 200 && res.statusCode < 300) {
        redis.setex(key, ttl, JSON.stringify(body)).catch(() => {});
      }
      return originalJson(body);
    };

    next();
  };
}

/**
 * Graceful shutdown: close Redis connection.
 */
async function shutdown() {
  if (redis) {
    try {
      await redis.quit();
      logger.info('Redis connection closed gracefully');
    } catch (err) {
      logger.error(`Redis shutdown error: ${err.message}`);
    }
  }
}

module.exports = {
  connect,
  getClient,
  isReady,
  get,
  set,
  del,
  flushPattern,
  cacheKey,
  cacheMiddleware,
  shutdown,
};
