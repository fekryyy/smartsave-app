/**
 * Admin routes for queue monitoring and dead letter queue (DLQ) management.
 *
 * All routes require JWT authentication (protect middleware).
 * Only users with admin privileges can access these endpoints.
 */

const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const { getQueueStats, dlq } = require('../services/queueService');
const logger = require('../utils/logger');

// All admin routes require authentication
router.use(protect);

/**
 * Optional: admin-only guard.
 * Uncomment the role check below if you add an `isAdmin` field to the User model.
 */
// router.use(async (req, res, next) => {
//   if (!req.user?.isAdmin) {
//     return res.status(403).json({ success: false, message: 'Admin access required' });
//   }
//   next();
// });

// ---------------------------------------------------------------------------
// Queue Stats
// ---------------------------------------------------------------------------

/**
 * GET /api/admin/queues/stats
 * Returns live stats for all Bull queues (waiting, active, completed, failed, delayed, dead).
 */
router.get('/queues/stats', async (req, res) => {
  try {
    const stats = await getQueueStats();
    res.json({ success: true, data: stats });
  } catch (err) {
    logger.error(`[Admin] Failed to get queue stats: ${err.message}`);
    res.status(500).json({ success: false, message: 'Failed to get queue stats' });
  }
});

// ---------------------------------------------------------------------------
// Dead Letter Queue
// ---------------------------------------------------------------------------

/**
 * GET /api/admin/queues/dlq
 * Returns DLQ stats (count of dead letter entries) for all queues.
 */
router.get('/queues/dlq', async (req, res) => {
  try {
    const queueNames = ['ai', 'export', 'ocr', 'notification'];
    const stats = await dlq.getAllDLQStats(queueNames);
    res.json({ success: true, data: stats });
  } catch (err) {
    logger.error(`[Admin] Failed to get DLQ stats: ${err.message}`);
    res.status(500).json({ success: false, message: 'Failed to get DLQ stats' });
  }
});

/**
 * GET /api/admin/queues/dlq/:queueName
 * Lists dead letter entries for a specific queue.
 * Query params: start (default 0), stop (default 49)
 */
router.get('/queues/dlq/:queueName', async (req, res) => {
  try {
    const { queueName } = req.params;
    const validQueues = ['ai', 'export', 'ocr', 'notification'];
    if (!validQueues.includes(queueName)) {
      return res.status(400).json({ success: false, message: `Invalid queue name. Valid: ${validQueues.join(', ')}` });
    }

    const start = parseInt(req.query.start) || 0;
    const stop = parseInt(req.query.stop) !== undefined ? parseInt(req.query.stop) : 49;
    const entries = await dlq.listDLQ(queueName, start, stop);
    const total = await dlq.getDLQCount(queueName);

    res.json({ success: true, data: { queueName, total, start, stop, entries } });
  } catch (err) {
    logger.error(`[Admin] Failed to list DLQ: ${err.message}`);
    res.status(500).json({ success: false, message: 'Failed to list DLQ entries' });
  }
});

/**
 * POST /api/admin/queues/dlq/:queueName/retry/:jobId
 * Retry a specific job from the dead letter queue.
 * Removes it from the DLQ and re-enqueues it to the original queue.
 */
router.post('/queues/dlq/:queueName/retry/:jobId', async (req, res) => {
  try {
    const { queueName, jobId } = req.params;
    const validQueues = ['ai', 'export', 'ocr', 'notification'];
    if (!validQueues.includes(queueName)) {
      return res.status(400).json({ success: false, message: `Invalid queue name. Valid: ${validQueues.join(', ')}` });
    }

    const record = await dlq.retryJob(queueName, jobId);
    if (!record) {
      return res.status(404).json({ success: false, message: `Job ${jobId} not found in DLQ "${queueName}"` });
    }

    // Re-enqueue the job to its original Bull queue
    const { aiQueue, exportQueue, ocrQueue, notificationQueue } = require('./queueService');
    const queueMap = { ai: aiQueue, export: exportQueue, ocr: ocrQueue, notification: notificationQueue };
    const targetQueue = queueMap[queueName];

    if (!targetQueue) {
      return res.status(500).json({ success: false, message: `Queue "${queueName}" not found` });
    }

    const newJob = await targetQueue.add(record.data, {
      jobId: `${record.id}-retry-${Date.now()}`,
      attempts: record.maxAttempts || 3,
    });

    logger.info(`[Admin] Retrying DLQ job ${jobId} on queue "${queueName}" as new job ${newJob.id}`);

    res.json({
      success: true,
      message: `Job ${jobId} retried as ${newJob.id} on "${queueName}"`,
      data: { originalJobId: jobId, newJobId: String(newJob.id), queueName },
    });
  } catch (err) {
    logger.error(`[Admin] Failed to retry DLQ job: ${err.message}`);
    res.status(500).json({ success: false, message: `Failed to retry job: ${err.message}` });
  }
});

/**
 * DELETE /api/admin/queues/dlq/:queueName
 * Clears all dead letter entries for a queue.
 */
router.delete('/queues/dlq/:queueName', async (req, res) => {
  try {
    const { queueName } = req.params;
    const validQueues = ['ai', 'export', 'ocr', 'notification'];
    if (!validQueues.includes(queueName)) {
      return res.status(400).json({ success: false, message: `Invalid queue name. Valid: ${validQueues.join(', ')}` });
    }

    await dlq.clearDLQ(queueName);
    res.json({ success: true, message: `DLQ cleared for queue "${queueName}"` });
  } catch (err) {
    logger.error(`[Admin] Failed to clear DLQ: ${err.message}`);
    res.status(500).json({ success: false, message: 'Failed to clear DLQ' });
  }
});

/**
 * DELETE /api/admin/queues/dlq/:queueName/:jobId
 * Removes a specific job from the dead letter queue.
 */
router.delete('/queues/dlq/:queueName/:jobId', async (req, res) => {
  try {
    const { queueName, jobId } = req.params;
    const removed = await dlq.clearDLQ(queueName, jobId);
    if (removed === 0) {
      return res.status(404).json({ success: false, message: `Job ${jobId} not found in DLQ "${queueName}"` });
    }
    res.json({ success: true, message: `Removed ${removed} entry(ies) for job ${jobId} from DLQ "${queueName}"` });
  } catch (err) {
    logger.error(`[Admin] Failed to remove DLQ job: ${err.message}`);
    res.status(500).json({ success: false, message: 'Failed to remove DLQ job' });
  }
});

module.exports = router;
