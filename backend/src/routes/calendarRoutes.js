const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const calendarController = require('../controllers/calendarController');

router.use(protect);
router.get('/', calendarController.getCalendarData);

module.exports = router;
