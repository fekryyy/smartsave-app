const RecurringTransaction = require('../models/RecurringTransaction');

const recurringController = {
  async getAll(req, res, next) {
    try {
      const recurring = await RecurringTransaction.find({ user: req.user.id, isActive: true }).sort('-createdAt');
      res.json({ success: true, data: recurring });
    } catch (error) {
      next(error);
    }
  },

  async create(req, res, next) {
    try {
      const { type, amount, category, description, frequency, interval, startDate, endDate, paymentMethod } = req.body;

      const recurring = await RecurringTransaction.create({
        user: req.user.id,
        type, amount, category, description, frequency,
        interval: interval || 1,
        startDate: startDate || new Date(),
        endDate: endDate || null,
        nextExecutionDate: startDate || new Date(),
        paymentMethod: paymentMethod || 'Cash',
      });

      res.status(201).json({ success: true, message: 'Recurring transaction created', data: recurring });
    } catch (error) {
      next(error);
    }
  },

  async update(req, res, next) {
    try {
      const recurring = await RecurringTransaction.findOne({ _id: req.params.id, user: req.user.id });
      if (!recurring) return res.status(404).json({ success: false, message: 'Recurring transaction not found' });

      const allowed = ['amount', 'category', 'description', 'frequency', 'interval', 'endDate', 'paymentMethod', 'isActive'];
      allowed.forEach(f => { if (req.body[f] !== undefined) recurring[f] = req.body[f]; });
      if (req.body.startDate) { recurring.startDate = req.body.startDate; recurring.nextExecutionDate = req.body.startDate; }

      await recurring.save();
      res.json({ success: true, data: recurring });
    } catch (error) {
      next(error);
    }
  },

  async remove(req, res, next) {
    try {
      const recurring = await RecurringTransaction.findOneAndUpdate(
        { _id: req.params.id, user: req.user.id },
        { isActive: false },
        { new: true },
      );
      if (!recurring) return res.status(404).json({ success: false, message: 'Recurring transaction not found' });
      res.json({ success: true, message: 'Recurring transaction cancelled' });
    } catch (error) {
      next(error);
    }
  },
};

module.exports = recurringController;
