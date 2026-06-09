const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const { validateZod, schemas } = require('../middleware/validate');
const xpController = require('../controllers/xpController');

router.use(protect);
router.get('/', xpController.getProgress);
router.post('/add', validateZod(schemas.addXp), xpController.addXp);

module.exports = router;
