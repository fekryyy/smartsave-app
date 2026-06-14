const Transaction = require('../models/Transaction');
const Budget = require('../models/Budget');
const Goal = require('../models/Goal');
const asyncHandler = require('../utils/catchAsync');
const { sumByGroup, sumTotal } = require('../utils/decryptedUtils');

const recommendationController = {
  getRecommendations: asyncHandler(async (req, res) => {
      const userId = req.user.id;
      const now = new Date();
      const currentMonth = now.getMonth() + 1;
      const currentYear = now.getFullYear();
      const lastMonth = currentMonth === 1 ? 12 : currentMonth - 1;
      const lastMonthYear = currentMonth === 1 ? currentYear - 1 : currentYear;

      const recommendations = [];

      // Get current month expenses
      const currentExpenses = await sumByGroup(Transaction, {
        user: req.user.id,
        type: 'expense',
        date: { $gte: new Date(currentYear, currentMonth - 1, 1), $lt: new Date(currentYear, currentMonth, 1) },
        isActive: true,
      }, 'category', 'amount');

      // Get last month expenses for comparison
      const lastExpenses = await sumByGroup(Transaction, {
        user: req.user.id,
        type: 'expense',
        date: { $gte: new Date(lastMonthYear, lastMonth - 1, 1), $lt: new Date(lastMonthYear, lastMonth, 1) },
        isActive: true,
      }, 'category', 'amount');

      const lastMonthMap = {};
      lastExpenses.forEach(e => { lastMonthMap[e._id] = e.total; });

      // 1. Compare with last month
      currentExpenses.forEach(current => {
        const lastAmount = lastMonthMap[current._id] || 0;
        if (lastAmount > 0) {
          const change = ((current.total - lastAmount) / lastAmount) * 100;
          if (change > 20) {
            recommendations.push({
              type: 'warning',
              category: current._id,
              message: `You spent ${Math.round(change)}% more on ${current._id} this month compared to last month. Consider reviewing your ${current._id.toLowerCase()} expenses.`,
              impact: 'high',
            });
          } else if (change < -20) {
            recommendations.push({
              type: 'success',
              category: current._id,
              message: `Great job! You reduced your ${current._id} spending by ${Math.round(Math.abs(change))}% compared to last month.`,
              impact: 'positive',
            });
          }
        }
      });

      // 2. Budget warnings
      const budgets = await Budget.find({ user: userId, month: currentMonth, year: currentYear });
      budgets.forEach(budget => {
        if (budget.amount > 0) {
          const percentage = (budget.spent / budget.amount) * 100;
          if (percentage >= 90) {
            recommendations.push({
              type: 'danger',
              category: budget.category,
              message: `You have used ${Math.round(percentage)}% of your ${budget.category} budget. Only $${(budget.amount - budget.spent).toFixed(2)} remaining.`,
              impact: 'high',
            });
          } else if (percentage >= 75) {
            recommendations.push({
              type: 'warning',
              category: budget.category,
              message: `You have used ${Math.round(percentage)}% of your ${budget.category} budget. Consider reducing spending.`,
              impact: 'medium',
            });
          }
        }
      });

      // 3. Savings opportunities
      const totalCurrentExpenses = currentExpenses.reduce((s, e) => s + e.total, 0);
      const averageExpense = currentExpenses.length > 0 ? totalCurrentExpenses / currentExpenses.length : 0;

      currentExpenses.forEach(exp => {
        if (exp.total > averageExpense * 1.5 && exp._id !== 'Bills' && exp._id !== 'Health') {
          recommendations.push({
            type: 'opportunity',
            category: exp._id,
            message: `Your ${exp._id} spending ($${exp.total.toFixed(2)}) is significantly higher than average. Consider setting a ${exp._id.toLowerCase()} budget.`,
            impact: 'medium',
          });
        }
      });

      // 4. Goal-related recommendations
      const activeGoals = await Goal.find({ user: userId, status: 'active' });
      for (const goal of activeGoals) {
        if (goal.monthlyContribution > 0) {
          const income = await sumTotal(Transaction, {
            user: req.user.id,
            type: 'income',
            date: { $gte: new Date(currentYear, currentMonth - 1, 1), $lt: new Date(currentYear, currentMonth, 1) },
            isActive: true,
          }, 'amount');
          if (income > 0 && goal.monthlyContribution > income * 0.3) {
            recommendations.push({
              type: 'warning',
              category: 'Goal',
              message: `Your monthly contribution to "${goal.title}" is ${Math.round((goal.monthlyContribution / income) * 100)}% of your income. Consider adjusting for better financial balance.`,
              impact: 'high',
            });
          }

          if (goal.currentAmount < goal.targetAmount) {
            const remaining = goal.targetAmount - goal.currentAmount;
            const extraMonthly = 50;
            if (goal.monthlyContribution > 0) {
              const currentMonths = Math.ceil(remaining / goal.monthlyContribution);
              const improvedMonths = Math.ceil(remaining / (goal.monthlyContribution + extraMonthly));
              if (improvedMonths < currentMonths) {
                recommendations.push({
                  type: 'opportunity',
                  category: 'Goal',
                  message: `Increasing your monthly contribution to "${goal.title}" by $50 could help you reach it ${currentMonths - improvedMonths} month(s) earlier.`,
                  impact: 'medium',
                });
              }
            }
          }
        } else if (goal.targetAmount > 0) {
          const remaining = goal.targetAmount - goal.currentAmount;
          const suggestedMonthly = Math.round(remaining / 6);
          recommendations.push({
            type: 'opportunity',
            category: 'Goal',
            message: `Set up a monthly contribution of $${suggestedMonthly} to reach your "${goal.title}" goal in approximately 6 months.`,
            impact: 'low',
          });
        }
      }

      // 5. Top spending category insight
      if (currentExpenses.length > 0) {
        const topCategory = currentExpenses.reduce((max, e) => e.total > max.total ? e : max, currentExpenses[0]);
        const topPercentage = (topCategory.total / totalCurrentExpenses) * 100;
        if (topPercentage > 40) {
          recommendations.push({
            type: 'insight',
            category: topCategory._id,
            message: `${topCategory._id} accounts for ${Math.round(topPercentage)}% of your total spending. Consider if this aligns with your financial priorities.`,
            impact: 'medium',
          });
        }
      }

      // Sort by impact
      const impactOrder = { high: 0, medium: 1, low: 2, positive: 3 };
      recommendations.sort((a, b) => (impactOrder[a.impact] || 0) - (impactOrder[b.impact] || 0));

      res.json({ success: true, data: recommendations });
    }),
};

module.exports = recommendationController;
