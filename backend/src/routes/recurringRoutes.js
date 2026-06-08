const express = require('express');
const { body } = require('express-validator');
const router = express.Router();
const recurringController = require('../controllers/recurringController');
const { protect } = require('../middleware/auth');
const validate = require('../middleware/validate');

router.use(protect);

router.get('/', recurringController.getAll);
router.post('/', [
  body('type').isIn(['income', 'expense']),
  body('amount').isFloat({ min: 0.01 }),
  body('category').notEmpty(),
  body('frequency').isIn(['daily', 'weekly', 'monthly', 'yearly']),
], validate, recurringController.create);

router.put('/:id', recurringController.update);
router.delete('/:id', recurringController.remove);

module.exports = router;
