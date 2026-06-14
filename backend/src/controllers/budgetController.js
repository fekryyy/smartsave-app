const Budget = require('../models/Budget');
const Transaction = require('../models/Transaction');
const asyncHandler = require('../utils/catchAsync');
const { AppError } = require('../middleware/errorHandler');
const { auditFromRequest } = require('../utils/audit');
const { sumTotal, sumByGroup } = require('../utils/decryptedUtils');

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

    const budgets = await Budget.find(query);

    res.json({ success: true, data: budgets });
  }),

  getById: asyncHandler(async (req, res) => {
    const budget = await Budget.findOne({ _id: req.params.id, user: req.user.id });
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
    const totalSpent = await sumTotal(Transaction, {
      user: req.user.id,
      type: 'expense',
      category: category === 'Overall' ? { $exists: true } : category,
      date: {
        $gte: new Date(year, month - 1, 1),
        $lt: new Date(year, month, 1),
      },
      isActive: true,
    }, 'amount');

    if (totalSpent > 0) {
      budget.spent = totalSpent;
      await budget.save();
    }

    auditFromRequest(req, 'create', 'budget', budget._id,
      `Created budget of $${amount} for ${category} (${period})`);

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
    auditFromRequest(req, 'update', 'budget', budget._id,
      `Updated budget ${budget.category}: amount → $${budget.amount}`);
    res.json({ success: true, message: 'Budget updated', data: budget });
  }),

  delete: asyncHandler(async (req, res) => {
    const budget = await Budget.findOneAndDelete({ _id: req.params.id, user: req.user.id });
    if (!budget) {
      throw new AppError('Budget not found', 404);
    }
    auditFromRequest(req, 'delete', 'budget', budget._id,
      `Deleted budget ${budget.category} ($${budget.amount}/${budget.period})`,
      { category: budget.category, amount: budget.amount, period: budget.period });
    res.json({ success: true, message: 'Budget deleted' });
  }),

  getOverview: asyncHandler(async (req, res) => {
    const now = new Date();
    const month = now.getMonth() + 1;
    const year = now.getFullYear();

    const budgets = await Budget.find({ user: req.user.id, month, year });
    const totalBudget = budgets.reduce((sum, b) => sum + b.amount, 0);
    const totalSpent = budgets.reduce((sum, b) => sum + b.spent, 0);

    // Get monthly spending by category
    const categorySpending = await sumByGroup(Transaction, {
      user: req.user.id,
      type: 'expense',
      date: { $gte: new Date(year, month - 1, 1), $lt: new Date(year, month, 1) },
      isActive: true,
    }, 'category', 'amount');

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
