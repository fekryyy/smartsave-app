const express = require('express');
const router = express.Router();
const analyticsController = require('../controllers/analyticsController');
const { protect } = require('../middleware/auth');

router.use(protect);

router.get('/dashboard', analyticsController.getDashboard);
router.get('/category-breakdown', analyticsController.getCategoryBreakdown);
router.get('/monthly-trend', analyticsController.getMonthlyTrend);
router.get('/income-vs-expenses', analyticsController.getIncomeVsExpenses);
router.get('/savings-growth', analyticsController.getSavingsGrowth);
router.get('/report', analyticsController.getFullReport);

module.exports = router;
