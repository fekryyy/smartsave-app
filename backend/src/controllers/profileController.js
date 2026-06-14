const User = require('../models/User');
const Transaction = require('../models/Transaction');
const Budget = require('../models/Budget');
const Goal = require('../models/Goal');
const asyncHandler = require('../utils/catchAsync');
const { sumTotal: decryptedSumTotal } = require('../utils/decryptedUtils');

const profileController = {
  getStats: asyncHandler(async (req, res) => {
      const now = new Date();
      const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
      const monthEnd = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59);

      const [
        totalTransactions,
        monthlyTransactions,
        activeGoals,
        activeBudgets,
        totalIncome,
        totalExpenses,
      ] = await Promise.all([
        Transaction.countDocuments({ user: req.user.id, isActive: true }),
        Transaction.countDocuments({ user: req.user.id, date: { $gte: monthStart, $lte: monthEnd }, isActive: true }),
        Goal.countDocuments({ user: req.user.id, status: 'active' }),
        Budget.countDocuments({ user: req.user.id, month: now.getMonth() + 1, year: now.getFullYear() }),
        decryptedSumTotal(Transaction, { user: req.user.id, type: 'income', isActive: true }, 'amount'),
        decryptedSumTotal(Transaction, { user: req.user.id, type: 'expense', isActive: true }, 'amount'),
      ]);

      res.json({
        success: true,
        data: {
          totalTransactions,
          monthlyTransactions,
          activeGoals,
          activeBudgets,
          totalIncome: totalIncome || 0,
          totalExpenses: totalExpenses || 0,
          balance: (totalIncome || 0) - (totalExpenses || 0),
        },
      });
    }),

  deleteAccount: asyncHandler(async (req, res) => {
    await Promise.all([
      Transaction.deleteMany({ user: req.user.id }),
      Budget.deleteMany({ user: req.user.id }),
      Goal.deleteMany({ user: req.user.id }),
      require('../models/Notification').deleteMany({ user: req.user.id }),
      User.findByIdAndDelete(req.user.id),
    ]);

    res.json({ success: true, message: 'Account permanently deleted' });
  }),
};

module.exports = profileController;
