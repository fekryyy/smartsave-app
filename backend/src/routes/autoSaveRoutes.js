const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const autoSaveController = require('../controllers/autoSaveController');

router.use(protect);
router.get('/', autoSaveController.getAll);
router.get('/:id', autoSaveController.getById);
router.post('/', autoSaveController.create);
router.put('/:id', autoSaveController.update);
router.delete('/:id', autoSaveController.remove);
router.post('/:id/trigger', autoSaveController.triggerContribution);

module.exports = router;
