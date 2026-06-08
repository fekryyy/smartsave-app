const express = require('express');
const router = express.Router();
const financialAdvisorController = require('../controllers/financialAdvisorController');
const { protect } = require('../middleware/auth');

router.use(protect);

router.get('/analysis', financialAdvisorController.getFullAnalysis);
router.get('/score', financialAdvisorController.getScore);
router.get('/insights', financialAdvisorController.getInsights);
router.get('/action-plan', financialAdvisorController.getActionPlan);
router.get('/predictions', financialAdvisorController.getPredictions);
router.post('/ask', financialAdvisorController.askQuestion);

module.exports = router;
