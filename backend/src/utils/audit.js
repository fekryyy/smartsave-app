const AuditLog = require('../models/AuditLog');
const logger = require('./logger');

/**
 * Record a financial audit event.
 *
 * Usage:
 *   await recordAudit({
 *     user: req.user.id,
 *     action: 'create',
 *     resource: 'transaction',
 *     resourceId: transaction._id,
 *     description: 'Created expense of $50 for Food',
 *     before: null,      // null for creates
 *     after: transaction, // the document after the change
 *     ip: req.ip,
 *     userAgent: req.get('User-Agent'),
 *   });
 *
 * @param {object} params
 * @param {string} params.user - User ID
 * @param {'create'|'update'|'delete'|'contribution'|'restore'} params.action
 * @param {'transaction'|'budget'|'goal'|'subscription'|'autosave'|'networth'|'recurring'} params.resource
 * @param {string} params.resourceId - The affected document's ID
 * @param {string} [params.description] - Human-readable summary
 * @param {object|null} [params.before] - Snapshot before the change
 * @param {object|null} [params.after] - Snapshot after the change
 * @param {string} [params.ip] - Request IP
 * @param {string} [params.userAgent] - Request User-Agent
 */
async function recordAudit(params) {
  try {
    await AuditLog.create({
      user: params.user,
      action: params.action,
      resource: params.resource,
      resourceId: params.resourceId,
      description: (params.description || '').slice(0, 500),
      before: params.before || null,
      after: params.after || null,
      ip: params.ip || '',
      userAgent: params.userAgent || '',
    });
  } catch (err) {
    // Audit failures must never break the main operation
    logger.error(`Audit log failed: ${err.message}`);
  }
}

/**
 * Convenience wrapper that extracts request metadata and calls recordAudit.
 * Call this from controllers after the mutation succeeds.
 */
function auditFromRequest(req, action, resource, resourceId, description, before, after) {
  return recordAudit({
    user: req.user?.id,
    action,
    resource,
    resourceId,
    description,
    before,
    after,
    ip: req.ip || req.headers['x-forwarded-for'] || '',
    userAgent: req.get('User-Agent') || '',
  });
}

module.exports = { recordAudit, auditFromRequest };
