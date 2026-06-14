const mongoose = require('mongoose');
const encryptFields = require('../utils/encryptFieldsPlugin');

const netWorthSchema = new mongoose.Schema({
  user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  entries: [{
    date: { type: Date, default: Date.now },
    assets: {
      cash: { type: mongoose.Schema.Types.Mixed, default: 0 },
      bankAccounts: { type: mongoose.Schema.Types.Mixed, default: 0 },
      savings: { type: mongoose.Schema.Types.Mixed, default: 0 },
      investments: { type: mongoose.Schema.Types.Mixed, default: 0 },
      otherAssets: { type: mongoose.Schema.Types.Mixed, default: 0 },
    },
    liabilities: {
      creditCardDebt: { type: mongoose.Schema.Types.Mixed, default: 0 },
      loans: { type: mongoose.Schema.Types.Mixed, default: 0 },
      personalDebt: { type: mongoose.Schema.Types.Mixed, default: 0 },
      mortgage: { type: mongoose.Schema.Types.Mixed, default: 0 },
    },
  }],
}, { timestamps: true });

netWorthSchema.virtual('totalAssets').get(function() {
  const last = this.entries[this.entries.length - 1];
  if (!last) return 0;
  const a = last.assets;
  return a.cash + a.bankAccounts + a.savings + a.investments + a.otherAssets;
});

netWorthSchema.virtual('totalLiabilities').get(function() {
  const last = this.entries[this.entries.length - 1];
  if (!last) return 0;
  const l = last.liabilities;
  return l.creditCardDebt + l.loans + l.personalDebt + l.mortgage;
});

netWorthSchema.virtual('netWorth').get(function() {
  return this.totalAssets - this.totalLiabilities;
});

netWorthSchema.set('toJSON', { virtuals: true });
netWorthSchema.set('toObject', { virtuals: true });

// Compound indexes for common queries
netWorthSchema.index({ user: 1 }, { unique: true });

// Apply field-level encryption to all financial value fields
encryptFields(netWorthSchema, {
  fields: [
    'entries.assets.cash',
    'entries.assets.bankAccounts',
    'entries.assets.savings',
    'entries.assets.investments',
    'entries.assets.otherAssets',
    'entries.liabilities.creditCardDebt',
    'entries.liabilities.loans',
    'entries.liabilities.personalDebt',
    'entries.liabilities.mortgage',
  ],
});

module.exports = mongoose.model('NetWorth', netWorthSchema);
