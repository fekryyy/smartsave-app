const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const { validateZod, schemas } = require('../middleware/validate');
const subscriptionController = require('../controllers/subscriptionController');

router.use(protect);
router.get('/', subscriptionController.getAll);
router.get('/:id', subscriptionController.getById);
router.post('/', validateZod(schemas.createSubscription), subscriptionController.create);
router.put('/:id', validateZod(schemas.updateSubscription), subscriptionController.update);
router.delete('/:id', subscriptionController.remove);

module.exports = router;
