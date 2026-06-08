const crypto = require('crypto');
const User = require('../models/User');
const config = require('../config');
const sendEmail = require('../utils/email');

const authController = {
  async register(req, res, next) {
    try {
      const { name, email, password } = req.body;

      const existingUser = await User.findOne({ email });
      if (existingUser) {
        return res.status(400).json({ success: false, message: 'Email already registered' });
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
    } catch (error) {
      next(error);
    }
  },

  async login(req, res, next) {
    try {
      const { email, password } = req.body;

      const user = await User.findOne({ email }).select('+password');
      if (!user) {
        return res.status(401).json({ success: false, message: 'Invalid email or password' });
      }

      const isMatch = await user.comparePassword(password);
      if (!isMatch) {
        return res.status(401).json({ success: false, message: 'Invalid email or password' });
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
    } catch (error) {
      next(error);
    }
  },

  async googleLogin(req, res, next) {
    try {
      const { idToken } = req.body;
      const { OAuth2Client } = require('google-auth-library');
      const client = new OAuth2Client(config.googleClientId);
      
      const ticket = await client.verifyIdToken({
        idToken,
        audience: config.googleClientId,
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
    } catch (error) {
      next(error);
    }
  },

  async forgotPassword(req, res, next) {
    try {
      const { email } = req.body;
      const user = await User.findOne({ email });

      if (!user) {
        return res.status(404).json({ success: false, message: 'User not found' });
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
        return res.status(500).json({ success: false, message: 'Email could not be sent' });
      }
    } catch (error) {
      next(error);
    }
  },

  async resetPassword(req, res, next) {
    try {
      const { token, password } = req.body;

      const hashedToken = crypto.createHash('sha256').update(token).digest('hex');
      const user = await User.findOne({
        resetPasswordToken: hashedToken,
        resetPasswordExpire: { $gt: Date.now() },
      });

      if (!user) {
        return res.status(400).json({ success: false, message: 'Invalid or expired token' });
      }

      user.password = password;
      user.resetPasswordToken = undefined;
      user.resetPasswordExpire = undefined;
      await user.save();

      res.json({ success: true, message: 'Password reset successful' });
    } catch (error) {
      next(error);
    }
  },

  async refreshToken(req, res, next) {
    try {
      const { refreshToken } = req.body;
      if (!refreshToken) {
        return res.status(400).json({ success: false, message: 'Refresh token required' });
      }

      const jwt = require('jsonwebtoken');
      const decoded = jwt.verify(refreshToken, config.jwtRefreshSecret);
      const user = await User.findById(decoded.id);

      if (!user) {
        return res.status(401).json({ success: false, message: 'Invalid refresh token' });
      }

      const newToken = user.generateAuthToken();
      const newRefreshToken = user.generateRefreshToken();

      res.json({
        success: true,
        data: { token: newToken, refreshToken: newRefreshToken },
      });
    } catch (error) {
      return res.status(401).json({ success: false, message: 'Invalid refresh token' });
    }
  },

  async getProfile(req, res, next) {
    try {
      const user = await User.findById(req.user.id);
      res.json({ success: true, data: user });
    } catch (error) {
      next(error);
    }
  },

  async updateProfile(req, res, next) {
    try {
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
    } catch (error) {
      next(error);
    }
  },

  async changePassword(req, res, next) {
    try {
      const { currentPassword, newPassword } = req.body;
      const user = await User.findById(req.user.id).select('+password');

      const isMatch = await user.comparePassword(currentPassword);
      if (!isMatch) {
        return res.status(400).json({ success: false, message: 'Current password is incorrect' });
      }

      user.password = newPassword;
      await user.save();

      res.json({ success: true, message: 'Password changed successfully' });
    } catch (error) {
      next(error);
    }
  },
};

module.exports = authController;
