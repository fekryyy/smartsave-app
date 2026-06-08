const express = require('express');
const { body } = require('express-validator');
const router = express.Router();
const goalController = require('../controllers/goalController');
const { protect } = require('../middleware/auth');
const validate = require('../middleware/validate');

router.use(protect);

router.get('/', goalController.getAll);
router.get('/progress', goalController.getProgress);
router.get('/:id', goalController.getById);

router.post('/', [
  body('title').trim().isLength({ min: 2 }).withMessage('Title must be at least 2 characters'),
  body('targetAmount').isFloat({ min: 1 }).withMessage('Target amount must be at least 1'),
], validate, goalController.create);

router.put('/:id', goalController.update);
router.delete('/:id', goalController.delete);
router.post('/:id/contribute', [
  body('amount').isFloat({ min: 0.01 }).withMessage('Amount must be greater than 0'),
], validate, goalController.addContribution);

module.exports = router;
