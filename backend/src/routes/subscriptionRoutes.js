const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const subscriptionController = require('../controllers/subscriptionController');

router.use(protect);
router.get('/', subscriptionController.getAll);
router.get('/:id', subscriptionController.getById);
router.post('/', subscriptionController.create);
router.put('/:id', subscriptionController.update);
router.delete('/:id', subscriptionController.remove);

module.exports = router;
