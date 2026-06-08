const User = require('../models/User');
const catchAsync = require('../utils/catchAsync');

exports.getProgress = catchAsync(async (req, res) => {
  const user = await User.findById(req.user.id);
  if (!user) return res.status(404).json({ success: false, message: 'User not found' });
  const levelInfo = User.getLevelInfo(user.xp);
  res.json({
    success: true,
    data: {
      ...levelInfo,
      totalTransactions: user.totalTransactions,
      totalIncome: user.totalIncome,
      totalExpenses: user.totalExpenses,
    },
  });
});

exports.addXp = catchAsync(async (req, res) => {
  const { amount, reason } = req.body;
  if (!amount || amount <= 0) return res.status(400).json({ success: false, message: 'Valid XP amount required' });
  const user = await User.findById(req.user.id);
  if (!user) return res.status(404).json({ success: false, message: 'User not found' });
  user.xp += amount;
  const prevLevel = user.level;
  const levelInfo = User.getLevelInfo(user.xp);
  user.level = levelInfo.level;
  await user.save();
  const leveledUp = user.level > prevLevel;
  res.json({
    success: true,
    data: {
      xpAdded: amount,
      totalXp: user.xp,
      level: user.level,
      levelName: levelInfo.name,
      leveledUp,
      reason: reason || 'General activity',
    },
  });
});
