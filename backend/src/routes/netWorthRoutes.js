const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const netWorthController = require('../controllers/netWorthController');

router.use(protect);
router.get('/', netWorthController.getNetWorth);
router.post('/entry', netWorthController.addEntry);
router.get('/history', netWorthController.getHistory);

module.exports = router;
