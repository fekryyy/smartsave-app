const FinancialAdvisorService = require('../services/financialAdvisorService');

const financialAdvisorController = {
  // GET /api/financial-advisor/analysis — Full financial analysis
  async getFullAnalysis(req, res, next) {
    try {
      const service = new FinancialAdvisorService(req.user.id);
      const analysis = await service.getFullAnalysis();
      res.json({ success: true, data: analysis });
    } catch (error) {
      next(error);
    }
  },

  // GET /api/financial-advisor/score — Financial score only
  async getScore(req, res, next) {
    try {
      const service = new FinancialAdvisorService(req.user.id);
      const score = await service.getScore();
      res.json({ success: true, data: score });
    } catch (error) {
      next(error);
    }
  },

  // GET /api/financial-advisor/insights — Smart insights only
  async getInsights(req, res, next) {
    try {
      const service = new FinancialAdvisorService(req.user.id);
      const insights = await service.getSmartInsights();
      res.json({ success: true, data: insights });
    } catch (error) {
      next(error);
    }
  },

  // GET /api/financial-advisor/action-plan — Action plans
  async getActionPlan(req, res, next) {
    try {
      const service = new FinancialAdvisorService(req.user.id);
      const actionPlans = await service.getActionPlans();
      res.json({ success: true, data: actionPlans });
    } catch (error) {
      next(error);
    }
  },

  // GET /api/financial-advisor/predictions — Predictive analytics
  async getPredictions(req, res, next) {
    try {
      const service = new FinancialAdvisorService(req.user.id);
      const predictions = await service.getPredictions();
      res.json({ success: true, data: predictions });
    } catch (error) {
      next(error);
    }
  },

  // POST /api/financial-advisor/ask — Conversational Q&A
  // Body: { question: string }
  async askQuestion(req, res, next) {
    try {
      const { question } = req.body;
      if (!question || typeof question !== 'string' || question.trim().length === 0) {
        return res.status(400).json({ success: false, message: 'Question is required' });
      }
      const service = new FinancialAdvisorService(req.user.id);
      const result = await service.askQuestion(question.trim());
      res.json({ success: true, data: result });
    } catch (error) {
      next(error);
    }
  },
};

module.exports = financialAdvisorController;
