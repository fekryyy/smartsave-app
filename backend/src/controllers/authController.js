const crypto = require('crypto');
const User = require('../models/User');
const config = require('../config');
const sendEmail = require('../utils/email');
const asyncHandler = require('../utils/catchAsync');
const { AppError } = require('../middleware/errorHandler');

const authController = {
  register: asyncHandler(async (req, res) => {
    const { name, email, password } = req.body;

    const existingUser = await User.findOne({ email }).lean();
    if (existingUser) {
      throw new AppError('Email already registered', 400);
    }

    const user = await User.create({ name, email, password });
    const token = user.generateAuthToken();
    const refreshToken = user.generateRefreshToken();

    res.status(201).json({
      success: true,
      message: 'Account created successfully',
      data: {
        user,
        token,
        refreshToken,
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

    const token = user.generateAuthToken();
    const refreshToken = user.generateRefreshToken();

    res.json({
      success: true,
      message: 'Login successful',
      data: {
        user,
        token,
        refreshToken,
      },
    });
  }),

  googleLogin: asyncHandler(async (req, res) => {
    const { idToken } = req.body;
    const { OAuth2Client } = require('google-auth-library');
    const client = new OAuth2Client(config.googleClientId);

    // Accept either the iOS or Android client ID as the audience.
    // The aud claim in the ID token varies by platform:
    //   Android → google-services.json default_web_client_id (client_type 3)
    //   iOS     → GoogleService-Info.plist CLIENT_ID          (client_type 2)
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
    const refreshToken = user.generateRefreshToken();

    res.json({
      success: true,
      message: 'Google login successful',
      data: { user, token, refreshToken },
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
    user.resetPasswordExpire = Date.now() + 30 * 60 * 1000; // 30 minutes
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

  refreshToken: asyncHandler(async (req, res) => {
    const { refreshToken } = req.body;
    if (!refreshToken) {
      throw new AppError('Refresh token required', 400);
    }

    const jwt = require('jsonwebtoken');
    const decoded = jwt.verify(refreshToken, config.jwtRefreshSecret);
    const user = await User.findById(decoded.id);

    if (!user) {
      throw new AppError('Invalid refresh token', 401);
    }

    const newToken = user.generateAuthToken();
    const newRefreshToken = user.generateRefreshToken();

    res.json({
      success: true,
      data: { token: newToken, refreshToken: newRefreshToken },
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
