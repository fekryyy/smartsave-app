const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const xpController = require('../controllers/xpController');

router.use(protect);
router.get('/', xpController.getProgress);
router.post('/add', xpController.addXp);

module.exports = router;
