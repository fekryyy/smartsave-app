/**
 * Money Utilities
 *
 * Prevents floating-point precision issues in financial calculations.
 *
 * Guidelines:
 * - All monetary values SHOULD be stored as integer cents (e.g., 1999 = $19.99).
 * - For the current transition period, we provide helpers to safely round
 *   and validate money values that are still stored as floats.
 * - New models should use `cents: { type: Number, … }` instead of `amount`.
 */

const ROUNDING_ERROR = 0.0001;

/**
 * Round a monetary value to the nearest cent (2 decimal places).
 * This prevents floating-point accumulation errors like 0.1 + 0.2 = 0.30000000000000004.
 *
 * @param {number} value - A dollar amount
 * @returns {number} The value rounded to 2 decimal places
 */
function roundToCents(value) {
  if (typeof value !== 'number' || !isFinite(value)) return 0;
  return Math.round(value * 100) / 100;
}

/**
 * Convert dollars to integer cents.
 * $19.99 → 1999
 *
 * @param {number} dollars
 * @returns {number} Integer cents
 */
function toCents(dollars) {
  if (typeof dollars !== 'number' || !isFinite(dollars)) return 0;
  return Math.round(dollars * 100);
}

/**
 * Convert integer cents to dollars.
 * 1999 → $19.99
 *
 * @param {number} cents
 * @returns {number} Dollar amount rounded to 2 decimals
 */
function fromCents(cents) {
  if (typeof cents !== 'number' || !isFinite(cents)) return 0;
  return Math.round(cents) / 100;
}

/**
 * Safely add two monetary values, rounding to avoid floating-point drift.
 *
 * @param {...number} values - Dollar amounts to sum
 * @returns {number}
 */
function safeSum(...values) {
  // Convert to cents, sum as integers, convert back — zero precision loss
  const totalCents = values.reduce((sum, v) => sum + toCents(v), 0);
  return fromCents(totalCents);
}

/**
 * Validate that a monetary value does not exceed 2 decimal places.
 * Returns an error message string or null if valid.
 *
 * @param {number} value
 * @returns {string|null}
 */
function validatePrecision(value) {
  if (typeof value !== 'number') return 'Value must be a number';
  if (!isFinite(value)) return 'Value must be a finite number';
  if (value < 0) return 'Value must be non-negative';
  const rounded = Math.round(value * 100);
  if (Math.abs(value - rounded / 100) > ROUNDING_ERROR) {
    return 'Monetary values cannot have more than 2 decimal places';
  }
  return null;
}

/**
 * Zod refinement: ensures a number has at most 2 decimal places.
 * Usage: z.number().refine(...)
 */
function maxTwoDecimals(value) {
  if (typeof value !== 'number') return false;
  const rounded = Math.round(value * 100);
  return Math.abs(value - rounded / 100) <= ROUNDING_ERROR;
}

module.exports = {
  roundToCents,
  toCents,
  fromCents,
  safeSum,
  validatePrecision,
  maxTwoDecimals,
};
