const express = require('express');
const router = express.Router();
const exportController = require('../controllers/exportController');
const { protect } = require('../middleware/auth');
const perUserRateLimit = require('../middleware/perUserRateLimit');

router.use(protect);
router.use(perUserRateLimit({ windowMs: 60 * 1000, max: 5 })); // 5 req/min per user

router.get('/pdf', exportController.exportPDF);
router.get('/csv', exportController.exportCSV);
router.get('/excel', exportController.exportExcel);

module.exports = router;
