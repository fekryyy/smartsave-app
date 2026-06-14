const Transaction = require('../models/Transaction');
const Budget = require('../models/Budget');
const catchAsync = require('../utils/catchAsync');
const {
  sumByType,
  sumByGroup,
  typeTotalsWithMax,
  monthlyTrend,
  dailyTotals,
  spendingStats,
} = require('../utils/decryptedUtils');

exports.getMonthlyReport = catchAsync(async (req, res) => {
  const { year, month } = req.query;
  const y = parseInt(year) || new Date().getFullYear();
  const m = parseInt(month) || new Date().getMonth() + 1;
  const startDate = new Date(y, m - 1, 1);
  const endDate = new Date(y, m, 1);

  const prevStart = new Date(y, m - 2, 1);
  const prevEnd = new Date(y, m - 1, 1);

  const [agg, prevAgg] = await Promise.all([
    typeTotalsWithMax(Transaction, { user: req.user.id, isActive: true, date: { $gte: startDate, $lt: endDate } }),
    sumByType(Transaction, { user: req.user.id, isActive: true, date: { $gte: prevStart, $lt: prevEnd } }),
  ]);

  const income = agg.find(a => a._id === 'income');
  const expense = agg.find(a => a._id === 'expense');
  const totalIncome = income?.total || 0;
  const totalExpenses = expense?.total || 0;
  const netSavings = totalIncome - totalExpenses;
  const savingsRate = totalIncome > 0 ? (netSavings / totalIncome) * 100 : 0;

  const prevIncome = prevAgg.find(a => a._id === 'income');
  const prevExpense = prevAgg.find(a => a._id === 'expense');
  const prevTotalIncome = prevIncome?.total || 0;
  const prevTotalExpenses = prevExpense?.total || 0;
  const incomeChange = prevTotalIncome > 0 ? ((totalIncome - prevTotalIncome) / prevTotalIncome) * 100 : 0;
  const expenseChange = prevTotalExpenses > 0 ? ((totalExpenses - prevTotalExpenses) / prevTotalExpenses) * 100 : 0;
  const savingsChange = prevTotalIncome - prevTotalExpenses !== 0
    ? ((netSavings - (prevTotalIncome - prevTotalExpenses)) / Math.abs(prevTotalIncome - prevTotalExpenses)) * 100 : 0;

  const [categoryBreakdown, methodBreakdown] = await Promise.all([
    sumByGroup(Transaction, { user: req.user.id, type: 'expense', category: { $ne: 'Savings' }, isActive: true, date: { $gte: startDate, $lt: endDate } }, 'category', 'amount'),
    sumByGroup(Transaction, { user: req.user.id, type: 'expense', isActive: true, date: { $gte: startDate, $lt: endDate } }, 'paymentMethod', 'amount'),
  ]);

  const largestExpense = await Transaction.findOne({
    user: req.user.id, type: 'expense', isActive: true, date: { $gte: startDate, $lt: endDate },
  }).sort({ amount: -1 });

  const budgets = await Budget.find({ user: req.user.id, month: m, year: y });
  const budgetPerformance = budgets.map(b => ({
    category: b.category, limit: b.limit, spent: b.spent,
    percentage: b.limit > 0 ? (b.spent / b.limit) * 100 : 0,
    remaining: Math.max(0, b.limit - b.spent),
  }));

  // Sort by total descending (original $sort is no longer applied by MongoDB)
  const sortedCategoryBreakdown = [...categoryBreakdown].sort((a, b) => b.total - a.total);
  const sortedMethodBreakdown = [...methodBreakdown].sort((a, b) => b.total - a.total);

  res.json({
    success: true,
    data: {
      period: { month: m, year: y },
      totalIncome, totalExpenses, netSavings, savingsRate: Math.round(savingsRate * 100) / 100,
      incomeChange: Math.round(incomeChange * 100) / 100,
      expenseChange: Math.round(expenseChange * 100) / 100,
      savingsChange: Math.round(savingsChange * 100) / 100,
      mostUsedMethod: sortedMethodBreakdown[0]?._id || 'N/A',
      largestExpense: largestExpense || null,
      topCategory: sortedCategoryBreakdown[0]?._id || 'N/A',
      categoryBreakdown: sortedCategoryBreakdown,
      methodBreakdown: sortedMethodBreakdown,
      budgetPerformance,
      transactionCount: (income?.count || 0) + (expense?.count || 0),
      incomeCount: income?.count || 0,
      expenseCount: expense?.count || 0,
    },
  });
});

