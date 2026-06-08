const NetWorth = require('../models/NetWorth');
const catchAsync = require('../utils/catchAsync');

exports.getNetWorth = catchAsync(async (req, res) => {
  let nw = await NetWorth.findOne({ user: req.user.id });
  if (!nw) {
    nw = await NetWorth.create({ user: req.user.id, entries: [{ assets: {}, liabilities: {} }] });
  }
  res.json({ success: true, data: nw });
});

exports.addEntry = catchAsync(async (req, res) => {
  const { assets = {}, liabilities = {} } = req.body;
  let nw = await NetWorth.findOne({ user: req.user.id });
  if (!nw) {
    nw = await NetWorth.create({ user: req.user.id, entries: [] });
  }
  nw.entries.push({
    date: new Date(),
    assets: {
      cash: assets.cash || 0,
      bankAccounts: assets.bankAccounts || 0,
      savings: assets.savings || 0,
      investments: assets.investments || 0,
      otherAssets: assets.otherAssets || 0,
    },
    liabilities: {
      creditCardDebt: liabilities.creditCardDebt || 0,
      loans: liabilities.loans || 0,
      personalDebt: liabilities.personalDebt || 0,
      mortgage: liabilities.mortgage || 0,
    },
  });
  await nw.save();
  res.json({ success: true, data: nw });
});

exports.getHistory = catchAsync(async (req, res) => {
  const nw = await NetWorth.findOne({ user: req.user.id });
  if (!nw) return res.json({ success: true, data: [] });
  const history = nw.entries.map(e => ({
    date: e.date,
    totalAssets: e.assets.cash + e.assets.bankAccounts + e.assets.savings + e.assets.investments + e.assets.otherAssets,
    totalLiabilities: e.liabilities.creditCardDebt + e.liabilities.loans + e.liabilities.personalDebt + e.liabilities.mortgage,
    netWorth: (e.assets.cash + e.assets.bankAccounts + e.assets.savings + e.assets.investments + e.assets.otherAssets) -
      (e.liabilities.creditCardDebt + e.liabilities.loans + e.liabilities.personalDebt + e.liabilities.mortgage),
  }));
  res.json({ success: true, data: history });
});
