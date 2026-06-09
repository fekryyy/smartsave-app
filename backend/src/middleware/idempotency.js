const IdempotencyRequest = require('../models/IdempotencyRequest');
const logger = require('../utils/logger');
const crypto = require('crypto');

/**
 * Idempotency Middleware
 *
 * Stripe-style idempotency: if the client sends an Idempotency-Key header,
 * the server ensures that duplicate requests (with the same key) return the
 * same response without executing side effects more than once.
 *
 * Usage: router.post('/', idempotency(), controller.create)
 *
 * The middleware intercepts the response, caches it keyed by (user, key),
 * and replays it on subsequent identical requests.
 *
 * Keys expire after 24 hours (via TTL index on IdempotencyRequest).
 */
function idempotency() {
  return (req, res, next) => {
    const key = req.headers['idempotency-key'] || req.headers['Idempotency-Key'];

    // No key → skip idempotency
    if (!key) {
      return next();
    }

    // Validate key format (UUID v4 or similar random string, 8–128 chars)
    if (typeof key !== 'string' || key.length < 8 || key.length > 128 || /[^a-zA-Z0-9\-_]/.test(key)) {
      return res.status(400).json({
        success: false,
        message: 'Idempotency-Key must be a string of 8–128 URL-safe characters',
      });
    }

    // Require authentication for keyed requests
    if (!req.user || !req.user.id) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required for idempotent requests',
      });
    }

    const userId = req.user.id;

    // Check if this key was already processed
    IdempotencyRequest.findOne({ key, user: userId })
      .lean()
      .then(existing => {
        if (existing) {
          // Key already processed — return cached response
          logger.debug(`Idempotency hit: key=${key} user=${userId}`);
          return res.status(existing.statusCode).json(existing.responseBody);
        }

        // Key not seen — wrap res.json to intercept and cache the response
        const originalJson = res.json.bind(res);
        res.json = function (body) {
          // Save to idempotency store (fire-and-forget, non-blocking)
          IdempotencyRequest.create({
            key,
            user: userId,
            statusCode: res.statusCode,
            responseBody: body,
          }).catch(err => {
            logger.error(`Failed to save idempotency key ${key}: ${err.message}`);
          });

          return originalJson(body);
        };

        next();
      })
      .catch(err => {
        logger.error(`Idempotency lookup failed: ${err.message}`);
        // On error, allow the request through but log the failure
        next();
      });
  };
}

module.exports = { idempotency };
