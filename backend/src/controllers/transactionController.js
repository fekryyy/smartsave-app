const User = require('../models/User');
const Transaction = require('../models/Transaction');
const Budget = require('../models/Budget');
const Notification = require('../models/Notification');
const UserStreak = require('../models/UserStreak');
const asyncHandler = require('../utils/catchAsync');
const { AppError } = require('../middleware/errorHandler');
const { checkAndAward } = require('./challengeController');

const transactionController = {
  getAll: asyncHandler(async (req, res) => {
    const { page = 1, limit = 20, type, category, startDate, endDate, paymentMethod, sort = '-date' } = req.query;
    const query = { user: req.user.id, isActive: true };

    if (type) query.type = type;
    if (category) query.category = category;
    if (paymentMethod) query.paymentMethod = paymentMethod;
    if (startDate || endDate) {
      query.date = {};
      if (startDate) query.date.$gte = new Date(startDate);
      if (endDate) query.date.$lte = new Date(endDate);
    }

    const transactions = await Transaction.find(query)
      .sort(sort)
      .skip((page - 1) * limit)
      .limit(parseInt(limit))
      .lean();

    const total = await Transaction.countDocuments(query);

    res.json({
      success: true,
      data: {
        transactions,
        pagination: {
          page: parseInt(page),
          limit: parseInt(limit),
          total,
          pages: Math.ceil(total / limit),
        },
      },
    });
  }),

  getById: asyncHandler(async (req, res) => {
    const transaction = await Transaction.findOne({
      _id: req.params.id,
      user: req.user.id,
    }).lean();

    if (!transaction) {
      throw new AppError('Transaction not found', 404);
    }

    res.json({ success: true, data: transaction });
  }),

  create: asyncHandler(async (req, res) => {
    const { type, amount, category, description, date, paymentMethod, currency, tags } = req.body;

    const transaction = await Transaction.create({
      user: req.user.id,
      type,
      amount,
      category,
      description,
      date: date || new Date(),
      paymentMethod,
      currency,
      tags,
    });

    // Update user totals
    const incFields = { totalTransactions: 1 };
    if (type === 'income') {
      incFields.totalIncome = amount;
    } else if (type === 'expense') {
      incFields.totalExpenses = amount;
      await updateBudgetSpent(req.user.id, category, amount, date);
    }
    await User.findByIdAndUpdate(req.user.id, { $inc: incFields });

    // Create notification
    try {
      const notifData = type === 'expense'
        ? { type: 'budget_warning', title: 'Expense Recorded', message: `\$${amount} spent on ${category}${description ? ': ' + description : ''}` }
        : { type: 'weekly_summary', title: 'Income Received', message: `\$${amount} income from ${category}` };
      await Notification.create({ user: req.user.id, ...notifData });
    } catch (_) { /* notification failure is non-critical */ }

    // Gamification: award transaction count achievements
    try {
      const count = await Transaction.countDocuments({ user: req.user.id, isActive: true });
      await checkAndAward(req, 'first_transaction', count);
      await checkAndAward(req, 'ten_transactions', count);
      await checkAndAward(req, 'fifty_transactions', count);
      if (type === 'expense') {
        const streak = await UserStreak.findOne({ user: req.user.id });
        if (streak) {
          streak.noSpendStreak = 0;
          streak.lastSpendDate = new Date();
          await streak.save();
        }
      }
    } catch (_) { /* gamification failure is non-critical */ }

    res.status(201).json({
      success: true,
      message: 'Transaction created successfully',
      data: transaction,
    });
  }),

  update: asyncHandler(async (req, res) => {
    const transaction = await Transaction.findOne({
      _id: req.params.id,
      user: req.user.id,
    });

    if (!transaction) {
      throw new AppError('Transaction not found', 404);
    }

    const oldAmount = transaction.amount;
    const oldCategory = transaction.category;
    const oldType = transaction.type;

    const allowedUpdates = ['amount', 'category', 'description', 'date', 'paymentMethod', 'currency', 'tags'];
    allowedUpdates.forEach(field => {
      if (req.body[field] !== undefined) {
        transaction[field] = req.body[field];
      }
    });

    await transaction.save();

    // Update user totals on type/amount change
    const userInc = {};
    if (oldType !== transaction.type || oldAmount !== transaction.amount) {
      // Reverse old values
      if (oldType === 'income') userInc.totalIncome = -oldAmount;
      if (oldType === 'expense') userInc.totalExpenses = -oldAmount;
      // Add new values
      if (transaction.type === 'income') userInc.totalIncome = (userInc.totalIncome || 0) + transaction.amount;
      if (transaction.type === 'expense') userInc.totalExpenses = (userInc.totalExpenses || 0) + transaction.amount;
    }
    if (Object.keys(userInc).length > 0) {
      await User.findByIdAndUpdate(req.user.id, { $inc: userInc });
    }

    // Update budgets if expense changed
    if (oldType === 'expense') {
      await updateBudgetSpent(req.user.id, oldCategory, -oldAmount, transaction.date);
    }
    if (transaction.type === 'expense') {
      await updateBudgetSpent(req.user.id, transaction.category, transaction.amount, transaction.date);
    }

    res.json({
      success: true,
      message: 'Transaction updated successfully',
      data: transaction,
    });
  }),

  delete: asyncHandler(async (req, res) => {
    const transaction = await Transaction.findOne({
      _id: req.params.id,
      user: req.user.id,
    });

    if (!transaction) {
      throw new AppError('Transaction not found', 404);
    }

    transaction.isActive = false;
    await transaction.save();

    // Reverse user totals
    const decFields = { totalTransactions: -1 };
    if (transaction.type === 'income') {
      decFields.totalIncome = -transaction.amount;
    } else if (transaction.type === 'expense') {
      decFields.totalExpenses = -transaction.amount;
      await updateBudgetSpent(req.user.id, transaction.category, -transaction.amount, transaction.date);
    }
    await User.findByIdAndUpdate(req.user.id, { $inc: decFields });

    res.json({ success: true, message: 'Transaction deleted successfully' });
  }),

  getRecent: asyncHandler(async (req, res) => {
    const transactions = await Transaction.find({ user: req.user.id, isActive: true })
      .sort('-date')
      .limit(10)
      .lean();

    res.json({ success: true, data: transactions });
  }),
};

async function updateBudgetSpent(userId, category, amount, date) {
  const transactionDate = date ? new Date(date) : new Date();
  const month = transactionDate.getMonth() + 1;
  const year = transactionDate.getFullYear();

  // Update category budget (only if it exists, upsert disabled to avoid creating docs without amount)
  await Budget.findOneAndUpdate(
    { user: userId, category, month, year },
    { $inc: { spent: amount } },
  );

  // Update overall budget (only if it exists)
  await Budget.findOneAndUpdate(
    { user: userId, category: 'Overall', month, year },
    { $inc: { spent: amount } },
  );
}

module.exports = transactionController;
