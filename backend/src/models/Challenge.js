const mongoose = require('mongoose');

const challengeSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  title: {
    type: String,
    required: true,
  },
  description: String,
  type: {
    type: String,
    enum: ['savings', 'no_spend', 'budget_streak', 'transaction_count', 'login_streak'],
    required: true,
  },
  goal: {
    type: Number,
    required: true,
  },
  progress: {
    type: Number,
    default: 0,
  },
  points: {
    type: Number,
    default: 0,
  },
  startDate: {
    type: Date,
    default: Date.now,
  },
  endDate: Date,
  status: {
    type: String,
    enum: ['active', 'completed', 'failed'],
    default: 'active',
  },
  completedAt: Date,
}, {
  timestamps: true,
});

challengeSchema.virtual('progressPct').get(function() {
  return this.goal > 0 ? Math.min(100, Math.round((this.progress / this.goal) * 100)) : 0;
});

// Compound indexes for common queries
challengeSchema.index({ user: 1, status: 1, createdAt: -1 });
challengeSchema.index({ user: 1, type: 1, status: 1 });

module.exports = mongoose.model('Challenge', challengeSchema);
