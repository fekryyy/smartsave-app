const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const RefreshToken = require('../models/RefreshToken');
const config = require('../config');
const sendEmail = require('../utils/email');
const asyncHandler = require('../utils/catchAsync');
const { AppError } = require('../middleware/errorHandler');
const { generateAccessToken, generateRefreshToken, verifyAccessToken, REFRESH_TTL_MS } = require('../utils/tokenUtils');
const speakeasy = require('speakeasy');
const QRCode = require('qrcode');
const { encrypt, decrypt } = require('../utils/encryption');

const REFRESH_COOKIE_OPTIONS = {
  httpOnly: true,
  secure: process.env.NODE_ENV === 'production',
  sameSite: 'strict',
  path: '/api/auth',
  maxAge: REFRESH_TTL_MS,
};

/**
 * Issue a refresh token: save to DB, set as cookie, return raw value.
 */
async function issueRefreshToken(userId, req, res) {
  const { raw, hash } = generateRefreshToken();
  await RefreshToken.create({
    userId,
    tokenHash: hash,
    deviceId: req.headers['x-device-id'] || null,
    userAgent: req.headers['user-agent'] || null,
    ip: req.ip || req.connection?.remoteAddress || null,
    expiresAt: new Date(Date.now() + REFRESH_TTL_MS),
  });
  res.cookie('refreshToken', raw, REFRESH_COOKIE_OPTIONS);
  return raw;
}

