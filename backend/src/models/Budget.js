const mongoose = require('mongoose');
const encryptFields = require('../utils/encryptFieldsPlugin');

const budgetSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  category: {
    type: String,
    enum: ['Food', 'Transportation', 'Shopping', 'Bills', 'Entertainment', 'Health', 'Education', 'Travel', 'Other', 'Overall'],
    required: [true, 'Category is required'],
  },
  amount: {
    type: mongoose.Schema.Types.Mixed,
    required: [true, 'Budget amount is required'],
  },
  spent: {
    type: Number,
    default: 0,
  },
  period: {
    type: String,
    enum: ['weekly', 'monthly', 'yearly'],
    default: 'monthly',
  },
  month: {
    type: Number,
    default: () => new Date().getMonth() + 1,
  },
  year: {
    type: Number,
    default: () => new Date().getFullYear(),
  },
  isActive: {
    type: Boolean,
    default: true,
  },
  notifications: {
    type: Boolean,
    default: true,
  },
}, {
  timestamps: true,
});

budgetSchema.index({ user: 1, category: 1, month: 1, year: 1 }, { unique: true });

budgetSchema.virtual('percentageUsed').get(function() {
  if (!this.amount || this.amount === 0) return 0;
  return Math.round((this.spent / this.amount) * 100);
});

budgetSchema.virtual('remaining').get(function() {
  if (!this.amount) return 0;
  return this.amount - this.spent;
});

budgetSchema.set('toJSON', { virtuals: true });
budgetSchema.set('toObject', { virtuals: true });

// Apply field-level encryption to financial data
// NOTE: 'spent' is intentionally NOT encrypted because it's updated via $inc,
// which is incompatible with encrypted string storage. 'spent' is a computed
// running total derived from transaction amounts (which are encrypted).
encryptFields(budgetSchema, {
  fields: ['amount'],
});

module.exports = mongoose.model('Budget', budgetSchema);
