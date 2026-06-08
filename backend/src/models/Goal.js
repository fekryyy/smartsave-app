const mongoose = require('mongoose');

const goalSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  title: {
    type: String,
    required: [true, 'Goal title is required'],
    trim: true,
    maxlength: [100, 'Title cannot exceed 100 characters'],
  },
  description: {
    type: String,
    trim: true,
    maxlength: [500, 'Description cannot exceed 500 characters'],
    default: '',
  },
  targetAmount: {
    type: Number,
    required: [true, 'Target amount is required'],
    min: [1, 'Target amount must be at least 1'],
  },
  currentAmount: {
    type: Number,
    default: 0,
    min: 0,
  },
  targetDate: {
    type: Date,
    default: null,
  },
  category: {
    type: String,
    enum: ['Emergency Fund', 'Travel', 'Education', 'Shopping', 'Investment', 'Debt Payment', 'Retirement', 'Other'],
    default: 'Other',
  },
  priority: {
    type: String,
    enum: ['low', 'medium', 'high'],
    default: 'medium',
  },
  status: {
    type: String,
    enum: ['active', 'completed', 'cancelled'],
    default: 'active',
  },
  icon: {
    type: String,
    default: 'savings',
  },
  color: {
    type: String,
    default: '#4CAF50',
  },
  monthlyContribution: {
    type: Number,
    default: 0,
  },
  autoContribute: {
    type: Boolean,
    default: false,
  },
}, {
  timestamps: true,
});

goalSchema.virtual('progress').get(function() {
  if (this.targetAmount === 0) return 0;
  return Math.min(100, Math.round((this.currentAmount / this.targetAmount) * 100));
});

goalSchema.virtual('remaining').get(function() {
  return Math.max(0, this.targetAmount - this.currentAmount);
});

goalSchema.virtual('estimatedCompletionDate').get(function() {
  if (this.monthlyContribution <= 0 || this.currentAmount >= this.targetAmount) return null;
  const remaining = this.targetAmount - this.currentAmount;
  const monthsNeeded = Math.ceil(remaining / this.monthlyContribution);
  const estimated = new Date();
  estimated.setMonth(estimated.getMonth() + monthsNeeded);
  return estimated;
});

goalSchema.methods.addContribution = function(amount) {
  this.currentAmount = Math.min(this.currentAmount + amount, this.targetAmount);
  if (this.currentAmount >= this.targetAmount) {
    this.status = 'completed';
  }
  return this.save();
};

goalSchema.set('toJSON', { virtuals: true });
goalSchema.set('toObject', { virtuals: true });

module.exports = mongoose.model('Goal', goalSchema);
