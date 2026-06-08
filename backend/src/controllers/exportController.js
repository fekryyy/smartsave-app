const PDFDocument = require('pdfkit');
const { Parser } = require('json2csv');
const XLSX = require('xlsx');
const Transaction = require('../models/Transaction');
const Goal = require('../models/Goal');
const asyncHandler = require('../utils/catchAsync');
const { getDateRange } = require('../utils/helpers');

const exportController = {
  exportPDF: asyncHandler(async (req, res) => {
    const { period = 'monthly', type = 'transactions' } = req.query;
    const { start, end } = getDateRange(period);

      let data;
      if (type === 'transactions') {
        data = await Transaction.find({ user: req.user.id, date: { $gte: start, $lte: end }, isActive: true }).sort('-date').lean();
      } else {
        data = await Goal.find({ user: req.user.id }).lean();
      }

      const doc = new PDFDocument({ margin: 30, size: 'A4' });
      res.setHeader('Content-Type', 'application/pdf');
      res.setHeader('Content-Disposition', `attachment; filename=smartsave-${type}-${period}-${Date.now()}.pdf`);
      doc.pipe(res);

      // Header
      doc.fontSize(24).font('Helvetica-Bold').text('SmartSave', { align: 'center' });
      doc.fontSize(12).font('Helvetica').text('Personal Finance Report', { align: 'center' });
      doc.moveDown();
      doc.fontSize(10).text(`Period: ${start.toLocaleDateString()} - ${end.toLocaleDateString()}`, { align: 'center' });
      doc.moveDown();

      // Summary
      if (type === 'transactions' && data.length > 0) {
        const totalIncome = data.filter(t => t.type === 'income').reduce((s, t) => s + t.amount, 0);
        const totalExpenses = data.filter(t => t.type === 'expense').reduce((s, t) => s + t.amount, 0);

        doc.fontSize(14).font('Helvetica-Bold').text('Summary');
        doc.fontSize(10).font('Helvetica');
        doc.text(`Total Income: $${totalIncome.toFixed(2)}`);
        doc.text(`Total Expenses: $${totalExpenses.toFixed(2)}`);
        doc.text(`Net: $${(totalIncome - totalExpenses).toFixed(2)}`);
        doc.moveDown();

        // Transactions table
        doc.fontSize(14).font('Helvetica-Bold').text('Transactions');
        doc.moveDown(0.5);

        data.forEach(t => {
          const date = new Date(t.date).toLocaleDateString();
          const type = t.type === 'income' ? '+' : '-';
          doc.fontSize(9).font('Helvetica')
            .text(`${date} | ${t.category.padEnd(15)} | ${t.description.padEnd(25)} | ${type}$${t.amount.toFixed(2)}`);
        });
      } else if (type === 'goals') {
        doc.fontSize(14).font('Helvetica-Bold').text('Savings Goals');
        doc.moveDown(0.5);

        data.forEach(g => {
          const progress = g.targetAmount > 0 ? Math.round((g.currentAmount / g.targetAmount) * 100) : 0;
          doc.fontSize(10).font('Helvetica')
            .text(`${g.title}: $${g.currentAmount.toFixed(2)} / $${g.targetAmount.toFixed(2)} (${progress}%)`);
        });
      }

      doc.end();
    }),

  exportCSV: asyncHandler(async (req, res) => {
      const { period = 'monthly', type = 'transactions' } = req.query;
      const { start, end } = getDateRange(period);

      let data;
      if (type === 'transactions') {
        data = await Transaction.find({ user: req.user.id, date: { $gte: start, $lte: end }, isActive: true })
          .lean()
          .select('type amount category description date paymentMethod');

        const fields = ['type', 'amount', 'category', 'description', 'date', 'paymentMethod'];
        const parser = new Parser({ fields });
        const csv = parser.parse(data);

        res.setHeader('Content-Type', 'text/csv');
        res.setHeader('Content-Disposition', `attachment; filename=smartsave-transactions-${Date.now()}.csv`);
        res.send(csv);
      } else {
        data = await Goal.find({ user: req.user.id }).lean().select('title targetAmount currentAmount status targetDate');

        const fields = ['title', 'targetAmount', 'currentAmount', 'status', 'targetDate'];
        const parser = new Parser({ fields });
        const csv = parser.parse(data);

        res.setHeader('Content-Type', 'text/csv');
        res.setHeader('Content-Disposition', `attachment; filename=smartsave-goals-${Date.now()}.csv`);
        res.send(csv);
      }
    }),

  exportExcel: asyncHandler(async (req, res) => {
    const { period = 'monthly' } = req.query;
    const { start, end } = getDateRange(period);

    const [transactions, goals] = await Promise.all([
      Transaction.find({ user: req.user.id, date: { $gte: start, $lte: end }, isActive: true }).lean(),
      Goal.find({ user: req.user.id }).lean(),
    ]);

    const wb = XLSX.utils.book_new();

    // Transactions sheet
    const txData = transactions.map(t => ({
      Type: t.type,
      Amount: t.amount,
      Category: t.category,
      Description: t.description,
      Date: new Date(t.date).toLocaleDateString(),
      'Payment Method': t.paymentMethod,
    }));
    const txSheet = XLSX.utils.json_to_sheet(txData);
    XLSX.utils.book_append_sheet(wb, txSheet, 'Transactions');

    // Goals sheet
    const goalData = goals.map(g => ({
      Title: g.title,
      'Target Amount': g.targetAmount,
      'Current Amount': g.currentAmount,
      Progress: g.targetAmount > 0 ? `${Math.round((g.currentAmount / g.targetAmount) * 100)}%` : '0%',
      Status: g.status,
      'Target Date': g.targetDate ? new Date(g.targetDate).toLocaleDateString() : 'No target',
    }));
    const goalSheet = XLSX.utils.json_to_sheet(goalData);
    XLSX.utils.book_append_sheet(wb, goalSheet, 'Savings Goals');

    // Summary sheet
    const totalIncome = transactions.filter(t => t.type === 'income').reduce((s, t) => s + t.amount, 0);
    const totalExpenses = transactions.filter(t => t.type === 'expense').reduce((s, t) => s + t.amount, 0);
    const summaryData = [
      { Metric: 'Total Income', Value: totalIncome },
      { Metric: 'Total Expenses', Value: totalExpenses },
      { Metric: 'Net Savings', Value: totalIncome - totalExpenses },
      { Metric: 'Period', Value: `${start.toLocaleDateString()} - ${end.toLocaleDateString()}` },
    ];
    const summarySheet = XLSX.utils.json_to_sheet(summaryData);
    XLSX.utils.book_append_sheet(wb, summarySheet, 'Summary');

    const buffer = XLSX.write(wb, { type: 'buffer', bookType: 'xlsx' });

    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', `attachment; filename=smartsave-report-${Date.now()}.xlsx`);
    res.send(buffer);
  }),
};

module.exports = exportController;
