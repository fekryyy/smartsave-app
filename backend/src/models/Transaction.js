const mongoose = require('mongoose');
const encryptFields = require('../utils/encryptFieldsPlugin');

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
    // Mixed type — encrypted value is stored as String in MongoDB,
    // decrypted post-init returns a Number for application use.
    type: mongoose.Schema.Types.Mixed,
    required: [true, 'Amount is required'],
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
transactionSchema.index({ user: 1, isActive: 1, date: -1 });
transactionSchema.index({ user: 1, type: 1, isActive: 1, date: -1 });
transactionSchema.index({ user: 1, category: 1, isActive: 1 });

/**
 * Get monthly income/expense totals.
 *
 * Since 'amount' is encrypted at rest, we cannot use MongoDB $sum.
 * Instead, we fetch matching docs (decrypted by post('init')) and sum in Node.js.
 */
transactionSchema.statics.getMonthlyTotals = async function(userId, year, month) {
  // Must use hydrated docs (not lean) so post('init') decrypts 'amount'
  const docs = await this.find({
    user: userId,
    isActive: true,
    date: {
      $gte: new Date(year, month - 1, 1),
      $lt: new Date(year, month, 1),
    },
  });

  const result = { income: { total: 0, count: 0 }, expense: { total: 0, count: 0 } };

  for (const doc of docs) {
    const type = doc.type;
    if (!result[type]) result[type] = { total: 0, count: 0 };
    result[type].total += (typeof doc.amount === 'number' ? doc.amount : parseFloat(doc.amount) || 0);
    result[type].count += 1;
  }

  return Object.entries(result)
    .filter(([_, v]) => v.count > 0)
    .map(([type, data]) => ({ _id: type, ...data }));
};

/**
 * Get category breakdown for expenses over a date range.
 *
 * Uses find() + in-memory decryption instead of aggregation $sum.
 */
transactionSchema.statics.getCategoryBreakdown = async function(userId, startDate, endDate) {
  const docs = await this.find({
    user: userId,
    type: 'expense',
    category: { $ne: 'Savings' },
    date: { $gte: startDate, $lte: endDate },
    isActive: true,
  });

  const breakdown = {};
  for (const doc of docs) {
    const cat = doc.category;
    if (!breakdown[cat]) breakdown[cat] = { total: 0, count: 0 };
    breakdown[cat].total += (typeof doc.amount === 'number' ? doc.amount : parseFloat(doc.amount) || 0);
    breakdown[cat].count += 1;
  }

  return Object.entries(breakdown)
    .map(([category, data]) => ({ _id: category, ...data }))
    .sort((a, b) => b.total - a.total);
};

// Apply field-level encryption to financial data
encryptFields(transactionSchema, {
  fields: ['amount', 'description'],
});

module.exports = mongoose.model('Transaction', transactionSchema);
