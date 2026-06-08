const express = require('express');
const router = express.Router();
const { challengeController } = require('../controllers/challengeController');
const { protect } = require('../middleware/auth');

router.use(protect);

router.get('/', challengeController.getAll);
router.post('/join', challengeController.joinChallenge);
router.put('/progress/:id', challengeController.updateProgress);
router.post('/achievement', challengeController.awardAchievement);
router.post('/achievement/count', challengeController.awardByCount);
router.post('/login', challengeController.recordLogin);
router.post('/spend', challengeController.recordSpend);

module.exports = router;
