const express = require('express');
const multer = require('multer');
const router = express.Router();
const ocrController = require('../controllers/ocrController');
const { protect } = require('../middleware/auth');

router.use(protect);

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, 'uploads/'),
  filename: (req, file, cb) => cb(null, `receipt-${Date.now()}-${file.originalname}`),
});

const upload = multer({
  storage,
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/')) {
      cb(null, true);
    } else {
      cb(new Error('Only image files are allowed'), false);
    }
  },
});

router.post('/scan', upload.single('receipt'), ocrController.scanReceipt);

module.exports = router;
