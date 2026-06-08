/**
 * Financial Advisor Service — LLM-Powered
 *
 * Replaces the previous rule-based implementation with an AI-powered advisor
 * that uses real user financial data as context for every response.
 *
 * Key capabilities:
 *   - Financial Score (0-100) with AI explanation
 *   - Personalized insights based on user data
 *   - Financial health analysis
 *   - Custom advice and savings opportunities
 *   - Action plans with step-by-step guidance
 *   - Predictive analytics and forecasting
 *   - Conversational Q&A with memory
 */

const aiContextBuilder = require('./aiContextBuilder');
const aiService = require('./aiService');
const AdvisorMemory = require('../models/AdvisorMemory');
const logger = require('../utils/logger');

class FinancialAdvisorService {
  constructor(userId) {
    this.userId = userId;
    this.context = null;
  }

  // ══════════════════════════════════════════════
  // PUBLIC API
  // ══════════════════════════════════════════════

  /**
   * Full financial analysis — all data in one call
   */
  async getFullAnalysis() {
    const ctx = await this._buildContext();
    const score = this._calculateScore(ctx);

    // Run AI-powered analyses in parallel
    const [insights, health, advice, opportunities, actionPlans, predictions] = await Promise.all([
      this._aiInsights(ctx),
      this._aiHealth(ctx),
      this._aiAdvice(ctx),
      this._aiOpportunities(ctx),
      this._aiActionPlans(ctx),
      this._aiPredictions(ctx),
    ]);

    return {
      context: ctx,
      score,
      insights,
      actionPlans,
      predictions,
      health,
      advice,
      opportunities,
    };
  }

  /**
   * Financial score only
   */
  async getScore() {
    const ctx = await this._buildContext();
    const score = this._calculateScore(ctx);
    // Use deterministic explanation for speed (AI explanation still available via chat)
    const explanation = this._defaultExplanation(score, ctx);
    return { ...score, explanation };
  }

  /**
   * Smart insights only
   */
  async getSmartInsights() {
    const ctx = await this._buildContext();
    return this._aiInsights(ctx);
  }

  /**
   * Action plans only
   */
  async getActionPlans() {
    const ctx = await this._buildContext();
    return this._aiActionPlans(ctx);
  }

  /**
   * Predictions only
   */
  async getPredictions() {
    const ctx = await this._buildContext();
    return this._aiPredictions(ctx);
  }

  /**
   * Health analysis only
   */
  async getHealth() {
    const ctx = await this._buildContext();
    return this._aiHealth(ctx);
  }

  /**
   * Advice only
   */
  async getAdvice() {
    const ctx = await this._buildContext();
    return this._aiAdvice(ctx);
  }

  /**
   * Savings opportunities only
   */
  async getSavingsOpportunities() {
    const ctx = await this._buildContext();
    return this._aiOpportunities(ctx);
  }

  /**
   * Conversational Q&A with memory
   */
  async askQuestion(question) {
    const ctx = await this._buildContext();
    return this._answerWithAI(question, ctx);
  }

  // ══════════════════════════════════════════════
  // CONTEXT BUILDER
  // ══════════════════════════════════════════════

  async _buildContext() {
    this.context = await aiContextBuilder.buildContext(this.userId);
    return this.context;
  }

  // ══════════════════════════════════════════════
  // FINANCIAL SCORE (0-100) — Deterministic + AI
  // ══════════════════════════════════════════════

  _calculateScore(ctx) {
    let score = 0;
    const details = [];

    // 1. Budget adherence (30 pts)
    if (ctx.budgetUtilization.length > 0) {
      const overBudgetCount = ctx.budgetUtilization.filter(b => b.status === 'over_budget').length;
      const totalBudgets = ctx.budgetUtilization.length;
      const adherenceRatio = totalBudgets > 0 ? (totalBudgets - overBudgetCount) / totalBudgets : 1;
      const budgetScore = Math.round(adherenceRatio * 30);
      score += budgetScore;
      details.push({
        component: 'Budget Adherence', score: budgetScore, max: 30,
        detail: overBudgetCount === 0
          ? 'All budgets on track'
          : `${overBudgetCount} of ${totalBudgets} budgets exceeded`,
      });
    } else {
      score += 15;
      details.push({ component: 'Budget Adherence', score: 15, max: 30, detail: 'No budgets set — partial score' });
    }

    // 2. Savings consistency (25 pts)
    const savingsRate = ctx.savingsRate;
    let savingsScore = 0;
    if (savingsRate >= 30) savingsScore = 25;
    else if (savingsRate >= 20) savingsScore = 22;
    else if (savingsRate >= 15) savingsScore = 18;
    else if (savingsRate >= 10) savingsScore = 14;
    else if (savingsRate >= 5) savingsScore = 10;
    else if (savingsRate > 0) savingsScore = 6;
    else savingsScore = 0;
    score += savingsScore;
    details.push({ component: 'Savings Consistency', score: savingsScore, max: 25, detail: `Savings rate: ${savingsRate}%` });

    // 3. Spending habits (20 pts)
    let habitsScore = 0;
    const projectedRatio = (ctx.habits.projectedMonthlyExpenses || 0) / (ctx.monthlyIncome || 1);
    if (projectedRatio <= 0.7) habitsScore = 20;
    else if (projectedRatio <= 0.85) habitsScore = 16;
    else if (projectedRatio <= 1.0) habitsScore = 10;
    else habitsScore = 4;
    if ((ctx.habits.expenseTransactionCount || 0) >= 10) habitsScore = Math.min(20, habitsScore + 2);
    score += habitsScore;
    details.push({
      component: 'Spending Habits', score: habitsScore, max: 20,
      detail: `Projected expense/income ratio: ${Math.round(projectedRatio * 100)}%`,
    });

    // 4. Income stability (15 pts)
    const trends = ctx.monthlyTrends || [];
    let incomeStability = 0;
    if (trends.length >= 3) {
      const recentIncomes = trends.slice(-3).map(t => t.income);
      const avgIncome = recentIncomes.reduce((s, v) => s + v, 0) / recentIncomes.length;
      const variance = recentIncomes.reduce((s, v) => s + Math.pow(v - avgIncome, 2), 0) / recentIncomes.length;
      const cv = avgIncome > 0 ? Math.sqrt(variance) / avgIncome : 1;
      if (cv <= 0.1) incomeStability = 15;
      else if (cv <= 0.2) incomeStability = 13;
      else if (cv <= 0.3) incomeStability = 10;
      else if (cv <= 0.5) incomeStability = 7;
      else incomeStability = 3;
    } else {
      incomeStability = 8;
    }
    score += incomeStability;
    details.push({
      component: 'Income Stability', score: incomeStability, max: 15,
      detail: trends.length >= 3 ? 'Based on last 3 months' : 'Insufficient data',
    });

    // 5. Debt & Subscriptions (10 pts)
    const totalSubs = ctx.subscriptions.reduce((s, sub) => s + (sub.monthlyAmount || 0), 0);
    const debtRatio = ctx.monthlyIncome > 0 ? totalSubs / ctx.monthlyIncome : 0;
    let debtScore = 0;
    if (debtRatio <= 0.1) debtScore = 10;
    else if (debtRatio <= 0.2) debtScore = 8;
    else if (debtRatio <= 0.3) debtScore = 6;
    else if (debtRatio <= 0.5) debtScore = 4;
    else debtScore = 2;
    score += debtScore;
    details.push({
      component: 'Debt & Subscriptions', score: debtScore, max: 10,
      detail: totalSubs > 0 ? `Subscription ratio: ${Math.round(debtRatio * 100)}% of income` : 'No subscriptions',
    });

    const finalScore = Math.min(100, Math.max(0, Math.round(score)));

    let level;
    if (finalScore >= 90) level = 'Excellent';
    else if (finalScore >= 75) level = 'Good';
    else if (finalScore >= 60) level = 'Average';
    else level = 'Needs Improvement';

    return { score: finalScore, level, details, maxScore: 100 };
  }

