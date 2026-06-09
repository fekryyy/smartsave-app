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
        logger.warn(`OpenAI API rate-limited for ${retryAfter}s (429)`);
        throw new Error(`OpenAI API rate-limited (429): ${errorBody}`);
      }

      throw new Error(`OpenAI API error ${response.status}: ${errorBody}`);
    }

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
    const trends = data.monthlyTrends || [];

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
    let stabilityScore = 10; // default
    if (trends.length >= 3) {
      const recentIncomes = trends.slice(-3).map(t => t.income);
      const avgIncome = recentIncomes.reduce((s, v) => s + v, 0) / recentIncomes.length;
      const variance = recentIncomes.reduce((s, v) => s + Math.pow(v - avgIncome, 2), 0) / recentIncomes.length;
      const cv = avgIncome > 0 ? Math.sqrt(variance) / avgIncome : 1;
      if (cv <= 0.1) stabilityScore = 15;
      else if (cv <= 0.2) stabilityScore = 13;
      else if (cv <= 0.3) stabilityScore = 10;
      else if (cv <= 0.5) stabilityScore = 7;
      else stabilityScore = 3;
    }
    score += stabilityScore;
    details.push({ component: 'Income Stability', score: stabilityScore, max: 15, detail: trends.length >= 3 ? 'Based on last 3 months' : 'Limited data available' });

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

    // Build a richer explanation
    let explanation = `Your financial score is ${finalScore}/100 (${level}). `;
    const weakest = details.reduce((min, d) => d.score < min.score ? d : min, details[0]);
    const strongest = details.reduce((best, d) => d.score > best.score ? d : best, details[0]);

    if (strongest && strongest.score >= strongest.max * 0.8) {
      explanation += `Your strongest area is "${strongest.component}" (${strongest.score}/${strongest.max}). `;
    }
    if (weakest && weakest.score < weakest.max * 0.5) {
      explanation += `Your biggest opportunity is "${weakest.component}" (${weakest.score}/${weakest.max}). `;
    }
    explanation += finalScore >= 75
      ? 'Keep up the good habits!'
      : finalScore >= 60
        ? 'There is room for improvement — focus on the lowest-scoring area.'
        : 'Focus on reducing expenses and increasing savings to boost your score.';

    return JSON.stringify({ score: finalScore, level, maxScore: 100, details, explanation });
  }

  _fallbackInsights(data) {
    const insights = [];
    const cats = data.categoryBreakdown || [];
    const changes = data.categoryChanges || [];
    const budgets = data.budgetUtilization || [];
    const savingsRate = data.savingsRate || 0;
    const expenseChange = data.expenseChange || 0;
    const habits = data.habits || {};
    const subs = data.subscriptions || [];
    const goals = data.savingsGoals || [];
    const income = data.monthlyIncome || 0;
    const expenses = data.monthlyExpenses || 0;

    // Top category insight
    if (cats.length > 0) {
      const cat = cats[0];
      insights.push({
        type: 'insight', icon: 'trending_up',
        title: `Biggest: ${cat.category}`,
        message: `${cat.category} leads at $${cat.amount} (${cat.percentage}% of total). ${cat.percentage > 35 ? 'A 10% trim would save ~$' + Math.round(cat.amount * 0.1) + '/month.' : ''}`,
        category: cat.category,
        priority: cat.percentage > 30 ? 'high' : 'medium',
      });
    }

    // Rising categories
    const growing = changes.filter(c => c.change > 0).sort((a, b) => b.change - a.change);
    if (growing.length > 0) {
      insights.push({
        type: 'warning', icon: 'warning',
        title: `Rising: ${growing[0].category}`,
        message: `${growing[0].category} up ${growing[0].change}% vs last month. ${growing[0].change > 50 ? 'Significant jump — worth reviewing.' : 'Moderate increase.'}`,
        category: growing[0].category,
        priority: Math.abs(growing[0].change) > 50 ? 'high' : 'medium',
      });
    }

    // Declining categories (positive signal)
    const declining = changes.filter(c => c.change < -10).sort((a, b) => a.change - b.change);
    if (declining.length > 0) {
      insights.push({
        type: 'success', icon: 'trending_down',
        title: `Down: ${declining[0].category}`,
        message: `${declining[0].category} spending dropped ${Math.abs(declining[0].change)}% — good progress.`,
        category: declining[0].category,
        priority: 'low',
      });
    }

    // Budget alerts
    const atRisk = budgets.filter(b => b.status === 'at_risk' || b.status === 'over_budget');
    atRisk.forEach(b => {
      insights.push({
        type: 'warning', icon: 'warning',
        title: b.status === 'over_budget' ? `${b.category} Over Budget` : `${b.category} Near Limit`,
        message: b.status === 'over_budget'
          ? `Spent $${b.spent} of $${b.budgeted} (${b.percentUsed}%).`
          : `Used ${b.percentUsed}% of $${b.budgeted} budget — $${b.remaining} left.`,
        category: b.category,
        priority: b.status === 'over_budget' ? 'high' : 'medium',
      });
    });

    // Budget on track (positive)
    const onTrack = budgets.filter(b => b.status === 'on_track');
    onTrack.slice(0, 1).forEach(b => {
      insights.push({
        type: 'success', icon: 'savings',
        title: `On Track: ${b.category}`,
        message: `$${b.spent} of $${b.budgeted} spent — within budget.`,
        category: b.category,
        priority: 'low',
      });
    });

    // Savings rate
    if (savingsRate > 0) {
      insights.push({
        type: savingsRate >= 20 ? 'success' : 'insight', icon: 'savings',
        title: `Savings: ${savingsRate}%`,
        message: `Saving ${savingsRate}% of income.${savingsRate >= 20 ? ' Excellent!' : savingsRate >= 10 ? ' Solid — aim for 20%.' : ' Room to grow — target 20%.'}`,
        category: 'Savings',
        priority: savingsRate >= 20 ? 'low' : 'medium',
      });
    } else {
      insights.push({
        type: 'warning', icon: 'savings',
        title: 'Not Saving',
        message: 'Spending matches or exceeds income. Even 5% would build momentum.',
        category: 'Savings',
        priority: 'high',
      });
    }

    // Expense spike
    if (expenseChange > 30) {
      insights.push({
        type: 'warning', icon: 'trending_up',
        title: 'Spending Spike',
        message: `Expenses up ${expenseChange}% vs last month — $${Math.round(expenses - (expenses / (1 + expenseChange / 100)))} more.`,
        category: 'Spending',
        priority: 'high',
      });
    }

    // Goals progress
    goals.forEach(g => {
      if (g.progress >= 75) {
        insights.push({
          type: 'success', icon: 'flag',
          title: `"${g.name}" Almost Done`,
          message: `You're ${g.progress}% there. Just $${Math.round((g.target || 0) - (g.current || 0))} to go!`,
          category: 'Goals', priority: 'medium',
        });
      } else if (g.progress >= 25 && g.progress < 75) {
        insights.push({
          type: 'insight', icon: 'flag',
          title: `"${g.name}" In Progress`,
          message: `${g.progress}% toward goal. ${g.monthlyContribution ? `$${g.monthlyContribution}/month contribution active.` : 'Consider setting a recurring contribution.'}`,
          category: 'Goals', priority: 'medium',
        });
      }
    });

    // Daily spend
    if (habits.averageDailySpend > 0) {
      const projected = habits.projectedMonthlyExpenses || 0;
      const diff = projected - income;
      insights.push({
        type: diff > 0 ? 'warning' : 'insight', icon: 'calculator',
        title: diff > 0 ? 'Overspend Risk' : 'Daily Spending',
        message: diff > 0
          ? `At $${habits.averageDailySpend}/day, on track to exceed income by $${Math.round(diff)}.`
          : `At $${habits.averageDailySpend}/day, on track for $${Math.round(Math.abs(diff))} surplus.`,
        category: 'Spending',
        priority: diff > 0 ? 'high' : 'low',
      });
    }

    // Subscription insight
    const subTotal = subs.reduce((s, x) => s + (x.monthlyAmount || 0), 0);
    if (subTotal > 50) {
      insights.push({
        type: 'insight', icon: 'subscriptions',
        title: `${subs.length} Subscription${subs.length > 1 ? 's' : ''}`,
        message: `$${subTotal}/month ($${subTotal * 12}/year). ${subTotal > income * 0.1 ? 'Over 10% of income — worth auditing.' : 'Reasonable level.'}`,
        category: 'Subscriptions',
        priority: subTotal > income * 0.1 ? 'medium' : 'low',
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
    const income = data.monthlyIncome || 0;
    const expenses = data.monthlyExpenses || 0;
    const expenseRatio = income > 0 ? Math.round((expenses / income) * 100) : 0;

    // Savings analysis
    if (savingsRate >= 20) strengths.push('Excellent savings rate of ' + savingsRate + '%');
    else if (savingsRate >= 10) strengths.push('Good savings rate of ' + savingsRate + '%');
    else if (savingsRate <= 0) issues.push('Not saving — spending matches or exceeds income');
    else issues.push('Savings rate of ' + savingsRate + '% could be improved, aim for 20%');

    // Expense ratio
    if (expenseRatio <= 70) strengths.push('Expense ratio of ' + expenseRatio + '% leaves good breathing room');
    else if (expenseRatio <= 85) strengths.push('Expense ratio of ' + expenseRatio + '% is manageable');
    else if (expenseRatio > 100) issues.push('Expenses exceed income by ' + (expenseRatio - 100) + '% — spending needs attention');
    else issues.push('Expense ratio of ' + expenseRatio + '% is high — targeting 70% would free up cash');

    // Budgets
    const budgets = data.budgetUtilization || [];
    const over = budgets.filter(b => b.status === 'over_budget');
    const atRisk = budgets.filter(b => b.status === 'at_risk');
    const onTrack = budgets.filter(b => b.status === 'on_track');
    if (over.length === 0 && atRisk.length === 0 && budgets.length > 0) strengths.push('All budgets on track');
    if (over.length > 0) issues.push(over.length + ' categor' + (over.length > 1 ? 'ies' : 'y') + ' over budget');
    if (atRisk.length > 0) issues.push(atRisk.length + ' categor' + (atRisk.length > 1 ? 'ies' : 'y') + ' at risk of exceeding budget');

    // Spending trends
    const expenseChange = data.expenseChange || 0;
    if (expenseChange > 20) issues.push('Expenses up ' + expenseChange + '% from last month');
    else if (expenseChange < -10) strengths.push('Expenses down ' + Math.abs(expenseChange) + '% from last month');

    // Income diversification
    const incBreakdown = data.incomeBreakdown || [];
    if (incBreakdown.length <= 1) {
      issues.push('Single income source — diversification would add stability');
    } else {
      strengths.push('Multiple income sources (' + incBreakdown.length + ')');
    }

    // Daily spending habit
    const habits = data.habits || {};
    if (habits.averageDailySpend > 0) {
      const projected = habits.projectedMonthlyExpenses || 0;
      if (projected > income) {
        issues.push('Daily spend of $' + habits.averageDailySpend + '/day projects to exceed income');
      }
    }

    // Subscriptions
    const subs = data.subscriptions || [];
    const subTotal = subs.reduce((s, x) => s + (x.monthlyAmount || 0), 0);
    if (subTotal > income * 0.15) {
      issues.push('Subscription costs (' + subs.length + ') are ' + Math.round((subTotal / income) * 100) + '% of income');
    }

    const issueCount = issues.length;
    return JSON.stringify({
      status: issueCount === 0 ? 'excellent' : issueCount <= 2 ? 'good' : 'needs_attention',
      strengths,
      issues,
      summary: issueCount === 0
        ? 'Your financial health looks great! All metrics are positive.'
        : issueCount <= 2
          ? 'Your finances are generally healthy with some areas to improve.'
          : 'Your finances need attention in ' + issueCount + ' areas.',
    });
  }

  _fallbackActionPlans(data) {
    const plans = [];
    const cats = data.categoryBreakdown || [];
    const budgets = data.budgetUtilization || [];
    const expenses = data.monthlyExpenses || 0;
    const income = data.monthlyIncome || 0;
    const goals = data.savingsGoals || [];
    const subs = data.subscriptions || [];
    const habits = data.habits || {};
    const savingsRate = data.savingsRate || 0;

    // 30-Day Savings Plan
    if (expenses > 0 && cats.length > 0) {
      const w1Action = cats[0]
        ? `Reduce ${cats[0].category} by 10% (save ~$${Math.round(cats[0].amount * 0.1)})`
        : 'Track all expenses for 7 days';
      const w1Tip = cats[0]
        ? `Set a daily limit of $${Math.round(cats[0].amount / 30)} for ${cats[0].category}`
        : 'Use a notes app or spreadsheet';

      const w2Savings = cats[1] ? Math.round(cats[1].amount * 0.15) : 0;
      const w2Action = w2Savings > 0
        ? `Limit ${cats[1].category} spending by ${Math.round(cats[1].amount * 0.15)}% (save ~$${w2Savings})`
        : 'Cancel one unused subscription';
      const w2Tip = w2Savings > 0
        ? `Cook at home 3 more times this week for ${cats[1].category} savings`
        : 'Check last 60 days of statements for unused services';

      const subReview = subs.length > 0
        ? `Audit ${subs.length} subscription${subs.length > 1 ? 's' : ''} — cut what you haven't used in 60 days`
        : 'Review all recurring charges on your bank statement';

      const cat1Savings = cats[0] ? Math.round(cats[0].amount * 0.1) : 0;
      const cat2Savings = cats[1] ? Math.round(cats[1].amount * 0.15) : 0;
      const total = cat1Savings + cat2Savings + 50;

      plans.push({
        type: 'savings',
        title: '30-Day Savings Plan',
        expectedMonthlySavings: total > 0 ? total : Math.round(expenses * 0.1),
        duration: '30 days',
        steps: [
          { week: 'Week 1', action: w1Action, tip: w1Tip },
          { week: 'Week 2', action: w2Action, tip: w2Tip },
          { week: 'Week 3', action: `Save an extra $50/month`, tip: 'Automate a transfer to savings on payday' },
          { week: 'Week 4', action: subReview, tip: 'Call providers to negotiate better rates' },
        ],
      });
    }

    // Budget Recovery Plan
    const overBudget = budgets.filter(b => b.status === 'over_budget');
    if (overBudget.length > 0) {
      plans.push({
        type: 'budget',
        title: 'Budget Recovery Plan',
        expectedMonthlySavings: overBudget.reduce((s, b) => s + Math.round((b.spent - b.budgeted) * 100) / 100, 0),
        duration: 'This month',
        steps: overBudget.slice(0, 3).map(b => ({
          week: 'Immediate',
          action: `Cut ${b.category} spending by $${Math.round((b.spent - b.budgeted) * 100) / 100} to get back within budget`,
          tip: `Daily limit: $${Math.round((b.budgeted / 30) * 100) / 100} for ${b.category}`,
        })),
      });
    }

    // Goal Acceleration Plan
    const activeGoal = goals.find(g => (g.progress || 0) < 100 && (g.progress || 0) > 0);
    if (activeGoal && income > 0) {
      const remaining = (activeGoal.target || 0) - (activeGoal.current || 0);
      const monthlyFree = income - expenses;
      const suggestedExtra = Math.round(Math.max(0, monthlyFree * 0.2));

      if (suggestedExtra > 10) {
        plans.push({
          type: 'goal',
          title: `"${activeGoal.name}" Accelerator`,
          expectedMonthlySavings: suggestedExtra,
          duration: `${Math.ceil(remaining / Math.max(1, suggestedExtra + (activeGoal.monthlyContribution || 0)))} months`,
          steps: [
            { week: 'Week 1', action: `Increase contribution by $${suggestedExtra}/month`, tip: 'Even small increases compound quickly' },
            { week: 'Week 2', action: `Redirect one trimmed category to "${activeGoal.name}"`, tip: 'Use the 24-hour rule before non-essential purchases' },
            { week: 'Ongoing', action: 'Review progress monthly and adjust as needed', tip: 'Automate the extra contribution on payday' },
          ],
        });
      }
    }

    // Savings Rate Improvement Plan (if savings rate is low)
    if (savingsRate < 10 && income > 0 && cats.length > 0) {
      const targetSavings = Math.round(income * 0.1);
      plans.push({
        type: 'savings',
        title: '10% Savings Target Plan',
        expectedMonthlySavings: targetSavings - Math.round(income * savingsRate / 100),
        duration: '60 days',
        steps: [
          { week: 'Days 1–7', action: `Track every expense to find ${Math.round(targetSavings * 0.5)} in cuts`, tip: 'Use the app to categorize every transaction' },
          { week: 'Days 8–30', action: `Reduce ${cats[0].category} by 15%`, tip: 'Set a weekly budget for this category' },
          { week: 'Days 31–60', action: 'Automate savings transfer on payday', tip: 'Start with the amount you found in week 1' },
        ],
      });
    }

    return JSON.stringify(plans);
  }

  _fallbackPredictions(data) {
    const predictions = [];
    const income = data.monthlyIncome || 0;
    const expenses = data.monthlyExpenses || 0;
    const habits = data.habits || {};
    const trends = data.monthlyTrends || [];
    const dailyExpense = habits.averageDailySpend || (expenses > 0 ? expenses / Math.max(1, new Date().getDate()) : 0);
    const dailyIncome = income > 0 ? income / Math.max(1, new Date().getDate()) : 0;
    const daysInMonth = new Date(new Date().getFullYear(), new Date().getMonth() + 1, 0).getDate();
    const dayOfMonth = Math.min(new Date().getDate(), daysInMonth);
    const remainingDays = daysInMonth - dayOfMonth;

    // 1. End-of-month balance prediction using trends if available
    const mTrend = trends.length >= 2 ? trends[trends.length - 1] : null;
    const expenseGrowth = mTrend && trends.length >= 2
      ? Math.max(0, (mTrend.expenses - trends[trends.length - 2].expenses) / Math.max(1, trends[trends.length - 2].expenses))
      : 0;

    const adjustedDailyExpense = dailyExpense * (1 + expenseGrowth);
    const projectedEndBalance = Math.round((dailyIncome - adjustedDailyExpense) * remainingDays + (income - expenses) * (dayOfMonth / daysInMonth) * 100) / 100;
    predictions.push({
      type: 'end_of_month_balance', title: 'End-of-Month Balance',
      value: projectedEndBalance,
      detail: projectedEndBalance > 0
        ? `Projected balance of $${projectedEndBalance}${expenseGrowth > 0.1 ? ' (expense growth factored in)' : ''}`
        : `Warning: Projected deficit of $${Math.abs(projectedEndBalance)}`,
      confidence: remainingDays <= 7 ? 'high' : remainingDays <= 15 ? 'medium' : 'low',
    });

    // 2. Budget overrun predictions
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

    // 3. Goal completion predictions with trend adjustment
    const goals = data.savingsGoals || [];
    const goalPredictions = goals.map(g => {
      if (!g.monthlyContribution || g.monthlyContribution <= 0 || g.progress >= 100) return null;
      const remaining = (g.target || 0) - (g.current || 0);
      const monthsToComplete = Math.ceil(remaining / g.monthlyContribution);
      return {
        name: g.name, currentProgress: g.progress, monthsRemaining: monthsToComplete,
        estimatedCompletionDate: new Date(new Date().getFullYear(), new Date().getMonth() + monthsToComplete, 1).toISOString().split('T')[0],
        onTrack: g.monthlyContribution > 0 && remaining > 0,
      };
    }).filter(Boolean);
    predictions.push({ type: 'goal_completion', title: 'Savings Goal Projections', goals: goalPredictions });

    // 4. Subscription annual forecast
    const subs = data.subscriptions || [];
    const subTotal = subs.reduce((s, x) => s + (x.monthlyAmount || 0), 0);
    if (subTotal > 0) {
      predictions.push({
        type: 'spending_trend', title: 'Subscription Annual Cost',
        value: subTotal * 12,
        detail: `${subs.length} subscription${subs.length > 1 ? 's' : ''} cost $${subTotal}/month — $${subTotal * 12}/year. ${subTotal > 100 ? 'Over $100/month — consider auditing.' : ''}`,
        confidence: 'high',
      });
    }

    // 5. Next month projection
    predictions.push({
      type: 'next_month', title: 'Next Month Projection',
      estimatedIncome: Math.round(dailyIncome * daysInMonth * 100) / 100,
      estimatedExpenses: Math.round(adjustedDailyExpense * daysInMonth * 100) / 100,
      estimatedSavings: Math.round((dailyIncome - adjustedDailyExpense) * daysInMonth * 100) / 100,
    });

    return JSON.stringify(predictions);
  }

  _fallbackOpportunities(data) {
    const opportunities = [];
    const cats = data.categoryBreakdown || [];
    const subs = data.subscriptions || [];
    const totalSubsMonthly = subs.reduce((s, sub) => s + (sub.monthlyAmount || 0), 0);
    const changes = data.categoryChanges || [];
    const income = data.monthlyIncome || 0;
    const expenses = data.monthlyExpenses || 0;
    const balance = income - expenses;
    const goals = data.savingsGoals || [];
    const habits = data.habits || {};

    // Subscriptions
    if (totalSubsMonthly > 30) {
      opportunities.push({
        area: 'Subscriptions',
        description: `${subs.length} subscription${subs.length > 1 ? 's' : ''} at $${totalSubsMonthly}/month ($${totalSubsMonthly * 12}/year). Canceling just what you don't use could save $${Math.round(Math.min(subTotal * 0.3, 50))}/month.`,
        estimatedSavings: Math.round(Math.min(50, totalSubsMonthly * 0.3) * 100) / 100,
        effort: 'low', impact: 'medium',
      });
    }

    // Food & Dining
    const food = cats.find(c => c.category === 'Food' || c.category === 'Dining');
    if (food && food.amount > 100) {
      const savings30 = Math.round(food.amount * 0.15);
      opportunities.push({
        area: 'Food & Dining',
        description: `Food is $${food.amount}/month (${food.percentage}% of spending). A 15% reduction saves ~$${savings30}/month — meal prepping and limiting dining out are the easiest paths.`,
        estimatedSavings: savings30,
        effort: 'low', impact: 'high',
      });
    }

    // Transportation
    const transport = cats.find(c => c.category === 'Transportation' || c.category === 'Transport');
    if (transport && transport.amount > 100) {
      const transSaving = Math.round(transport.amount * 0.15);
      opportunities.push({
        area: 'Transportation',
        description: `Transport is $${transport.amount}/month. Carpooling or public transit 1–2 days/week could save ~$${transSaving}/month.`,
        estimatedSavings: transSaving,
        effort: 'medium', impact: 'medium',
      });
    }

    // Entertainment
    const entertainment = cats.find(c => c.category === 'Entertainment');
    if (entertainment && entertainment.amount > 50) {
      const entSaving = Math.round(entertainment.amount * 0.2);
      opportunities.push({
        area: 'Entertainment',
        description: `Entertainment is $${entertainment.amount}/month. Cutting by 20% saves ~$${entSaving}/month — try free alternatives every other weekend.`,
        estimatedSavings: entSaving,
        effort: 'medium', impact: 'medium',
      });
    }

    // Shopping
    const shopping = cats.find(c => c.category === 'Shopping');
    if (shopping && shopping.amount > 100) {
      const shopSaving = Math.round(shopping.amount * 0.2);
      opportunities.push({
        area: 'Shopping',
        description: `Shopping is $${shopping.amount}/month. A 24-hour rule before non-essential purchases could save ~$${shopSaving}/month.`,
        estimatedSavings: shopSaving,
        effort: 'medium', impact: 'high',
      });
    }

    // Growing categories (recent increases that are candidates for review)
    const fastGrowing = changes.filter(c => c.change > 20 && c.currentAmount > 50).slice(0, 1);
    if (fastGrowing.length > 0) {
      const gc = fastGrowing[0];
      opportunities.push({
        area: gc.category,
        description: `${gc.category} spending jumped ${gc.change}% vs last month ($${gc.currentAmount} vs $${gc.previousAmount}). Reversing half the increase saves ~$${Math.round((gc.currentAmount - gc.previousAmount) / 2)}/month.`,
        estimatedSavings: Math.round((gc.currentAmount - gc.previousAmount) / 2),
        effort: 'medium', impact: 'medium',
      });
    }

    // Daily spend reduction
    if (habits.averageDailySpend > 20) {
      const dailyTarget = Math.round(habits.averageDailySpend * 0.85);
      const monthlyFromDaily = Math.round((habits.averageDailySpend - dailyTarget) * 30);
      if (monthlyFromDaily > 20) {
        opportunities.push({
          area: 'Daily Spending',
          description: `Cutting daily spend from $${habits.averageDailySpend} to $${dailyTarget} saves ~$${monthlyFromDaily}/month with no major lifestyle changes.`,
          estimatedSavings: monthlyFromDaily,
          effort: 'low', impact: 'high',
        });
      }
    }

    // Savings Goal boost
    if (balance > 0 && goals.length > 0) {
      const lowestProgress = [...goals].sort((a, b) => (a.progress || 0) - (b.progress || 0))[0];
      if (lowestProgress) {
        const boostAmount = Math.round(Math.min(balance, 100));
        opportunities.push({
          area: 'Goal Boost',
          description: `Move $${boostAmount}/month to "${lowestProgress.name}" (${lowestProgress.progress || 0}% progress) to accelerate it.`,
          estimatedSavings: boostAmount,
          effort: 'low', impact: 'high',
        });
      }
    }

    return JSON.stringify(opportunities.slice(0, 8));
  }

  _fallbackAdvice(data) {
    const advice = [];
    const changes = data.categoryChanges || [];
    const budgets = data.budgetUtilization || [];
    const cats = data.categoryBreakdown || [];
    const subs = data.subscriptions || [];
    const goals = data.savingsGoals || [];
    const income = data.monthlyIncome || 0;
    const expenses = data.monthlyExpenses || 0;
    const savingsRate = data.savingsRate || 0;
    const habits = data.habits || {};

    // Growing categories — need attention
    changes
      .filter(c => c.change > 15 && c.currentAmount > 50)
      .forEach(c => {
        advice.push({
          type: 'reduction',
          title: `Reduce ${c.category} Spending`,
          message: `${c.category} up ${c.change}% ($${c.currentAmount} vs $${c.previousAmount}). Setting a weekly limit of $${Math.round(c.currentAmount / 4)} would help control it.`,
          category: c.category,
          potentialSavings: Math.round((c.currentAmount - c.previousAmount) * 100) / 100,
        });
      });

    // Over-budget categories
    budgets
      .filter(b => b.status === 'over_budget')
      .forEach(b => {
        advice.push({
          type: 'budget',
          title: `Review ${b.category} Budget`,
          message: `Spent $${b.spent} of $${b.budgeted} (${b.percentUsed}%). A daily limit of $${Math.round(b.budgeted / 30)} would keep this on track.`,
          category: b.category,
          potentialSavings: Math.round((b.spent - b.budgeted) * 100) / 100,
        });
      });

    // At-risk budgets
    budgets
      .filter(b => b.status === 'at_risk')
      .forEach(b => {
        advice.push({
          type: 'budget',
          title: `${b.category} Near Limit`,
          message: `Used ${b.percentUsed}% of $${b.budgeted} ${b.category} budget — $${b.remaining} left. Pace accordingly for the rest of the month.`,
          category: b.category,
          potentialSavings: null,
        });
      });

    // Subscription reduction
    const subTotal = subs.reduce((s, x) => s + (x.monthlyAmount || 0), 0);
    if (subTotal > 30) {
      const subSaving = Math.round(subTotal * 0.3);
      advice.push({
        type: 'subscription',
        title: `Audit ${subs.length} Subscription${subs.length > 1 ? 's' : ''}`,
        message: `$${subTotal}/month ($${subTotal * 12}/year). Cutting unused ones could save ~$${subSaving}/month.`,
        category: 'Subscriptions',
        potentialSavings: subSaving,
      });
    }

    // Biggest category optimization
    if (cats.length > 0 && cats[0].percentage > 35) {
      advice.push({
        type: 'reduction',
        title: `Optimize ${cats[0].category}`,
        message: `${cats[0].category} is ${cats[0].percentage}% of your spending. A 10% trim saves ~$${Math.round(cats[0].amount * 0.1)}/month.`,
        category: cats[0].category,
        potentialSavings: Math.round(cats[0].amount * 0.1),
      });
    }

    // Goal pacing
    const activeGoal = goals.find(g => (g.progress || 0) < 100 && (g.progress || 0) > 0);
    if (activeGoal && activeGoal.progress < 50) {
      const remaining = (activeGoal.target || 0) - (activeGoal.current || 0);
      const monthlyFree = Math.max(0, income - expenses);
      const neededMonthly = Math.ceil(remaining / 6); // aim for 6 months
      if (neededMonthly > (activeGoal.monthlyContribution || 0) && monthlyFree > neededMonthly) {
        advice.push({
          type: 'goal',
          title: `Accelerate "${activeGoal.name}"`,
          message: `Increasing contribution from $${activeGoal.monthlyContribution || 0}/month to $${neededMonthly}/month would complete it in ~6 months.`,
          category: 'Goals',
          potentialSavings: neededMonthly - (activeGoal.monthlyContribution || 0),
        });
      }
    }

    // Savings rate advice
    if (savingsRate < 10 && income > 0) {
      const targetAmount = Math.round(income * 0.1);
      advice.push({
        type: 'general',
        title: 'Build Savings to 10%',
        message: `Current savings rate: ${savingsRate}%. Automating $${targetAmount}/month to savings on payday is the simplest way to reach 10%.`,
        category: 'Savings',
        potentialSavings: targetAmount - Math.round(income * savingsRate / 100),
      });
    }

    // Daily spend advice
    if (habits.averageDailySpend > 30) {
      const reduced = Math.round(habits.averageDailySpend * 0.85);
      advice.push({
        type: 'reduction',
        title: 'Reduce Daily Spending',
        message: `Averaging $${habits.averageDailySpend}/day. Reducing to $${reduced}/day saves ~$${Math.round((habits.averageDailySpend - reduced) * 30)}/month.`,
        category: 'Spending',
        potentialSavings: Math.round((habits.averageDailySpend - reduced) * 30),
      });
    }

    return JSON.stringify(advice.slice(0, 8));
  }

  _fallbackChat(question, data) {
    const income = data.monthlyIncome || 0;
    const expenses = data.monthlyExpenses || 0;
    const balance = income - expenses;
    const savingsRate = data.savingsRate || 0;
    const habits = data.habits || {};
    const biggest = habits.biggestCategory;
    const cats = data.categoryBreakdown || [];
    const budgets = data.budgetUtilization || [];
    const goals = data.savingsGoals || [];
    const subs = data.subscriptions || [];
    const expenseChange = data.expenseChange || 0;
    const q = question.toLowerCase();

    // Saving / reduce questions
    if (q.includes('save') || q.includes('reduce') || q.includes('cut') || q.includes('spend less')) {
      let answer = `Based on your data, here are the best ways to save:\n\n`;
      if (biggest) {
        answer += `• Your largest expense is ${biggest.category} at $${biggest.amount} (${biggest.percentage}% of spending). A 10% reduction saves ~$${Math.round(biggest.amount * 0.1)}/month.\n`;
      }
      if (cats.length >= 2) {
        answer += `• ${cats[1].category} is your second-largest at $${cats[1].amount}. Cutting 10–15% there saves ~$${Math.round(cats[1].amount * 0.12)}/month.\n`;
      }
      const subTotal = subs.reduce((s, x) => s + (x.monthlyAmount || 0), 0);
      if (subTotal > 30) {
        answer += `• You have ${subs.length} subscription${subs.length > 1 ? 's' : ''} costing $${subTotal}/month. Auditing them usually saves 20–30%.\n`;
      }
      if (habits.averageDailySpend > 0) {
        const reduced = Math.round(habits.averageDailySpend * 0.9);
        answer += `• Your daily spend is $${habits.averageDailySpend}. Reducing to $${reduced} saves ~$${Math.round((habits.averageDailySpend - reduced) * 30)}/month.\n`;
      }
      answer += `\nYour current savings rate is ${savingsRate}%. Aiming for 20% is a great target.`;
      return JSON.stringify({ answer, type: 'advice' });
    }

    // Health / score questions
    if (q.includes('health') || q.includes('score') || q.includes('how am i') || q.includes('doing')) {
      let level;
      const rate = Math.round((income > 0 ? (expenses / income) * 100 : 0));
      if (rate <= 70) level = 'good';
      else if (rate <= 85) level = 'fair';
      else level = 'needs_attention';

      let answer = `Financial Health Summary:\n\n• Income: $${income}/month\n• Expenses: $${expenses}/month\n• Savings Rate: ${savingsRate}%\n• Balance: $${balance}\n`;

      if (biggest) {
        answer += `• Top category: ${biggest.category} ($${biggest.amount})\n`;
      }
      const subTotal = subs.reduce((s, x) => s + (x.monthlyAmount || 0), 0);
      if (subTotal > 0) {
        answer += `• Subscriptions: ${subs.length} totaling $${subTotal}/month\n`;
      }

      answer += `\nStatus: ${level === 'good' ? 'Good — you\'re spending within your means.' : level === 'fair' ? 'Fair — some room for improvement.' : 'Needs attention — expenses are high relative to income.'}`;

      if (level !== 'good' && biggest) {
        answer += `\n\nRecommendation: Start by reviewing your ${biggest.category} spending.`;
      }

      return JSON.stringify({ answer, type: 'analysis' });
    }

    // Budget questions
    if (q.includes('budget') || q.includes('budgets') || q.includes('track')) {
      let answer = '';
      if (budgets.length === 0) {
        answer = `You don't have any budgets set up yet. Setting even one or two would give you real-time control over your spending. I'd start with ${biggest ? biggest.category : 'your biggest category'}.`;
      } else {
        const over = budgets.filter(b => b.status === 'over_budget');
        const onTrack = budgets.filter(b => b.status === 'on_track');
        answer = `You have ${budgets.length} budget${budgets.length > 1 ? 's' : ''} set up.\n`;
        if (over.length > 0) {
          answer += `\n⚠️ Over budget: ${over.map(b => `${b.category} ($${b.spent} of $${b.budgeted})`).join(', ')}.`;
        }
        if (onTrack.length > 0) {
          answer += `\n✅ On track: ${onTrack.map(b => `${b.category} ($${b.spent} of $${b.budgeted})`).join(', ')}.`;
        }
      }
      return JSON.stringify({ answer, type: 'analysis' });
    }

    // Goal questions
    if (q.includes('goal') || q.includes('goals') || q.includes('progress') || q.includes('save for')) {
      let answer = '';
      if (goals.length === 0) {
        answer = `You don't have any savings goals set up yet. Even $${Math.round(Math.max(50, Math.abs(balance) * 0.1))}/month toward a specific goal builds momentum. An emergency fund (3× expenses = $${Math.round(expenses * 3)}) is always a great starting point.`;
      } else {
        answer = goals.map(g => {
          const pct = g.progress || 0;
          const remaining = (g.target || 0) - (g.current || 0);
          return `• "${g.name}": ${pct}% complete — $${remaining} remaining${g.monthlyContribution ? ` ($${g.monthlyContribution}/month)` : ''}`;
        }).join('\n');
        answer = `You have ${goals.length} savings goal${goals.length > 1 ? 's' : ''}:\n\n${answer}`;
      }
      return JSON.stringify({ answer, type: 'analysis' });
    }

    // Default: data-rich snapshot
    let answer = `Here's a quick snapshot of your finances:\n\n`;
    answer += `• Balance: $${balance > 0 ? '+' : ''}${balance}\n`;
    answer += `• Income: $${income}/month\n`;
    answer += `• Expenses: $${expenses}/month\n`;
    answer += `• Savings rate: ${savingsRate}%\n`;

    if (biggest) {
      answer += `• Top category: ${biggest.category} ($${biggest.amount})\n`;
    }
    if (expenseChange) {
      answer += `• Spending vs last month: ${expenseChange > 0 ? '+' : ''}${expenseChange}%\n`;
    }
    if (goals.length > 0) {
      const g = goals[0];
      answer += `• Active goal: "${g.name}" (${g.progress || 0}%)\n`;
    }

    answer += `\nWhat would you like to know more about?`;
    return JSON.stringify({ answer, type: 'info' });
  }

  _sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

module.exports = new AIService();
