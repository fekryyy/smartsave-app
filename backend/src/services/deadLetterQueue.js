/**
 * Dead Letter Queue (DLQ) Manager.
 *
 * When a Bull job exhausts all its retries, this module captures its
 * payload and moves it to a Redis-backed dead letter list for the queue.
 * Operators can inspect, retry, or clear DLQ entries via API endpoints.
 *
 * Each queue gets a Redis key:  `dlq:<queueName>` — a list of JSON-encoded
 * job records with id, name, data, error, failedAt, attemptsMade.
 *
 * Usage in queueService:
 *   const dlq = require('./deadLetterQueue');
 *   queue.on('failed', (job, err) => dlq.handleFailed(queue, job, err));
 */

const logger = require('../utils/logger');
const redisService = require('./redisService');

const DLQ_PREFIX = 'dlq';

// TTL for DLQ entries (7 days in seconds — gives operators a week to inspect)
const DLQ_TTL = 7 * 24 * 60 * 60;

/**
 * Build the Redis key for a queue's dead letter list.
 */
function dlqKey(queueName) {
  return `${DLQ_PREFIX}:${queueName}`;
}

/**
 * Handle a job failure event from Bull.
 *
 * If the job has exhausted its retry attempts (attemptsMade >= opts.attempts),
 * its data is captured and pushed onto the DLQ Redis list.
 *
 * @param {String} queueName — human-readable name (e.g. 'ai', 'export')
 * @param {Object} job       — Bull job instance
 * @param {Error}  err       — the failure error
 */
async function handleFailed(queueName, job, err) {
  if (!job) return;

  const maxAttempts = job.opts.attempts || 1;
  const attemptsMade = (job.attemptsMade || 0);

  // Only capture to DLQ when retries are truly exhausted
  if (attemptsMade < maxAttempts) return;

  const record = {
    id: String(job.id),
    name: job.name || 'unnamed',
    data: job.data || {},
    error: {
      message: err?.message || 'Unknown error',
      stack: err?.stack?.split('\n').slice(0, 5).join('\n') || '',
    },
    failedAt: new Date().toISOString(),
    attemptsMade,
    maxAttempts,
    timestamp: Date.now(),
  };

  try {
    const key = dlqKey(queueName);
    const client = redisService.getClient();
    if (client && redisService.isReady()) {
      // Push to front of the list so newest failures appear first
      await client.lpush(key, JSON.stringify(record));
      // Trim list to max 1000 entries to prevent unbounded growth
      await client.ltrim(key, 0, 999);
      // Set TTL — extend each time a new entry is added
      await client.expire(key, DLQ_TTL);
    }

    logger.error(
      `[DLQ] Job ${job.id} moved to dead letter queue "${queueName}" ` +
      `after ${attemptsMade}/${maxAttempts} attempts: ${err?.message}`
    );

    // ALERT: In production, this is where you'd send a webhook/email/Slack notification.
    // For now, the error log above serves as the alert.
    // Example webhook integration (uncomment when configured):
    // await sendAlert({ queue: queueName, jobId: job.id, error: err?.message, attemptsMade, maxAttempts });

  } catch (redisErr) {
    logger.error(`[DLQ] Failed to store dead letter for queue "${queueName}": ${redisErr.message}`);
  }
}

/**
 * List all DLQ entries for a given queue.
 * Returns array of records, newest first.
 *
 * @param {String} queueName
 * @param {Number} [start=0]
 * @param {Number} [stop=49]
 * @returns {Array}
 */
async function listDLQ(queueName, start = 0, stop = 49) {
  const client = redisService.getClient();
  if (!client || !redisService.isReady()) return [];

  try {
    const key = dlqKey(queueName);
    const entries = await client.lrange(key, start, stop);
    return entries.map((e) => {
      try { return JSON.parse(e); } catch { return null; }
    }).filter(Boolean);
  } catch (err) {
    logger.error(`[DLQ] Failed to list "${queueName}": ${err.message}`);
    return [];
  }
}

/**
 * Get the count of dead letter entries for a queue.
 *
 * @param {String} queueName
 * @returns {Number}
 */
async function getDLQCount(queueName) {
  const client = redisService.getClient();
  if (!client || !redisService.isReady()) return 0;

  try {
    return await client.llen(dlqKey(queueName));
  } catch (err) {
    logger.error(`[DLQ] Failed to get count for "${queueName}": ${err.message}`);
    return 0;
  }
}

/**
 * Get DLQ stats for all tracked queues.
 *
 * @param {String[]} queueNames — list of queue names
 * @returns {Object} map of queueName -> { count }
 */
async function getAllDLQStats(queueNames = []) {
  const stats = {};
  for (const name of queueNames) {
    stats[name] = { dead: await getDLQCount(name) };
  }
  return stats;
}

/**
 * Retry a specific DLQ job by removing it from the DLQ and returning its data.
 * The caller is responsible for adding it back to the appropriate queue.
 *
 * @param {String} queueName
 * @param {String} jobId
 * @returns {Object|null} the job record, or null if not found
 */
async function retryJob(queueName, jobId) {
  const client = redisService.getClient();
  if (!client || !redisService.isReady()) return null;

  try {
    const key = dlqKey(queueName);
    const entries = await client.lrange(key, 0, -1);
    for (const entry of entries) {
      let record;
      try { record = JSON.parse(entry); } catch { continue; }
      if (record.id === jobId) {
        // Remove this entry from the DLQ
        await client.lrem(key, 1, entry);
        logger.info(`[DLQ] Job ${jobId} removed from DLQ "${queueName}" for retry`);
        return record;
      }
    }
    return null;
  } catch (err) {
    logger.error(`[DLQ] Failed to retry job ${jobId} from "${queueName}": ${err.message}`);
    return null;
  }
}

/**
 * Clear all dead letter entries for a queue (or a specific job).
 *
 * @param {String} queueName
 * @param {String} [jobId] — optional; if provided, only removes that job
 * @returns {Number} number of entries removed
 */
async function clearDLQ(queueName, jobId) {
  const client = redisService.getClient();
  if (!client || !redisService.isReady()) return 0;

  try {
    const key = dlqKey(queueName);
    if (jobId) {
      // Remove specific job
      const entries = await client.lrange(key, 0, -1);
      let removed = 0;
      for (const entry of entries) {
        try {
          const record = JSON.parse(entry);
          if (record.id === jobId) {
            await client.lrem(key, 1, entry);
            removed++;
          }
        } catch { continue; }
      }
      logger.info(`[DLQ] Removed ${removed} entry(ies) for job ${jobId} from "${queueName}"`);
      return removed;
    } else {
      // Clear entire DLQ for this queue
      await client.del(key);
      logger.info(`[DLQ] Cleared all entries for queue "${queueName}"`);
      return -1; // sentinel for "all cleared"
    }
  } catch (err) {
    logger.error(`[DLQ] Failed to clear "${queueName}": ${err.message}`);
    return 0;
  }
}

module.exports = {
  handleFailed,
  listDLQ,
  getDLQCount,
  getAllDLQStats,
  retryJob,
  clearDLQ,
};
