const mongoose = require('mongoose');

const transactionSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  type: {
    type: String,
    enum: ['income', 'expense'],
    required: [true, 'Transaction type is required'],
  },
  amount: {
    type: Number,
    required: [true, 'Amount is required'],
    min: [0.01, 'Amount must be greater than 0'],
  },
  category: {
    type: String,
    enum: ['Food', 'Transportation', 'Shopping', 'Bills', 'Entertainment', 'Health', 'Education', 'Travel', 'Other', 'Salary', 'Freelance', 'Investment', 'Gift', 'Refund', 'Savings'],
    required: [true, 'Category is required'],
  },
  description: {
    type: String,
    trim: true,
    maxlength: [200, 'Description cannot exceed 200 characters'],
    default: '',
  },
  date: {
    type: Date,
    required: [true, 'Date is required'],
    default: Date.now,
    index: true,
  },
  paymentMethod: {
    type: String,
    enum: ['Cash', 'Credit Card', 'Debit Card', 'Bank Transfer', 'Mobile Wallet', 'Other'],
    default: 'Cash',
  },
  currency: {
    type: String,
    enum: ['USD', 'EUR', 'GBP', 'EGP', 'SAR', 'AED'],
    default: 'USD',
  },
  isRecurring: {
    type: Boolean,
    default: false,
  },
  recurringFrequency: {
    type: String,
    enum: ['daily', 'weekly', 'monthly', 'yearly', 'none'],
    default: 'none',
  },
  recurringEndDate: {
    type: Date,
    default: null,
  },
  receiptUrl: {
    type: String,
    default: null,
  },
  tags: [{
    type: String,
    trim: true,
  }],
  isActive: {
    type: Boolean,
    default: true,
  },
}, {
  timestamps: true,
});

transactionSchema.index({ user: 1, date: -1 });
transactionSchema.index({ user: 1, category: 1 });
transactionSchema.index({ user: 1, type: 1, date: -1 });

transactionSchema.statics.getMonthlyTotals = function(userId, year, month) {
  return this.aggregate([
    {
      $match: {
        user: new mongoose.Types.ObjectId(userId),
        isActive: true,
        date: {
          $gte: new Date(year, month - 1, 1),
          $lt: new Date(year, month, 1),
        },
      },
    },
    {
      $group: {
        _id: '$type',
        total: { $sum: '$amount' },
        count: { $sum: 1 },
      },
    },
  ]);
};

transactionSchema.statics.getCategoryBreakdown = function(userId, startDate, endDate) {
    return this.aggregate([
      {
        $match: {
          user: new mongoose.Types.ObjectId(userId),
          type: 'expense',
          category: { $ne: 'Savings' },
          date: { $gte: startDate, $lte: endDate },
          isActive: true,
        },
      },
    {
      $group: {
        _id: '$category',
        total: { $sum: '$amount' },
        count: { $sum: 1 },
      },
    },
    { $sort: { total: -1 } },
  ]);
};

module.exports = mongoose.model('Transaction', transactionSchema);
