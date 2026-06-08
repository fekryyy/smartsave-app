const mongoose = require('mongoose');

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
    type: Number,
    required: [true, 'Budget amount is required'],
    min: [1, 'Budget must be at least 1'],
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

module.exports = mongoose.model('Budget', budgetSchema);
