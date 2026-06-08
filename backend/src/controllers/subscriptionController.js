const Subscription = require('../models/Subscription');
const catchAsync = require('../utils/catchAsync');

exports.getAll = catchAsync(async (req, res) => {
  const subs = await Subscription.find({ user: req.user.id }).sort({ nextBillingDate: 1 });
  const monthlyTotal = subs.reduce((sum, s) => sum + s.monthlyAmount, 0);
  const yearlyTotal = subs.reduce((sum, s) => sum + s.yearlyAmount, 0);
  const upcoming = subs.filter(s => s.isActive && s.nextBillingDate && new Date(s.nextBillingDate) <= new Date(Date.now() + 30 * 86400000));
  res.json({ success: true, data: { subscriptions: subs, monthlyTotal, yearlyTotal, upcoming } });
});

exports.getById = catchAsync(async (req, res) => {
  const sub = await Subscription.findOne({ _id: req.params.id, user: req.user.id });
  if (!sub) return res.status(404).json({ success: false, message: 'Subscription not found' });
  res.json({ success: true, data: sub });
});

exports.create = catchAsync(async (req, res) => {
  const { name, amount, billingDate, renewalFrequency, category, description, logo, website } = req.body;
  const nextBillingDate = new Date();
  nextBillingDate.setDate(billingDate);
  if (nextBillingDate < new Date()) nextBillingDate.setMonth(nextBillingDate.getMonth() + 1);
  const sub = await Subscription.create({
    user: req.user.id, name, amount, billingDate, renewalFrequency: renewalFrequency || 'monthly',
    category: category || 'Other', description, logo, website, nextBillingDate,
  });
  res.status(201).json({ success: true, data: sub });
});

exports.update = catchAsync(async (req, res) => {
  const sub = await Subscription.findOneAndUpdate(
    { _id: req.params.id, user: req.user.id },
    { $set: req.body },
    { new: true, runValidators: true }
  );
  if (!sub) return res.status(404).json({ success: false, message: 'Subscription not found' });
  res.json({ success: true, data: sub });
});

exports.remove = catchAsync(async (req, res) => {
  const sub = await Subscription.findOneAndDelete({ _id: req.params.id, user: req.user.id });
  if (!sub) return res.status(404).json({ success: false, message: 'Subscription not found' });
  res.json({ success: true, message: 'Subscription deleted' });
});
