/**
 * Unified AI Service
 *
 * Provides a single interface for generating responses from OpenAI, Claude, or DeepSeek.
 * Uses native fetch (Node 18+) to avoid additional dependencies.
 * Features: retries with exponential backoff, rate limiting, error handling.
 */

const aiConfig = require('../config/ai');
const logger = require('../utils/logger');

class AIFallbackError extends Error {
  constructor(message, systemPrompt, userPrompt) {
    super(message);
    this.name = 'AIFallbackError';
    this.systemPrompt = systemPrompt;
    this.userPrompt = userPrompt;
  }
}

class AIService {
  /**
   * Rate-limit guard: if we hit 429, skip future calls until the limit resets.
   * Set from OpenRouter's `X-RateLimit-Reset` header or a conservative default.
   */
  static _rateLimitedUntil = 0;
  static _rateLimitBufferMs = 5000; // Extra buffer beyond the reset timestamp

  /**
   * Check if the AI service is currently rate-limited.
   * If so, throw immediately rather than wasting a futile HTTP call.
   */
  static _checkRateLimited() {
    if (Date.now() < AIService._rateLimitedUntil) {
      const remaining = Math.ceil((AIService._rateLimitedUntil - Date.now()) / 1000);
      throw new AIFallbackError(
        `AI rate-limited for ~${remaining}s (skipping to avoid wasted calls)`,
        '',
        ''
      );
    }
  }

  /**
   * Record that we hit a rate limit.
   * @param {number} [retryAfter] Seconds until retry (from Retry-After header)
   */
  static _markRateLimited(retryAfter) {
    const duration = retryAfter ? retryAfter * 1000 : 60_000; // default 60s
    AIService._rateLimitedUntil = Date.now() + duration + AIService._rateLimitBufferMs;
    logger.warn(`AI rate-limited for ${Math.ceil(duration / 1000)}s (detected)`);
  }

  /**
   * Clear rate-limit state after a successful call.
   */
  static _clearRateLimited() {
    AIService._rateLimitedUntil = 0;
  }

  /**
   * Generate a response from the configured AI provider.
   *
   * @param {string} systemPrompt - The system-level instruction
   * @param {string} userPrompt - The user's query or context
   * @param {object} [options] - Override generation options
   * @param {number} [options.temperature]
   * @param {number} [options.maxTokens]
   * @returns {Promise<string>} The AI-generated text
   */
  async generate(systemPrompt, userPrompt, options = {}) {
    if (!aiConfig.isConfigured) {
      logger.warn('AI service not configured');
      throw new AIFallbackError('AI service not configured', systemPrompt, userPrompt);
    }

    // Early exit if we know we're rate-limited
    AIService._checkRateLimited();

    const provider = aiConfig.provider;
    const temperature = options.temperature ?? aiConfig.temperature;
    const maxTokens = options.maxTokens ?? aiConfig.maxTokens;
    const maxRetries = options.maxRetries ?? aiConfig.maxRetries;
    // totalAttempts ensures at least 1 try even when maxRetries is 0
    const totalAttempts = Math.max(1, maxRetries);

    let lastError;

    for (let attempt = 1; attempt <= totalAttempts; attempt++) {
      try {
        let result;
        if (provider === 'openai') {
          result = await this._callOpenAI(systemPrompt, userPrompt, temperature, maxTokens);
        } else if (provider === 'claude') {
          result = await this._callClaude(systemPrompt, userPrompt, temperature, maxTokens);
        } else if (provider === 'deepseek') {
          result = await this._callDeepSeek(systemPrompt, userPrompt, temperature, maxTokens);
        } else {
          throw new Error(`Unknown AI provider: ${provider}`);
        }
        return result;
      } catch (error) {
        lastError = error;
        logger.warn(`AI service attempt ${attempt}/${maxRetries} failed: ${error.message}`);

        if (attempt < maxRetries) {
          // Exponential backoff
          const delay = aiConfig.retryDelayMs * Math.pow(2, attempt - 1);
          await this._sleep(delay);
        }
      }
    }

    logger.error(`AI service failed after ${totalAttempts} attempt(s): ${lastError.message}`);
    throw new AIFallbackError(lastError.message, systemPrompt, userPrompt);
  }

