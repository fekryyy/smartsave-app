const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const connectDB = require('./config/database');
const config = require('./config');
const { errorHandler } = require('./middleware/errorHandler');
const { protect } = require('./middleware/auth');
const logger = require('./utils/logger');
const recurringService = require('./services/recurringService');
const redisService = require('./services/redisService');
const socketService = require('./services/socketService');
const { getQueueStats, closeAll } = require('./services/queueService');

// Bull Board — job queue monitoring UI
const { createBullBoard } = require('@bull-board/api');
const { BullAdapter } = require('@bull-board/api/bullAdapter');
const { ExpressAdapter } = require('@bull-board/express');
const { aiQueue, exportQueue, ocrQueue, notificationQueue } = require('./services/queueService');

const serverAdapter = new ExpressAdapter();
serverAdapter.setBasePath('/admin/queues');
createBullBoard({
  queues: [
    new BullAdapter(aiQueue),
    new BullAdapter(exportQueue),
    new BullAdapter(ocrQueue),
    new BullAdapter(notificationQueue),
  ],
  serverAdapter,
});

const app = express();

// Security middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:", "blob:"],
      connectSrc: ["'self'"],
      frameSrc: ["'none'"],
      objectSrc: ["'none'"],
    },
  },
  hsts: { maxAge: 31536000, includeSubDomains: true, preload: true },
  referrerPolicy: { policy: 'strict-origin-when-cross-origin' },
  frameguard: { action: 'deny' },
  noSniff: true,
  xssFilter: true,
}));
app.use(cors({
  origin: [config.frontendUrl, 'http://localhost:3000', 'http://localhost:5000'].filter(Boolean),
  credentials: true,
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 500,
  message: { success: false, message: 'Too many requests, please try again later.' },
});
app.use('/api/auth', rateLimit({ windowMs: 15 * 60 * 1000, max: 50 }));
app.use('/api', limiter);

// Body parsing
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(require('cookie-parser')());

// Logging
if (process.env.NODE_ENV !== 'test') {
  app.use(morgan('combined', { stream: { write: message => logger.info(message.trim()) } }));
}

// Static files
app.use('/uploads', express.static('uploads'));

// Routes
app.use('/api/auth', require('./routes/authRoutes'));
app.use('/api/transactions', require('./routes/transactionRoutes'));
app.use('/api/budgets', require('./routes/budgetRoutes'));
app.use('/api/goals', require('./routes/goalRoutes'));
app.use('/api/analytics', require('./routes/analyticsRoutes'));
app.use('/api/export', require('./routes/exportRoutes'));
app.use('/api/recommendations', require('./routes/recommendationRoutes'));
app.use('/api/ocr', require('./routes/ocrRoutes'));
app.use('/api/profile', require('./routes/profileRoutes'));
app.use('/api/notifications', require('./routes/notificationRoutes'));
app.use('/api/recurring', require('./routes/recurringRoutes'));
app.use('/api/challenges', require('./routes/challengeRoutes'));
app.use('/api/subscriptions', require('./routes/subscriptionRoutes'));
app.use('/api/networth', require('./routes/netWorthRoutes'));
app.use('/api/autosave', require('./routes/autoSaveRoutes'));
app.use('/api/calendar', require('./routes/calendarRoutes'));
app.use('/api/reports', require('./routes/reportRoutes'));
app.use('/api/xp', require('./routes/xpRoutes'));
app.use('/api/financial-advisor', require('./routes/financialAdvisorRoutes'));

// Bull Board UI — requires valid JWT (admin/protected)
app.use('/admin/queues', protect, serverAdapter.getRouter());

// Health check
app.get('/api/health', async (req, res) => {
  const queueStats = await getQueueStats();
  res.json({
    success: true,
    message: 'SmartSave API is running',
    timestamp: new Date().toISOString(),
    redis: redisService.isReady() ? 'connected' : 'disconnected',
    queues: queueStats,
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ success: false, message: 'Route not found' });
});

// Error handler
app.use(errorHandler);

// Start server
const startServer = async () => {
  await connectDB();

  // Connect Redis (non-blocking — cache is optional)
  redisService.connect();

  recurringService.start();

  const server = app.listen(config.port, () => {
    logger.info(`SmartSave server running on port ${config.port}`);
  });

  // Initialize Socket.io with Redis adapter and JWT auth
  socketService.initSocket(server);

  // Graceful shutdown
  const shutdown = async (signal) => {
    logger.info(`${signal} received. Shutting down gracefully...`);
    server.close(async () => {
      await socketService.shutdown();
      await redisService.shutdown();
      await closeAll();
      logger.info('Server closed');
      process.exit(0);
    });
    // Force exit after 10s
    setTimeout(() => {
      logger.error('Forced shutdown after timeout');
      process.exit(1);
    }, 10000);
  };

  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
};

startServer();

module.exports = app;