  /**
   * AI-enhanced score explanation
   */
  async _aiScoreExplanation(ctx, score) {
    const systemPrompt = `You are a financial advisor AI. Your task is to write a brief, personalized explanation of a user's financial score based on their actual data. The explanation should be 2-3 sentences, conversational, and highlight their key strength and their biggest area for improvement. FINANCIAL_SCORE`;

    const userPrompt = `User financial data (JSON):
${JSON.stringify(ctx, null, 2)}

Their calculated score is ${score.score}/100 (${score.level}).

Write a brief, personalized explanation (2-3 sentences) of this score. Mention their specific savings rate (${ctx.savingsRate}%) and one key action they could take to improve. Return ONLY a JSON object with a single field "explanation" containing the text.`;

    try {
      const result = await aiService.generate(systemPrompt, userPrompt, { temperature: 0.4, maxTokens: 500, maxRetries: 0 });
      const parsed = this._extractJSON(result);
      if (parsed && parsed.explanation) return parsed.explanation;
      return this._defaultExplanation(score, ctx);
    } catch (e) {
      return this._defaultExplanation(score, ctx);
    }
  }

  _defaultExplanation(score, ctx) {
    const s = score.score;
    const rate = ctx.savingsRate;
    const ratio = ctx.monthlyIncome > 0 ? Math.round((ctx.monthlyExpenses / ctx.monthlyIncome) * 100) : 0;
    if (s >= 75) {
      return `Great work! Your financial score of ${s}/100 reflects your strong savings rate of ${rate}% and solid budget management. Keep maintaining these healthy habits.`;
    } else if (s >= 60) {
      return `Your financial score of ${s}/100 shows you're on the right track. With a savings rate of ${rate}%, focusing on reducing discretionary spending could help you reach the next level.`;
    }
    return `Your score of ${s}/100 indicates room for improvement. Your savings rate of ${rate}% and expense ratio of ${ratio}% are the key areas to focus on — try to cut unnecessary expenses and aim to save at least 10% of your income.`;
  }

  // ══════════════════════════════════════════════
  // AI-POWERED INSIGHTS
  // ══════════════════════════════════════════════

  async _aiInsights(ctx) {
    const systemPrompt = `You are a financial insights AI. Based on the user's actual financial data, generate personalized insights.

Each insight must:
1. Be directly based on the user's data (income, expenses, budgets, categories, goals, etc.)
2. Include specific dollar amounts and percentages from their data
3. Be actionable and personalized
4. Not be generic — every number and recommendation must come from their data

Return a JSON array of insight objects. Maximum 10 insights. Each insight object:
{
  "type": "success" | "warning" | "insight" | "opportunity",
  "icon": "trending_up" | "warning" | "savings" | "flag" | "calculator" | "credit_card" | "subscriptions" | "trending_down",
  "title": "Short title (max 50 chars)",
  "message": "Detailed message with specific amounts from user data",
  "category": "Category name (e.g. Food, Transportation, Savings, Spending, Goals, Subscriptions, Payment)",
  "priority": "high" | "medium" | "low",
  "change": optional number (percentage change if applicable),
  "value": optional number (monetary amount if applicable),
  "progress": optional number (percentage progress if applicable)
}

FINANCIAL_INSIGHTS`;

    const userPrompt = `User financial data (JSON):
${JSON.stringify(ctx, null, 2)}

Generate up to 10 personalized financial insights based EXCLUSIVELY on this data. Every insight must reference specific numbers, categories, and amounts from the data above. Never invent data. Return ONLY a valid JSON array.`;

    try {
      const result = await aiService.generate(systemPrompt, userPrompt, { temperature: 0.3, maxTokens: 1000, maxRetries: 0 });
      const parsed = this._extractJSON(result);
      if (Array.isArray(parsed)) return parsed.slice(0, 15);
      throw new Error('Insights response is not an array');
    } catch (e) {
      logger.error('AI insights parsing failed, using fallback:', e.message);
      const fallback = aiService._getFallbackResponse('FINANCIAL_INSIGHTS', userPrompt);
      try { return JSON.parse(fallback); } catch { return []; }
    }
  }

