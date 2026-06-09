const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const { validateZod, schemas } = require('../middleware/validate');
const netWorthController = require('../controllers/netWorthController');

router.use(protect);
router.get('/', netWorthController.getNetWorth);
router.post('/entry', validateZod(schemas.addNetWorthEntry), netWorthController.addEntry);
router.get('/history', netWorthController.getHistory);

module.exports = router;
