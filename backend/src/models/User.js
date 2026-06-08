const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const config = require('../config');

const userSchema = new mongoose.Schema({
  name: {
    type: String,
    required: [true, 'Name is required'],
    trim: true,
    minlength: [2, 'Name must be at least 2 characters'],
    maxlength: [50, 'Name cannot exceed 50 characters'],
  },
  email: {
    type: String,
    required: [true, 'Email is required'],
    unique: true,
    trim: true,
    lowercase: true,
    match: [/^\w+([\.-]?\w+)*@\w+([\.-]?\w+)*(\.\w{2,3})+$/, 'Please provide a valid email'],
  },
  password: {
    type: String,
    required: [true, 'Password is required'],
    minlength: [6, 'Password must be at least 6 characters'],
    select: false,
  },
  avatar: {
    type: String,
    default: '',
  },
  currency: {
    type: String,
    enum: ['USD', 'EUR', 'GBP', 'EGP', 'SAR', 'AED'],
    default: 'USD',
  },
  monthlyBudget: {
    type: Number,
    default: 0,
  },
  emailVerified: {
    type: Boolean,
    default: false,
  },
  googleId: {
    type: String,
    default: null,
  },
  resetPasswordToken: String,
  resetPasswordExpire: Date,
  onboardingCompleted: {
    type: Boolean,
    default: false,
  },
  notificationPreferences: {
    budgetWarnings: { type: Boolean, default: true },
    goalReminders: { type: Boolean, default: true },
    weeklySummary: { type: Boolean, default: true },
    savingSuggestions: { type: Boolean, default: true },
  },
  xp: { type: Number, default: 0 },
  level: { type: Number, default: 1 },
  totalTransactions: { type: Number, default: 0 },
  totalIncome: { type: Number, default: 0 },
  totalExpenses: { type: Number, default: 0 },
}, {
  timestamps: true,
});

const LEVEL_THRESHOLDS = [
  { level: 1, name: 'Beginner Saver', minXp: 0 },
  { level: 2, name: 'Budget Explorer', minXp: 100 },
  { level: 3, name: 'Smart Planner', minXp: 300 },
  { level: 4, name: 'Finance Master', minXp: 700 },
  { level: 5, name: 'Wealth Builder', minXp: 1500 },
];

userSchema.statics.getLevelInfo = function(xp) {
  let currentLevel = LEVEL_THRESHOLDS[0];
  for (let i = LEVEL_THRESHOLDS.length - 1; i >= 0; i--) {
    if (xp >= LEVEL_THRESHOLDS[i].minXp) {
      currentLevel = LEVEL_THRESHOLDS[i];
      break;
    }
  }
  const nextLevel = LEVEL_THRESHOLDS.find(l => l.minXp > currentLevel.minXp);
  const currentThreshold = currentLevel.minXp;
  const nextThreshold = nextLevel ? nextLevel.minXp : currentLevel.minXp;
  const progress = nextLevel ? ((xp - currentThreshold) / (nextThreshold - currentThreshold)) * 100 : 100;
  return {
    level: currentLevel.level,
    name: currentLevel.name,
    xp,
    currentThreshold,
    nextThreshold,
    progress: Math.min(100, Math.round(progress)),
    nextLevelName: nextLevel ? nextLevel.name : null,
  };
};

userSchema.pre('save', async function(next) {
  if (!this.isModified('password')) return next();
  const salt = await bcrypt.genSalt(12);
  this.password = await bcrypt.hash(this.password, salt);
  next();
});

userSchema.methods.comparePassword = async function(candidatePassword) {
  return bcrypt.compare(candidatePassword, this.password);
};

userSchema.methods.generateAuthToken = function() {
  return jwt.sign({ id: this._id, email: this.email }, config.jwtSecret, {
    expiresIn: config.jwtExpire,
  });
};

userSchema.methods.generateRefreshToken = function() {
  return jwt.sign({ id: this._id }, config.jwtRefreshSecret, {
    expiresIn: config.jwtRefreshExpire,
  });
};

userSchema.methods.toJSON = function() {
  const obj = this.toObject();
  delete obj.password;
  delete obj.resetPasswordToken;
  delete obj.resetPasswordExpire;
  return obj;
};

module.exports = mongoose.model('User', userSchema);
