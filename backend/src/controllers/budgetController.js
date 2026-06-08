const Budget = require('../models/Budget');
const Transaction = require('../models/Transaction');

const budgetController = {
  async getAll(req, res, next) {
    try {
      const { month, year } = req.query;
      const query = { user: req.user.id };

      if (month) query.month = parseInt(month);
      if (year) query.year = parseInt(year);
      if (!month && !year) {
        const now = new Date();
        query.month = now.getMonth() + 1;
        query.year = now.getFullYear();
      }

      const budgets = await Budget.find(query);

      res.json({ success: true, data: budgets });
    } catch (error) {
      next(error);
    }
  },

  async getById(req, res, next) {
    try {
      const budget = await Budget.findOne({ _id: req.params.id, user: req.user.id });
      if (!budget) {
        return res.status(404).json({ success: false, message: 'Budget not found' });
      }
      res.json({ success: true, data: budget });
    } catch (error) {
      next(error);
    }
  },

  async create(req, res, next) {
    try {
      const { category, amount, period, notifications } = req.body;
      const now = new Date();
      const month = now.getMonth() + 1;
      const year = now.getFullYear();

      const existing = await Budget.findOne({
        user: req.user.id,
        category,
        month,
        year,
      });

      if (existing) {
        return res.status(400).json({
          success: false,
          message: `Budget for ${category} already exists this month`,
        });
      }

      const budget = await Budget.create({
        user: req.user.id,
        category,
        amount,
        period: period || 'monthly',
        month,
        year,
        notifications,
      });

      // Calculate current spending
      const spent = await Transaction.aggregate([
        {
          $match: {
            user: req.user._id,
            type: 'expense',
            category: category === 'Overall' ? { $exists: true } : category,
            date: {
              $gte: new Date(year, month - 1, 1),
              $lt: new Date(year, month, 1),
            },
            isActive: true,
          },
        },
        { $group: { _id: null, total: { $sum: '$amount' } } },
      ]);

      if (spent.length > 0) {
        budget.spent = spent[0].total;
        await budget.save();
      }

      res.status(201).json({ success: true, message: 'Budget created', data: budget });
    } catch (error) {
      next(error);
    }
  },

  async update(req, res, next) {
    try {
      const budget = await Budget.findOne({ _id: req.params.id, user: req.user.id });
      if (!budget) {
        return res.status(404).json({ success: false, message: 'Budget not found' });
      }

      const { amount, notifications } = req.body;
      if (amount) budget.amount = amount;
      if (notifications !== undefined) budget.notifications = notifications;

      await budget.save();
      res.json({ success: true, message: 'Budget updated', data: budget });
    } catch (error) {
      next(error);
    }
  },

  async delete(req, res, next) {
    try {
      const budget = await Budget.findOneAndDelete({ _id: req.params.id, user: req.user.id });
      if (!budget) {
        return res.status(404).json({ success: false, message: 'Budget not found' });
      }
      res.json({ success: true, message: 'Budget deleted' });
    } catch (error) {
      next(error);
    }
  },

  async getOverview(req, res, next) {
    try {
      const now = new Date();
      const month = now.getMonth() + 1;
      const year = now.getFullYear();

      const budgets = await Budget.find({ user: req.user.id, month, year });
      const totalBudget = budgets.reduce((sum, b) => sum + b.amount, 0);
      const totalSpent = budgets.reduce((sum, b) => sum + b.spent, 0);

      // Get monthly spending by category
      const categorySpending = await Transaction.aggregate([
        {
          $match: {
            user: req.user._id,
            type: 'expense',
            date: { $gte: new Date(year, month - 1, 1), $lt: new Date(year, month, 1) },
            isActive: true,
          },
        },
        { $group: { _id: '$category', total: { $sum: '$amount' } } },
      ]);

      res.json({
        success: true,
        data: {
          budgets,
          summary: {
            totalBudget,
            totalSpent,
            remaining: totalBudget - totalSpent,
            percentageUsed: totalBudget > 0 ? Math.round((totalSpent / totalBudget) * 100) : 0,
          },
          categorySpending,
        },
      });
    } catch (error) {
      next(error);
    }
  },
};

module.exports = budgetController;