exports.getComparison = catchAsync(async (req, res) => {
  const { year, month } = req.query;
  const y = parseInt(year) || new Date().getFullYear();
  const m = parseInt(month) || new Date().getMonth() + 1;

  const months = [];
  for (let i = 5; i >= 0; i--) {
    let targetM = m - i;
    let targetY = y;
    if (targetM <= 0) { targetM += 12; targetY -= 1; }
    months.push({ month: targetM, year: targetY });
  }

  const data = await Promise.all(months.map(async ({ month: mm, year: yy }) => {
    const start = new Date(yy, mm - 1, 1);
    const end = new Date(yy, mm, 1);
    const [byType, catBreak, methodBreak] = await Promise.all([
      sumByType(Transaction, { user: req.user.id, isActive: true, date: { $gte: start, $lt: end } }),
      sumByGroup(Transaction, { user: req.user.id, type: 'expense', category: { $ne: 'Savings' }, isActive: true, date: { $gte: start, $lt: end } }, 'category', 'amount'),
      sumByGroup(Transaction, { user: req.user.id, type: 'expense', isActive: true, date: { $gte: start, $lt: end } }, 'paymentMethod', 'amount'),
    ]);
    const income = byType.find(a => a._id === 'income')?.total || 0;
    const expense = byType.find(a => a._id === 'expense')?.total || 0;

    return { month: mm, year: yy, income, expense, savings: income - expense, categories: catBreak, methods: methodBreak };
  }));

  res.json({ success: true, data });
});

exports.getTrends = catchAsync(async (req, res) => {
  const ninetyDaysAgo = new Date(Date.now() - 90 * 86400000);

  const [monthlyAgg, categoryTrendsRaw] = await Promise.all([
    monthlyTrend(Transaction, { user: req.user.id, isActive: true, date: { $gte: ninetyDaysAgo } }),
    // Category trends: group by category + month (cannot use sumByGroup which only groups by one field)
    (async () => {
      const docs = await Transaction.find({ user: req.user.id, type: 'expense', category: { $ne: 'Savings' }, isActive: true, date: { $gte: ninetyDaysAgo } });
      const grouped = {};
      for (const doc of docs) {
        const d = doc.date || new Date();
        const key = `${doc.category}|${d.getFullYear()}|${d.getMonth() + 1}`;
        if (!grouped[key]) {
          grouped[key] = { _id: { category: doc.category, month: d.getMonth() + 1, year: d.getFullYear() }, total: 0 };
        }
        grouped[key].total += typeof doc.amount === 'number' ? doc.amount : parseFloat(doc.amount) || 0;
      }
      return Object.values(grouped).sort((a, b) => {
        if (a._id.year !== b._id.year) return a._id.year - b._id.year;
        return a._id.month - b._id.month;
      });
    })(),
  ]);

  const catMap = {};
  categoryTrendsRaw.forEach(c => {
    const key = c._id.category;
    if (!catMap[key]) catMap[key] = [];
    catMap[key].push({ month: c._id.month, year: c._id.year, total: c.total });
  });

  const fastestGrowing = { category: '', change: -Infinity };
  const mostReduced = { category: '', change: Infinity };
  Object.entries(catMap).forEach(([cat, vals]) => {
    if (vals.length >= 2) {
      const first = vals[0].total;
      const last = vals[vals.length - 1].total;
      const change = first > 0 ? ((last - first) / first) * 100 : 0;
      if (change > fastestGrowing.change) fastestGrowing.category = cat, fastestGrowing.change = change;
      if (change < mostReduced.change) mostReduced.category = cat, mostReduced.change = change;
    }
  });

  const dailySpending = await spendingStats(Transaction, { user: req.user.id, type: 'expense', isActive: true, date: { $gte: ninetyDaysAgo } });

  const ds = dailySpending[0] || {};
  const days = Math.max(1, Math.ceil((Date.now() - ninetyDaysAgo.getTime()) / 86400000));
  const avgDaily = ds.total / days || 0;
  const avgWeekly = avgDaily * 7;
  const avgMonthly = avgDaily * 30;

  res.json({
    success: true,
    data: {
      monthlyAgg,
      categoryTrends: catMap,
      fastestGrowing,
      mostReduced,
      averageDaily: Math.round(avgDaily * 100) / 100,
      averageWeekly: Math.round(avgWeekly * 100) / 100,
      averageMonthly: Math.round(avgMonthly * 100) / 100,
      totalSpending: ds.total || 0,
      transactionCount: ds.count || 0,
    },
  });
});

exports.getHeatmap = catchAsync(async (req, res) => {
  const { year } = req.query;
  const y = parseInt(year) || new Date().getFullYear();
  const startDate = new Date(y, 0, 1);
  const endDate = new Date(y + 1, 0, 1);

  const dailyAgg = await dailyTotals(Transaction, { user: req.user.id, type: 'expense', isActive: true, date: { $gte: startDate, $lt: endDate } });

  const heatmap = {};
  let maxSpend = 0;
  dailyAgg.forEach(d => {
    heatmap[d._id] = { total: d.total, count: d.count };
    if (d.total > maxSpend) maxSpend = d.total;
  });

  res.json({ success: true, data: { year: y, heatmap, maxSpend } });
});
