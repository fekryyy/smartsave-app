const FinancialAdvisorService = require('../services/financialAdvisorService');
const asyncHandler = require('../utils/catchAsync');
const { AppError } = require('../middleware/errorHandler');

const financialAdvisorController = {
  // GET /api/financial-advisor/analysis — Full financial analysis
  getFullAnalysis: asyncHandler(async (req, res) => {
    const service = new FinancialAdvisorService(req.user.id);
    const analysis = await service.getFullAnalysis();
    res.json({ success: true, data: analysis });
  }),

  // GET /api/financial-advisor/score — Financial score only
  getScore: asyncHandler(async (req, res) => {
    const service = new FinancialAdvisorService(req.user.id);
    const score = await service.getScore();
    res.json({ success: true, data: score });
  }),

  // GET /api/financial-advisor/insights — Smart insights only
  getInsights: asyncHandler(async (req, res) => {
    const service = new FinancialAdvisorService(req.user.id);
    const insights = await service.getSmartInsights();
    res.json({ success: true, data: insights });
  }),

  // GET /api/financial-advisor/action-plan — Action plans
  getActionPlan: asyncHandler(async (req, res) => {
    const service = new FinancialAdvisorService(req.user.id);
    const actionPlans = await service.getActionPlans();
    res.json({ success: true, data: actionPlans });
  }),

  // GET /api/financial-advisor/predictions — Predictive analytics
  getPredictions: asyncHandler(async (req, res) => {
    const service = new FinancialAdvisorService(req.user.id);
    const predictions = await service.getPredictions();
    res.json({ success: true, data: predictions });
  }),

  // POST /api/financial-advisor/ask — Conversational Q&A
  // Body: { question: string }
  askQuestion: asyncHandler(async (req, res) => {
    const { question } = req.body;
    if (!question || typeof question !== 'string' || question.trim().length === 0) {
      throw new AppError('Question is required', 400);
    }
    const service = new FinancialAdvisorService(req.user.id);
    const result = await service.askQuestion(question.trim());
    res.json({ success: true, data: result });
  }),
};

module.exports = financialAdvisorController;
