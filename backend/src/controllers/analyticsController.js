const Transaction = require('../models/Transaction');
const Budget = require('../models/Budget');
const Goal = require('../models/Goal');
const asyncHandler = require('../utils/catchAsync');
const { getDateRange } = require('../utils/helpers');
const {
  sumTotal,
  sumByGroup,
  monthlyTrend,
  monthlyIncomeVsExpenses,
} = require('../utils/decryptedUtils');

const analyticsController = {
  getDashboard: asyncHandler(async (req, res) => {
    const now = new Date();
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
    const monthEnd = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59);

    // Current month stats
    const monthlyTransactions = await Transaction.find({
      user: req.user.id,
      date: { $gte: monthStart, $lte: monthEnd },
      isActive: true,
    });

    const monthlyIncome = monthlyTransactions
      .filter(t => t.type === 'income')
      .reduce((sum, t) => sum + t.amount, 0);

    const monthlyExpenses = monthlyTransactions
      .filter(t => t.type === 'expense' && t.category !== 'Savings')
      .reduce((sum, t) => sum + t.amount, 0);

    // Current balance (all time) — includes Savings (goal contributions)
    const [totalIncome, totalExpenses] = await Promise.all([
      sumTotal(Transaction, { user: req.user.id, type: 'income', isActive: true }, 'amount'),
      sumTotal(Transaction, { user: req.user.id, type: 'expense', isActive: true }, 'amount'),
    ]);
    const balance = totalIncome - totalExpenses;

    // Budget info (sum of all budgets for the month)
    const budgets = await Budget.find({ user: req.user.id, month: now.getMonth() + 1, year: now.getFullYear() });
    const totalBudget = budgets.reduce((sum, b) => sum + b.amount, 0);
    const totalBudgetSpent = budgets.reduce((sum, b) => sum + b.spent, 0);
    const remainingBudget = totalBudget - totalBudgetSpent;

    // Savings (active goals total)
    const goals = await Goal.find({ user: req.user.id, status: 'active' });
    const totalSavings = goals.reduce((sum, g) => sum + g.currentAmount, 0);

    // Payment method breakdown (current month expenses)
    const paymentMethodBreakdown = await sumByGroup(Transaction, {
      user: req.user.id,
      type: 'expense',
      date: { $gte: monthStart, $lte: monthEnd },
      isActive: true,
    }, 'paymentMethod', 'amount');

    // Recent transactions
    const recentTransactions = await Transaction.find({ user: req.user.id, isActive: true })
      .sort('-date')
      .limit(5);

    res.json({
      success: true,
      data: {
        balance,
        monthlyIncome,
        monthlyExpenses,
        savings: totalSavings,
        remainingBudget,
        recentTransactions,
        paymentMethodBreakdown,
        month: now.getMonth() + 1,
        year: now.getFullYear(),
      },
    });
  }),

  getCategoryBreakdown: asyncHandler(async (req, res) => {
    const { period = 'monthly' } = req.query;
    const { start, end } = getDateRange(period);

    const breakdown = await Transaction.getCategoryBreakdown(req.user.id, start, end);
    const totalSpent = breakdown.reduce((sum, cat) => sum + cat.total, 0);

    const data = breakdown.map(cat => ({
      category: cat._id,
      amount: cat.total,
      count: cat.count,
      percentage: totalSpent > 0 ? Math.round((cat.total / totalSpent) * 100) : 0,
    }));

    res.json({ success: true, data: { breakdown: data, total: totalSpent, period } });
  }),

  getMonthlyTrend: asyncHandler(async (req, res) => {
    const { months = 6 } = req.query;
    const endDate = new Date();
    const startDate = new Date();
    startDate.setMonth(startDate.getMonth() - parseInt(months));

    const trends = await monthlyTrend(Transaction, {
      user: req.user.id,
      date: { $gte: startDate, $lte: endDate },
      category: { $ne: 'Savings' },
      isActive: true,
    });

    // Format data for charts
    const monthlyData = {};
    trends.forEach(t => {
      const key = `${t._id.year}-${String(t._id.month).padStart(2, '0')}`;
      if (!monthlyData[key]) {
        monthlyData[key] = { month: key, income: 0, expenses: 0 };
      }
      if (t._id.type === 'income') monthlyData[key].income = t.total;
      else monthlyData[key].expenses = t.total;
    });

    res.json({ success: true, data: Object.values(monthlyData) });
  }),

  getIncomeVsExpenses: asyncHandler(async (req, res) => {
    const { period = 'monthly' } = req.query;
    const { start, end } = getDateRange(period);

    const incomeVsExpenses = await sumByGroup(Transaction, {
      user: req.user.id,
      date: { $gte: start, $lte: end },
      category: { $ne: 'Savings' },
      isActive: true,
    }, 'type', 'amount');

    const income = incomeVsExpenses.find(t => t._id === 'income');
    const expenses = incomeVsExpenses.find(t => t._id === 'expense');

    res.json({
      success: true,
      data: {
        income: income ? { total: income.total, count: income.count } : { total: 0, count: 0 },
        expenses: expenses ? { total: expenses.total, count: expenses.count } : { total: 0, count: 0 },
        net: (income ? income.total : 0) - (expenses ? expenses.total : 0),
      },
    });
  }),

  getSavingsGrowth: asyncHandler(async (req, res) => {
    const { months = 6 } = req.query;
    const endDate = new Date();
    const startDate = new Date();
    startDate.setMonth(startDate.getMonth() - parseInt(months));

    const goals = await Goal.find({ user: req.user.id }).select('title currentAmount targetAmount updatedAt createdAt');
    const savingsByMonth = await monthlyIncomeVsExpenses(Transaction, {
      user: req.user.id,
      date: { $gte: startDate, $lte: endDate },
      category: { $ne: 'Savings' },
      isActive: true,
    });

    const growth = savingsByMonth.map(s => ({
      month: `${s._id.year}-${String(s._id.month).padStart(2, '0')}`,
      savings: s.income - s.expenses,
      income: s.income,
      expenses: s.expenses,
    }));

    res.json({ success: true, data: { growth, goals } });
  }),

  getFullReport: asyncHandler(async (req, res) => {
    const { period = 'monthly' } = req.query;
    const { start, end } = getDateRange(period);

    const [
      categoryBreakdown,
      incomeVsExpenses,
      transactions,
      budgetInfo,
      goals,
    ] = await Promise.all([
      Transaction.getCategoryBreakdown(req.user.id, start, end),
      sumByGroup(Transaction, { user: req.user.id, date: { $gte: start, $lte: end }, category: { $ne: 'Savings' }, isActive: true }, 'type', 'amount'),
      Transaction.find({ user: req.user.id, date: { $gte: start, $lte: end }, category: { $ne: 'Savings' }, isActive: true }).sort('-date'),
      Budget.find({ user: req.user.id, month: start.getMonth() + 1, year: start.getFullYear() }),
      Goal.find({ user: req.user.id, status: 'active' }),
    ]);

    const income = incomeVsExpenses.find(t => t._id === 'income');
    const expenses = incomeVsExpenses.find(t => t._id === 'expense');

    res.json({
      success: true,
      data: {
        period,
        dateRange: { start, end },
        summary: {
          income: income ? income.total : 0,
          expenses: expenses ? expenses.total : 0,
          net: (income ? income.total : 0) - (expenses ? expenses.total : 0),
        },
        categoryBreakdown,
        budgets: budgetInfo,
        goals,
        transactions,
      },
    });
  }),
};

module.exports = analyticsController;
