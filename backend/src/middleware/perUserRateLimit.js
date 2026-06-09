const rateLimit = require('express-rate-limit');

/**
 * Per-user rate limiter.
 *
 * Uses req.user.id when available (authenticated), falls back to IP.
 * This prevents a single user from abusing expensive endpoints
 * (AI analysis, OCR, export, etc.).
 *
 * Usage:
 *   app.use('/api/financial-advisor', perUserRateLimit({ windowMs: 1 * 60 * 1000, max: 10 }));
 */
function perUserRateLimit({ windowMs = 60 * 1000, max = 10, message } = {}) {
  return rateLimit({
    windowMs,
    max,
    message: message || { success: false, message: 'Too many requests. Please slow down.' },
    keyGenerator: (req) => {
      // Use user ID if authenticated, otherwise fall back to IP
      return req.user?.id || req.ip || req.connection?.remoteAddress || 'anonymous';
    },
    standardHeaders: true,
    legacyHeaders: false,
  });
}

module.exports = perUserRateLimit;
