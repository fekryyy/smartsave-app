const express = require('express');
const router = express.Router();
const profileController = require('../controllers/profileController');
const { protect } = require('../middleware/auth');

router.use(protect);

router.get('/stats', profileController.getStats);
router.delete('/account', profileController.deleteAccount);

module.exports = router;