  // ══════════════════════════════════════════════
  // AI-POWERED HEALTH ANALYSIS
  // ══════════════════════════════════════════════

  async _aiHealth(ctx) {
    const systemPrompt = `You are a financial health analyst AI. Analyze the user's financial data and produce a health assessment.

Return a JSON object:
{
  "status": "excellent" | "good" | "needs_attention",
  "strengths": ["string array of strengths based on data"],
  "issues": ["string array of issues based on data"],
  "summary": "A 1-2 sentence summary of their financial health"
}

FINANCIAL_HEALTH`;

    const userPrompt = `User financial data:
${JSON.stringify(ctx, null, 2)}

Analyze their financial health. Status should be "excellent" if no major issues, "good" if 1-2 minor issues, "needs_attention" if significant concerns. Return ONLY valid JSON.`;

    try {
      const result = await aiService.generate(systemPrompt, userPrompt, { temperature: 0.3, maxTokens: 1000, maxRetries: 0 });
      const parsed = this._extractJSON(result);
      if (parsed && parsed.status) return parsed;
      throw new Error('Health response missing required fields');
    } catch (e) {
      logger.error('AI health parsing failed, using fallback:', e.message);
      const fallback = aiService._getFallbackResponse('FINANCIAL_HEALTH', userPrompt);
      try { return this._extractJSON(fallback) || { status: 'needs_attention', strengths: [], issues: ['Unable to analyze'], summary: 'Health analysis unavailable.' }; } catch { return { status: 'needs_attention', strengths: [], issues: ['Unable to analyze'], summary: 'Health analysis unavailable.' }; }
    }
  }

  // ══════════════════════════════════════════════
  // AI-POWERED ADVICE
  // ══════════════════════════════════════════════

  async _aiAdvice(ctx) {
    const systemPrompt = `You are a financial advisor AI. Generate personalized advice based on the user's actual financial data.

Each advice item must:
- Reference specific categories and amounts from the user's data
- Include a potential savings amount where applicable
- Be actionable and practical

Return a JSON array of advice objects. Maximum 8 items:
{
  "type": "reduction" | "budget" | "payment" | "goal" | "subscription" | "recurring" | "general",
  "title": "Actionable title",
  "message": "Specific advice with numbers from their data",
  "category": "Category name",
  "potentialSavings": number (estimated monthly savings, or null)
}

ADVICE`;

    const userPrompt = `User financial data:
${JSON.stringify(ctx, null, 2)}

Generate personalized advice based EXCLUSIVELY on this data. Include specific dollar amounts. Return ONLY a valid JSON array.`;

    try {
      const result = await aiService.generate(systemPrompt, userPrompt, { temperature: 0.3, maxTokens: 1000, maxRetries: 0 });
      const parsed = this._extractJSON(result);
      if (Array.isArray(parsed)) return parsed.slice(0, 8);
      throw new Error('Advice response is not an array');
    } catch (e) {
      logger.error('AI advice parsing failed, using fallback:', e.message);
      const fallback = aiService._getFallbackResponse('ADVICE', userPrompt);
      try { const fb = this._extractJSON(fallback); return Array.isArray(fb) ? fb.slice(0, 8) : []; } catch { return []; }
    }
  }

  // ══════════════════════════════════════════════
  // AI-POWERED SAVINGS OPPORTUNITIES
  // ══════════════════════════════════════════════

  async _aiOpportunities(ctx) {
    const systemPrompt = `You are a savings opportunity finder AI. Identify specific savings opportunities based on the user's actual financial data.

Each opportunity must include estimated savings amounts from their data.

Return a JSON array. Maximum 6 items:
{
  "area": "Category or area name",
  "description": "Specific suggestion with potential savings amount",
  "estimatedSavings": number (monthly savings estimate),
  "effort": "low" | "medium" | "high",
  "impact": "low" | "medium" | "high"
}

SAVINGS_OPPORTUNITIES`;

    const userPrompt = `User financial data:
${JSON.stringify(ctx, null, 2)}

Identify savings opportunities based EXCLUSIVELY on this data. Include specific amounts. Return ONLY a valid JSON array.`;

    try {
      const result = await aiService.generate(systemPrompt, userPrompt, { temperature: 0.3, maxTokens: 800, maxRetries: 0 });
      const parsed = this._extractJSON(result);
      if (Array.isArray(parsed)) return parsed.slice(0, 6);
      throw new Error('Opportunities response is not an array');
    } catch (e) {
      logger.error('AI opportunities parsing failed, using fallback:', e.message);
      const fallback = aiService._getFallbackResponse('SAVINGS_OPPORTUNITIES', userPrompt);
      try { const fb = this._extractJSON(fallback); return Array.isArray(fb) ? fb.slice(0, 6) : []; } catch { return []; }
    }
  }

  // ══════════════════════════════════════════════
  // AI-POWERED ACTION PLANS
  // ══════════════════════════════════════════════

