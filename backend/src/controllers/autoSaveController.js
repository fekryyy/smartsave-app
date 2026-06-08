const AutoSave = require('../models/AutoSave');
const Transaction = require('../models/Transaction');
const User = require('../models/User');
const catchAsync = require('../utils/catchAsync');
const mongoose = require('mongoose');

exports.getAll = catchAsync(async (req, res) => {
  const { page = 1, limit = 50 } = req.query;
  const query = { user: req.user.id };

  const rules = await AutoSave.find(query)
    .sort({ createdAt: -1 })
    .skip((page - 1) * limit)
    .limit(parseInt(limit))
    .lean();
  const total = await AutoSave.countDocuments(query);
  const totalProjected = rules.reduce((sum, r) => sum + r.totalContributed, 0);

  res.json({
    success: true,
    data: { rules, totalProjected },
    pagination: {
      page: parseInt(page),
      limit: parseInt(limit),
      total,
      pages: Math.ceil(total / limit),
    },
  });
});

exports.getById = catchAsync(async (req, res) => {
  const rule = await AutoSave.findOne({ _id: req.params.id, user: req.user.id });
  if (!rule) return res.status(404).json({ success: false, message: 'Rule not found' });
  res.json({ success: true, data: rule });
});

exports.create = catchAsync(async (req, res) => {
  const { name, type, amount, percentage, targetAccount, frequency, paydayDay } = req.body;
  if (type === 'percentage_of_income' && !percentage) {
    return res.status(400).json({ success: false, message: 'Percentage required for percentage_of_income type' });
  }
  if (type === 'fixed_payday' && !paydayDay) {
    return res.status(400).json({ success: false, message: 'Payday day required for fixed_payday type' });
  }
  const rule = await AutoSave.create({
    user: req.user.id, name, type, amount, percentage, targetAccount, frequency, paydayDay,
  });
  res.status(201).json({ success: true, data: rule });
});

exports.update = catchAsync(async (req, res) => {
  const rule = await AutoSave.findOneAndUpdate(
    { _id: req.params.id, user: req.user.id },
    { $set: req.body },
    { new: true, runValidators: true }
  );
  if (!rule) return res.status(404).json({ success: false, message: 'Rule not found' });
  res.json({ success: true, data: rule });
});

exports.remove = catchAsync(async (req, res) => {
  const rule = await AutoSave.findOneAndDelete({ _id: req.params.id, user: req.user.id });
  if (!rule) return res.status(404).json({ success: false, message: 'Rule not found' });
  res.json({ success: true, message: 'Rule deleted' });
});

exports.triggerContribution = catchAsync(async (req, res) => {
  const rule = await AutoSave.findOne({ _id: req.params.id, user: req.user.id });
  if (!rule) return res.status(404).json({ success: false, message: 'Rule not found' });
  let amount = 0;
  const user = await User.findById(req.user.id);
  switch (rule.type) {
    case 'fixed_daily': amount = rule.amount || 0; break;
    case 'fixed_payday': amount = rule.amount || 0; break;
    case 'percentage_of_income': {
      const totalIncome = await Transaction.aggregate([
        { $match: { user: new mongoose.Types.ObjectId(req.user.id), type: 'income', isActive: true } },
        { $group: { _id: null, total: { $sum: '$amount' } } },
      ]);
      amount = ((totalIncome[0]?.total || 0) * (rule.percentage || 0)) / 100;
      break;
    }
    case 'percentage_bonus': amount = ((user.totalIncome || 0) * (rule.percentage || 0)) / 100; break;
    default: amount = rule.amount || 0;
  }
  const tx = await Transaction.create({
    user: req.user.id, type: 'expense', amount, category: 'Savings',
    description: `Auto-save: ${rule.name}`, date: new Date(),
  });
  rule.totalContributed += amount;
  rule.contributionCount += 1;
  rule.lastContribution = new Date();
  rule.history.push({ date: new Date(), amount, transactionId: tx._id });
  await rule.save();
  res.json({ success: true, data: { rule, transaction: tx } });
});
