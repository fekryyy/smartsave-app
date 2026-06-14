const mongoose = require('mongoose');

/**
 * AI Audit Log — audit trail for all AI interactions.
 *
 * Records every AI prompt/response pair for compliance, debugging,
 * and improving the AI system. Tracks which provider was used,
 * whether it was AI-generated or fallback, and estimated token usage.
 *
 * NOTE: User financial data is NOT stored in audit logs for privacy.
 * Only prompt types, response lengths, and metadata are recorded.
 */
const aiAuditLogSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  endpoint: {
    type: String,
    enum: ['analysis', 'score', 'insights', 'action_plan', 'predictions', 'advice', 'health', 'opportunities', 'chat', 'consent'],
    required: true,
  },
  provider: {
    type: String,
    enum: ['openai', 'claude', 'deepseek', 'fallback', 'none'],
    default: 'none',
  },
  responseType: {
    type: String,
    enum: ['ai', 'fallback', 'error'],
    required: true,
  },
  // System prompt length (proxy for complexity)
  systemPromptLength: {
    type: Number,
    default: 0,
  },
  // User prompt length
  userPromptLength: {
    type: Number,
    default: 0,
  },
  // Response length (characters)
  responseLength: {
    type: Number,
    default: 0,
  },
  // Estimated token usage (rough: chars / 4)
  estimatedTokens: {
    type: Number,
    default: 0,
  },
  // Latency in ms
  latencyMs: {
    type: Number,
    default: 0,
  },
  // Error message if any
  error: {
    type: String,
    default: null,
  },
  // Whether consent was checked
  consentChecked: {
    type: Boolean,
    default: true,
  },
  // Whether consent was granted
  consentGranted: {
    type: Boolean,
    default: false,
  },
}, {
  timestamps: true,
});

// Indexes for efficient querying
aiAuditLogSchema.index({ user: 1, createdAt: -1 });
aiAuditLogSchema.index({ endpoint: 1, createdAt: -1 });
// TTL index — keep audit logs for 1 year
aiAuditLogSchema.index({ createdAt: 1 }, { expireAfterSeconds: 365 * 24 * 60 * 60 });

module.exports = mongoose.model('AIAuditLog', aiAuditLogSchema);