const authController = {
  register: asyncHandler(async (req, res) => {
    const { name, email, password } = req.body;

    const existingUser = await User.findOne({ email }).lean();
    if (existingUser) {
      throw new AppError('Email already registered', 400);
    }

    const user = await User.create({ name, email, password });
    const token = user.generateAuthToken();
    const refreshTokenRaw = await issueRefreshToken(user._id, req, res);

    res.status(201).json({
      success: true,
      message: 'Account created successfully',
      data: {
        user,
        token,
        refreshToken: refreshTokenRaw,
      },
    });
  }),

  login: asyncHandler(async (req, res) => {
    const { email, password } = req.body;

    const user = await User.findOne({ email }).select('+password');
    if (!user) {
      throw new AppError('Invalid email or password', 401);
    }

    const isMatch = await user.comparePassword(password);
    if (!isMatch) {
      throw new AppError('Invalid email or password', 401);
    }

    // If user has MFA enabled, issue a short-lived MFA pending token instead of full access
    if (user.mfaEnabled) {
      const mfaToken = jwt.sign(
        { id: user._id, mfaPending: true },
        config.jwtSecret,
        { expiresIn: '5m' },
      );
      return res.json({
        success: true,
        message: 'MFA code required',
        mfaRequired: true,
        data: {
          mfaToken,
          userId: user._id,
        },
      });
    }

    const token = user.generateAuthToken();
    const refreshTokenRaw = await issueRefreshToken(user._id, req, res);

    res.json({
      success: true,
      message: 'Login successful',
      data: {
        user,
        token,
        refreshToken: refreshTokenRaw,
      },
    });
  }),

  googleLogin: asyncHandler(async (req, res) => {
    const { idToken } = req.body;
    const { OAuth2Client } = require('google-auth-library');
    const client = new OAuth2Client(config.googleClientId);

    const audiences = [config.googleClientId];
    if (config.googleAndroidClientId) {
      audiences.push(config.googleAndroidClientId);
    }

    const ticket = await client.verifyIdToken({
      idToken,
      audience: audiences,
    });

    const { email, name, picture } = ticket.getPayload();

    let user = await User.findOne({ email });

    if (!user) {
      user = await User.create({
        name,
        email,
        password: crypto.randomBytes(20).toString('hex'),
        googleId: ticket.getPayload().sub,
        avatar: picture,
        emailVerified: true,
      });
    } else if (!user.googleId) {
      user.googleId = ticket.getPayload().sub;
      if (picture) user.avatar = picture;
      await user.save();
    }

    const token = user.generateAuthToken();
    const refreshTokenRaw = await issueRefreshToken(user._id, req, res);

    res.json({
      success: true,
      message: 'Google login successful',
      data: { user, token, refreshToken: refreshTokenRaw },
    });
  }),

  forgotPassword: asyncHandler(async (req, res) => {
    const { email } = req.body;
    const user = await User.findOne({ email });

    if (!user) {
      throw new AppError('User not found', 404);
    }

    const resetToken = crypto.randomBytes(32).toString('hex');
    user.resetPasswordToken = crypto.createHash('sha256').update(resetToken).digest('hex');
    user.resetPasswordExpire = Date.now() + 30 * 60 * 1000;
    await user.save();

    const resetUrl = `${config.frontendUrl}/reset-password/${resetToken}`;

    try {
      await sendEmail({
        to: user.email,
        subject: 'SmartSave - Password Reset Request',
        html: `
          <h1>Password Reset Request</h1>
          <p>You requested a password reset. Click the link below to reset your password:</p>
          <a href="${resetUrl}" style="display: inline-block; padding: 12px 24px; background: #4F46E5; color: white; text-decoration: none; border-radius: 8px;">Reset Password</a>
          <p>This link expires in 30 minutes.</p>
          <p>If you didn't request this, please ignore this email.</p>
        `,
      });

      res.json({ success: true, message: 'Password reset email sent' });
    } catch (err) {
      user.resetPasswordToken = undefined;
      user.resetPasswordExpire = undefined;
      await user.save();
      throw new AppError('Email could not be sent', 500);
    }
  }),

  resetPassword: asyncHandler(async (req, res) => {
    const { token, password } = req.body;

    const hashedToken = crypto.createHash('sha256').update(token).digest('hex');
    const user = await User.findOne({
      resetPasswordToken: hashedToken,
      resetPasswordExpire: { $gt: Date.now() },
    });

    if (!user) {
      throw new AppError('Invalid or expired token', 400);
    }

    user.password = password;
    user.resetPasswordToken = undefined;
    user.resetPasswordExpire = undefined;
    await user.save();

    res.json({ success: true, message: 'Password reset successful' });
  }),

  /**
   * Cookie-based refresh with rotation:
   * 1. Read refresh token from HttpOnly cookie
   * 2. Hash it and look up in DB
   * 3. Verify not revoked and not expired
   * 4. Revoke old token (rotation)
   * 5. Issue new access token + new refresh token
   */
  refresh: asyncHandler(async (req, res) => {
    const rawToken = req.cookies?.refreshToken;
    if (!rawToken) {
      throw new AppError('Refresh token required', 400);
    }

    const hash = crypto.createHash('sha256').update(rawToken).digest('hex');
    const storedToken = await RefreshToken.findOne({ tokenHash: hash });

    if (!storedToken) {
      throw new AppError('Invalid refresh token', 401);
    }

    if (storedToken.revokedAt) {
      // Token was revoked — could be a rotation reuse attack. Revoke all tokens for this user.
      await RefreshToken.updateMany(
        { userId: storedToken.userId, revokedAt: null },
        { revokedAt: new Date() },
      );
      throw new AppError('Refresh token revoked — all sessions invalidated', 401);
    }

    if (storedToken.expiresAt < new Date()) {
      throw new AppError('Refresh token expired', 401);
    }

    const user = await User.findById(storedToken.userId);
    if (!user) {
      throw new AppError('User not found', 401);
    }

    // Revoke the old token (rotation)
    await RefreshToken.updateOne(
      { _id: storedToken._id },
      { revokedAt: new Date() },
    );

    // Issue new tokens
    const accessToken = user.generateAuthToken();
    const newRefreshTokenRaw = await issueRefreshToken(user._id, req, res);

    res.json({
      success: true,
      data: {
        token: accessToken,
        refreshToken: newRefreshTokenRaw,
      },
    });
  }),

  /**
   * Logout: revoke the current refresh token and clear the cookie.
   */
  logout: asyncHandler(async (req, res) => {
    const rawToken = req.cookies?.refreshToken;
    if (rawToken) {
      const hash = crypto.createHash('sha256').update(rawToken).digest('hex');
      await RefreshToken.updateOne({ tokenHash: hash }, { revokedAt: new Date() });
    }

    res.clearCookie('refreshToken', { path: '/api/auth' });
    res.json({ success: true, message: 'Logged out successfully' });
  }),

  /**
   * Legacy body-based refresh token endpoint (backward compatible).
   */
  refreshTokenLegacy: asyncHandler(async (req, res) => {
    const { refreshToken } = req.body;
    if (!refreshToken) {
      throw new AppError('Refresh token required', 400);
    }

    const hash = crypto.createHash('sha256').update(refreshToken).digest('hex');
    const storedToken = await RefreshToken.findOne({ tokenHash: hash });

    if (!storedToken || storedToken.revokedAt) {
      throw new AppError('Invalid refresh token', 401);
    }

    if (storedToken.expiresAt < new Date()) {
      throw new AppError('Refresh token expired', 401);
    }

    const user = await User.findById(storedToken.userId);
    if (!user) {
      throw new AppError('User not found', 401);
    }

    // Revoke old token
    await RefreshToken.updateOne(
      { _id: storedToken._id },
      { revokedAt: new Date() },
    );

    const newToken = user.generateAuthToken();
    const newRefreshTokenRaw = await issueRefreshToken(user._id, req, res);

    res.json({
      success: true,
      data: { token: newToken, refreshToken: newRefreshTokenRaw },
    });
  }),

  getProfile: asyncHandler(async (req, res) => {
    const user = await User.findById(req.user.id).lean();
    res.json({ success: true, data: user });
  }),

  updateProfile: asyncHandler(async (req, res) => {
    const { name, currency, notificationPreferences } = req.body;
    const updateFields = {};

    if (name) updateFields.name = name;
    if (currency) updateFields.currency = currency;
    if (notificationPreferences) updateFields.notificationPreferences = notificationPreferences;
    if (req.body.onboardingCompleted !== undefined) updateFields.onboardingCompleted = req.body.onboardingCompleted;

    const user = await User.findByIdAndUpdate(req.user.id, updateFields, {
      new: true,
      runValidators: true,
    });

    res.json({ success: true, message: 'Profile updated', data: user });
  }),

  /**
   * Generate TOTP secret and QR code URI for the authenticated user.
   * Does NOT enable MFA yet — user must verify first.
   */
  mfaSetup: asyncHandler(async (req, res) => {
    const secret = speakeasy.generateSecret({
      name: `SmartSave:${req.user.email}`,
      issuer: 'SmartSave',
    });

    // Store encrypted secret temporarily
    req.user.mfaSecret = encrypt(secret.base32);
    req.user.mfaVerified = false;
    await req.user.save();

    // Generate QR code as data URL
    const qrCode = await QRCode.toDataURL(secret.otpauth_url);

    res.json({
      success: true,
      data: {
        secret: secret.base32,
        qrCode,
        otpauthUrl: secret.otpauth_url,
      },
    });
  }),

  /**
   * Verify the user's first TOTP code and enable MFA.
   */
  mfaVerifySetup: asyncHandler(async (req, res) => {
    const { token } = req.body;
    if (!token) {
      throw new AppError('TOTP code is required', 400);
    }

    const user = await User.findById(req.user.id);
    if (!user.mfaSecret) {
      throw new AppError('MFA setup not initiated. Call /auth/mfa/setup first.', 400);
    }

    const decryptedSecret = decrypt(user.mfaSecret);
    const verified = speakeasy.totp.verify({
      secret: decryptedSecret,
      encoding: 'base32',
      token,
      window: 2,
    });

    if (!verified) {
      throw new AppError('Invalid TOTP code. Please try again.', 400);
    }

    user.mfaEnabled = true;
    user.mfaVerified = true;
    await user.save();

    res.json({
      success: true,
      message: 'MFA enabled successfully',
    });
  }),

  /**
   * Validate TOTP code during login and issue full access token.
   */
  mfaValidate: asyncHandler(async (req, res) => {
    const { mfaToken, token } = req.body;
    if (!mfaToken || !token) {
      throw new AppError('mfaToken and token are required', 400);
    }

    let decoded;
    try {
      decoded = jwt.verify(mfaToken, config.jwtSecret);
    } catch (err) {
      throw new AppError('MFA token expired or invalid. Please log in again.', 401);
    }

    if (!decoded.mfaPending) {
      throw new AppError('Invalid MFA token', 401);
    }

    const user = await User.findById(decoded.id).select('+password');
    if (!user || !user.mfaEnabled) {
      throw new AppError('MFA is not enabled for this account', 401);
    }

    const decryptedSecret = decrypt(user.mfaSecret);
    const verified = speakeasy.totp.verify({
      secret: decryptedSecret,
      encoding: 'base32',
      token,
      window: 2,
    });

    if (!verified) {
      throw new AppError('Invalid TOTP code. Please try again.', 401);
    }

    const accessToken = user.generateAuthToken();
    const refreshTokenRaw = await issueRefreshToken(user._id, req, res);

    res.json({
      success: true,
      message: 'Login successful',
      data: {
        user,
        token: accessToken,
        refreshToken: refreshTokenRaw,
      },
    });
  }),

  /**
   * Disable MFA. Requires password confirmation.
   */
  mfaDisable: asyncHandler(async (req, res) => {
    const { password } = req.body;
    if (!password) {
      throw new AppError('Password is required to disable MFA', 400);
    }

    const user = await User.findById(req.user.id).select('+password');
    const isMatch = await user.comparePassword(password);
    if (!isMatch) {
      throw new AppError('Password is incorrect', 400);
    }

    user.mfaEnabled = false;
    user.mfaSecret = null;
    user.mfaVerified = false;
    await user.save();

    res.json({
      success: true,
      message: 'MFA disabled successfully',
    });
  }),

  changePassword: asyncHandler(async (req, res) => {
    const { currentPassword, newPassword } = req.body;
    const user = await User.findById(req.user.id).select('+password');

    const isMatch = await user.comparePassword(currentPassword);
    if (!isMatch) {
      throw new AppError('Current password is incorrect', 400);
    }

    user.password = newPassword;
    await user.save();

    res.json({ success: true, message: 'Password changed successfully' });
  }),
};

module.exports = authController;
