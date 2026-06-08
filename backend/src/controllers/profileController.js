const User = require('../models/User');
const Transaction = require('../models/Transaction');
const Budget = require('../models/Budget');
const Goal = require('../models/Goal');

const profileController = {
  async getStats(req, res, next) {
    try {
      const now = new Date();
      const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
      const monthEnd = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59);

      const [
        totalTransactions,
        monthlyTransactions,
        activeGoals,
        budgets,
        totalIncome,
        totalExpenses,
      ] = await Promise.all([
        Transaction.countDocuments({ user: req.user.id, isActive: true }),
        Transaction.countDocuments({ user: req.user.id, date: { $gte: monthStart, $lte: monthEnd }, isActive: true }),
        Goal.countDocuments({ user: req.user.id, status: 'active' }),
        Budget.countDocuments({ user: req.user.id, month: now.getMonth() + 1, year: now.getFullYear() }),
        Transaction.aggregate([
          { $match: { user: req.user._id, type: 'income', isActive: true } },
          { $group: { _id: null, total: { $sum: '$amount' } } },
        ]),
        Transaction.aggregate([
          { $match: { user: req.user._id, type: 'expense', isActive: true } },
          { $group: { _id: null, total: { $sum: '$amount' } } },
        ]),
      ]);

      res.json({
        success: true,
        data: {
          totalTransactions,
          monthlyTransactions,
          activeGoals,
          activeBudgets: budgets,
          totalIncome: totalIncome.length > 0 ? totalIncome[0].total : 0,
          totalExpenses: totalExpenses.length > 0 ? totalExpenses[0].total : 0,
          balance: (totalIncome.length > 0 ? totalIncome[0].total : 0) - (totalExpenses.length > 0 ? totalExpenses[0].total : 0),
        },
      });
    } catch (error) {
      next(error);
    }
  },

  async deleteAccount(req, res, next) {
    try {
      await Promise.all([
        Transaction.deleteMany({ user: req.user.id }),
        Budget.deleteMany({ user: req.user.id }),
        Goal.deleteMany({ user: req.user.id }),
        Notification.deleteMany({ user: req.user.id }),
        User.findByIdAndDelete(req.user.id),
      ]);

      res.json({ success: true, message: 'Account permanently deleted' });
    } catch (error) {
      next(error);
    }
  },
};

module.exports = profileController;
