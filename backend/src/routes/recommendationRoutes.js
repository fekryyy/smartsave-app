const express = require('express');
const router = express.Router();
const recommendationController = require('../controllers/recommendationController');
const { protect } = require('../middleware/auth');

router.use(protect);
router.get('/', recommendationController.getRecommendations);

module.exports = router;
