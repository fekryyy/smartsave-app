require('dotenv').config({ override: true });

module.exports = {
  port: process.env.PORT || 5000,
  mongoUri: process.env.MONGODB_URI || 'mongodb://localhost:27017/smartsave',
  jwtSecret: process.env.JWT_SECRET || 'smartsave_jwt_secret_key_2024',
  jwtExpire: process.env.JWT_EXPIRE || '30d',
  jwtRefreshSecret: process.env.JWT_REFRESH_SECRET || 'smartsave_refresh_secret_key_2024',
  jwtRefreshExpire: process.env.JWT_REFRESH_EXPIRE || '90d',
  emailHost: process.env.EMAIL_HOST || 'smtp.gmail.com',
  emailPort: process.env.EMAIL_PORT || 587,
  emailUser: process.env.EMAIL_USER || '',
  emailPass: process.env.EMAIL_PASS || '',
  googleClientId: process.env.GOOGLE_CLIENT_ID || '',
  appUrl: process.env.APP_URL || 'http://localhost:5000',
  frontendUrl: process.env.FRONTEND_URL || 'http://localhost:3000',
  redisUrl: process.env.REDIS_URL || 'redis://localhost:6379',
  redisCacheTTL: parseInt(process.env.REDIS_CACHE_TTL || '300'),
};
