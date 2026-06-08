const Bull = require('bull');
const logger = require('../utils/logger');

const REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379';

// ── Queue definitions ──

/**
 * AI and advisory tasks (financial analysis, insights, chat responses).
 * These are CPU/IO-heavy and benefit from non-blocking execution.
 */
const aiQueue = new Bull('ai-tasks', REDIS_URL, {
  defaultJobOptions: {
    attempts: 3,
    backoff: { type: 'exponential', delay: 2000 },
    removeOnComplete: 100,
    removeOnFail: 50,
    timeout: 60000, // 60 seconds max
  },
  limiter: {
    max: 10, // max jobs per duration
    duration: 1000, // per second
  },
});

/**
 * Export tasks (PDF, CSV, Excel generation).
 * These are memory-intensive and should be serialized.
 */
const exportQueue = new Bull('export-tasks', REDIS_URL, {
  defaultJobOptions: {
    attempts: 2,
    backoff: { type: 'fixed', delay: 5000 },
    removeOnComplete: 50,
    removeOnFail: 20,
    timeout: 120000, // 2 minutes
  },
  limiter: {
    max: 2, // max 2 exports per second
    duration: 1000,
  },
});

/**
 * OCR / receipt scanning tasks.
 * tesseract.js is CPU-intensive; queue prevents UI blocking.
 */
const ocrQueue = new Bull('ocr-tasks', REDIS_URL, {
  defaultJobOptions: {
    attempts: 2,
    backoff: { type: 'fixed', delay: 3000 },
    removeOnComplete: 50,
    removeOnFail: 20,
    timeout: 120000, // 2 minutes
  },
  limiter: {
    max: 3,
    duration: 1000,
  },
});

/**
 * Notification delivery tasks (email, push).
 * Queued so we don't block the request thread.
 */
const notificationQueue = new Bull('notification-tasks', REDIS_URL, {
  defaultJobOptions: {
    attempts: 3,
    backoff: { type: 'exponential', delay: 2000 },
    removeOnComplete: 100,
    removeOnFail: 30,
    timeout: 30000,
  },
});

// ── Event logging ──

function setupQueueLogging(queue, name) {
  queue.on('completed', (job) => {
    logger.debug(`Queue[${name}] Job ${job.id} completed in ${job.finishedOn - job.processedOn}ms`);
  });
  queue.on('failed', (job, err) => {
    logger.error(`Queue[${name}] Job ${job.id} failed after ${job.attemptsMade} attempts: ${err.message}`);
  });
  queue.on('stalled', (job) => {
    logger.warn(`Queue[${name}] Job ${job.id} stalled — will be retried`);
  });
  queue.on('error', (err) => {
    logger.error(`Queue[${name}] error: ${err.message}`);
  });
}

setupQueueLogging(aiQueue, 'ai');
setupQueueLogging(exportQueue, 'export');
setupQueueLogging(ocrQueue, 'ocr');
setupQueueLogging(notificationQueue, 'notification');

// ── Graceful shutdown ──

async function closeAll() {
  await Promise.all([
    aiQueue.close(),
    exportQueue.close(),
    ocrQueue.close(),
    notificationQueue.close(),
  ]);
  logger.info('All Bull queues closed');
}

/**
 * Get queue statistics for monitoring.
 */
async function getQueueStats() {
  const queues = [
    { name: 'ai', queue: aiQueue },
    { name: 'export', queue: exportQueue },
    { name: 'ocr', queue: ocrQueue },
    { name: 'notification', queue: notificationQueue },
  ];

  const stats = {};
  for (const { name, queue } of queues) {
    const [waiting, active, completed, failed, delayed] = await Promise.all([
      queue.getWaitingCount(),
      queue.getActiveCount(),
      queue.getCompletedCount(),
      queue.getFailedCount(),
      queue.getDelayedCount(),
    ]);
    stats[name] = { waiting, active, completed, failed, delayed };
  }
  return stats;
}

// ── Quick helpers ──

/**
 * Add an AI analysis job to the queue.
 * Returns the job object immediately (caller can await job.finished() if needed).
 */
function enqueueAIAnalysis(userId, type, payload = {}) {
  return aiQueue.add(
    { userId, type, ...payload },
    {
      jobId: `ai:${userId}:${type}:${Date.now()}`,
    },
  );
}

/**
 * Add an export job to the queue (PDF/CSV/Excel).
 */
function enqueueExport(userId, format, type, period, filters = {}) {
  return exportQueue.add(
    { userId, format, type, period, filters },
    {
      jobId: `export:${userId}:${format}:${type}:${Date.now()}`,
    },
  );
}

/**
 * Add an OCR scan job.
 */
function enqueueOCR(userId, filePath) {
  return ocrQueue.add(
    { userId, filePath },
    {
      jobId: `ocr:${userId}:${Date.now()}`,
    },
  );
}

module.exports = {
  aiQueue,
  exportQueue,
  ocrQueue,
  notificationQueue,
  closeAll,
  getQueueStats,
  enqueueAIAnalysis,
  enqueueExport,
  enqueueOCR,
};
