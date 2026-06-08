const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const connectDB = require('./config/database');
const config = require('./config');
const errorHandler = require('./middleware/errorHandler');
const logger = require('./utils/logger');
const recurringService = require('./services/recurringService');

const app = express();

// Security middleware
app.use(helmet());
app.use(cors({
  origin: process.env.NODE_ENV === 'production' ? config.frontendUrl : '*',
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
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

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

// Health check
app.get('/api/health', (req, res) => {
  res.json({ success: true, message: 'SmartSave API is running', timestamp: new Date().toISOString() });
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
  recurringService.start();
  app.listen(config.port, () => {
    logger.info(`SmartSave server running on port ${config.port}`);
  });
};

startServer();

module.exports = app;
