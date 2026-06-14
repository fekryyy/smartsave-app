const mongoose = require('mongoose');

/**
 * AI Consent Log — immutable audit trail for user consent changes.
 *
 * Records every time a user accepts or revokes AI data processing consent.
 * This is a regulatory/compliance requirement for AI-powered features
 * that process personal financial data.
 */
const aiConsentLogSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  action: {
    type: String,
    enum: ['accepted', 'revoked'],
    required: true,
  },
  ipAddress: {
    type: String,
    default: '',
  },
  userAgent: {
    type: String,
    default: '',
  },
  source: {
    type: String,
    enum: ['api', 'web', 'mobile', 'admin'],
    default: 'api',
  },
}, {
  timestamps: true,
});

// Index for chronological queries per user
aiConsentLogSchema.index({ user: 1, createdAt: -1 });
// TTL index — keep consent logs for 3 years (regulatory requirement)
aiConsentLogSchema.index({ createdAt: 1 }, { expireAfterSeconds: 3 * 365 * 24 * 60 * 60 });

module.exports = mongoose.model('AIConsentLog', aiConsentLogSchema);
