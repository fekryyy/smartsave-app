/**
 * Decrypted Aggregation Helpers
 *
 * Transaction.aggregate() cannot $sum encrypted fields.
 * These helpers use find() (which triggers post('init') decryption)
 * followed by in-memory computation.
 *
 * For a personal-finance app, the result set per query is always
 * bounded by user + date range (typically < 10 000 docs), so
 * in-memory reduction is practical and correct.
 */

/**
 * Sum a field across documents matching the given query,
 * grouped by a key.
 *
 * @param {Model} Model - Mongoose model
 * @param {Object} match - MongoDB filter
 * @param {String} groupKey - Field to group by (e.g. 'category', 'type')
 * @param {String} sumKey - Field to sum (e.g. 'amount')
 * @returns {Promise<Array<{_id: any, total: number, count: number}>>}
 */
async function sumByGroup(Model, match, groupKey, sumKey) {
  // Use non-lean find so post('init') middleware decrypts fields
  const docs = await Model.find(match);

  const groups = {};
  for (const doc of docs) {
    const key = doc[groupKey];
    if (key === null || key === undefined) continue;
    if (!groups[key]) groups[key] = { total: 0, count: 0 };
    const val = typeof doc[sumKey] === 'number' ? doc[sumKey] : parseFloat(doc[sumKey]) || 0;
    groups[key].total += val;
    groups[key].count += 1;
  }

  return Object.entries(groups).map(([key, data]) => ({
    _id: key,
    total: data.total,
    count: data.count,
  }));
}

/**
 * Sum a field across documents, grouped by type ('income'/'expense').
 * Shortcut for the very common income/expense summing pattern.
 *
 * @param {Model} Model
 * @param {Object} match
 * @param {String} sumKey - default 'amount'
 * @returns {Promise<Array<{_id: string, total: number, count: number}>>}
 */
async function sumByType(Model, match, sumKey = 'amount') {
  return sumByGroup(Model, match, 'type', sumKey);
}

/**
 * Total sum of a field across all matching documents.
 *
 * @param {Model} Model
 * @param {Object} match
 * @param {String} sumKey
 * @returns {Promise<number>}
 */
async function sumTotal(Model, match, sumKey) {
  const docs = await Model.find(match);
  let total = 0;
  for (const doc of docs) {
    total += typeof doc[sumKey] === 'number' ? doc[sumKey] : parseFloat(doc[sumKey]) || 0;
  }
  return total;
}

/**
 * Get total + count + max for income and expense grouped by type.
 * Replaces the typical aggregate used in getMonthlyReport.
 *
 * @returns {Promise<Array<{_id: string, total: number, count: number, maxAmount: number}>>}
 */
async function typeTotalsWithMax(Model, match) {
  const docs = await Model.find(match);
  const groups = { income: { total: 0, count: 0, maxAmount: 0 }, expense: { total: 0, count: 0, maxAmount: 0 } };
  for (const doc of docs) {
    const type = doc.type;
    if (!groups[type]) groups[type] = { total: 0, count: 0, maxAmount: 0 };
    const val = typeof doc.amount === 'number' ? doc.amount : parseFloat(doc.amount) || 0;
    groups[type].total += val;
    groups[type].count += 1;
    if (val > groups[type].maxAmount) groups[type].maxAmount = val;
  }
  return Object.entries(groups)
    .filter(([_, v]) => v.count > 0)
    .map(([type, data]) => ({ _id: type, ...data }));
}

/**
 * Monthly income/expense trend over a date range.
 * Returns array of { _id: { year, month, type }, total }.
 */
async function monthlyTrend(Model, match) {
  const docs = await Model.find(match);
  const groups = {};
  for (const doc of docs) {
    const d = doc.date || new Date();
    const key = `${d.getFullYear()}-${d.getMonth() + 1}-${doc.type}`;
    if (!groups[key]) {
      groups[key] = {
        _id: { year: d.getFullYear(), month: d.getMonth() + 1, type: doc.type },
        total: 0,
      };
    }
    const val = typeof doc.amount === 'number' ? doc.amount : parseFloat(doc.amount) || 0;
    groups[key].total += val;
  }
  return Object.values(groups).sort((a, b) => {
    if (a._id.year !== b._id.year) return a._id.year - b._id.year;
    if (a._id.month !== b._id.month) return a._id.month - b._id.month;
    return a._id.type.localeCompare(b._id.type);
  });
}

/**
 * Daily spending heatmap data.
 * Returns { _id: 'YYYY-MM-DD', total, count }[]
 */
async function dailyTotals(Model, match) {
  const docs = await Model.find(match);
  const groups = {};
  for (const doc of docs) {
    const d = doc.date || new Date();
    const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
    if (!groups[key]) groups[key] = { _id: key, total: 0, count: 0 };
    const val = typeof doc.amount === 'number' ? doc.amount : parseFloat(doc.amount) || 0;
    groups[key].total += val;
    groups[key].count += 1;
  }
  return Object.values(groups).sort((a, b) => a._id.localeCompare(b._id));
}

/**
 * Average + total + count for spending over a date range.
 */
async function spendingStats(Model, match) {
  const docs = await Model.find(match);
  let total = 0;
  let count = 0;
  let sumSquares = 0;
  for (const doc of docs) {
    const val = typeof doc.amount === 'number' ? doc.amount : parseFloat(doc.amount) || 0;
    total += val;
    count += 1;
    sumSquares += val * val;
  }
  const avg = count > 0 ? total / count : 0;
  return [{ _id: null, avg, total, count }];
}

/**
 * Monthly income and expense totals, both in a single row.
 * Returns array of { _id: { year, month }, income, expenses }.
 */
async function monthlyIncomeVsExpenses(Model, match) {
  const docs = await Model.find(match);
  const groups = {};
  for (const doc of docs) {
    const d = doc.date || new Date();
    const key = `${d.getFullYear()}-${d.getMonth() + 1}`;
    if (!groups[key]) {
      groups[key] = { _id: { year: d.getFullYear(), month: d.getMonth() + 1 }, income: 0, expenses: 0 };
    }
    const val = typeof doc.amount === 'number' ? doc.amount : parseFloat(doc.amount) || 0;
    if (doc.type === 'income') {
      groups[key].income += val;
    } else {
      groups[key].expenses += val;
    }
  }
  return Object.values(groups).sort((a, b) => {
    if (a._id.year !== b._id.year) return a._id.year - b._id.year;
    return a._id.month - b._id.month;
  });
}

module.exports = {
  sumByGroup,
  sumByType,
  sumTotal,
  typeTotalsWithMax,
  monthlyTrend,
  dailyTotals,
  spendingStats,
  monthlyIncomeVsExpenses,
};
