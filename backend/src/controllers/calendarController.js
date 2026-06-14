const Transaction = require('../models/Transaction');
const RecurringTransaction = require('../models/RecurringTransaction');
const Budget = require('../models/Budget');
const Goal = require('../models/Goal');
const catchAsync = require('../utils/catchAsync');
const mongoose = require('mongoose');

exports.getCalendarData = catchAsync(async (req, res) => {
  const { year, month } = req.query;
  const y = parseInt(year) || new Date().getFullYear();
  const m = parseInt(month) || new Date().getMonth() + 1;
  const startDate = new Date(y, m - 1, 1);
  const endDate = new Date(y, m, 1);

  const transactions = await Transaction.find({
    user: req.user.id, isActive: true,
    date: { $gte: startDate, $lt: endDate },
  }).sort({ date: 1 });

  const dailyMap = {};
  const pad = (n) => String(n).padStart(2, '0');
  transactions.forEach(tx => {
    const d = new Date(tx.date);
    const dayKey = `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
    if (!dailyMap[dayKey]) dailyMap[dayKey] = { income: 0, expense: 0, savings: 0, transactions: [] };
    const key = tx.category === 'Savings' ? 'savings' : tx.type;
    dailyMap[dayKey][key] += tx.amount;
    dailyMap[dayKey].transactions.push(tx);
  });

  const upcomingRecurring = await RecurringTransaction.find({
    user: req.user.id, isActive: true,
    startDate: { $lte: endDate },
    $or: [{ endDate: null }, { endDate: { $gte: startDate } }],
  }).lean();

  const budgets = await Budget.find({ user: req.user.id, month: m, year: y });
  const budgetDeadlines = budgets.map(b => ({
    category: b.category,
    limit: b.amount,
    spent: b.spent,
    deadline: new Date(y, m, 0),
  }));

  const goals = await Goal.find({ user: req.user.id, status: 'active' });
  const goalMilestones = goals.map(g => ({
    title: g.title,
    targetDate: g.targetDate,
    progress: g.progress,
  }));

  res.json({
    success: true,
    data: {
      year: y,
      month: m,
      daily: dailyMap,
      upcomingRecurring,
      budgetDeadlines,
      goalMilestones,
    },
  });
});
