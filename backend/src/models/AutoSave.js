const mongoose = require('mongoose');
const encryptFields = require('../utils/encryptFieldsPlugin');

const autoSaveSchema = new mongoose.Schema({
  user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  name: { type: String, required: true },
  type: {
    type: String,
    enum: ['percentage_of_income', 'fixed_daily', 'fixed_payday', 'percentage_bonus', 'round_up'],
    required: true,
  },
  amount: { type: mongoose.Schema.Types.Mixed },
  percentage: { type: Number },
  targetAccount: { type: String, default: 'savings' },
  isActive: { type: Boolean, default: true },
  frequency: { type: String, enum: ['daily', 'weekly', 'monthly', 'per_transaction'], default: 'monthly' },
  paydayDay: { type: Number },
  lastContribution: Date,
  totalContributed: { type: mongoose.Schema.Types.Mixed, default: 0 },
  contributionCount: { type: Number, default: 0 },
  history: [{
    date: Date,
    amount: mongoose.Schema.Types.Mixed,
    transactionId: { type: mongoose.Schema.Types.ObjectId, ref: 'Transaction' },
  }],
}, { timestamps: true });

// Compound indexes for common queries
autoSaveSchema.index({ user: 1, isActive: 1 });
autoSaveSchema.index({ user: 1, createdAt: -1 });

// Apply field-level encryption to financial data
encryptFields(autoSaveSchema, {
  fields: ['amount', 'totalContributed', 'history.amount'],
});

module.exports = mongoose.model('AutoSave', autoSaveSchema);
