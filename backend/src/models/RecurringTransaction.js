const mongoose = require('mongoose');

const recurringTransactionSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  type: {
    type: String,
    enum: ['income', 'expense'],
    required: true,
  },
  amount: {
    type: Number,
    required: [true, 'Amount is required'],
    min: [0.01, 'Amount must be greater than 0'],
  },
  category: {
    type: String,
    required: [true, 'Category is required'],
    enum: ['Food', 'Transportation', 'Shopping', 'Bills', 'Entertainment', 'Health', 'Education', 'Travel', 'Other', 'Salary', 'Freelance', 'Investment', 'Gift', 'Refund'],
  },
  description: {
    type: String,
    trim: true,
    default: '',
  },
  frequency: {
    type: String,
    enum: ['daily', 'weekly', 'monthly', 'yearly'],
    required: true,
  },
  interval: {
    type: Number,
    default: 1,
    min: 1,
  },
  startDate: {
    type: Date,
    required: true,
  },
  endDate: {
    type: Date,
    default: null,
  },
  nextExecutionDate: {
    type: Date,
    required: true,
  },
  paymentMethod: {
    type: String,
    enum: ['Cash', 'Credit Card', 'Debit Card', 'Bank Transfer', 'Mobile Wallet', 'Other'],
    default: 'Cash',
  },
  isActive: {
    type: Boolean,
    default: true,
  },
  lastExecuted: {
    type: Date,
    default: null,
  },
  executionCount: {
    type: Number,
    default: 0,
  },
}, {
  timestamps: true,
});

recurringTransactionSchema.methods.calculateNextExecution = function() {
  const next = new Date(this.nextExecutionDate);
  switch (this.frequency) {
    case 'daily':
      next.setDate(next.getDate() + this.interval);
      break;
    case 'weekly':
      next.setDate(next.getDate() + (7 * this.interval));
      break;
    case 'monthly':
      next.setMonth(next.getMonth() + this.interval);
      break;
    case 'yearly':
      next.setFullYear(next.getFullYear() + this.interval);
      break;
  }
  return next;
};

module.exports = mongoose.model('RecurringTransaction', recurringTransactionSchema);
