const mongoose = require('mongoose');

/**
 * Idempotency Request Model
 *
 * Stores processed idempotency keys so that duplicate requests
 * return the same response without side effects.
 *
 * Keys auto-expire after 24 hours via TTL index.
 */
const idempotencySchema = new mongoose.Schema({
  key: {
    type: String,
    required: true,
    unique: true,
    index: true,
  },
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  statusCode: {
    type: Number,
    required: true,
  },
  responseBody: {
    type: mongoose.Schema.Types.Mixed,
    required: true,
  },
}, {
  timestamps: true,
});

// TTL index — auto-delete after 24 hours
idempotencySchema.index({ createdAt: 1 }, { expireAfterSeconds: 86400 });

module.exports = mongoose.model('IdempotencyRequest', idempotencySchema);