  /**
   * Call OpenAI chat completions API
   */
  async _callOpenAI(systemPrompt, userPrompt, temperature, maxTokens) {
    const url = `${aiConfig.openaiBaseUrl}/chat/completions`;

    // 15-second timeout — if OpenRouter hangs, fail fast and let fallback handle it
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 15000);

    let response;
    try {
      response = await fetch(url, {
        signal: controller.signal,
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${aiConfig.openaiApiKey}`,
          'Referer': 'https://smartsave.app',
          'X-Title': 'SmartSave',
        },
        body: JSON.stringify({
          model: aiConfig.openaiModel,
          messages: [
            { role: 'system', content: systemPrompt },
            { role: 'user', content: userPrompt },
          ],
          temperature,
          max_tokens: maxTokens,
        }),
      });
    } finally {
      clearTimeout(timeoutId);
    }

    if (!response.ok) {
      const errorBody = await response.text().catch(() => '');

      // Rate-limit detection (OpenRouter returns 429 with Retry-After)
      if (response.status === 429) {
        const retryAfter = parseInt(response.headers.get('Retry-After') || '60', 10);
        AIService._markRateLimited(retryAfter);
        throw new Error(`OpenAI API rate-limited (429): ${errorBody}`);
      }

      throw new Error(`OpenAI API error ${response.status}: ${errorBody}`);
    }

    // Successful call — clear any previous rate-limit state
    AIService._clearRateLimited();

    const data = await response.json();
    return data.choices?.[0]?.message?.content?.trim() || '';
  }

  /**
   * Call Claude messages API
   */
  async _callClaude(systemPrompt, userPrompt, temperature, maxTokens) {
    const url = `${aiConfig.claudeBaseUrl}/messages`;

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 15000);

    let response;
    try {
      response = await fetch(url, {
        signal: controller.signal,
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': aiConfig.claudeApiKey,
          'anthropic-version': '2023-06-01',
        },
        body: JSON.stringify({
          model: aiConfig.claudeModel,
          system: systemPrompt,
          messages: [
            { role: 'user', content: userPrompt },
          ],
          temperature,
          max_tokens: maxTokens,
        }),
      });
    } finally {
      clearTimeout(timeoutId);
    }

    if (!response.ok) {
      const errorBody = await response.text().catch(() => '');
      throw new Error(`Claude API error ${response.status}: ${errorBody}`);
    }

    const data = await response.json();
    return data.content?.[0]?.text?.trim() || '';
  }

  /**
   * Call DeepSeek chat completions API (OpenAI-compatible format)
   */
  async _callDeepSeek(systemPrompt, userPrompt, temperature, maxTokens) {
    const url = `${aiConfig.deepseekBaseUrl}/chat/completions`;

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 15000);

    let response;
    try {
      response = await fetch(url, {
        signal: controller.signal,
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${aiConfig.deepseekApiKey}`,
          'Referer': 'https://smartsave.app',
          'X-Title': 'SmartSave',
        },
        body: JSON.stringify({
          model: aiConfig.deepseekModel,
          messages: [
            { role: 'system', content: systemPrompt },
            { role: 'user', content: userPrompt },
          ],
          temperature,
          max_tokens: maxTokens,
        }),
      });
    } finally {
      clearTimeout(timeoutId);
    }

    if (!response.ok) {
      const errorBody = await response.text().catch(() => '');
      throw new Error(`DeepSeek API error ${response.status}: ${errorBody}`);
    }

    const data = await response.json();
    return data.choices?.[0]?.message?.content?.trim() || '';
  }

  /**
   * Fallback when AI is not configured — returns a rule-based response
   * using the context embedded in the user prompt.
   */
  _getFallbackResponse(systemPrompt, userPrompt) {
    // Extract financial data from user prompt (it's JSON in the prompt)
    let financialData = {};
    try {
      const jsonMatch = userPrompt.match(/\{.*"generatedAt".*\}/s);
      if (jsonMatch) {
        financialData = JSON.parse(jsonMatch[0]);
      }
    } catch (_) {
      // Ignore parse errors
    }

    const monthlyIncome = financialData.monthlyIncome || 0;
    const monthlyExpenses = financialData.monthlyExpenses || 0;
    const savingsRate = financialData.savingsRate || 0;
    const balance = (monthlyIncome - monthlyExpenses);

    // Determine if this is a structured request (analysis, score, insights) or chat
    if (systemPrompt.includes('FINANCIAL_SCORE')) {
      return this._fallbackScore(financialData);
    }
    if (systemPrompt.includes('FINANCIAL_INSIGHTS')) {
      return this._fallbackInsights(financialData);
    }
    if (systemPrompt.includes('FINANCIAL_HEALTH')) {
      return this._fallbackHealth(financialData);
    }
    if (systemPrompt.includes('ACTION_PLANS')) {
      return this._fallbackActionPlans(financialData);
    }
    if (systemPrompt.includes('PREDICTIONS')) {
      return this._fallbackPredictions(financialData);
    }
    if (systemPrompt.includes('SAVINGS_OPPORTUNITIES')) {
      return this._fallbackOpportunities(financialData);
    }
    if (systemPrompt.includes('ADVICE')) {
      return this._fallbackAdvice(financialData);
    }

    // Default fallback for conversational Q&A
    return this._fallbackChat(userPrompt, financialData);
  }

  _fallbackScore(data) {
    const income = data.monthlyIncome || 0;
    const expenses = data.monthlyExpenses || 0;
    const savingsRate = data.savingsRate || 0;
    const budgets = data.budgetUtilization || [];

    let score = 0;
    const details = [];

    // Budget adherence (30 pts)
    if (budgets.length > 0) {
      const overBudget = budgets.filter(b => b.status === 'over_budget').length;
      const ratio = Math.max(0, (budgets.length - overBudget) / budgets.length);
      const budgetScore = Math.round(ratio * 30);
      score += budgetScore;
      details.push({ component: 'Budget Adherence', score: budgetScore, max: 30, detail: overBudget === 0 ? 'All budgets on track' : `${overBudget} of ${budgets.length} budgets exceeded` });
    } else {
      score += 15;
      details.push({ component: 'Budget Adherence', score: 15, max: 30, detail: 'No budgets set — partial score' });
    }

    // Savings consistency (25 pts)
    let savingsScore = 0;
    if (savingsRate >= 30) savingsScore = 25;
    else if (savingsRate >= 20) savingsScore = 22;
    else if (savingsRate >= 15) savingsScore = 18;
    else if (savingsRate >= 10) savingsScore = 14;
    else if (savingsRate >= 5) savingsScore = 10;
    else if (savingsRate > 0) savingsScore = 6;
    score += savingsScore;
    details.push({ component: 'Savings Consistency', score: savingsScore, max: 25, detail: `Savings rate: ${savingsRate}%` });

    // Spending habits (20 pts)
    const projectedRatio = expenses / (income || 1);
    let habitsScore = 0;
    if (projectedRatio <= 0.7) habitsScore = 20;
    else if (projectedRatio <= 0.85) habitsScore = 16;
    else if (projectedRatio <= 1.0) habitsScore = 10;
    else habitsScore = 4;
    score += habitsScore;
    details.push({ component: 'Spending Habits', score: habitsScore, max: 20, detail: `Expense/income ratio: ${Math.round(projectedRatio * 100)}%` });

    // Income stability (15 pts)
    score += 10;
    details.push({ component: 'Income Stability', score: 10, max: 15, detail: 'Limited data available' });

    // Debt & subscriptions (10 pts)
    const subs = data.subscriptions || [];
    const totalSubs = subs.reduce((s, sub) => s + (sub.monthlyAmount || 0), 0);
    const debtRatio = income > 0 ? totalSubs / income : 0;
    let debtScore = 0;
    if (debtRatio <= 0.1) debtScore = 10;
    else if (debtRatio <= 0.2) debtScore = 8;
    else if (debtRatio <= 0.3) debtScore = 6;
    else debtScore = 4;
    score += debtScore;
    details.push({ component: 'Debt & Subscriptions', score: debtScore, max: 10, detail: totalSubs > 0 ? `Subscription ratio: ${Math.round(debtRatio * 100)}% of income` : 'No subscriptions' });

    const finalScore = Math.min(100, Math.max(0, Math.round(score)));
    let level;
    if (finalScore >= 90) level = 'Excellent';
    else if (finalScore >= 75) level = 'Good';
    else if (finalScore >= 60) level = 'Average';
    else level = 'Needs Improvement';

    return JSON.stringify({
      score: finalScore,
      level,
      maxScore: 100,
      details,
      explanation: `Your financial score is ${finalScore}/100 (${level}). ` +
        `Your savings rate of ${savingsRate}% and expense-to-income ratio of ${Math.round(projectedRatio * 100)}% ` +
        `are the main drivers. ${finalScore >= 75 ? 'Keep up the good habits!' : finalScore >= 60 ? 'There is room for improvement.' : 'Focus on reducing expenses and increasing savings.'}`,
    });
  }

  _fallbackInsights(data) {
    const insights = [];
    const cats = data.categoryBreakdown || [];
    const changes = data.categoryChanges || [];
    const budgets = data.budgetUtilization || [];
    const savingsRate = data.savingsRate || 0;
    const expenseChange = data.expenseChange || 0;
    const habits = data.habits || {};

    if (cats.length > 0) {
      insights.push({
        type: 'insight', icon: 'trending_up',
        title: `Biggest Expense: ${cats[0].category}`,
        message: `${cats[0].category} is your largest expense at $${cats[0].amount} (${cats[0].percentage}% of total).`,
        category: cats[0].category,
        priority: cats[0].percentage > 30 ? 'high' : 'medium',
      });
    }

    const growing = changes.filter(c => c.change > 0).sort((a, b) => b.change - a.change);
    if (growing.length > 0) {
      insights.push({
        type: 'warning', icon: 'warning',
        title: `Rising: ${growing[0].category}`,
        message: `${growing[0].category} spending increased ${growing[0].change}% vs last month.`,
        category: growing[0].category,
        priority: Math.abs(growing[0].change) > 50 ? 'high' : 'medium',
      });
    }

    const atRisk = budgets.filter(b => b.status === 'at_risk' || b.status === 'over_budget');
    atRisk.forEach(b => {
      insights.push({
        type: 'warning', icon: 'warning',
        title: b.status === 'over_budget' ? `${b.category} Over Budget` : `${b.category} Near Limit`,
        message: b.status === 'over_budget'
          ? `Spent $${b.spent} of $${b.budgeted} (${b.percentUsed}%).`
          : `Used ${b.percentUsed}% of $${b.budgeted} ${b.category} budget. $${b.remaining} left.`,
        category: b.category,
        priority: b.status === 'over_budget' ? 'high' : 'medium',
      });
    });

    if (savingsRate > 0) {
      insights.push({
        type: 'success', icon: 'savings',
        title: 'Savings Rate',
        message: `Saving ${savingsRate}% of income.${savingsRate >= 20 ? ' Excellent!' : savingsRate >= 10 ? ' Keep it up!' : ' Try for 20%.'}`,
        category: 'Savings',
        priority: savingsRate >= 20 ? 'low' : 'medium',
      });
    }

    if (expenseChange > 30) {
      insights.push({
        type: 'warning', icon: 'trending_up',
        title: 'Spending Spike',
        message: `Expenses up ${expenseChange}% vs last month. Review recent transactions.`,
        category: 'Spending',
        priority: 'high',
      });
    }

    const goals = data.savingsGoals || [];
    goals.forEach(g => {
      if (g.progress >= 75) {
        insights.push({
          type: 'success', icon: 'flag',
          title: `"${g.name}" Almost Complete`,
          message: `You're ${g.progress}% toward your goal!`,
          category: 'Goals', priority: 'medium',
        });
      } else if (g.progress > 0 && g.progress < 25) {
        insights.push({
          type: 'insight', icon: 'flag',
          title: `"${g.name}" Needs Attention`,
          message: `Only ${g.progress}% toward goal. Consider increasing contributions.`,
          category: 'Goals', priority: 'medium',
        });
      }
    });

    if (habits.averageDailySpend > 0) {
      const projected = habits.projectedMonthlyExpenses || 0;
      const diff = projected - (data.monthlyIncome || 0);
      insights.push({
        type: 'insight', icon: 'calculator',
        title: 'Daily Spending',
        message: diff > 0
          ? `At $${habits.averageDailySpend}/day, on track to exceed income by $${Math.round(diff)}.`
          : `At $${habits.averageDailySpend}/day, on track to save $${Math.round(Math.abs(diff))}.`,
        category: 'Spending',
        priority: diff > 0 ? 'high' : 'low',
      });
    }

    const priorityOrder = { high: 0, medium: 1, low: 2 };
    insights.sort((a, b) => (priorityOrder[a.priority] || 2) - (priorityOrder[b.priority] || 2));
    return JSON.stringify(insights.slice(0, 15));
  }

  _fallbackHealth(data) {
    const issues = [];
    const strengths = [];
    const savingsRate = data.savingsRate || 0;

    if (savingsRate >= 20) strengths.push('Excellent savings rate');
    else if (savingsRate >= 10) strengths.push('Good savings rate');
    else if (savingsRate <= 0) issues.push('Not saving this month — spending exceeds income');
    else issues.push('Savings rate could be improved');

    const budgets = data.budgetUtilization || [];
    const over = budgets.filter(b => b.status === 'over_budget');
    const atRisk = budgets.filter(b => b.status === 'at_risk');
    if (over.length === 0 && atRisk.length === 0 && budgets.length > 0) strengths.push('All budgets on track');
    if (over.length > 0) issues.push(`${over.length} categor${over.length > 1 ? 'ies' : 'y'} over budget`);
    if (atRisk.length > 0) issues.push(`${atRisk.length} categor${atRisk.length > 1 ? 'ies' : 'y'} at risk`);

    const expenseChange = data.expenseChange || 0;
    if (expenseChange > 20) issues.push(`Expenses up ${expenseChange}% from last month`);
    else if (expenseChange < -10) strengths.push(`Expenses down ${Math.abs(expenseChange)}% from last month`);

    return JSON.stringify({
      status: issues.length === 0 ? 'excellent' : issues.length <= 2 ? 'good' : 'needs_attention',
      strengths,
      issues,
      summary: issues.length === 0
        ? 'Your financial health looks great! All metrics are positive.'
        : issues.length <= 2
          ? 'Your finances are generally healthy with some areas to improve.'
          : 'Your finances need attention in several areas.',
    });
  }

  _fallbackActionPlans(data) {
    const plans = [];
    const cats = data.categoryBreakdown || [];
    const budgets = data.budgetUtilization || [];
    const expenses = data.monthlyExpenses || 0;

    if (expenses > 0) {
      const w1 = cats[0] ? `Reduce ${cats[0].category} by 10% (save ~$${Math.round(cats[0].amount * 0.1)})` : 'Track all expenses for 7 days';
      const w2 = cats[1] ? Math.round(cats[1].amount * 0.15) : 0;
      const w3 = 50;
      const total = Math.round((cats[0] ? cats[0].amount * 0.1 : 0) + (cats[1] ? cats[1].amount * 0.15 : 0) + w3);

      plans.push({
        type: 'savings', title: '30-Day Savings Plan',
        expectedMonthlySavings: total > 0 ? total : Math.round(expenses * 0.1),
        duration: '30 days',
        steps: [
          { week: 1, action: w1, tip: 'Use cash instead of card for this category' },
          { week: 2, action: w2 > 0 ? `Limit ${cats[1].category} to $${Math.round(cats[1].amount * 0.85)} (save $${w2})` : 'Cancel one unused subscription', tip: 'Unsubscribe from unused services' },
          { week: 3, action: `Save an extra $${w3}/month`, tip: 'Automate a transfer to savings on payday' },
          { week: 4, action: 'Review all recurring subscriptions', tip: 'Call providers to negotiate better rates' },
        ],
      });
    }

    const overBudget = budgets.filter(b => b.status === 'over_budget');
    if (overBudget.length > 0) {
      plans.push({
        type: 'budget', title: 'Budget Recovery Plan',
        expectedMonthlySavings: overBudget.reduce((s, b) => s + Math.round((b.spent - b.budgeted) * 100) / 100, 0),
        duration: 'This month',
        steps: overBudget.slice(0, 3).map(b => ({
          week: 'Immediate',
          action: `Cut ${b.category} spending by $${Math.round((b.spent - b.budgeted) * 100) / 100} to stay within budget`,
          tip: `Set a daily limit of $${Math.round((b.budgeted / 30) * 100) / 100} for ${b.category}`,
        })),
      });
    }

    return JSON.stringify(plans);
  }

  _fallbackPredictions(data) {
    const predictions = [];
    const income = data.monthlyIncome || 0;
    const expenses = data.monthlyExpenses || 0;
    const habits = data.habits || {};
    const dailyExpense = habits.averageDailySpend || (expenses > 0 ? expenses / Math.max(1, new Date().getDate()) : 0);
    const dailyIncome = income > 0 ? income / Math.max(1, new Date().getDate()) : 0;
    const daysInMonth = new Date(new Date().getFullYear(), new Date().getMonth() + 1, 0).getDate();
    const dayOfMonth = Math.min(new Date().getDate(), daysInMonth);
    const remainingDays = daysInMonth - dayOfMonth;

    const projectedEndBalance = Math.round((dailyIncome - dailyExpense) * daysInMonth * 100) / 100;
    predictions.push({
      type: 'end_of_month_balance', title: 'End-of-Month Balance',
      value: projectedEndBalance,
      detail: projectedEndBalance > 0
        ? `Projected balance of $${projectedEndBalance}`
        : `Warning: Projected deficit of $${Math.abs(projectedEndBalance)}`,
      confidence: remainingDays <= 7 ? 'high' : remainingDays <= 15 ? 'medium' : 'low',
    });

    const budgets = data.budgetUtilization || [];
    const budgetOverruns = budgets
      .filter(b => b.status === 'at_risk' || b.status === 'over_budget')
      .map(b => {
        const dailyRate = dayOfMonth > 0 ? b.spent / dayOfMonth : 0;
        const projectedSpend = Math.round(dailyRate * daysInMonth * 100) / 100;
        const overrun = Math.max(0, Math.round((projectedSpend - b.budgeted) * 100) / 100);
        return { category: b.category, budgeted: b.budgeted, projectedSpend, expectedOverrun: overrun, risk: overrun > b.budgeted * 0.2 ? 'high' : overrun > 0 ? 'medium' : 'low' };
      });

    predictions.push({ type: 'budget_overruns', title: 'Budget Overrun Predictions', items: budgetOverruns, count: budgetOverruns.length });

    const goals = data.savingsGoals || [];
    const goalPredictions = goals.map(g => {
      if (!g.monthlyContribution || g.monthlyContribution <= 0 || g.progress >= 100) return null;
      const remaining = (g.target || 0) - (g.current || 0);
      const monthsToComplete = Math.ceil(remaining / g.monthlyContribution);
      return {
        name: g.name, currentProgress: g.progress, monthsRemaining: monthsToComplete,
        estimatedCompletionDate: new Date(new Date().getFullYear(), new Date().getMonth() + monthsToComplete, 1).toISOString().split('T')[0],
        onTrack: true,
      };
    }).filter(Boolean);
    predictions.push({ type: 'goal_completion', title: 'Savings Goal Projections', goals: goalPredictions });

    predictions.push({
      type: 'next_month', title: 'Next Month Projection',
      estimatedIncome: Math.round(dailyIncome * daysInMonth * 100) / 100,
      estimatedExpenses: Math.round(dailyExpense * daysInMonth * 100) / 100,
      estimatedSavings: Math.round((dailyIncome - dailyExpense) * daysInMonth * 100) / 100,
    });

    return JSON.stringify(predictions);
  }

  _fallbackOpportunities(data) {
    const opportunities = [];
    const cats = data.categoryBreakdown || [];
    const subs = data.subscriptions || [];
    const totalSubsMonthly = subs.reduce((s, sub) => s + (sub.monthlyAmount || 0), 0);

    if (totalSubsMonthly > 50) {
      opportunities.push({
        area: 'Subscriptions',
        description: `Review ${subs.length} subscriptions ($${totalSubsMonthly}/month). Canceling just one could save $20-50/month.`,
        estimatedSavings: Math.round(Math.min(50, totalSubsMonthly * 0.15) * 100) / 100,
        effort: 'low', impact: 'medium',
      });
    }

    const food = cats.find(c => c.category === 'Food' || c.category === 'Dining');
    if (food && food.amount > 100) {
      opportunities.push({
        area: 'Food & Dining',
        description: `Reduce food spending by 15% to save ~$${Math.round(food.amount * 0.15)}/month. Try meal prepping.`,
        estimatedSavings: Math.round(food.amount * 0.15 * 100) / 100,
        effort: 'low', impact: 'high',
      });
    }

    const entertainment = cats.find(c => c.category === 'Entertainment');
    if (entertainment && entertainment.amount > 50) {
      opportunities.push({
        area: 'Entertainment',
        description: `Cutting entertainment by 20% saves ~$${Math.round(entertainment.amount * 0.2)}/month.`,
        estimatedSavings: Math.round(entertainment.amount * 0.2 * 100) / 100,
        effort: 'medium', impact: 'medium',
      });
    }

    const shopping = cats.find(c => c.category === 'Shopping');
    if (shopping && shopping.amount > 100) {
      opportunities.push({
        area: 'Shopping',
        description: `Implement a 24-hour rule before non-essential purchases to save ~$${Math.round(shopping.amount * 0.2)}/month.`,
        estimatedSavings: Math.round(shopping.amount * 0.2 * 100) / 100,
        effort: 'medium', impact: 'high',
      });
    }

    const balance = (data.monthlyIncome || 0) - (data.monthlyExpenses || 0);
    const goals = data.savingsGoals || [];
    if (balance > 0 && goals.length > 0) {
      const topGoal = goals.sort((a, b) => (a.progress || 0) - (b.progress || 0))[0];
      if (topGoal) {
        opportunities.push({
          area: 'Savings Goal',
          description: `Move $${Math.round(Math.min(balance, 100))} to "${topGoal.name}" to boost progress.`,
          estimatedSavings: Math.round(Math.min(balance, 100) * 100) / 100,
          effort: 'low', impact: 'high',
        });
      }
    }

    return JSON.stringify(opportunities);
  }

  _fallbackAdvice(data) {
    const advice = [];
    const changes = data.categoryChanges || [];
    const budgets = data.budgetUtilization || [];

    changes.filter(c => c.change > 15 && c.currentAmount > 50).forEach(c => {
      advice.push({
        type: 'reduction',
        title: `Reduce ${c.category} Spending`,
        message: `Your ${c.category} spending increased ${c.change}% from last month. Consider setting a limit.`,
        category: c.category,
        potentialSavings: Math.round((c.currentAmount - c.previousAmount) * 100) / 100,
      });
    });

    budgets.filter(b => b.status === 'over_budget').forEach(b => {
      advice.push({
        type: 'budget',
        title: `Review ${b.category} Budget`,
        message: `Spent $${b.spent} of $${b.budgeted}. Consider adjusting or cutting back.`,
        category: b.category,
        potentialSavings: Math.round((b.spent - b.budgeted) * 100) / 100,
      });
    });

    return JSON.stringify(advice.slice(0, 8));
  }

  _fallbackChat(question, data) {
    const income = data.monthlyIncome || 0;
    const expenses = data.monthlyExpenses || 0;
    const balance = income - expenses;
    const savingsRate = data.savingsRate || 0;
    const biggest = data.habits?.biggestCategory;
    const q = question.toLowerCase();

    if (q.includes('save') || q.includes('reduce')) {
      return JSON.stringify({
        answer: `Based on your data, here are ways to save:\n\n` +
          (biggest ? `Your largest expense is ${biggest.category} ($${biggest.amount}). A 10% reduction saves ~$${Math.round(biggest.amount * 0.1)}/month.\n` : '') +
          `Your savings rate is ${savingsRate}%. Aim for 20%.\n` +
          `Current balance: $${balance > 0 ? '+' : ''}${balance}`,
        type: 'advice',
      });
    }

    if (q.includes('health') || q.includes('score') || q.includes('how am i')) {
      let level;
      const rate = Math.round((income > 0 ? (expenses / income) * 100 : 0));
      if (rate <= 70) level = 'good';
      else if (rate <= 85) level = 'fair';
      else level = 'needs_attention';
      return JSON.stringify({
        answer: `Financial Health Summary:\n\n• Income: $${income}/month\n• Expenses: $${expenses}/month\n• Savings Rate: ${savingsRate}%\n• Balance: $${balance}\n\nStatus: ${level === 'good' ? '✅ Good — you\'re spending within your means.' : level === 'fair' ? '⚠️ Fair — some room for improvement.' : '❌ Needs attention — expenses are high relative to income.'}`,
        type: 'analysis',
      });
    }

    return JSON.stringify({
      answer: `Here's a snapshot of your finances:\n\n` +
        `• Balance: $${balance > 0 ? '+' : ''}${balance}\n` +
        `• Income: $${income}/month\n` +
        `• Expenses: $${expenses}/month\n` +
        `• Savings rate: ${savingsRate}%\n` +
        (biggest ? `• Top category: ${biggest.category} ($${biggest.amount})\n` : '') +
        `\nAsk me about saving money, financial health, budgets, or your savings goals!`,
      type: 'info',
    });
  }

  _sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

module.exports = new AIService();
