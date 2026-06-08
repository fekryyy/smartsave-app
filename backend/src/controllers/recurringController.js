const RecurringTransaction = require('../models/RecurringTransaction');
const asyncHandler = require('../utils/catchAsync');
const { AppError } = require('../middleware/errorHandler');

const recurringController = {
  getAll: asyncHandler(async (req, res) => {
    const { page = 1, limit = 50 } = req.query;
    const query = { user: req.user.id, isActive: true };

    const recurring = await RecurringTransaction.find(query)
      .sort('-createdAt')
      .skip((page - 1) * limit)
      .limit(parseInt(limit))
      .lean();

    const total = await RecurringTransaction.countDocuments(query);

    res.json({
      success: true,
      data: recurring,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / limit),
      },
    });
  }),

  create: asyncHandler(async (req, res) => {
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
  }),

  update: asyncHandler(async (req, res) => {
    const recurring = await RecurringTransaction.findOne({ _id: req.params.id, user: req.user.id });
    if (!recurring) throw new AppError('Recurring transaction not found', 404);

    const allowed = ['amount', 'category', 'description', 'frequency', 'interval', 'endDate', 'paymentMethod', 'isActive'];
    allowed.forEach(f => { if (req.body[f] !== undefined) recurring[f] = req.body[f]; });
    if (req.body.startDate) { recurring.startDate = req.body.startDate; recurring.nextExecutionDate = req.body.startDate; }

    await recurring.save();
    res.json({ success: true, data: recurring });
  }),

  remove: asyncHandler(async (req, res) => {
    const recurring = await RecurringTransaction.findOneAndUpdate(
      { _id: req.params.id, user: req.user.id },
      { isActive: false },
      { new: true },
    );
    if (!recurring) throw new AppError('Recurring transaction not found', 404);
    res.json({ success: true, message: 'Recurring transaction cancelled' });
  }),
};

module.exports = recurringController;
