const mongoose = require('mongoose');

const subscriptionSchema = new mongoose.Schema({
  user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  name: { type: String, required: true },
  description: String,
  amount: { type: Number, required: true },
  currency: { type: String, default: 'USD' },
  billingDate: { type: Number, required: true },
  renewalFrequency: { type: String, enum: ['weekly', 'monthly', 'quarterly', 'yearly'], default: 'monthly' },
  category: { type: String, default: 'Other' },
  logo: String,
  website: String,
  isActive: { type: Boolean, default: true },
  nextBillingDate: Date,
  lastBilledDate: Date,
  missedPayments: { type: Number, default: 0 },
  reminderEnabled: { type: Boolean, default: true },
}, { timestamps: true });

subscriptionSchema.virtual('monthlyAmount').get(function() {
  switch (this.renewalFrequency) {
    case 'weekly': return this.amount * 4.33;
    case 'quarterly': return this.amount / 3;
    case 'yearly': return this.amount / 12;
    default: return this.amount;
  }
});

subscriptionSchema.virtual('yearlyAmount').get(function() {
  switch (this.renewalFrequency) {
    case 'weekly': return this.amount * 52;
    case 'quarterly': return this.amount * 4;
    case 'yearly': return this.amount;
    default: return this.amount * 12;
  }
});

subscriptionSchema.set('toJSON', { virtuals: true });
subscriptionSchema.set('toObject', { virtuals: true });

// Compound indexes for common queries
subscriptionSchema.index({ user: 1, isActive: 1 });
subscriptionSchema.index({ user: 1, nextBillingDate: 1 });

module.exports = mongoose.model('Subscription', subscriptionSchema);
