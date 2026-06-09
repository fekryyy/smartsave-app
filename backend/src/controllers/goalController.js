const Goal = require('../models/Goal');
const Transaction = require('../models/Transaction');
const Notification = require('../models/Notification');
const asyncHandler = require('../utils/catchAsync');
const { AppError } = require('../middleware/errorHandler');
const { auditFromRequest } = require('../utils/audit');

const goalController = {
  getAll: asyncHandler(async (req, res) => {
    const { status, page = 1, limit = 50 } = req.query;
    const query = { user: req.user.id };
    if (status) query.status = status;

    const goals = await Goal.find(query)
      .sort('-createdAt')
      .skip((page - 1) * limit)
      .limit(parseInt(limit))
      .lean({ virtuals: true });

    const total = await Goal.countDocuments(query);

    res.json({
      success: true,
      data: goals,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / limit),
      },
    });
  }),

  getById: asyncHandler(async (req, res) => {
    const goal = await Goal.findOne({ _id: req.params.id, user: req.user.id }).lean({ virtuals: true });
    if (!goal) {
      throw new AppError('Goal not found', 404);
    }
    res.json({ success: true, data: goal });
  }),

  create: asyncHandler(async (req, res) => {
    const { title, description, targetAmount, targetDate, category, priority, icon, color, monthlyContribution } = req.body;

    const goal = await Goal.create({
      user: req.user.id,
      title,
      description,
      targetAmount,
      targetDate,
      category,
      priority: priority || 'medium',
      icon,
      color,
      monthlyContribution: monthlyContribution || 0,
    });

    auditFromRequest(req, 'create', 'goal', goal._id,
      `Created goal "${title}" with target $${targetAmount}`);

    res.status(201).json({ success: true, message: 'Goal created', data: goal });
  }),

  update: asyncHandler(async (req, res) => {
    const goal = await Goal.findOne({ _id: req.params.id, user: req.user.id });
    if (!goal) {
      throw new AppError('Goal not found', 404);
    }

    const allowedUpdates = ['title', 'description', 'targetAmount', 'targetDate', 'category', 'priority', 'monthlyContribution', 'icon', 'color'];
    allowedUpdates.forEach(field => {
      if (req.body[field] !== undefined) {
        goal[field] = req.body[field];
      }
    });

    await goal.save();
    auditFromRequest(req, 'update', 'goal', goal._id,
      `Updated goal "${goal.title}"`);
    res.json({ success: true, message: 'Goal updated', data: goal });
  }),

  delete: asyncHandler(async (req, res) => {
    const goal = await Goal.findOneAndDelete({ _id: req.params.id, user: req.user.id });
    if (!goal) {
      throw new AppError('Goal not found', 404);
    }
    auditFromRequest(req, 'delete', 'goal', goal._id,
      `Deleted goal "${goal.title}" ($${goal.currentAmount}/$${goal.targetAmount})`,
      { title: goal.title, targetAmount: goal.targetAmount, currentAmount: goal.currentAmount });
    res.json({ success: true, message: 'Goal deleted' });
  }),

  addContribution: asyncHandler(async (req, res) => {
    const { amount } = req.body;
    const goal = await Goal.findOne({ _id: req.params.id, user: req.user.id });

    if (!goal) {
      throw new AppError('Goal not found', 404);
    }

    if (goal.status === 'completed') {
      throw new AppError('Goal already completed', 400);
    }

    await goal.addContribution(amount);

    // Create expense transaction to deduct from balance
    await Transaction.create({
      user: req.user.id,
      type: 'expense',
      amount,
      category: 'Savings',
      description: `Contribution to "${goal.title}"`,
      date: new Date(),
    });

    // Create notification
    try {
      await Notification.create({
        user: req.user.id,
        type: 'goal_reminder',
        title: 'Savings Contribution',
        message: `\$${amount} added to "${goal.title}" goal`,
      });
    } catch (_) { /* notification failure is non-critical */ }

    auditFromRequest(req, 'contribution', 'goal', goal._id,
      `Added $${amount} contribution to "${goal.title}"`);

    res.json({ success: true, message: 'Contribution added', data: goal });
  }),

  getProgress: asyncHandler(async (req, res) => {
    const goals = await Goal.find({ user: req.user.id, status: 'active' }).lean({ virtuals: true });

    const progress = goals.map(goal => ({
      id: goal._id,
      title: goal.title,
      targetAmount: goal.targetAmount,
      currentAmount: goal.currentAmount,
      progress: goal.progress,
      remaining: goal.remaining,
      estimatedCompletionDate: goal.estimatedCompletionDate,
      monthlyContribution: goal.monthlyContribution,
    }));

    res.json({ success: true, data: progress });
  }),
};

module.exports = goalController;