  async _aiActionPlans(ctx) {
    const systemPrompt = `You are a financial planning AI. Create personalized action plans based on the user's actual financial data.

Each plan should have specific weekly steps with actionable advice based on their categories, budgets, and goals.

Return a JSON array. Maximum 3 plans:
{
  "type": "savings" | "budget" | "goal" | "debt",
  "title": "Plan title",
  "expectedMonthlySavings": number (estimated),
  "duration": "Duration string (e.g. '30 days', 'This month')",
  "steps": [
    {
      "week": "Week number or 'Immediate' or 'Ongoing'",
      "action": "Specific actionable step with amounts from their data",
      "tip": "Helpful tip"
    }
  ]
}

ACTION_PLANS`;

    const userPrompt = `User financial data:
${JSON.stringify(ctx, null, 2)}

Create up to 3 personalized action plans based EXCLUSIVELY on this data. Every step must reference specific categories and amounts. Return ONLY a valid JSON array.`;

    try {
      const result = await aiService.generate(systemPrompt, userPrompt, { temperature: 0.3, maxTokens: 1000, maxRetries: 0 });
      const parsed = this._extractJSON(result);
      if (Array.isArray(parsed)) return parsed.slice(0, 3);
      throw new Error('Action plans response is not an array');
    } catch (e) {
      logger.error('AI action plans parsing failed, using fallback:', e.message);
      const fallback = aiService._getFallbackResponse('ACTION_PLANS', userPrompt);
      try { const fb = this._extractJSON(fallback); return Array.isArray(fb) ? fb.slice(0, 3) : []; } catch { return []; }
    }
  }

  // ══════════════════════════════════════════════
  // AI-POWERED PREDICTIONS & FORECASTING
  // ══════════════════════════════════════════════

  async _aiPredictions(ctx) {
    const systemPrompt = `You are a financial forecasting AI. Generate predictions and projections based on the user's actual financial data.

Include end-of-month balance predictions, budget overrun risks, goal completion estimates, and next month projections.

Return a JSON array. Each prediction object:
{
  "type": "end_of_month_balance" | "budget_overruns" | "goal_completion" | "next_month" | "spending_trend",
  "title": "Prediction title",
  "value": number (monetary value if applicable),
  "detail": "Description with specific projections",
  "confidence": "high" | "medium" | "low",
  // For budget_overruns:
  "items": [{ "category": "...", "budgeted": number, "projectedSpend": number, "expectedOverrun": number, "risk": "high"|"medium"|"low" }],
  "count": number,
  // For goal_completion:
  "goals": [{ "name": "...", "currentProgress": number, "monthsRemaining": number, "estimatedCompletionDate": "YYYY-MM-DD", "onTrack": bool }],
  // For next_month:
  "estimatedIncome": number,
  "estimatedExpenses": number,
  "estimatedSavings": number
}

PREDICTIONS`;

    const userPrompt = `User financial data:
${JSON.stringify(ctx, null, 2)}

Generate financial predictions based EXCLUSIVELY on this data. Include specific projected amounts. Calculate end-of-month projections using their average daily spend. Return ONLY a valid JSON array.`;

    try {
      const result = await aiService.generate(systemPrompt, userPrompt, { temperature: 0.2, maxTokens: 1000, maxRetries: 0 });
      const parsed = this._extractJSON(result);
      if (Array.isArray(parsed)) return parsed.slice(0, 6);
      throw new Error('Predictions response is not an array');
    } catch (e) {
      logger.error('AI predictions parsing failed, using fallback:', e.message);
      const fallback = aiService._getFallbackResponse('PREDICTIONS', userPrompt);
      try { const fb = this._extractJSON(fallback); return Array.isArray(fb) ? fb.slice(0, 6) : []; } catch { return []; }
    }
  }

  // ══════════════════════════════════════════════
  // AI-POWERED CONVERSATION WITH MEMORY
  // ══════════════════════════════════════════════

  async _answerWithAI(question, ctx) {
    // Load recent conversation history (last 3 exchanges only to save tokens)
    const recentMemory = await AdvisorMemory.find({ user: this.userId })
      .sort({ createdAt: -1 })
      .limit(6)
      .lean();

    const conversationHistory = recentMemory.reverse().map(m =>
      `${m.role === 'user' ? 'User' : 'Advisor'}: ${m.content.slice(0, 300)}`
    ).join('\n').slice(0, 1000);

    // Compact financial snapshot — drastically smaller than full context
    const topCategories = (ctx.categoryBreakdown || []).slice(0, 3).map(c =>
      `${c.category}: $${c.amount} (${c.percentage}%)`
    ).join(', ');

    const budgetAlerts = (ctx.budgetUtilization || []).slice(0, 3).map(b =>
      `${b.category}: $${b.spent} of $${b.budgeted} (${b.status})`
    ).join(', ');

    const topGoals = (ctx.savingsGoals || []).slice(0, 2).map(g =>
      `${g.name}: $${g.current || 0} of $${g.target || 0} (${g.progress || 0}%)`
    ).join(', ');

    const subTotal = ctx.subscriptions?.reduce((s, x) => s + (x.monthlyAmount || 0), 0) || 0;
    const compactData = [
      `Reference data (use as supporting evidence, do not dump):`,
      `Balance: $${ctx.balance || 0}, Income: $${ctx.monthlyIncome || 0}/mo, Expenses: $${ctx.monthlyExpenses || 0}/mo`,
      `Savings rate: ${ctx.savingsRate || 0}%, Monthly surplus: $${(ctx.monthlyIncome || 0) - (ctx.monthlyExpenses || 0)}`,
      `Top categories: ${topCategories || 'none'}`,
      budgetAlerts ? `Budgets: ${budgetAlerts}` : null,
      topGoals ? `Goals: ${topGoals}` : null,
      `Subscriptions: ${(ctx.subscriptions || []).length} totaling $${subTotal}/mo`,
      `Expense change: ${ctx.expenseChange || 0}% vs last month`,
    ].filter(Boolean).join('\n');

    const systemPrompt = `You are a thoughtful financial advisor, "SmartSave Advisor". Lead with your answer or insight — do NOT start with a list of numbers. Use financial data as supporting evidence, not the main point. Explain your reasoning, discuss tradeoffs, and give personalized recommendations. Keep it conversational, be concise (2-3 paragraphs max), and sound like a human advisor. Return valid JSON only.`;

    const userPrompt = `DATA:
${compactData}

${conversationHistory ? `HISTORY:\n${conversationHistory}\n` : ''}Q: ${question}

JSON: {"answer":"...","type":"advice|analysis|info","suggestedActions":["..."]|null}`;

    try {
      const result = await aiService.generate(systemPrompt, userPrompt, { temperature: 0.4, maxTokens: 500, maxRetries: 0 });
      const parsed = this._extractJSON(result);

      if (!parsed || !parsed.answer) {
        throw new Error('Could not extract valid JSON response from AI');
      }

      // Save to conversation memory
      await this._saveMemory('user', question, 'chat');
      await this._saveMemory('assistant', parsed.answer || '', parsed.type || 'chat');

      return parsed;
    } catch (e) {
      logger.error('AI chat failed, using data-driven fallback:', e.message);

      // Smart keyword-driven fallback — answers questions using real user data
      const response = this._smartFallback(question, ctx);

      await this._saveMemory('user', question, 'chat');
      await this._saveMemory('assistant', response.answer, response.type || 'chat');

      return response;
    }
  }

