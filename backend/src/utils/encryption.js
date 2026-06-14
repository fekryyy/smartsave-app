const crypto = require('crypto');

const ALGORITHM = 'aes-256-gcm';
const IV_LENGTH = 16;
const TAG_LENGTH = 16;

/**
 * Get an encryption key from environment by variable name.
 * Must be a 32-byte (64 hex char) key.
 *
 * @param {String} envVar - Environment variable name (default: 'MFA_ENCRYPTION_KEY')
 */
function getKey(envVar = 'MFA_ENCRYPTION_KEY') {
  const key = process.env[envVar];
  if (!key) {
    throw new Error(`${envVar} environment variable is not set`);
  }
  // Accept either raw 32-byte string or 64-char hex
  if (key.length === 64) {
    return Buffer.from(key, 'hex');
  }
  // Derive a 32-byte key from the string
  return crypto.createHash('sha256').update(key).digest();
}

/**
 * Encrypt plaintext using AES-256-GCM.
 * Returns hex-encoded string: iv:authTag:ciphertext
 *
 * @param {String} plaintext - Text to encrypt
 * @param {String} [envVar='MFA_ENCRYPTION_KEY'] - Env var name for the key
 */
function encrypt(plaintext, envVar = 'MFA_ENCRYPTION_KEY') {
  if (plaintext === null || plaintext === undefined) return null;
  const key = getKey(envVar);
  const iv = crypto.randomBytes(IV_LENGTH);
  const cipher = crypto.createCipheriv(ALGORITHM, key, iv);
  let encrypted = cipher.update(String(plaintext), 'utf8', 'hex');
  encrypted += cipher.final('hex');
  const authTag = cipher.getAuthTag().toString('hex');
  return `${iv.toString('hex')}:${authTag}:${encrypted}`;
}

/**
 * Decrypt a hex-encoded string of format iv:authTag:ciphertext.
 *
 * @param {String} ciphertext - Encrypted text
 * @param {String} [envVar='MFA_ENCRYPTION_KEY'] - Env var name for the key
 */
function decrypt(ciphertext, envVar = 'MFA_ENCRYPTION_KEY') {
  if (!ciphertext) return null;
  const key = getKey(envVar);
  const parts = ciphertext.split(':');
  if (parts.length !== 3) {
    throw new Error('Invalid encrypted format');
  }
  const iv = Buffer.from(parts[0], 'hex');
  const authTag = Buffer.from(parts[1], 'hex');
  const encrypted = parts[2];
  const decipher = crypto.createDecipheriv(ALGORITHM, key, iv);
  decipher.setAuthTag(authTag);
  let decrypted = decipher.update(encrypted, 'hex', 'utf8');
  decrypted += decipher.final('utf8');
  return decrypted;
}

module.exports = { encrypt, decrypt };
