const Notification = require('../models/Notification');
const Budget = require('../models/Budget');
const Goal = require('../models/Goal');
const Transaction = require('../models/Transaction');
const cron = require('node-cron');
const logger = require('../utils/logger');

class NotificationService {
  start() {
    // Check budgets daily
    cron.schedule('0 9 * * *', async () => {
      try {
        await this.checkBudgetWarnings();
      } catch (error) {
        logger.error('Budget check error:', error);
      }
    });

    // Weekly summary every Monday
    cron.schedule('0 10 * * 1', async () => {
      try {
        await this.sendWeeklySummary();
      } catch (error) {
        logger.error('Weekly summary error:', error);
      }
    });

    // Goal reminders weekly
    cron.schedule('0 10 * * 0', async () => {
      try {
        await this.checkGoalReminders();
      } catch (error) {
        logger.error('Goal reminder error:', error);
      }
    });

    logger.info('Notification service started');
  }

  async createNotification(userId, type, title, message, data = {}) {
    return Notification.create({ user: userId, type, title, message, data });
  }

  async checkBudgetWarnings() {
    const now = new Date();
    const month = now.getMonth() + 1;
    const year = now.getFullYear();

    const budgets = await Budget.find({
      month,
      year,
      notifications: true,
      isActive: true,
    }).populate('user');

    for (const budget of budgets) {
      if (budget.amount > 0) {
        const percentage = (budget.spent / budget.amount) * 100;
        if (percentage >= 90 && percentage < 100) {
          await this.createNotification(
            budget.user._id,
            'budget_warning',
            'Budget Warning',
            `You have used ${Math.round(percentage)}% of your ${budget.category} budget. Only $${(budget.amount - budget.spent).toFixed(2)} remaining.`,
            { budgetId: budget._id, category: budget.category, percentage }
          );
        } else if (percentage >= 100) {
          await this.createNotification(
            budget.user._id,
            'budget_warning',
            'Budget Exceeded',
            `You have exceeded your ${budget.category} budget of $${budget.amount.toFixed(2)}. Current spending: $${budget.spent.toFixed(2)}.`,
            { budgetId: budget._id, category: budget.category, percentage }
          );
        }
      }
    }
  }

  async sendWeeklySummary() {
    const users = await User.find({ 'notificationPreferences.weeklySummary': true });
    
    for (const user of users) {
      const weekAgo = new Date();
      weekAgo.setDate(weekAgo.getDate() - 7);

      const weekTransactions = await Transaction.find({
        user: user._id,
        date: { $gte: weekAgo },
        isActive: true,
      });

      const income = weekTransactions.filter(t => t.type === 'income').reduce((s, t) => s + t.amount, 0);
      const expenses = weekTransactions.filter(t => t.type === 'expense').reduce((s, t) => s + t.amount, 0);

      await this.createNotification(
        user._id,
        'weekly_summary',
        'Weekly Financial Summary',
        `This week: Income $${income.toFixed(2)} | Expenses $${expenses.toFixed(2)} | Net $${(income - expenses).toFixed(2)}`,
        { income, expenses, net: income - expenses, transactionCount: weekTransactions.length }
      );
    }
  }

  async checkGoalReminders() {
    const goals = await Goal.find({ status: 'active' }).populate('user');

    for (const goal of goals) {
      if (goal.targetDate) {
        const daysUntilTarget = Math.ceil((goal.targetDate - new Date()) / (1000 * 60 * 60 * 24));
        
        if (daysUntilTarget <= 30 && daysUntilTarget > 0 && goal.currentAmount < goal.targetAmount) {
          const remaining = goal.targetAmount - goal.currentAmount;
          await this.createNotification(
            goal.user._id,
            'goal_reminder',
            'Goal Reminder',
            `You are $${remaining.toFixed(2)} away from your "${goal.title}" goal. Target date is in ${daysUntilTarget} days.`,
            { goalId: goal._id, remaining, daysLeft: daysUntilTarget }
          );
        }
      }
    }
  }
}

module.exports = new NotificationService();
