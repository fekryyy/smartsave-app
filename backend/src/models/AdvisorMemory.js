const mongoose = require('mongoose');

/**
 * Stores conversation history between users and the AI Financial Advisor.
 * Enables the AI to reference past advice, goals, and patterns for continuous coaching.
 */
const advisorMemorySchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  role: {
    type: String,
    enum: ['user', 'assistant'],
    required: true,
  },
  content: {
    type: String,
    required: true,
    maxlength: 10000,
  },
  type: {
    type: String,
    enum: ['chat', 'advice', 'analysis', 'plan', 'prediction', 'insight', 'score', 'system'],
    default: 'chat',
  },
  metadata: {
    type: mongoose.Schema.Types.Mixed,
    default: {},
  },
}, {
  timestamps: true,
});

// Index for efficient conversation retrieval
advisorMemorySchema.index({ user: 1, createdAt: -1 });

// Limit to last 100 messages per user
advisorMemorySchema.statics.cleanup = async function (userId) {
  const count = await this.countDocuments({ user: userId });
  if (count > 100) {
    const oldest = await this.find({ user: userId })
      .sort({ createdAt: 1 })
      .limit(count - 100)
      .select('_id');
    if (oldest.length > 0) {
      await this.deleteMany({ _id: { $in: oldest.map(o => o._id) } });
    }
  }
};

module.exports = mongoose.model('AdvisorMemory', advisorMemorySchema);
