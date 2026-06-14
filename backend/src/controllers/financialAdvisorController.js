const FinancialAdvisorService = require('../services/financialAdvisorService');
const asyncHandler = require('../utils/catchAsync');
const { AppError } = require('../middleware/errorHandler');

const FINANCIAL_DISCLAIMER = '\n\n*This is for informational purposes only and does not constitute financial advice. Consult a qualified professional before making financial decisions.*';

/**
 * Inject the financial disclaimer into a text field of an object.
 */
function addDisclaimer(obj, field = 'explanation') {
  if (!obj || typeof obj !== 'object') return obj;
  if (obj[field] && typeof obj[field] === 'string') {
    return { ...obj, [field]: obj[field] + FINANCIAL_DISCLAIMER };
  }
  return obj;
}

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
    res.json({ success: true, data: addDisclaimer(score, 'explanation') });
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
    // Disclaimer is injected by the service for chat responses
    res.json({ success: true, data: result });
  }),
};

module.exports = financialAdvisorController;
