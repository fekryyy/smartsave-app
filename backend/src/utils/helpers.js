const config = require('../config');

const helpers = {
  generateOTP() {
    return Math.floor(100000 + Math.random() * 900000).toString();
  },

  calculatePercentage(used, total) {
    if (total === 0) return 0;
    return Math.round((used / total) * 100);
  },

  calculateProgress(current, goal) {
    if (goal === 0) return 0;
    return Math.min(100, Math.round((current / goal) * 100));
  },

  getDateRange(period) {
    const now = new Date();
    let start, end = new Date(now);

    switch (period) {
      case 'daily':
        start = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        end = new Date(start);
        end.setDate(end.getDate() + 1);
        break;
      case 'weekly':
        const day = now.getDay();
        start = new Date(now);
        start.setDate(now.getDate() - day);
        start.setHours(0, 0, 0, 0);
        end = new Date(start);
        end.setDate(end.getDate() + 7);
        break;
      case 'monthly':
        start = new Date(now.getFullYear(), now.getMonth(), 1);
        end = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59);
        break;
      case 'yearly':
        start = new Date(now.getFullYear(), 0, 1);
        end = new Date(now.getFullYear(), 11, 31, 23, 59, 59);
        break;
      default:
        start = new Date(0);
        break;
    }

    return { start, end };
  },

  getCurrentMonthRange() {
    const now = new Date();
    const start = new Date(now.getFullYear(), now.getMonth(), 1);
    const end = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59);
    return { start, end };
  },

  formatCurrency(amount, currency = 'USD') {
    const currencies = {
      USD: 'USD', EUR: 'EUR', GBP: 'GBP', EGP: 'EGP', SAR: 'SAR', AED: 'AED'
    };
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: currencies[currency] || 'USD',
    }).format(amount);
  },

  calculateEstimatedCompletion(currentAmount, targetAmount, monthlyContribution) {
    if (monthlyContribution <= 0) return null;
    const remaining = targetAmount - currentAmount;
    if (remaining <= 0) return 0;
    const monthsNeeded = Math.ceil(remaining / monthlyContribution);
    const estimatedDate = new Date();
    estimatedDate.setMonth(estimatedDate.getMonth() + monthsNeeded);
    return { monthsNeeded, estimatedDate, remaining };
  },
};

module.exports = helpers;
