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
      const result = await aiService.generate(systemPrompt, userPrompt, { temperature: 0.4, maxTokens: 500 });
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
      const result = await aiService.generate(systemPrompt, userPrompt, { temperature: 0.3, maxTokens: 1000 });
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
      const result = await aiService.generate(systemPrompt, userPrompt, { temperature: 0.3, maxTokens: 1000 });
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
      const result = await aiService.generate(systemPrompt, userPrompt, { temperature: 0.3, maxTokens: 1000 });
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
      const result = await aiService.generate(systemPrompt, userPrompt, { temperature: 0.3, maxTokens: 800 });
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
      const result = await aiService.generate(systemPrompt, userPrompt, { temperature: 0.3, maxTokens: 1000 });
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
      const result = await aiService.generate(systemPrompt, userPrompt, { temperature: 0.2, maxTokens: 1000 });
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
      const result = await aiService.generate(systemPrompt, userPrompt, { temperature: 0.4, maxTokens: 500 });
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
    // 1. TRAVEL questions — destination-aware with per-city cost breakdowns
    // ──────────────────────────────────────────────
    if (/\b(travel|trip|vacation|tokyo|paris|london|fly|flights?|holiday|visit|japan|abroad|bali|new.?york|dubai|rome|barcelona|thailand|vietnam|australia)\b/i.test(q)) {
      // Destination cost database (7-day trip, mid-range budget)
      const costDb = {
        tokyo:      { label: 'Tokyo',      accommodation: 140, food: 40,  transport: 20,  flights: 900,  daily: 200 },
        paris:      { label: 'Paris',      accommodation: 180, food: 55,  transport: 22,  flights: 700,  daily: 257 },
        london:     { label: 'London',     accommodation: 200, food: 50,  transport: 30,  flights: 750,  daily: 280 },
        'new york': { label: 'New York',   accommodation: 220, food: 60,  transport: 25,  flights: 600,  daily: 305 },
        bali:       { label: 'Bali',       accommodation: 60,  food: 20,  transport: 10,  flights: 800,  daily: 90 },
        dubai:      { label: 'Dubai',      accommodation: 150, food: 45,  transport: 20,  flights: 850,  daily: 215 },
        rome:       { label: 'Rome',       accommodation: 130, food: 45,  transport: 18,  flights: 750,  daily: 193 },
        barcelona:  { label: 'Barcelona',  accommodation: 120, food: 40,  transport: 15,  flights: 700,  daily: 175 },
        thailand:   { label: 'Thailand',   accommodation: 40,  food: 15,  transport: 8,   flights: 700,  daily: 63 },
        vietnam:    { label: 'Vietnam',    accommodation: 30,  food: 10,  transport: 5,   flights: 800,  daily: 45 },
        australia:  { label: 'Australia',  accommodation: 160, food: 50,  transport: 25,  flights: 1100, daily: 235 },
        japan:      { label: 'Japan',      accommodation: 100, food: 35,  transport: 18,  flights: 900,  daily: 153 },
      };

      // Detect destination from question
      const matchedDest = Object.keys(costDb).find(d => q.includes(d));
      const dest = matchedDest ? costDb[matchedDest] : null;
      const tripDays = 7;

      let avgCost, costBreakdown;
      if (dest) {
        const accomTotal = dest.accommodation * tripDays;
        const foodTotal = dest.food * tripDays;
        const transportTotal = dest.transport * tripDays;
        avgCost = accomTotal + foodTotal + transportTotal + dest.flights;
        costBreakdown = `• Accommodation (${tripDays} nights): ${$(accomTotal)} (${$(dest.accommodation)}/night)\n• Food & drinks: ${$(foodTotal)} (${$(dest.food)}/day)\n• Local transport: ${$(transportTotal)} (${$(dest.transport)}/day)\n• Flights: ${$(dest.flights)}\n• Estimated total: ${$(avgCost)}`;
      } else {
        avgCost = 2800;
        costBreakdown = `A mid-range 7-day trip typically costs between ${$(2000)} and ${$(4000)} depending on the destination. Flights range ${$(500)}–${$(1200)}, accommodation ${$(60)}–${$(220)}/night, and daily expenses ${$(50)}–${$(100)}.`;
      }

      const canAffordNow = balance >= avgCost;
      const monthsToSave = monthlyFree > 0 ? Math.ceil((avgCost - Math.max(0, balance * 0.5)) / Math.max(1, monthlyFree)) : null;

      if (!canAffordNow && monthlyFree <= 0) {
        return {
          answer: `A trip to ${dest ? dest.label : 'your destination'} sounds great. Here's a realistic cost picture:\n\n${costBreakdown}\n\nRight now, your monthly expenses are matching or exceeding your income, so funding this trip would mean dipping into your savings. That's not a dealbreaker — it just means planning ahead matters more. If you could free up about ${$(Math.round(avgCost / 12))} a month, you'd be ready within the year.\n\n${topCat ? `I notice your biggest spending area is ${topCat.category.toLowerCase()} at ${$(topCat.amount)} this month — even a small trim there could go a long way.` : ''} Want me to help find specific areas to cut?`,
          type: 'advice',
          suggestedActions: ['Where can I cut spending to save for travel?', `How much do I need to save monthly for ${dest ? dest.label : 'a trip'}?`, 'What is the cheapest time to travel?'],
        };
      }

      if (canAffordNow) {
        const cushion = balance - avgCost;
        return {
          answer: `Yes, you can afford a trip to ${dest ? dest.label : 'that destination'}! Here's what you're looking at:\n\n${costBreakdown}\n\nYou have ${$(balance)} available, so even after covering the estimated ${$(avgCost)} cost, you'd have about ${$(cushion)} left over as a cushion. That's a comfortable position.\n\n${goal ? `The one thing to think about: you're also working toward "${goal.name}" (${goal.progress}% there). If funding both feels tight, you could adjust your goal contribution for a month or two rather than pausing it entirely.` : ''} Want me to help sketch out a full trip budget?`,
          type: 'advice',
          suggestedActions: ['What would my full trip budget look like?', 'How much spending money should I bring?', dest ? `Best time of year to visit ${dest.label}?` : 'What destinations fit my budget?'],
        };
      }

      // Can afford with planning
      const monthlyTarget = Math.min(monthlyFree, Math.round(avgCost / Math.max(1, monthsToSave || 6)));
      return {
        answer: `A trip to ${dest ? dest.label : 'your destination'} is within reach with some planning. Here's the cost picture:\n\n${costBreakdown}\n\nYou're about ${$(avgCost - balance)} short of the full amount right now, but at your current savings pace you could get there in about ${monthsToSave || 'several'} months. ${goal ? `You've also got your "${goal.name}" goal going — you'd want to balance both.` : ''}\n\nA practical approach: set aside about ${$(monthlyTarget)} a month into a dedicated travel fund. That's roughly ${monthlyFree > 0 ? Math.round((monthlyTarget / monthlyFree) * 100) : 30}% of your monthly surplus, which leaves room for everything else. Would you like me to help set up a travel savings plan?`,
        type: 'advice',
        suggestedActions: ['Help me set up a travel savings plan', `What's the minimum I need to save monthly for ${dest ? dest.label : 'a trip'}?`, 'Should I adjust my other savings goals?'],
      };
    }

    // ──────────────────────────────────────────────
    // 2. SAVING / REDUCE questions — data-driven with category-level precision
    // ──────────────────────────────────────────────
    // Intentionally placed AFTER goal — "savings goals" should match GOAL, not SAVING
    // Only match when user explicitly asks about saving/reducing spending (verb form),
    // not when "savings" appears as a noun (savings rate, savings goals, etc.)
    if (/\b((?<!savin)sav(e|ing)|reduc(ing|e|tion)?|cut|spend less|cheaper|discount|optimiz)\b/i.test(q) && !/goals?\b/i.test(q)) {
      const opportunities = [];
      const savings = [];

      if (topCat) {
        const trimmed = Math.round(topCat.amount * 0.15);
        opportunities.push({ area: `${topCat.category.toLowerCase()}`, detail: `biggest at ${topCat.percentage}% of spending`, amount: trimmed });
        savings.push(trimmed);
      }

      // Check second category too
      if (secondCat && secondCat.amount > 50) {
        const trimmed2 = Math.round(secondCat.amount * 0.12);
        opportunities.push({ area: `${secondCat.category.toLowerCase()}`, detail: `second-largest category`, amount: trimmed2 });
        savings.push(trimmed2);
      }

      if (budget && budget.status === 'over_budget') {
        const overage = Math.round(budget.spent - budget.budgeted);
        opportunities.push({ area: `${budget.category.toLowerCase()}`, detail: `over budget by ${$(overage)}`, amount: overage });
        savings.push(overage);
      }
      if (subTotal > 30) {
        const subSavings = Math.round(subTotal * 0.3);
        opportunities.push({ area: 'subscriptions', detail: `${subs.length} costing ${$(subTotal)}/mo`, amount: subSavings });
        savings.push(subSavings);
      }
      if (expenseChange && expenseChange > 10) {
        opportunities.push({ area: 'recent spending increases', detail: `up ${expenseChange}% vs last month`, amount: 0 });
      }

      const total = savings.reduce((s, v) => s + v, 0);
      const bestOpp = opportunities.sort((a, b) => (b.amount || 0) - (a.amount || 0))[0];

      // Pick a response style based on what data is available
      const hasMultipleCats = cats.length >= 2;
      const isOverBudget = budget && budget.status === 'over_budget';
      const hasSubs = subTotal > 30;

      let answer = '';

      // Opening — vary based on savings rate
      if (savingsRate >= 20) {
        answer = `You're already saving ${savingsRate}% of your income, which is strong. But there's usually room to optimize without cutting into the things that matter. `;
      } else if (savingsRate >= 10) {
        answer = `Your savings rate of ${savingsRate}% is decent, and the fastest way to lift it is looking at where your money naturally flows. `;
      } else {
        answer = `The most effective way to save more is to look at where your money is already going — small percentage cuts add up fast. `;
      }

      // Body — specific category analysis
      if (topCat && topCat.percentage > 40) {
        answer += `Your ${topCat.category.toLowerCase()} spending dominates at ${topCat.percentage}% of your total. Even a 10% trim there would free up about ${$(Math.round(topCat.amount * 0.1))} a month — and that's often as simple as making one small change to how you approach it. `;
      } else if (topCat) {
        answer += `Your top area is ${topCat.category.toLowerCase()} at ${$(topCat.amount)} this month (${topCat.percentage}% of spending). Trimming it by 10–15% is usually painless and would save around ${$(Math.round(topCat.amount * 0.1))}–${$(Math.round(topCat.amount * 0.15))}. `;
      }

      if (isOverBudget) {
        answer += `You're also over on your ${budget.category.toLowerCase()} budget by ${$(budget.spent - budget.budgeted)}. Getting back to the limit is one of the fastest wins because it's a defined target — you know exactly where the line is. `;
      }

      if (hasSubs) {
        const perSub = $(Math.round(subTotal / subs.length));
        answer += `${subs.length === 1 ? 'That one subscription' : `Those ${subs.length} subscriptions`} averaging ${perSub} each adds up fast — ${$(subTotal)} a month, ${$(subTotal * 12)} a year. A 15-minute audit usually uncovers at least one you barely use. `;
      }

      if (expenseChange && expenseChange > 15 && topCat) {
        answer += `Worth noting: your expenses jumped ${expenseChange}% compared to last month. If that's a new normal, locking in a budget now prevents it from drifting higher. `;
      }

      // Use habits data if available
      if (habits.averageDailySpend && habits.averageDailySpend > 0) {
        const reducedDaily = Math.round(habits.averageDailySpend * 0.9);
        const monthlyFromDaily = Math.round((habits.averageDailySpend - reducedDaily) * 30);
        if (monthlyFromDaily > 20) {
          answer += `Even trimming your daily spend from ${$(habits.averageDailySpend)} to ${$(reducedDaily)} would save about ${$(monthlyFromDaily)} a month without any big lifestyle changes. `;
        }
      }

      if (total > 0 && bestOpp) {
        answer += `All told, you could free up roughly ${$(total)} a month — and the quickest win is your ${bestOpp.area}. `;
      }

      // Closing
      answer += goal
        ? `Put that toward your "${goal.name}" goal and you'd be looking at a much shorter timeline. Want to start with the easiest one?`
        : `Want me to walk you through the first step?`;

      return {
        answer,
        type: 'advice',
        suggestedActions: [
          bestOpp ? `How can I reduce my ${bestOpp.area}?` : 'How can I reduce my spending?',
          hasSubs ? 'Audit my subscriptions for me' : `What's a realistic savings target for me?`,
          goal ? `How does this affect my "${goal.name}" goal?` : 'What should my savings target be?',
        ].filter(Boolean),
      };
    }

    // ──────────────────────────────────────────────
    // 3. BUDGET questions — with multi-budget awareness
    // ──────────────────────────────────────────────
    if (/\b(budgets?|over.?budget|limit|alerts?|track)\b/i.test(q)) {
      const budgetList = ctx.budgetUtilization || [];
      const overBudgetCount = budgetList.filter(b => b.status === 'over_budget').length;
      const atRiskCount = budgetList.filter(b => b.status === 'at_risk').length;

      if (!budget) {
        return {
          answer: `You haven't set up any budgets yet, so there's nothing to compare your spending against. That's common, but having even one or two category limits makes a big difference — it shifts you from tracking after the fact to controlling things in real time. ${topCat ? `Looking at your data, ${topCat.category.toLowerCase()} would be a great place to start at ${$(topCat.amount)} this month. A realistic cap there would give you immediate visibility.` : ''} Want help setting one up?`,
          type: 'advice',
          suggestedActions: [
            topCat ? `Help me set a ${topCat.category.toLowerCase()} budget` : 'Help me set up a budget',
            'What categories should I budget for?',
            'How does the 50/30/20 rule work?',
          ],
        };
      }

      // Multiple budgets context
      let multiBudgetContext = '';
      if (budgetList.length > 1) {
        const overNames = budgetList.filter(b => b.status === 'over_budget').map(b => b.category);
        const atRiskNames = budgetList.filter(b => b.status === 'at_risk').map(b => b.category);
        if (overNames.length > 0) multiBudgetContext = ` You also have ${overNames.length > 1 ? 'some other budgets' : 'another budget'} that need attention: ${overNames.join(', ')}. `;
        else if (atRiskNames.length > 0) multiBudgetContext = ` A few others (${atRiskNames.join(', ')}) are getting close, so keeping an eye on them this week would help. `;
      }

      if (budget.status === 'over_budget') {
        const dailyTarget = Math.round(budget.budgeted / 30);
        const overAmount = Math.round(budget.spent - budget.budgeted);
        return {
          answer: `Your ${budget.category.toLowerCase()} budget of ${$(budget.budgeted)} has been exceeded by ${$(overAmount)} (spent ${$(budget.spent)} so far). The real question is whether the original limit was too tight or spending has been creeping up. Looking at ${habits.averageDailySpend ? `your average daily spend of ${$(habits.averageDailySpend)}` : 'the numbers'}, I'd suggest setting a daily target of ${$(dailyTarget)} for the rest of the month — it is much easier to track day by day than to realize you've blown past it at month-end. ${overAmount > 50 ? `The good news: that ${$(overAmount)} overage is recoverable in the second half of the month if you tighten up now.` : ''}${multiBudgetContext}Want to set up a spending alert for this category?`,
          type: 'advice',
          suggestedActions: [
            `Review my ${budget.category.toLowerCase()} transactions`,
            'Set a daily spending limit',
            'Adjust my budget amount',
          ],
        };
      }

      // On track
      const surplus = Math.round(budget.budgeted - budget.spent);
      return {
        answer: `Your ${budget.category.toLowerCase()} budget is on track — ${$(budget.spent)} spent of ${$(budget.budgeted)}, with ${$(surplus)} left. That's a good discipline to maintain. ${surplus > 50 ? `If you keep this up, you could redirect that ${$(surplus)} surplus toward something specific at the end of the month.` : ''}${multiBudgetContext}${goal ? ` And as a reminder, you're also working toward "${goal.name}" — consistent budgeting is what makes progress there possible.` : ''} Want to set up budgets for the other categories?`,
        type: 'advice',
        suggestedActions: ['Set up another budget', 'How do I track daily spending?', 'Should I adjust my budget amounts?'],
      };
    }

    // ──────────────────────────────────────────────
    // 4. GOAL questions — multi-goal aware with timeline precision
    // ──────────────────────────────────────────────
    if (/\b(goals?|target|save for|progress|milestone)\b/i.test(q)) {
      const allGoals = ctx.savingsGoals || [];

      if (!goal) {
        // Suggest based on actual financial profile
        const suggestedAmount = Math.round(Math.max(50, monthlyFree * 0.2));
        const eFund = Math.round(expenses * 3);
        const suggestions = [];
        if (monthlyFree > 100) suggestions.push(`an emergency fund of ${$(eFund)}`);
        suggestions.push('a trip', 'a big purchase');
        return {
          answer: `You don't have any savings goals set up yet, which means your savings don't have a specific purpose pulling them forward — and goals make a real difference. Based on your finances, even ${$(suggestedAmount)} a month toward ${suggestions[0]} would build momentum fast. An emergency fund of ${$(eFund)} (3 months of expenses) is always a solid first goal if you're not sure where to start. Want to create one?`,
          type: 'advice',
          suggestedActions: ['Help me set up an emergency fund goal', 'What should I save for first?', 'How much should I save each month?'],
        };
      }

      // Multiple goals context
      let multiGoalContext = '';
      if (allGoals.length > 1) {
        const otherGoals = allGoals.filter(g => (g.name || g.title) !== (goal.name || goal.title));
        if (otherGoals.length > 0) {
          const nextGoal = otherGoals[0];
          multiGoalContext = ` You also have "${nextGoal.name}" at ${nextGoal.progress || 0}% progress. ${nextGoal.progress > 50 ? 'That one is well on its way too.' : 'Something to keep in the picture as you allocate your savings.'}`;
        }
      }

      const progress = goal.progress || 0;
      const remaining = goal.target - (goal.current || 0);
      const monthsNeeded = monthlyFree > 0 ? Math.ceil(remaining / monthlyFree) : null;
      const hasEnoughNow = balance >= remaining;

      let answer = '';
      if (progress >= 75) {
        answer = `You're ${progress}% of the way to your "${goal.name}" goal — the finish line is in sight. `;
      } else if (progress >= 50) {
        answer = `You're more than halfway to your "${goal.name}" goal at ${progress}%. That momentum is worth protecting. `;
      } else if (progress >= 25) {
        answer = `You're ${progress}% toward your "${goal.name}" goal. Solid start — the key now is consistency. `;
      } else {
        answer = `You're ${progress}% of the way to your "${goal.name}" goal. Early progress is the hardest part, and you're past it. `;
      }

      if (hasEnoughNow) {
        answer += `And you actually have enough in your account right now to complete it — ${$(remaining)} remaining. The decision is whether to fund it in one go or keep the cash buffer and contribute gradually. ${monthlyFree > 0 ? `If you spread it out, at ${$(monthlyFree)} a month of free cash flow, you'd be done in ${monthsNeeded} months without touching your cushion.` : ''} `;
      } else if (monthsNeeded) {
        if (goal.monthlyContribution) {
          answer += `At your current ${$(goal.monthlyContribution)}/month contribution, you're looking at roughly ${monthsNeeded} months to get there. That auto-contribution is doing the heavy lifting for you — consistency is everything. `;
        } else {
          const suggestedMonthly = Math.round(remaining / Math.max(1, monthsNeeded));
          answer += `At your current savings rate, you're roughly ${monthsNeeded} months out. Setting up an automatic ${$(suggestedMonthly)}/month contribution would turn that estimate into a plan. `;
        }
      } else {
        answer += `Your free cash flow is tight right now, so the fastest path here is to look at trimming expenses rather than increasing savings. ${topCat ? `Starting with ${topCat.category.toLowerCase()} (your biggest category) is usually the most effective approach.` : ''} `;
      }

      answer += multiGoalContext;
      answer += `\n\nWould you like me to calculate the optimal monthly amount to hit a specific target date?`;

      return { answer, type: 'advice', suggestedActions: ['Calculate what I need to save monthly', 'Should I fund it from my balance now?', 'What other goals should I set?'] };
    }

    // ──────────────────────────────────────────────
    // 5. SPENDING / WHERE / CATEGORY questions — with trend & subcategory depth
    // ──────────────────────────────────────────────
    if (/\b(spend(ing|s)?|expens|where|categor|going|goes|breakdown|analys)\b/i.test(q)) {
      let answer = '';
      const growingCats = (ctx.categoryChanges || []).filter(c => c.change > 10).slice(0, 2);

      if (!topCat && cats.length === 0) {
        answer = `You don't have any categorized spending yet, so I can't give you a breakdown. Once you add a few transactions with categories, I'll be able to show you exactly where your money is going. `;
      } else if (topCat && topCat.percentage > 50) {
        answer = `Your spending is heavily concentrated in ${topCat.category.toLowerCase()} at ${topCat.percentage}% of your total (${$(topCat.amount)} this month). That means small changes there have an outsized impact. Even a 10% reduction would free up about ${$(Math.round(topCat.amount * 0.1))}. `;
      } else if (topCat) {
        answer = `Your largest category is ${topCat.category.toLowerCase()} at ${$(topCat.amount)} (${topCat.percentage}% of spending), followed by ${secondCat ? `${secondCat.category.toLowerCase()} at ${$(secondCat.amount)}` : 'other categories'}. `;
        if (topCat.percentage > 30) {
          answer += `At over 30% of your total, ${topCat.category.toLowerCase()} is worth a closer look. `;
        } else {
          answer += `The distribution is fairly balanced, which is generally healthy. `;
        }
      }

      // Growing categories — most actionable signal
      if (growingCats.length > 0) {
        answer += `I also noticed ${growingCats.map(c => `${c.category} is up ${c.change}%`).join(' and ')} compared to last month. ${growingCats.some(c => c.change > 30) ? 'That is a significant jump — worth reviewing what changed.' : 'A moderate increase — something to watch.'} `;
      }

      if (expenseChange) {
        const direction = expenseChange > 0 ? 'up' : 'down';
        answer += `Overall, your spending is ${direction} ${Math.abs(expenseChange)}% versus last month. ${expenseChange > 10 ? `If that trend continues, it could start cutting into your ${savingsRate > 0 ? `${savingsRate}% savings rate` : 'budget'}.` : expenseChange < -5 ? 'That is a positive shift.' : 'Relatively stable month over month.'} `;
      }

      if (habits.averageDailySpend) {
        const projected = habits.projectedMonthlyExpenses || expenses;
        answer += `Right now you're averaging ${$(habits.averageDailySpend)}/day in spending. At that pace, you'd hit about ${$(projected)} by month end — ${projected > monthlyIncome ? `which would exceed your income by ${$(projected - monthlyIncome)}.` : `${monthlyIncome - projected > 0 ? `leaving you about ${$(monthlyIncome - projected)} to save.` : ''}`} `;
      }

      // Category breakdown summary if multiple categories
      if (cats.length >= 3) {
        const top3 = cats.slice(0, 3).map(c => `${c.category} (${c.percentage}%)`).join(', ');
        answer += `\n\nQuick snapshot of your top categories: ${top3}. `;
      }

      answer += `\n\nWant to look at any specific category more closely?`;

      return {
        answer, type: 'analysis',
        suggestedActions: [
          topCat ? `Analyze my ${topCat.category.toLowerCase()} spending in detail` : 'Analyze my biggest spending category',
          growingCats.length > 0 ? `Why is ${growingCats[0].category} spending increasing?` : 'How does this compare to last month?',
          'Show me my spending trends',
        ],
      };
    }

    // ──────────────────────────────────────────────
    // 6. SCORE / HEALTH questions — with per-component breakdown
    // ──────────────────────────────────────────────
    if (/\b(health|healthy|score|how am i|how are|rating|doing|financially)\b/i.test(q)) {
      const score = this._calculateScore(ctx);
      const details = score.details || [];
      const strongest = details.reduce((best, d) => d.score > best.score ? d : best, details[0]);
      const weakest = details.reduce((min, d) => d.score < min.score ? d : min, details[0]);

      let answer = '';

      if (score.score >= 80) {
        answer = `Your financial health is strong — score of ${score.score}/100 (${score.level}). Your savings habits and spending discipline are working well together. `;
      } else if (score.score >= 60) {
        answer = `You're doing okay with a score of ${score.score}/100 (${score.level}) — some areas are solid, others have room to grow. `;
      } else {
        answer = `Your score is ${score.score}/100 (${score.level}), which means there are clear areas to work on. The good news is the path forward is pretty clear. `;
      }

      // Strongest area
      if (strongest && strongest.score >= strongest.max * 0.8) {
        answer += `Your strongest area is "${strongest.component}" (${strongest.score}/${strongest.max}). `;
      }

      // Weakest area — specific guidance
      if (weakest && weakest.score < weakest.max) {
        answer += `The biggest improvement opportunity is "${weakest.component}" where you scored ${weakest.score} out of ${weakest.max}. `;
        if (weakest.component === 'Budget Adherence') {
          if (budget && budget.status === 'over_budget') {
            answer += `Getting your ${budget.category.toLowerCase()} spending back under the ${$(budget.budgeted)} limit would move this score the most. `;
          } else {
            answer += `Setting up and sticking to category budgets is the most effective way to raise this. `;
          }
        } else if (weakest.component === 'Savings Consistency') {
          answer += `Even small increases to your savings rate make a big difference here. Aim to add 2–3% — about ${$(Math.round(monthlyIncome * 0.03))} a month. `;
        } else if (weakest.component === 'Spending Habits') {
          answer += `Your expense-to-income ratio is the key driver — reducing spending or increasing income would directly improve this. `;
        } else if (weakest.component === 'Income Stability') {
          answer += `Diversifying your income sources would strengthen this over time. `;
        } else if (weakest.component === 'Debt & Subscriptions') {
          answer += `Reviewing your subscriptions and reducing where possible is the quickest fix here. `;
        }
      }

      if (savingsRate >= 20) {
        answer += `\n\nYour savings rate of ${savingsRate}% is genuinely impressive — that is a strong foundation for everything else.`;
      } else if (savingsRate >= 10) {
        answer += `\n\nYour savings rate of ${savingsRate}% is decent — pushing it past 20% would move you into excellent territory.`;
      } else if (savingsRate > 0) {
        answer += `\n\nYour savings rate is ${savingsRate}%. Even getting to 10% would be a meaningful improvement.`;
      }

      answer += `\n\nThe single most effective habit: check your budget weekly instead of monthly. Catching overruns early prevents them from compounding. Want to dive into any specific area?`;

      return {
        answer, type: 'analysis',
        suggestedActions: [
          weakest ? `How can I improve my ${weakest.component.toLowerCase()}?` : 'How can I improve my financial health?',
          'What is a good target score?',
          'Compare my finances to benchmarks',
        ],
      };
    }

    // ──────────────────────────────────────────────
    // 7. SUBSCRIPTIONS — with per-item detail
    // ──────────────────────────────────────────────
    if (/\b(subscriptions?|renew|monthly fee|membership|recurring)\b/i.test(q)) {
      if (subs.length === 0) {
        return {
          answer: `You don't have any active subscriptions, which is refreshing — a lot of people end up with several they barely use. Keeping this clean avoids the slow drip of small charges that can add up to hundreds a year without you noticing.`,
          type: 'analysis',
          suggestedActions: ['What is my total monthly spending?', 'How can I save more?', 'Show my financial health'],
        };
      }

      // Sort by cost descending and list top ones
      const sortedSubs = [...subs].sort((a, b) => (b.monthlyAmount || 0) - (a.monthlyAmount || 0));
      const expensiveSub = sortedSubs[0];
      const annualTotal = subTotal * 12;

      let answer = `You have ${subs.length === 1 ? '1 active subscription' : `${subs.length} active subscriptions`} costing ${$(subTotal)}/month — that's ${$(annualTotal)} a year. `;

      if (subs.length <= 3) {
        const names = subs.map(s => `${s.name} (${$(s.monthlyAmount || 0)}/mo)`).join(', ');
        answer += `Here they are: ${names}. `;
      } else {
        const topNames = sortedSubs.slice(0, 3).map(s => `${s.name} (${$(s.monthlyAmount || 0)}/mo)`).join(', ');
        answer += `Your most expensive ones: ${topNames}. ${subs.length > 3 ? `The remaining ${subs.length - 3} add up to about ${$(sortedSubs.slice(3).reduce((s, x) => s + (x.monthlyAmount || 0), 0))}/month.` : ''} `;
      }

      if (expensiveSub && expensiveSub.monthlyAmount > 20) {
        answer += `Your priciest is ${expensiveSub.name} at ${$(expensiveSub.monthlyAmount)}/month — that's ${Math.round((expensiveSub.monthlyAmount / Math.max(1, subTotal)) * 100)}% of your subscription spend right there. `;
      }

      answer += `The real question isn't cost — it's value. A quick scan of your last 60 days of bank or credit card statements will show which ones you actually use. Anything untouched for two months is a candidate. ${goal ? `Just cutting half the cost (${$(Math.round(subTotal * 0.5))}/mo) to your "${goal.name}" goal would noticeably accelerate it.` : `Even cutting ${$(Math.round(subTotal * 0.3))}/month would add up to ${$(Math.round(subTotal * 0.3 * 12))} a year.`}`;

      return {
        answer, type: 'analysis',
        suggestedActions: [
          'Which subscriptions should I cancel?',
          'How much could I save by cutting unused ones?',
          'Set a subscription spending limit',
        ],
      };
    }

    // ──────────────────────────────────────────────
    // 8. INCOME questions — with diversification & ratio analysis
    // ──────────────────────────────────────────────
    if (/\b(income|salary|earn|pay|revenue|making|make)\b/i.test(q)) {
      const incBreakdown = ctx.incomeBreakdown || [];
      const expenseRatio = income > 0 ? Math.round((expenses / income) * 100) : 0;
      let answer = `You're earning ${$(income)}/month, spending ${$(expenses)} (${expenseRatio}% of income), and keeping about ${$(monthlyFree)} — a savings rate of ${savingsRate}%. `;

      if (expenseRatio <= 70) {
        answer += `That expense ratio gives you decent breathing room. `;
      } else if (expenseRatio <= 85) {
        answer += `Your expense ratio of ${expenseRatio}% is okay, but it means less room for error. `;
      } else {
        answer += `At ${expenseRatio}%, most of your income is spoken for — small changes to either earnings or spending would have an outsized impact. `;
      }

      if (incBreakdown.length <= 1) {
        answer += `I also notice your income comes from a single source. That's common, but it does mean any disruption would be felt immediately. Even a side stream of ${$(Math.round(income * 0.1))}–${$(Math.round(income * 0.15))}/month would add both stability and momentum. ${habits.averageDailySpend ? `For context, that's about ${Math.round(Math.round(income * 0.1) / habits.averageDailySpend)} days of your current daily spending.` : ''} `;
      } else {
        const sources = incBreakdown.slice(0, 3).map(i => `${i.category} (${i.percentage}%)`).join(', ');
        answer += `You have ${incBreakdown.length} income sources: ${sources}. That diversification is a real strength. `;
      }

      // Trends
      const trends = ctx.monthlyTrends || [];
      if (trends.length >= 2) {
        const recent = trends[trends.length - 1];
        const prev = trends[trends.length - 2];
        if (recent.income > prev.income) {
          answer += `Your income has been growing — ${$(prev.income)} to ${$(recent.income)} over the last couple of months. That is a positive trend. `;
        } else if (recent.income < prev.income) {
          answer += `Your income has dipped slightly recently (${$(prev.income)} → ${$(recent.income)}). Worth keeping an eye on. `;
        }
      }

      answer += `\n\nWant to explore ways to grow your income further?`;

      return {
        answer, type: 'analysis',
        suggestedActions: [
          'How can I increase my income?',
          `What is my expense-to-income ratio?`,
          'How does my income compare to averages?',
        ],
      };
    }

    // ──────────────────────────────────────────────
    // DEBT questions
    // ──────────────────────────────────────────────
    if (/\b(debt|loan|owe|credit|mortgage|borrow)\b/i.test(q)) {
      const subRatio = income > 0 ? Math.round((subTotal / income) * 100) : 0;
      let answer = `I don't see any debt recorded in your account, which is a great sign. `;

      if (subTotal > 0) {
        answer += `You do have ${subs.length} subscription${subs.length > 1 ? 's' : ''} totaling ${$(subTotal)}/month (${subRatio}% of your income) — which isn't debt, but it's a fixed commitment that functions similarly. `;
      }

      answer += `If you have debt elsewhere that isn't tracked here, adding it would help me give you more tailored advice. ${goal ? `In the meantime, your "${goal.name}" goal shows you have the discipline to manage payments well — the same approach works for paying down balances.` : 'The same habits that build savings work well for paying down balances too.'}`;

      return {
        answer, type: 'analysis',
        suggestedActions: ['How should I prioritize paying off debt?', 'What is a healthy debt-to-income ratio?', 'Should I invest or pay off debt?'],
      };
    }

    // ──────────────────────────────────────────────
    // INVESTMENT questions — with emergency fund & amount calculation
    // ──────────────────────────────────────────────
    if (/\b(invest(?:ing|ment|s|ed|or)?|stocks?|bonds?|portfolio|retirement|compound)\b/i.test(q)) {
      let answer = '';

      const efund = Math.round(expenses * 3);
      const hasEfund = balance >= efund;

      if (hasEfund && monthlyFree > 0) {
        const suggestedMonthly = Math.round(monthlyFree * 0.5);
        answer = `You're in a good position to start investing. You have a solid emergency fund (${$(balance)} vs. ${$(efund)} target) and about ${$(monthlyFree)} of free cash flow each month. `;
        answer += `A common approach is to invest about half of your surplus — around ${$(suggestedMonthly)}/month — while keeping the rest as a buffer. `;
      } else if (monthlyFree > 0) {
        answer = `Thinking about investing is a smart next step. With your current savings rate of ${savingsRate}% and about ${$(monthlyFree)} left each month, you have some room. `;
        answer += `Before committing to the market though, I'd aim to build an emergency fund of ${$(efund)} (3 months of expenses) first. You're at ${$(balance)} now — about ${$(efund - balance)} short. `;
      } else {
        answer = `Investing is a great goal, but right now your expenses are absorbing most of your income. `;
        answer += `The first step would be to free up some room in your budget. ${topCat ? `Starting with ${topCat.category.toLowerCase()} (your biggest category at ${$(topCat.amount)}) is usually the most effective.` : ''} `;
        answer += `Once you have 3 months of expenses saved (about ${$(efund)}), investing becomes a realistic next step. `;
      }

      // Compound interest example
      if (monthlyFree > 50) {
        const monthly = Math.min(200, Math.round(monthlyFree * 0.5));
        const annual = monthly * 12;
        const tenYears = Math.round(annual * (Math.pow(1.07, 10) - 1) / 0.07);
        answer += `\n\nTo put it in perspective: investing ${$(monthly)}/month at a conservative 7% annual return would grow to roughly ${$(tenYears)} over 10 years. That is the power of compounding — small amounts consistently add up to something significant.`;
      }

      answer += `\n\nWant to talk through a specific investment approach?`;

      return {
        answer, type: 'advice',
        suggestedActions: [
          'How much should I invest each month?',
          `What is a good emergency fund target?`,
          'Explain compound interest with my numbers',
        ],
      };
    }

    // ──────────────────────────────────────────────
    // DEFAULT: Conversational greeting / unknown — data-aware
    // ──────────────────────────────────────────────
    let answer = '';

    if (/hello|hi |hey|good (morning|afternoon|evening)/i.test(q)) {
      answer = `Hi there! I'm your SmartSave advisor. `;

      // Personalize the greeting with a data point
      if (savingsRate >= 20) {
        answer += `I can see you're saving ${savingsRate}% of your income — that's impressive. `;
      } else if (goal && goal.progress > 50) {
        answer += `I see you're over halfway to your "${goal.name}" goal — great progress! `;
      } else if (topCat) {
        answer += `Looking at your data, the biggest thing I notice is your ${topCat.category.toLowerCase()} spending. `;
      } else {
        answer += `I can help with your spending, savings goals, budget, or any financial questions. `;
      }

      answer += `What's on your mind?`;
    } else {
      // For unrecognized questions — be helpful and concise
      const score = this._calculateScore(ctx);

      answer = `That's an interesting question. `;

      // Lead with the most relevant data point
      if (goal && goal.progress < 100) {
        answer += `The most relevant thing I can see right now is your "${goal.name}" goal — you're ${goal.progress}% there with ${$(goal.target - (goal.current || 0))} to go. `;
      } else if (topCat && topCat.percentage > 35) {
        answer += `The standout in your finances is ${topCat.category.toLowerCase()} at ${topCat.percentage}% of your spending (${$(topCat.amount)} this month). `;
      } else if (expenseChange && Math.abs(expenseChange) > 15) {
        const direction = expenseChange > 0 ? 'up' : 'down';
        answer += `I noticed your spending is ${direction} ${Math.abs(expenseChange)}% compared to last month — ${expenseChange > 0 ? 'worth keeping an eye on.' : 'a positive trend.'} `;
      } else {
        answer += `Your financial score is ${score.score}/100 (${score.level}), with a savings rate of ${savingsRate}% and monthly surplus of ${$(monthlyFree)}. `;
      }

      answer += `\n\nHere's what I can help with:\n` +
        `• Saving more money and cutting expenses\n` +
        `• Understanding where your money goes\n` +
        `• Planning for purchases or trips\n` +
        `• Checking your financial health\n` +
        `• Tracking savings goals and budgets\n\n` +
        `What would be most useful to you?`;
    }

    return {
      answer, type: 'info',
      suggestedActions: [
        'How can I save more money?',
        'How healthy are my finances?',
        'What is my biggest spending category?',
        'Can I afford a trip?',
        'How are my savings goals doing?',
      ],
    };
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
