const express = require('express');
const router = express.Router();
const financialAdvisorController = require('../controllers/financialAdvisorController');
const aiConsentController = require('../controllers/aiConsentController');
const { protect } = require('../middleware/auth');
const { validateZod, schemas } = require('../middleware/validate');
const perUserRateLimit = require('../middleware/perUserRateLimit');

router.use(protect);
router.use(perUserRateLimit({ windowMs: 60 * 1000, max: 10 })); // 10 req/min per user

// ── Consent management ──
router.get('/consent', aiConsentController.getConsentStatus);
router.post('/consent/accept', aiConsentController.acceptConsent);
router.post('/consent/revoke', aiConsentController.revokeConsent);
router.get('/consent/log', aiConsentController.getConsentLog);

// ── AI-powered endpoints ──
router.get('/analysis', financialAdvisorController.getFullAnalysis);
router.get('/score', financialAdvisorController.getScore);
router.get('/insights', financialAdvisorController.getInsights);
router.get('/action-plan', financialAdvisorController.getActionPlan);
router.get('/predictions', financialAdvisorController.getPredictions);
router.post('/ask', validateZod(schemas.askQuestion), financialAdvisorController.askQuestion);

module.exports = router;
