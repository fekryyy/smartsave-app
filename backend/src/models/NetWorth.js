const mongoose = require('mongoose');

const netWorthSchema = new mongoose.Schema({
  user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  entries: [{
    date: { type: Date, default: Date.now },
    assets: {
      cash: { type: Number, default: 0 },
      bankAccounts: { type: Number, default: 0 },
      savings: { type: Number, default: 0 },
      investments: { type: Number, default: 0 },
      otherAssets: { type: Number, default: 0 },
    },
    liabilities: {
      creditCardDebt: { type: Number, default: 0 },
      loans: { type: Number, default: 0 },
      personalDebt: { type: Number, default: 0 },
      mortgage: { type: Number, default: 0 },
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

module.exports = mongoose.model('NetWorth', netWorthSchema);
