const Budget = require('../models/Budget');
const Transaction = require('../models/Transaction');
const asyncHandler = require('../utils/catchAsync');
const { AppError } = require('../middleware/errorHandler');

const budgetController = {
  getAll: asyncHandler(async (req, res) => {
    const { month, year } = req.query;
    const query = { user: req.user.id };

    if (month) query.month = parseInt(month);
    if (year) query.year = parseInt(year);
    if (!month && !year) {
      const now = new Date();
      query.month = now.getMonth() + 1;
      query.year = now.getFullYear();
    }

    const budgets = await Budget.find(query).lean();

    res.json({ success: true, data: budgets });
  }),

  getById: asyncHandler(async (req, res) => {
    const budget = await Budget.findOne({ _id: req.params.id, user: req.user.id }).lean({ virtuals: true });
    if (!budget) {
      throw new AppError('Budget not found', 404);
    }
    res.json({ success: true, data: budget });
  }),

  create: asyncHandler(async (req, res) => {
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
      throw new AppError(`Budget for ${category} already exists this month`, 400);
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
  }),

  update: asyncHandler(async (req, res) => {
    const budget = await Budget.findOne({ _id: req.params.id, user: req.user.id });
    if (!budget) {
      throw new AppError('Budget not found', 404);
    }

    const { amount, notifications } = req.body;
    if (amount) budget.amount = amount;
    if (notifications !== undefined) budget.notifications = notifications;

    await budget.save();
    res.json({ success: true, message: 'Budget updated', data: budget });
  }),

  delete: asyncHandler(async (req, res) => {
    const budget = await Budget.findOneAndDelete({ _id: req.params.id, user: req.user.id });
    if (!budget) {
      throw new AppError('Budget not found', 404);
    }
    res.json({ success: true, message: 'Budget deleted' });
  }),

  getOverview: asyncHandler(async (req, res) => {
    const now = new Date();
    const month = now.getMonth() + 1;
    const year = now.getFullYear();

    const budgets = await Budget.find({ user: req.user.id, month, year }).lean();
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
  }),
};

module.exports = budgetController;
