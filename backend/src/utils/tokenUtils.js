const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { v4: uuidv4 } = require('uuid');
const config = require('../config');

const ACCESS_SECRET = config.jwtSecret;
const ACCESS_TTL = '15m';
const REFRESH_TTL_MS = 30 * 24 * 60 * 60 * 1000; // 30 days

/**
 * Generate a short-lived JWT access token.
 */
function generateAccessToken(userId) {
  return jwt.sign({ id: userId }, ACCESS_SECRET, { expiresIn: ACCESS_TTL });
}

/**
 * Generate a random refresh token and its SHA-256 hash.
 * The raw token is returned to the client; the hash is stored in the database.
 */
function generateRefreshToken() {
  const raw = uuidv4() + crypto.randomBytes(16).toString('hex');
  const hash = crypto.createHash('sha256').update(raw).digest('hex');
  return { raw, hash };
}

/**
 * Verify a JWT access token. Returns decoded payload or throws.
 */
function verifyAccessToken(token) {
  return jwt.verify(token, ACCESS_SECRET);
}

module.exports = {
  generateAccessToken,
  generateRefreshToken,
  verifyAccessToken,
  REFRESH_TTL_MS,
};
