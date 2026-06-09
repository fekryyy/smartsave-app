const express = require('express');
const router = express.Router();
const recommendationController = require('../controllers/recommendationController');
const { protect } = require('../middleware/auth');
const perUserRateLimit = require('../middleware/perUserRateLimit');

router.use(protect);
router.use(perUserRateLimit({ windowMs: 60 * 1000, max: 30 })); // 30 req/min per user
router.get('/', recommendationController.getRecommendations);

module.exports = router;
