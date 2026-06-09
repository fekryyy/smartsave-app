const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const { validateZod, schemas } = require('../middleware/validate');
const autoSaveController = require('../controllers/autoSaveController');

router.use(protect);
router.get('/', autoSaveController.getAll);
router.get('/:id', autoSaveController.getById);
router.post('/', validateZod(schemas.createAutoSave), autoSaveController.create);
router.put('/:id', validateZod(schemas.updateAutoSave), autoSaveController.update);
router.delete('/:id', autoSaveController.remove);
router.post('/:id/trigger', autoSaveController.triggerContribution);

module.exports = router;
