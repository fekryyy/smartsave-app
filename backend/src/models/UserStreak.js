const mongoose = require('mongoose');

const userStreakSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    unique: true,
  },
  loginStreak: {
    type: Number,
    default: 0,
  },
  lastLoginDate: Date,
  noSpendStreak: {
    type: Number,
    default: 0,
  },
  lastSpendDate: Date,
  bestLoginStreak: {
    type: Number,
    default: 0,
  },
  bestNoSpendStreak: {
    type: Number,
    default: 0,
  },
  totalPoints: {
    type: Number,
    default: 0,
  },
}, {
  timestamps: true,
});

module.exports = mongoose.model('UserStreak', userStreakSchema);
