const mongoose = require('mongoose');

/**
 * Audit Log Model
 *
 * Immutable record of all financial mutations.
 * Never updated or deleted — only inserted.
 *
 * Tracks who made the change, what changed, when, and the before/after state.
 */
const auditLogSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  action: {
    type: String,
    enum: ['create', 'update', 'delete', 'contribution', 'restore'],
    required: true,
  },
  resource: {
    type: String,
    enum: ['transaction', 'budget', 'goal', 'subscription', 'autosave', 'networth', 'recurring'],
    required: true,
  },
  resourceId: {
    type: mongoose.Schema.Types.ObjectId,
    required: true,
  },
  description: {
    type: String,
    maxlength: 500,
    default: '',
  },
  // Snapshot of the document before the change (null for creates)
  before: {
    type: mongoose.Schema.Types.Mixed,
    default: null,
  },
  // Snapshot of the document after the change (null for deletes)
  after: {
    type: mongoose.Schema.Types.Mixed,
    default: null,
  },
  // IP address of the requester
  ip: {
    type: String,
    default: '',
  },
  // User-Agent of the requester
  userAgent: {
    type: String,
    default: '',
  },
}, {
  timestamps: true,
});

// Index for efficient queries
auditLogSchema.index({ user: 1, createdAt: -1 });
auditLogSchema.index({ resource: 1, resourceId: 1 });
auditLogSchema.index({ action: 1, createdAt: -1 });

// TTL index — auto-delete logs older than 1 year
auditLogSchema.index({ createdAt: 1 }, { expireAfterSeconds: 365 * 86400 });

module.exports = mongoose.model('AuditLog', auditLogSchema);