  /**
   * Save a conversation entry to memory and clean up old entries
   */
  async _saveMemory(role, content, type = 'chat') {
    try {
      await AdvisorMemory.create({
        user: this.userId,
        role,
        content: content.slice(0, 10000),
        type,
      });
      // Cleanup old messages (keep last 100)
      await AdvisorMemory.cleanup(this.userId);
    } catch (e) {
      logger.error(`Failed to save advisor memory: ${e.message || e}`);
    }
  }

  /**
   * Conversational fallback — designed to sound like a real financial advisor,
   * not a reporting engine.
   *
   * Rules:
   *  - Lead with the answer or insight, not the numbers.
   *  - Use data as supporting evidence, not the main event.
   *  - Explain reasoning and tradeoffs.
   *  - Be concise (2-3 paragraphs max).
   *  - Sound human (contractions, varied sentence structure, natural flow).
   *  - End with a useful follow-up question.
   */
  _smartFallback(question, ctx) {
    const q = question.toLowerCase();
    const balance = ctx.balance || 0;
    const income = ctx.monthlyIncome || 0;
    const expenses = ctx.monthlyExpenses || 0;
    const savingsRate = ctx.savingsRate || 0;
    const topCat = ctx.categoryBreakdown?.[0];
    const secondCat = ctx.categoryBreakdown?.[1];
    const budget = ctx.budgetUtilization?.[0];
    const goal = ctx.savingsGoals?.[0];
    const subs = ctx.subscriptions || [];
    const subTotal = subs.reduce((s, x) => s + (x.monthlyAmount || 0), 0);
    const cats = ctx.categoryBreakdown || [];
    const expenseChange = ctx.expenseChange;
    const monthlyFree = income - expenses;
    const habits = ctx.habits || {};

    // Helper: format currency
    const $ = (n) => `$${Math.round(n).toLocaleString()}`;
    const firstFew = (items, label) => {
      if (!items || items.length === 0) return '';
      const names = items.slice(0, 3).map(i => i.name || i.category).join(', ');
      return items.length > 3 ? `${names}, and ${items.length - 3} more` : names;
    };

    // ──────────────────────────────────────────────
    // 1. TRAVEL questions
    // ──────────────────────────────────────────────
    if (/\b(travel|trip|vacation|tokyo|paris|london|fly|flights?|holiday|visit|japan|abroad)\b/i.test(q)) {
      const avgCost = 2500;
      const canAfford = balance >= avgCost;
      const monthsToSave = Math.ceil((avgCost - balance) / Math.max(1, monthlyFree));

      if (!canAfford && monthlyFree <= 0) {
        return {
          answer: `A trip sounds great, but right now your expenses are matching or exceeding your income each month, so funding travel would mean cutting into your existing balance. That's not necessarily a dealbreaker — it just means you'd want to plan ahead. If you could free up about ${$(Math.round(avgCost / 12))} a month, you'd be ready within the year. Want me to help find areas where you could trim?`,
          type: 'advice',
          suggestedActions: ['Where can I cut spending to save for travel?', 'How can I increase my income?', 'What is the cheapest time to travel?'],
        };
      }

      if (canAfford) {
        return {
          answer: `That trip is well within reach. With what you've got available, the cost wouldn't put any real strain on your day-to-day finances. ${goal ? `The bigger question is whether you'd rather put that money toward your "${goal.name}" goal instead — you're making solid progress there.` : ''} If you do decide to go, just carve the travel budget out upfront so it doesn't blur into your regular spending. Want to map out what the overall budget would look like?`,
          type: 'advice',
          suggestedActions: ['What would my budget look like with this trip?', 'How much should I set aside for travel?', 'Should I delay my savings goal?'],
        };
      }

      return {
        answer: `You're about ${$(avgCost - balance)} short of the estimated cost, but that's achievable within a few months at your current savings pace. ${goal ? `You've also got your "${goal.name}" goal going, so you'd want to balance both.` : ''} The simplest approach would be to set up a separate travel fund and contribute to it automatically each month. At about ${$(Math.round(monthlyFree * 0.3))} a month, you'd be there in roughly ${monthsToSave} months without feeling the pinch elsewhere.`,
        type: 'advice',
        suggestedActions: ['Help me set up a travel fund', 'How can I save faster for this trip?', 'Should I adjust my savings goal?'],
      };
    }

    // ──────────────────────────────────────────────
    // 2. SAVING / REDUCE questions
    // ──────────────────────────────────────────────
    // Intentionally placed AFTER goal — "savings goals" should match GOAL, not SAVING
    // Only match when user explicitly asks about saving/reducing spending (verb form),
    // not when "savings" appears as a noun (savings rate, savings goals, etc.)
    if (/\b((?<!savin)sav(e|ing)|reduc(ing|e|tion)?|cut|spend less|cheaper|discount|optimiz)\b/i.test(q) && !/goals?\b/i.test(q)) {
      const opportunities = [];
      const savings = [];

      if (topCat) {
        const trimmed = Math.round(topCat.amount * 0.15);
        opportunities.push(`${topCat.category.toLowerCase()} (your biggest category at ${topCat.percentage}% of spending)`);
        savings.push(trimmed);
      }
      if (budget && budget.status === 'over_budget') {
        opportunities.push(`${budget.category.toLowerCase()} (currently over budget by ${$(budget.spent - budget.budgeted)})`);
        savings.push(Math.round(budget.spent - budget.budgeted));
      }
      if (subTotal > 30) {
        opportunities.push('subscriptions');
        savings.push(Math.round(subTotal * 0.3));
      }
      if (expenseChange && expenseChange > 10) {
        opportunities.push('recent spending increases');
      }

      const total = savings.reduce((s, v) => s + v, 0);
      const topOpp = opportunities[0] || 'discretionary spending';

      let answer = `The simplest way to save more is where you're already spending the most. `;

      if (topCat) {
        answer += `A small trim in ${topCat.category.toLowerCase()} — say 10–15% — would free up meaningful money without you really noticing the difference day to day. `;
      }

      if (budget && budget.status === 'over_budget') {
        answer += `I also notice your ${budget.category.toLowerCase()} budget is being exceeded by about ${$(budget.spent - budget.budgeted)}. Getting back within that limit alone would go a long way. `;
      }

      if (subTotal > 30) {
        answer += `${subs.length === 1 ? 'One subscription' : `${subs.length} subscriptions`} cost about ${$(subTotal)} a month — auditing those is usually the lowest-effort way to free up cash. `;
      }

      if (total > 0) {
        answer += `Between these areas, you could reasonably free up around ${$(total)} a month. `;
      }

      answer += goal
        ? `That kind of amount would make a real dent in your "${goal.name}" goal, if that's where you'd want to direct it. Want me to walk through the quickest win first?`
        : `Want me to walk through the quickest win first?`;

      return { answer, type: 'advice', suggestedActions: [`How can I reduce my ${topCat ? topCat.category.toLowerCase() : 'spending'}?`, 'Audit my subscriptions for me', 'What should my savings target be?'] };
    }

    // ──────────────────────────────────────────────
    // 3. BUDGET questions
    // ──────────────────────────────────────────────
    if (/\b(budgets?|over.?budget|limit|alerts?|track)\b/i.test(q)) {
      if (!budget) {
        return {
          answer: `You haven't set up any budgets yet, so there's nothing to compare your spending against. That's common, but having even one or two category limits makes a big difference — it shifts you from tracking after the fact to controlling things in real time. I'd start with your largest category (${topCat ? topCat.category.toLowerCase() : 'wherever you spend the most'}) and set a realistic monthly cap there. Want help setting one up?`,
          type: 'advice',
          suggestedActions: ['Help me set up a budget', 'What categories should I budget for?', 'How does the 50/30/20 rule work?'],
        };
      }

      if (budget.status === 'over_budget') {
        return {
          answer: `Your ${budget.category.toLowerCase()} budget is being exceeded, and the key question is whether the limit is too tight or the spending is creeping up. A quick way to tell: look at the last week or two of ${budget.category.toLowerCase()} transactions. Often it's just one or two purchases that account for most of the overage. Try setting a daily target of ${$(Math.round(budget.budgeted / 30))} for now — it's easier to track day by day than to realize you've overshot at the end of the month.`,
          type: 'advice',
          suggestedActions: [`Review my ${budget.category.toLowerCase()} transactions`, 'Set a daily spending limit', 'Adjust my budget amount'],
        };
      }

      return {
        answer: `Your ${budget.category.toLowerCase()} budget is on track — you're staying within the limit you set. That's worth acknowledging because most people find this harder than expected. If you keep this up, you could even redirect any surplus toward ${goal ? `your "${goal.name}" goal` : 'savings'} at the end of the month. Want to set up budgets for other categories too?`,
        type: 'advice',
        suggestedActions: ['Set up another budget', 'How do I track daily spending?', 'Should I adjust my budget amounts?'],
      };
    }

    // ──────────────────────────────────────────────
    // 4. GOAL questions
    // ──────────────────────────────────────────────
    if (/\b(goals?|target|save for|progress|milestone)\b/i.test(q)) {
      if (!goal) {
        return {
          answer: `You don't have any savings goals set up yet, which means your savings don't have a specific purpose attached to them — and they tend to grow faster when they do. It doesn't have to be big: an emergency fund, a purchase, a trip. Even ${$(Math.round(Math.max(50, monthlyFree * 0.2)))} a month toward a named goal builds momentum. Want to create one?`,
          type: 'advice',
          suggestedActions: ['Help me set up a savings goal', 'What should I save for first?', 'How much should I save each month?'],
        };
      }

      const progress = goal.progress || 0;
      const remaining = goal.target - (goal.current || 0);
      const monthsNeeded = monthlyFree > 0 ? Math.ceil(remaining / monthlyFree) : null;
      const hasEnoughNow = balance >= remaining;

      let answer = `You're ${progress}% of the way to your "${goal.name}" goal, which is solid progress. `;

      if (hasEnoughNow) {
        answer += `In fact, you have enough in your account right now to complete it. The decision then becomes whether to fund it now or keep the cash as a buffer and contribute gradually. There's no wrong answer — it depends on how comfortable you are with a lower balance for a while. `;
      } else if (monthsNeeded) {
        answer += `At your current savings rate, you're looking at roughly ${monthsNeeded} months to get there — which is reasonable. ${goal.monthlyContribution ? 'You already have a recurring contribution set up, which is the most reliable way to stay on track.' : 'Setting up an automatic contribution — even a small one — would keep you moving forward without having to think about it.'} `;
      }

      answer += `Would you like me to help you figure out the optimal monthly amount to hit a specific target date?`;

      return { answer, type: 'advice', suggestedActions: ['Calculate what I need to save monthly', 'Should I fund it from my balance now?', 'What other goals should I set?'] };
    }

    // ──────────────────────────────────────────────
    // 5. SPENDING / WHERE / CATEGORY questions
    // ──────────────────────────────────────────────
    if (/\b(spend(ing|s)?|expens|where|categor|going|goes|breakdown|analys)\b/i.test(q)) {
      let answer = '';

      if (topCat && topCat.percentage > 50) {
        answer = `Your spending is heavily concentrated in ${topCat.category.toLowerCase()} — it accounts for more than half of everything you spend. That's not necessarily a problem, but it does mean small changes there have an outsized impact. `;
      } else if (topCat) {
        answer = `Your biggest spending area is ${topCat.category.toLowerCase()}, followed by ${secondCat ? secondCat.category.toLowerCase() : 'other categories'}. ${topCat.percentage > 30 ? `At ${topCat.percentage}% of your total, it's worth taking a closer look.` : 'The distribution is fairly spread out.'} `;
      } else {
        answer = `You don't have any categorized spending yet, so I can't give you a breakdown. Once you add a few transactions with categories, I'll be able to show you exactly where your money is going. `;
      }

      if (expenseChange) {
        const direction = expenseChange > 0 ? 'up' : 'down';
        answer += `Compared to last month, your total spending is ${direction} by ${Math.abs(expenseChange)}%. ${expenseChange > 0 ? 'If that trend continues, it could start eating into your savings.' : 'That is a positive trend.'} `;
      }

      if (habits.averageDailySpend) {
        answer += `On an average day, you're spending about ${$(habits.averageDailySpend)}. Over a full month, that pace would land you around ${$(habits.projectedMonthlyExpenses || expenses)}. `;
      }

      answer += `Want to look at any specific category more closely?`;

      return { answer, type: 'analysis', suggestedActions: [`Analyze my ${topCat ? topCat.category.toLowerCase() : 'biggest'} spending in detail`, 'How does this compare to last month?', 'Show me my spending trends'] };
    }

    // ──────────────────────────────────────────────
    // 6. SCORE / HEALTH questions
    // ──────────────────────────────────────────────
    if (/\b(health|healthy|score|how am i|how are|rating|doing|financially)\b/i.test(q)) {
      const score = this._calculateScore(ctx);
      const weakest = score.details?.reduce((min, d) => d.score < min.score ? d : min, score.details?.[0]);

      let answer = '';

      if (score.score >= 75) {
        answer = `You're in a solid position. A score of ${score.score} puts you in the "${score.level}" range. Your savings habits and spending control are working well together. `;
      } else if (score.score >= 60) {
        answer = `You're doing okay — score of ${score.score} — but there's room to move up. `;
      } else {
        answer = `A score of ${score.score} suggests there are a few areas worth tightening up. The good news is the levers are clear. `;
      }

      if (weakest && weakest.score < weakest.max) {
        answer += `The biggest opportunity to improve is in "${weakest.component}" where you scored ${weakest.score} out of ${weakest.max}. ${weakest.component === 'Budget Adherence' && budget ? `Your ${budget.category.toLowerCase()} spending is the main factor there.` : 'Focusing there would move your score the most.'} `;
      }

      if (savingsRate >= 20) {
        answer += `Your savings rate of ${savingsRate}% is genuinely strong — that's the foundation everything else builds on. `;
      }

      answer += `The most effective thing you can do is check in on your budget weekly instead of monthly. Catching overruns early keeps small issues from compounding. Want to dive into any specific area?`;

      return { answer, type: 'analysis', suggestedActions: ['How can I improve my budget adherence?', 'What is a good target score?', 'Compare my finances to benchmarks'] };
    }

    // ──────────────────────────────────────────────
    // 7. SUBSCRIPTIONS
    // ──────────────────────────────────────────────
    if (/\b(subscriptions?|renew|monthly fee|membership|recurring)\b/i.test(q)) {
      if (subs.length === 0) {
        return {
          answer: `You don't have any active subscriptions, which is refreshing — a lot of people end up with several they barely use. Keeping this clean avoids the slow drip of small charges that can add up to hundreds a year without you noticing.`,
          type: 'analysis',
          suggestedActions: ['What is my total monthly spending?', 'How can I save more?', 'Show my financial health'],
        };
      }

      let answer = `You've got ${subs.length} active subscription${subs.length > 1 ? 's' : ''} costing about ${$(subTotal)} a month, or ${$(subTotal * 12)} annually. `;

      if (subs.length <= 3) {
        const names = subs.map(s => s.name).join(', ');
        answer += `Specifically: ${names}. `;
      } else {
        answer += `The main ones are ${firstFew(subs, 'subscriptions')}. `;
      }

      answer += `The key question isn't whether each one is worth having — it's whether you're actually getting value from it. A quick audit of your bank or credit card statement for the past 60 days will show you which ones you've used. Anything untouched for two months is a candidate for cancellation. ${goal ? `Redirecting even half of that ${$(subTotal)} toward your "${goal.name}" goal would make a noticeable difference.` : ''} Want me to help you figure out which ones to keep?`;

      return { answer, type: 'analysis', suggestedActions: ['Which subscriptions should I cancel?', 'How much could I save by cutting unused ones?', 'Set a subscription spending limit'] };
    }

    // ──────────────────────────────────────────────
    // 8. INCOME questions
    // ──────────────────────────────────────────────
    if (/\b(income|salary|earn|pay|revenue|making|make)\b/i.test(q)) {
      const incBreakdown = ctx.incomeBreakdown || [];
      let answer = `You're earning ${$(income)} a month, and after expenses you keep about ${$(monthlyFree)} — a savings rate of ${savingsRate}%. That's a healthy position. `;

      if (incBreakdown.length <= 1) {
        answer += `I notice your income comes from a single source. That's the most common setup, but it also means any disruption to that stream would be felt immediately. Diversifying — even with a small side stream of ${$(Math.round(income * 0.1))}–${$(Math.round(income * 0.15))} a month — would add both stability and momentum to your savings goals. `;
      } else {
        const sources = incBreakdown.slice(0, 3).map(i => i.category).join(', ');
        answer += `You have income coming from ${sources}, which gives you some natural diversification. `;
      }

      answer += `Want to explore ways to grow your income further?`;

      return { answer, type: 'analysis', suggestedActions: ['How can I increase my income?', 'What is my expense-to-income ratio?', 'How does my income compare to averages?'] };
    }

    // ──────────────────────────────────────────────
    // DEBT questions
    // ──────────────────────────────────────────────
    if (/\b(debt|loan|owe|credit|mortgage|borrow)\b/i.test(q)) {
      return {
        answer: `I don't see any debt recorded in your account, which is a great sign. If you do have debt that isn't tracked here yet, adding it would help me give you more tailored advice. In the meantime, your savings habits suggest you're in a good position to manage debt sensibly — the same discipline that builds savings works well for paying down balances too.`,
        type: 'analysis',
        suggestedActions: ['How should I prioritize paying off debt?', 'What is a healthy debt-to-income ratio?', 'Should I invest or pay off debt?'],
      };
    }

    // ──────────────────────────────────────────────
    // INVESTMENT questions
    // ──────────────────────────────────────────────
    if (/\b(invest(?:ing|ment|s|ed|or)?|stocks?|bonds?|portfolio|retirement|compound)\b/i.test(q)) {
      let answer = `Thinking about investing is a natural next step. `;

      if (monthlyFree > 0) {
        answer += `With your current savings rate of ${savingsRate}% and about ${$(monthlyFree)} left each month, you have room to start without straining your budget. `;
      } else {
        answer += `Right now your expenses are absorbing most of your income, so the first step would be to free up some room in your budget before investing. `;
      }

      const efund = Math.round(expenses * 3);
      answer += `Before putting money into the market though, I usually recommend having 3–6 months of expenses set aside as an emergency fund. For you that would be about ${$(efund)} to ${$(efund * 2)}. `;

      if (balance >= efund) {
        answer += `You're already there, which means you can start thinking about investing sooner rather than later. `;
      } else {
        answer += `That's something to build toward first before committing to investments. `;
      }

      answer += `Once that's in place, even a modest amount invested consistently makes a significant difference over time through compounding. Want to talk through a specific approach?`;

      return { answer, type: 'advice', suggestedActions: ['How much should I invest each month?', 'What is a good emergency fund target?', 'Explain compound interest with my numbers'] };
    }

    // ──────────────────────────────────────────────
    // DEFAULT: Conversational greeting / unknown
    // ──────────────────────────────────────────────
    let answer = '';

    if (/hello|hi |hey|good (morning|afternoon|evening)/i.test(q)) {
      answer = `Hi there! I'm your SmartSave advisor. I can help with questions about your spending, savings goals, budget, or anything else related to your finances. What's on your mind?`;
    } else {
      answer = `That's an interesting question. Based on what I can see in your account, `;
      if (topCat || goal) {
        answer += `the most relevant thing I can tell you is about `;
        if (goal) answer += `your "${goal.name}" goal (${goal.progress}% there)`;
        else if (topCat) answer += `your spending in ${topCat.category.toLowerCase()}`;
        answer += `. `;
      }
      answer += `I can help with a range of topics — saving more, understanding where your money goes, planning a purchase, or checking your financial health. What would be most useful to you?`;
    }

    return { answer, type: 'info', suggestedActions: ['How can I save more money?', 'How healthy are my finances?', 'What is my biggest spending category?', 'Can I afford a trip?', 'How are my savings goals doing?'] };
  }

