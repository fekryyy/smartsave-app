const express = require('express');
const { body } = require('express-validator');
const router = express.Router();
const budgetController = require('../controllers/budgetController');
const { protect } = require('../middleware/auth');
const validate = require('../middleware/validate');

router.use(protect);

router.get('/', budgetController.getAll);
router.get('/overview', budgetController.getOverview);
router.get('/:id', budgetController.getById);

router.post('/', [
  body('category').notEmpty().withMessage('Category is required'),
  body('amount').isFloat({ min: 1 }).withMessage('Budget must be at least 1'),
], validate, budgetController.create);

router.put('/:id', budgetController.update);
router.delete('/:id', budgetController.delete);

module.exports = router;
