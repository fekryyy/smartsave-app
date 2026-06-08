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
    // Enhance score explanation with AI
    const explanation = await this._aiScoreExplanation(ctx, score);
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
      const parsed = JSON.parse(result);
      return parsed.explanation || this._defaultExplanation(score, ctx);
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
      const result = await aiService.generate(systemPrompt, userPrompt, { temperature: 0.3, maxTokens: 3000 });
      const parsed = JSON.parse(result);
      return Array.isArray(parsed) ? parsed.slice(0, 15) : [];
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
      const parsed = JSON.parse(result);
      return parsed;
    } catch (e) {
      logger.error('AI health parsing failed, using fallback:', e.message);
      const fallback = aiService._getFallbackResponse('FINANCIAL_HEALTH', userPrompt);
      try { return JSON.parse(fallback); } catch { return { status: 'needs_attention', strengths: [], issues: ['Unable to analyze'], summary: 'Health analysis unavailable.' }; }
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
      const result = await aiService.generate(systemPrompt, userPrompt, { temperature: 0.3, maxTokens: 3000 });
      const parsed = JSON.parse(result);
      return Array.isArray(parsed) ? parsed.slice(0, 8) : [];
    } catch (e) {
      logger.error('AI advice parsing failed, using fallback:', e.message);
      const fallback = aiService._getFallbackResponse('ADVICE', userPrompt);
      try { return JSON.parse(fallback); } catch { return []; }
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
      const result = await aiService.generate(systemPrompt, userPrompt, { temperature: 0.3, maxTokens: 2000 });
      const parsed = JSON.parse(result);
      return Array.isArray(parsed) ? parsed.slice(0, 6) : [];
    } catch (e) {
      logger.error('AI opportunities parsing failed, using fallback:', e.message);
      const fallback = aiService._getFallbackResponse('SAVINGS_OPPORTUNITIES', userPrompt);
      try { return JSON.parse(fallback); } catch { return []; }
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
      const result = await aiService.generate(systemPrompt, userPrompt, { temperature: 0.3, maxTokens: 3000 });
      const parsed = JSON.parse(result);
      return Array.isArray(parsed) ? parsed.slice(0, 3) : [];
    } catch (e) {
      logger.error('AI action plans parsing failed, using fallback:', e.message);
      const fallback = aiService._getFallbackResponse('ACTION_PLANS', userPrompt);
      try { return JSON.parse(fallback); } catch { return []; }
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
      const result = await aiService.generate(systemPrompt, userPrompt, { temperature: 0.2, maxTokens: 3000 });
      const parsed = JSON.parse(result);
      return Array.isArray(parsed) ? parsed.slice(0, 6) : [];
    } catch (e) {
      logger.error('AI predictions parsing failed, using fallback:', e.message);
      const fallback = aiService._getFallbackResponse('PREDICTIONS', userPrompt);
      try { return JSON.parse(fallback); } catch { return []; }
    }
  }

  // ══════════════════════════════════════════════
  // AI-POWERED CONVERSATION WITH MEMORY
  // ══════════════════════════════════════════════

  async _answerWithAI(question, ctx) {
    // Load recent conversation history (last 10 exchanges)
    const recentMemory = await AdvisorMemory.find({ user: this.userId })
      .sort({ createdAt: -1 })
      .limit(10)
      .lean();

    const conversationHistory = recentMemory.reverse().map(m =>
      `${m.role === 'user' ? 'User' : 'Advisor'}: ${m.content}`
    ).join('\n');

    const systemPrompt = `You are a personal financial advisor AI called "SmartSave Advisor". You have access to the user's complete financial data.

RULES:
1. NEVER give generic advice. Every recommendation must be based on the user's actual financial data provided in the context.
2. Always include specific numbers (dollar amounts, percentages, categories) from their data.
3. Be conversational, supportive, and educational.
4. When the user asks about their finances, reference their specific data.
5. If asked about something not in the data, be honest and suggest what data could help.
6. Keep responses concise but informative (2-5 paragraphs typically).
7. You can discuss: saving money, reducing expenses, budget management, goal planning, investment basics, debt management, financial health, spending analysis.

Return a JSON object:
{
  "answer": "Your conversational response (plain text, no markdown, use emojis sparingly)",
  "type": "advice" | "analysis" | "info" | "help" | "error",
  "score": { "score": number, "level": "Excellent"|"Good"|"Average"|"Needs Improvement", "maxScore": 100 } | null,
  "suggestedActions": ["optional", "array", "of", "follow-up", "questions"] | null
}`;

    const userPrompt = `USER'S FINANCIAL DATA:
${JSON.stringify(ctx, null, 2)}

CONVERSATION HISTORY (most recent first):
${conversationHistory || 'No previous conversation.'}

USER'S QUESTION: ${question}

Remember: Base your answer on the actual financial data above. Include specific numbers. Return ONLY valid JSON.`;

    try {
      const result = await aiService.generate(systemPrompt, userPrompt, { temperature: 0.4, maxTokens: 2000 });
      const parsed = JSON.parse(result);

      // Save to conversation memory
      await this._saveMemory('user', question, 'chat');
      await this._saveMemory('assistant', parsed.answer || '', parsed.type || 'chat');

      return parsed;
    } catch (e) {
      logger.error('AI chat parsing failed, using fallback:', e.message);

      // Try to get fallback response
      try {
        const fallback = aiService._getFallbackResponse('', userPrompt);
        const parsed = JSON.parse(fallback);

        await this._saveMemory('user', question, 'chat');
        await this._saveMemory('assistant', parsed.answer || '', parsed.type || 'chat');

        return parsed;
      } catch (fbError) {
        // Ultimate fallback
        const response = {
          answer: `Here's a snapshot of your finances:\n\n• Balance: $${ctx.balance}\n• Income: $${ctx.monthlyIncome}/month\n• Expenses: $${ctx.monthlyExpenses}/month\n• Savings rate: ${ctx.savingsRate}%\n• Top category: ${ctx.categoryBreakdown[0]?.category || 'N/A'} ($${ctx.categoryBreakdown[0]?.amount || 0})\n\nTry asking "how can I save more" or "how healthy are my finances?"`,
          type: 'info',
          suggestedActions: ['How can I save more money?', 'How healthy are my finances?', 'What is my biggest spending?'],
        };

        await this._saveMemory('user', question, 'chat');
        await this._saveMemory('assistant', response.answer, 'info');

        return response;
      }
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
      logger.error('Failed to save advisor memory:', e.message);
    }
  }
}

module.exports = FinancialAdvisorService;