  /**
   * Robust JSON extraction from LLM responses.
   * Handles markdown code blocks, trailing text, and common formatting issues.
   *
   * @param {string} text - The LLM response text
   * @returns {object|array|null} Parsed JSON or null if extraction fails
   */
  _extractJSON(text) {
    if (!text || typeof text !== 'string') return null;

    // Strategy 1: Direct parse
    try {
      return JSON.parse(text);
    } catch (_) {
      // Continue to next strategy
    }

    // Strategy 2: Extract from markdown code blocks
    const codeBlockMatch = text.match(/```(?:json)?\s*\n?([\s\S]*?)```/);
    if (codeBlockMatch) {
      try {
        return JSON.parse(codeBlockMatch[1].trim());
      } catch (_) {}
    }

    // Strategy 3: Find first { ... } or [ ... ] block
    const objectMatch = text.match(/(\{[\s\S]*\})/);
    const arrayMatch = text.match(/(\[[\s\S]*\])/);
    const candidate = objectMatch?.[1] || arrayMatch?.[1];
    if (candidate) {
      try {
        return JSON.parse(candidate);
      } catch (_) {
        // Strategy 4: Try fixing common issues (trailing commas, single quotes)
        try {
          const fixed = candidate
            .replace(/,(\s*[}\]])/g, '$1')          // Remove trailing commas
            .replace(/'/g, '"')                       // Replace single quotes with double
            .replace(/([{,]\s*)(\w+)(\s*:)/g, '$1"$2"$3'); // Quote unquoted keys
          return JSON.parse(fixed);
        } catch (_) {}
      }
    }

    return null;
  }
}

module.exports = FinancialAdvisorService;
