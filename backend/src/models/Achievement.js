const mongoose = require('mongoose');

const achievementSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  badge: {
    type: String,
    required: true,
    enum: [
      'first_transaction', 'ten_transactions', 'fifty_transactions',
      'first_goal', 'goal_completed', 'budget_set',
      'budget_on_track', 'seven_day_streak', 'thirty_day_streak',
      'receipt_scanner', 'champion',
    ],
  },
  title: {
    type: String,
    required: true,
  },
  description: String,
  icon: {
    type: String,
    default: 'emoji_events',
  },
  unlockedAt: {
    type: Date,
    default: Date.now,
  },
}, {
  timestamps: true,
});

achievementSchema.index({ user: 1, badge: 1 }, { unique: true });

module.exports = mongoose.model('Achievement', achievementSchema);
