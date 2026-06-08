const express = require('express');
const router = express.Router();
const exportController = require('../controllers/exportController');
const { protect } = require('../middleware/auth');

router.use(protect);

router.get('/pdf', exportController.exportPDF);
router.get('/csv', exportController.exportCSV);
router.get('/excel', exportController.exportExcel);

module.exports = router;
