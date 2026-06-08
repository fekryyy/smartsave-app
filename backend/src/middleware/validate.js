const { validationResult } = require('express-validator');
const { z } = require('zod');
const { AppError } = require('./errorHandler');

// ── Express-Validator middleware (existing, kept for backward compatibility) ──

const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      message: 'Validation error',
      errors: errors.array().map(e => ({ field: e.path, message: e.msg })),
    });
  }
  next();
};

// ── Zod validation schemas ──

const schemas = {
  // Auth
  register: z.object({
    name: z.string().trim().min(2, 'Name must be at least 2 characters').max(50),
    email: z.string().email('Please provide a valid email'),
    password: z.string().min(6, 'Password must be at least 6 characters'),
  }),

  login: z.object({
    email: z.string().email('Please provide a valid email'),
    password: z.string().min(1, 'Password is required'),
  }),

  // Transactions
  createTransaction: z.object({
    type: z.enum(['income', 'expense']),
    amount: z.number().positive('Amount must be greater than 0'),
    category: z.string().min(1, 'Category is required'),
    description: z.string().max(200).optional().default(''),
    date: z.string().optional(),
    paymentMethod: z.enum(['Cash', 'Credit Card', 'Debit Card', 'Bank Transfer', 'Mobile Wallet', 'Other']).optional().default('Cash'),
    currency: z.enum(['USD', 'EUR', 'GBP', 'EGP', 'SAR', 'AED']).optional().default('USD'),
    tags: z.array(z.string()).optional(),
  }),

  updateTransaction: z.object({
    amount: z.number().positive().optional(),
    category: z.string().min(1).optional(),
    description: z.string().max(200).optional(),
    date: z.string().optional(),
    paymentMethod: z.enum(['Cash', 'Credit Card', 'Debit Card', 'Bank Transfer', 'Mobile Wallet', 'Other']).optional(),
    currency: z.enum(['USD', 'EUR', 'GBP', 'EGP', 'SAR', 'AED']).optional(),
    tags: z.array(z.string()).optional(),
  }),

  // Budgets
  createBudget: z.object({
    category: z.string().min(1, 'Category is required'),
    amount: z.number().positive('Budget amount must be at least 1'),
    period: z.enum(['weekly', 'monthly', 'yearly']).optional().default('monthly'),
    notifications: z.boolean().optional(),
  }),

  // Goals
  createGoal: z.object({
    title: z.string().trim().min(2, 'Title must be at least 2 characters').max(100),
    description: z.string().max(500).optional().default(''),
    targetAmount: z.number().positive('Target amount must be at least 1'),
    targetDate: z.string().optional().nullable(),
    category: z.enum(['Emergency Fund', 'Travel', 'Education', 'Shopping', 'Investment', 'Debt Payment', 'Retirement', 'Other']).optional().default('Other'),
    priority: z.enum(['low', 'medium', 'high']).optional().default('medium'),
    icon: z.string().optional(),
    color: z.string().optional(),
    monthlyContribution: z.number().min(0).optional().default(0),
  }),

  goalContribution: z.object({
    amount: z.number().positive('Amount must be greater than 0'),
  }),

  // Change password
  changePassword: z.object({
    currentPassword: z.string().min(1, 'Current password is required'),
    newPassword: z.string().min(6, 'New password must be at least 6 characters'),
  }),

  // Recurring
  createRecurring: z.object({
    type: z.enum(['income', 'expense']),
    amount: z.number().positive(),
    category: z.enum(['Food', 'Transportation', 'Shopping', 'Bills', 'Entertainment', 'Health', 'Education', 'Travel', 'Other', 'Salary', 'Freelance', 'Investment', 'Gift', 'Refund']),
    description: z.string().optional().default(''),
    frequency: z.enum(['daily', 'weekly', 'monthly', 'yearly']),
    interval: z.number().int().min(1).optional().default(1),
    startDate: z.string().optional(),
    endDate: z.string().optional().nullable(),
    paymentMethod: z.enum(['Cash', 'Credit Card', 'Debit Card', 'Bank Transfer', 'Mobile Wallet', 'Other']).optional().default('Cash'),
  }),

  // Auto-save
  createAutoSave: z.object({
    name: z.string().min(1, 'Name is required'),
    type: z.enum(['percentage_of_income', 'fixed_daily', 'fixed_payday', 'percentage_bonus', 'round_up']),
    amount: z.number().positive().optional(),
    percentage: z.number().min(0).max(100).optional(),
    targetAccount: z.string().optional().default('savings'),
    frequency: z.enum(['daily', 'weekly', 'monthly', 'per_transaction']).optional().default('monthly'),
    paydayDay: z.number().int().min(1).max(31).optional(),
  }),

  // Financial advisor
  askQuestion: z.object({
    question: z.string().min(1, 'Question is required').max(2000),
  }),

  // Net worth
  addNetWorthEntry: z.object({
    assets: z.object({
      cash: z.number().min(0).optional().default(0),
      bankAccounts: z.number().min(0).optional().default(0),
      savings: z.number().min(0).optional().default(0),
      investments: z.number().min(0).optional().default(0),
      otherAssets: z.number().min(0).optional().default(0),
    }).optional().default({}),
    liabilities: z.object({
      creditCardDebt: z.number().min(0).optional().default(0),
      loans: z.number().min(0).optional().default(0),
      personalDebt: z.number().min(0).optional().default(0),
      mortgage: z.number().min(0).optional().default(0),
    }).optional().default({}),
  }),

  // XP
  addXp: z.object({
    amount: z.number().int().positive('Valid XP amount required'),
    reason: z.string().optional(),
  }),
};

/**
 * Zod validation middleware.
 * Validates req.body against the named schema.
 * On failure, throws an AppError (caught by asyncHandler/errorHandler).
 *
 * Usage: router.post('/', validateZod(schemas.createTransaction), controller.create)
 */
function validateZod(schema) {
  return (req, res, next) => {
    const result = schema.safeParse(req.body);
    if (!result.success) {
      const firstError = result.error.errors[0];
      const message = firstError
        ? `${firstError.path.join('.')}: ${firstError.message}`
        : 'Validation error';
      return res.status(400).json({
        success: false,
        message,
        errors: result.error.errors.map(e => ({
          field: e.path.join('.'),
          message: e.message,
        })),
      });
    }
    // Replace req.body with parsed (and defaulted) values
    req.body = result.data;
    next();
  };
}

module.exports = validate;
module.exports.schemas = schemas;
module.exports.validateZod = validateZod;
