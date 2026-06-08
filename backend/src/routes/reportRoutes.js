const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const reportController = require('../controllers/reportController');

router.use(protect);
router.get('/monthly', reportController.getMonthlyReport);
router.get('/comparison', reportController.getComparison);
router.get('/trends', reportController.getTrends);
router.get('/heatmap', reportController.getHeatmap);

module.exports = router;
