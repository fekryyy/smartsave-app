require('dotenv').config({ override: true });

const MISSING_SECRET_MSG = 'FATAL: Required environment variable %s is not set. Set it in .env or your environment.';

// Validate critical secrets exist at startup — no fallback for security secrets
if (!process.env.JWT_SECRET) {
  throw new Error(MISSING_SECRET_MSG.replace('%s', 'JWT_SECRET'));
}
if (!process.env.JWT_REFRESH_SECRET) {
  throw new Error(MISSING_SECRET_MSG.replace('%s', 'JWT_REFRESH_SECRET'));
}
if (!process.env.MONGODB_URI) {
  throw new Error(MISSING_SECRET_MSG.replace('%s', 'MONGODB_URI'));
}

module.exports = {
  port: parseInt(process.env.PORT || '5000', 10),
  mongoUri: process.env.MONGODB_URI,
  jwtSecret: process.env.JWT_SECRET,
  jwtExpire: process.env.JWT_EXPIRE || '30d',
  jwtRefreshSecret: process.env.JWT_REFRESH_SECRET,
  jwtRefreshExpire: process.env.JWT_REFRESH_EXPIRE || '90d',
  emailHost: process.env.EMAIL_HOST || 'smtp.gmail.com',
  emailPort: parseInt(process.env.EMAIL_PORT || '587', 10),
  emailUser: process.env.EMAIL_USER || '',
  emailPass: process.env.EMAIL_PASS || '',
  googleClientId: process.env.GOOGLE_CLIENT_ID || '',
  appUrl: process.env.APP_URL || 'http://localhost:5000',
  frontendUrl: process.env.FRONTEND_URL || 'http://localhost:3000',
  redisUrl: process.env.REDIS_URL || 'redis://localhost:6379',
  redisCacheTTL: parseInt(process.env.REDIS_CACHE_TTL || '300', 10),
};
