const express = require('express');
const router = express.Router();
const { challengeController } = require('../controllers/challengeController');
const { protect } = require('../middleware/auth');
const { validateZod, schemas } = require('../middleware/validate');

router.use(protect);

router.get('/', challengeController.getAll);
router.post('/join', validateZod(schemas.joinChallenge), challengeController.joinChallenge);
router.put('/progress/:id', validateZod(schemas.updateChallengeProgress), challengeController.updateProgress);
router.post('/achievement', validateZod(schemas.awardAchievement), challengeController.awardAchievement);
router.post('/achievement/count', validateZod(schemas.awardByCount), challengeController.awardByCount);
router.post('/login', challengeController.recordLogin);
router.post('/spend', challengeController.recordSpend);

module.exports = router;
