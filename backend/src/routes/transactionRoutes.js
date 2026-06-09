const express = require('express');
const router = express.Router();
const transactionController = require('../controllers/transactionController');
const { protect } = require('../middleware/auth');
const { validateZod, schemas } = require('../middleware/validate');
const { idempotency } = require('../middleware/idempotency');

router.use(protect);

router.get('/', transactionController.getAll);
router.get('/recent', transactionController.getRecent);
router.get('/:id', transactionController.getById);

// POST with idempotency support (Idempotency-Key header) + Zod validation
router.post('/', idempotency(), validateZod(schemas.createTransaction), transactionController.create);

router.put('/:id', validateZod(schemas.updateTransaction), transactionController.update);
router.delete('/:id', transactionController.delete);

module.exports = router;
