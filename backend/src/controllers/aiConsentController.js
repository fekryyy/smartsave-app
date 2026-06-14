/**
 * AI Consent Controller — manage user consent for AI data processing.
 *
 * Users must explicitly opt in before the SmartSave Advisor processes
 * their financial data. Consent can be revoked at any time.
 *
 * All consent changes are logged immutably in AIConsentLog for compliance.
 */

const User = require('../models/User');
const AIConsentLog = require('../models/AIConsentLog');
const asyncHandler = require('../utils/catchAsync');
const { AppError } = require('../middleware/errorHandler');

const aiConsentController = {
  /**
   * GET /api/financial-advisor/consent
   * Returns the current consent status for the authenticated user.
   */
  getConsentStatus: asyncHandler(async (req, res) => {
    const user = await User.findById(req.user.id).select('aiConsent aiConsentDate');
    res.json({
      success: true,
      data: {
        aiConsent: user.aiConsent || false,
        aiConsentDate: user.aiConsentDate || null,
      },
    });
  }),

  /**
   * POST /api/financial-advisor/consent/accept
   * Accept AI data processing consent.
   */
  acceptConsent: asyncHandler(async (req, res) => {
    const user = await User.findById(req.user.id);
    if (user.aiConsent) {
      return res.json({
        success: true,
        message: 'AI consent already accepted',
        data: { aiConsent: true, aiConsentDate: user.aiConsentDate },
      });
    }

    user.aiConsent = true;
    user.aiConsentDate = new Date();
    await user.save();

    // Log immutably
    await AIConsentLog.create({
      user: user._id,
      action: 'accepted',
      ipAddress: req.ip || req.connection?.remoteAddress || '',
      userAgent: req.headers?.['user-agent'] || '',
      source: req.headers?.['x-source'] || 'api',
    });

    res.json({
      success: true,
      message: 'AI consent accepted. Your financial data can now be used to generate personalized insights.',
      data: { aiConsent: true, aiConsentDate: user.aiConsentDate },
    });
  }),

  /**
   * POST /api/financial-advisor/consent/revoke
   * Revoke AI data processing consent.
   */
  revokeConsent: asyncHandler(async (req, res) => {
    const user = await User.findById(req.user.id);
    if (!user.aiConsent) {
      return res.json({
        success: true,
        message: 'AI consent already revoked',
        data: { aiConsent: false, aiConsentDate: null },
      });
    }

    user.aiConsent = false;
    user.aiConsentDate = null;
    await user.save();

    // Log immutably
    await AIConsentLog.create({
      user: user._id,
      action: 'revoked',
      ipAddress: req.ip || req.connection?.remoteAddress || '',
      userAgent: req.headers?.['user-agent'] || '',
      source: req.headers?.['x-source'] || 'api',
    });

    res.json({
      success: true,
      message: 'AI consent revoked. Your financial data will no longer be used for AI processing.',
      data: { aiConsent: false, aiConsentDate: null },
    });
  }),

  /**
   * GET /api/financial-advisor/consent/log
   * Returns the consent change history for the user (last 50 entries).
   */
  getConsentLog: asyncHandler(async (req, res) => {
    const logs = await AIConsentLog.find({ user: req.user.id })
      .sort({ createdAt: -1 })
      .limit(50)
      .select('action ipAddress source createdAt')
      .lean();

    res.json({ success: true, data: logs });
  }),
};

module.exports = aiConsentController;
