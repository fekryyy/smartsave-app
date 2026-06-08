const express = require('express');
const { body } = require('express-validator');
const router = express.Router();
const transactionController = require('../controllers/transactionController');
const { protect } = require('../middleware/auth');
const validate = require('../middleware/validate');

router.use(protect);

router.get('/', transactionController.getAll);
router.get('/recent', transactionController.getRecent);
router.get('/:id', transactionController.getById);

router.post('/', [
  body('type').isIn(['income', 'expense']).withMessage('Type must be income or expense'),
  body('amount').isFloat({ min: 0.01 }).withMessage('Amount must be greater than 0'),
  body('category').notEmpty().withMessage('Category is required'),
], validate, transactionController.create);

router.put('/:id', transactionController.update);
router.delete('/:id', transactionController.delete);

module.exports = router;
