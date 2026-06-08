/**
 * AI Context Builder
 *
 * Gathers comprehensive financial data for a user and builds a FinancialContext
 * object used by the AI to generate personalized responses.
 *
 * The context includes:
 *   - Balance, income, expenses (current month and historical)
 *   - Spending by category and payment method
 *   - Budget utilization
 *   - Savings goals with progress
 *   - Subscriptions with monthly/yearly costs
 *   - Recurring transactions
 *   - Monthly trends (6 months)
 *   - Category changes vs previous month
 *   - Daily spending habits
 *   - Gamification data
 *   - Recent transactions
 *   - Income breakdown by category
 */

const mongoose = require('mongoose');
const Transaction = require('../models/Transaction');
const Budget = require('../models/Budget');
const Goal = require('../models/Goal');
const Subscription = require('../models/Subscription');
const RecurringTransaction = require('../models/RecurringTransaction');
const Challenge = require('../models/Challenge');

class AIContextBuilder {
  /**
   * Build the full financial context for a user.
   * @param {string|ObjectId} userId
   * @returns {Promise<Object>} FinancialContext
   */
  async buildContext(userId) {
    const uid = new mongoose.Types.ObjectId(userId);
    const now = new Date();
    const currentMonth = now.getMonth();
    const currentYear = now.getFullYear();
    const monthStart = new Date(currentYear, currentMonth, 1);
    const monthEnd = new Date(currentYear, currentMonth + 1, 1);
    const prevMonthStart = new Date(currentYear, currentMonth - 1, 1);
    const prevMonthEnd = new Date(currentYear, currentMonth, 1);

    // Run all data queries in parallel
    const [
      currentMonthTx,
      prevMonthTx,
      budgets,
      goals,
      subscriptions,
      recurring,
      challenges,
      sixMonthTx,
    ] = await Promise.all([
      Transaction.find({ user: uid, isActive: true, date: { $gte: monthStart, $lt: monthEnd } })
        .sort({ date: -1 }).lean(),
      Transaction.find({ user: uid, isActive: true, date: { $gte: prevMonthStart, $lt: prevMonthEnd } })
        .lean(),
      Budget.find({ user: uid }).lean(),
      Goal.find({ user: uid }).lean(),
      Subscription.find({ user: uid, isActive: true }).lean(),
      RecurringTransaction.find({ user: uid, isActive: true }).lean(),
      Challenge.find({ user: uid }).lean(),
      Transaction.find({
        user: uid,
        isActive: true,
        date: { $gte: new Date(currentYear, currentMonth - 5, 1) },
      }).sort({ date: -1 }).lean(),
    ]);

    // ── Current month aggregates ──
    const incomeTx = currentMonthTx.filter(t => t.type === 'income');
    const expenseTx = currentMonthTx.filter(t => t.type === 'expense');
    const monthlyIncome = incomeTx.reduce((s, t) => s + (t.amount || 0), 0);
    const monthlyExpenses = expenseTx.reduce((s, t) => s + (t.amount || 0), 0);
    const balance = monthlyIncome - monthlyExpenses;
    const savingsRate = monthlyIncome > 0 ? ((monthlyIncome - monthlyExpenses) / monthlyIncome * 100) : 0;

    // ── Category breakdown ──
    const categoryTotals = {};
    expenseTx.forEach(t => {
      const cat = t.category || 'Other';
      categoryTotals[cat] = (categoryTotals[cat] || 0) + (t.amount || 0);
    });
    const totalExpenses = Object.values(categoryTotals).reduce((s, v) => s + v, 0);
    const categoryBreakdown = Object.entries(categoryTotals)
      .map(([category, amount]) => ({
        category,
        amount: Math.round(amount * 100) / 100,
        percentage: totalExpenses > 0 ? Math.round((amount / totalExpenses) * 100) : 0,
      }))
      .sort((a, b) => b.amount - a.amount);

    // ── Payment method breakdown ──
    const methodTotals = {};
    expenseTx.forEach(t => {
      const m = t.paymentMethod || 'Cash';
      methodTotals[m] = (methodTotals[m] || 0) + (t.amount || 0);
    });
    const paymentMethodBreakdown = Object.entries(methodTotals)
      .map(([method, amount]) => ({
        method,
        amount: Math.round(amount * 100) / 100,
        percentage: totalExpenses > 0 ? Math.round((amount / totalExpenses) * 100) : 0,
      }));

    // ── Budget utilization ──
    const budgetUtilization = budgets.map(b => {
      const spent = categoryTotals[b.category] || 0;
      const remaining = Math.max(0, (b.amount || 0) - spent);
      return {
        category: b.category,
        budgeted: Math.round((b.amount || 0) * 100) / 100,
        spent: Math.round(spent * 100) / 100,
        remaining: Math.round(remaining * 100) / 100,
        percentUsed: b.amount > 0 ? Math.min(100, Math.round((spent / b.amount) * 100)) : 0,
        status: spent > (b.amount || 0) ? 'over_budget' : spent > (b.amount || 0) * 0.8 ? 'at_risk' : 'on_track',
      };
    });

    // ── Previous month comparison ──
    const prevIncome = prevMonthTx.filter(t => t.type === 'income').reduce((s, t) => s + (t.amount || 0), 0);
    const prevExpenses = prevMonthTx.filter(t => t.type === 'expense').reduce((s, t) => s + (t.amount || 0), 0);
    const incomeChange = prevIncome > 0 ? Math.round(((monthlyIncome - prevIncome) / prevIncome) * 100) : 0;
    const expenseChange = prevExpenses > 0 ? Math.round(((monthlyExpenses - prevExpenses) / prevExpenses) * 100) : 0;

    // ── Category changes vs last month ──
    const prevCategoryTotals = {};
    prevMonthTx.filter(t => t.type === 'expense').forEach(t => {
      const cat = t.category || 'Other';
      prevCategoryTotals[cat] = (prevCategoryTotals[cat] || 0) + (t.amount || 0);
    });
    const categoryChanges = Object.entries(categoryTotals).map(([cat, amount]) => {
      const prev = prevCategoryTotals[cat] || 0;
      return {
        category: cat,
        currentAmount: Math.round(amount * 100) / 100,
        previousAmount: Math.round(prev * 100) / 100,
        change: prev > 0 ? Math.round(((amount - prev) / prev) * 100) : amount > 0 ? 100 : 0,
      };
    }).sort((a, b) => Math.abs(b.change) - Math.abs(a.change));

    // ── Monthly trends (6 months) ──
    const monthlyTrends = [];
    for (let i = 5; i >= 0; i--) {
      const start = new Date(currentYear, currentMonth - i, 1);
      const end = new Date(currentYear, currentMonth - i + 1, 1);
      const monthTx = sixMonthTx.filter(t => {
        const d = new Date(t.date);
        return d >= start && d < end;
      });
      const mi = monthTx.filter(t => t.type === 'income').reduce((s, t) => s + (t.amount || 0), 0);
      const me = monthTx.filter(t => t.type === 'expense').reduce((s, t) => s + (t.amount || 0), 0);
      monthlyTrends.push({
        month: `${start.getFullYear()}-${String(start.getMonth() + 1).padStart(2, '0')}`,
        income: Math.round(mi * 100) / 100,
        expenses: Math.round(me * 100) / 100,
        savings: Math.round((mi - me) * 100) / 100,
      });
    }

    // ── Income breakdown ──
    const incomeByCategory = {};
    incomeTx.forEach(t => {
      const cat = t.category || 'Other';
      incomeByCategory[cat] = (incomeByCategory[cat] || 0) + (t.amount || 0);
    });
    const incomeBreakdown = Object.entries(incomeByCategory).map(([category, amount]) => ({
      category,
      amount: Math.round(amount * 100) / 100,
      percentage: monthlyIncome > 0 ? Math.round((amount / monthlyIncome) * 100) : 0,
    }));

    // ── Recurring split ──
    const recurringIncome = recurring.filter(r => r.type === 'income');
    const recurringExpenses = recurring.filter(r => r.type === 'expense');

    // ── Habits ──
    const daysInMonth = new Date(currentYear, currentMonth + 1, 0).getDate();
    const daysSoFar = Math.min(now.getDate(), daysInMonth);
    const avgDailySpend = daysSoFar > 0 ? Math.round((monthlyExpenses / daysSoFar) * 100) / 100 : 0;
    const projectedMonthly = Math.round(avgDailySpend * daysInMonth * 100) / 100;

    // Build and return the full context
    return {
      balance: Math.round(balance * 100) / 100,
      monthlyIncome: Math.round(monthlyIncome * 100) / 100,
      monthlyExpenses: Math.round(monthlyExpenses * 100) / 100,
      savingsRate: Math.round(savingsRate * 100) / 100,
      totalExpenses: Math.round(totalExpenses * 100) / 100,

      incomeBreakdown,
      categoryBreakdown,
      paymentMethodBreakdown,
      budgetUtilization,

      savingsGoals: goals.map(g => ({
        name: g.title || g.name || 'Untitled Goal',
        target: g.targetAmount || 0,
        current: g.currentAmount || 0,
        progress: g.targetAmount > 0 ? Math.min(100, Math.round(((g.currentAmount || 0) / g.targetAmount) * 100)) : 0,
        monthlyContribution: g.monthlyContribution || 0,
        remainingMonths: g.monthlyContribution > 0
          ? Math.ceil(((g.targetAmount || 0) - (g.currentAmount || 0)) / g.monthlyContribution)
          : null,
        targetDate: g.targetDate || null,
        category: g.category || 'Other',
      })),

      subscriptions: subscriptions.map(s => ({
        name: s.name,
        amount: s.amount || 0,
        category: s.category || 'Other',
        monthlyAmount: s.monthlyAmount || s.amount || 0,
        yearlyAmount: s.yearlyAmount || (s.amount || 0) * 12,
        nextBillingDate: s.nextBillingDate || null,
        billingDate: s.billingDate || 1,
        renewalFrequency: s.renewalFrequency || 'monthly',
      })),

      recurringTransactions: {
        income: recurringIncome.map(r => ({
          name: r.name,
          amount: r.amount || 0,
          frequency: r.frequency || 'monthly',
          category: r.category || 'Other',
        })),
        expenses: recurringExpenses.map(r => ({
          name: r.name,
          amount: r.amount || 0,
          frequency: r.frequency || 'monthly',
          category: r.category || 'Other',
        })),
      },

      monthlyTrends,
      categoryChanges,
      incomeChange,
      expenseChange,

      habits: {
        biggestCategory: categoryBreakdown[0] || null,
        fastestGrowing: categoryChanges.filter(c => c.change > 0 && c.currentAmount > 0)[0] || null,
        mostUsedPaymentMethod: paymentMethodBreakdown.sort((a, b) => b.amount - a.amount)[0] || null,
        averageDailySpend: avgDailySpend,
        projectedMonthlyExpenses: projectedMonthly,
        transactionCount: currentMonthTx.length,
        incomeTransactionCount: incomeTx.length,
        expenseTransactionCount: expenseTx.length,
        daysInMonth,
        daysSoFar,
        remainingDays: daysInMonth - daysSoFar,
      },

      recentTransactions: currentMonthTx.slice(0, 10).map(t => ({
        description: t.description || '',
        amount: t.amount || 0,
        type: t.type,
        category: t.category || 'Other',
        date: t.date,
        paymentMethod: t.paymentMethod || 'Cash',
      })),

      gamification: {
        totalPoints: challenges.reduce((s, c) => s + (c.points || c.totalPoints || 0), 0),
        loginStreak: challenges[0]?.loginStreak || 0,
        noSpendStreak: challenges[0]?.noSpendStreak || 0,
        activeChallenges: challenges.filter(c => c.status === 'active' || !c.status).length,
      },

      generatedAt: new Date().toISOString(),
      userId: userId.toString(),
    };
  }
}

module.exports = new AIContextBuilder();
