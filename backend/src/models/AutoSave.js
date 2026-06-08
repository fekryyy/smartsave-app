const mongoose = require('mongoose');

const autoSaveSchema = new mongoose.Schema({
  user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  name: { type: String, required: true },
  type: {
    type: String,
    enum: ['percentage_of_income', 'fixed_daily', 'fixed_payday', 'percentage_bonus', 'round_up'],
    required: true,
  },
  amount: { type: Number },
  percentage: { type: Number },
  targetAccount: { type: String, default: 'savings' },
  isActive: { type: Boolean, default: true },
  frequency: { type: String, enum: ['daily', 'weekly', 'monthly', 'per_transaction'], default: 'monthly' },
  paydayDay: { type: Number },
  lastContribution: Date,
  totalContributed: { type: Number, default: 0 },
  contributionCount: { type: Number, default: 0 },
  history: [{
    date: Date,
    amount: Number,
    transactionId: { type: mongoose.Schema.Types.ObjectId, ref: 'Transaction' },
  }],
}, { timestamps: true });

// Compound indexes for common queries
autoSaveSchema.index({ user: 1, isActive: 1 });
autoSaveSchema.index({ user: 1, createdAt: -1 });

module.exports = mongoose.model('AutoSave', autoSaveSchema);
