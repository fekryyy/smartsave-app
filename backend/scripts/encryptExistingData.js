/**
 * Migration Script: Encrypt existing unencrypted financial data.
 *
 * This script scans all documents in Transaction, Budget, Goal, NetWorth,
 * and AutoSave collections. For any document whose financial fields are
 * stored as plain Numbers (not yet encrypted), it encrypts them using
 * the same encryption key and format as the Mongoose plugin.
 *
 * Uses native MongoDB driver (via mongoose.connection.db) to bypass
 * Mongoose type casting that would otherwise convert encrypted strings
 * back to NaN for Number-type fields.
 *
 * Usage:
 *   node scripts/encryptExistingData.js
 *
 * Prerequisites:
 *   - DATA_ENCRYPTION_KEY must be set in .env
 *   - MongoDB must be running and accessible via MONGODB_URI
 *   - Run from the backend/ directory
 *
 * Safe to re-run: skips already-encrypted fields (check: value is a
 * string in "iv:authTag:ciphertext" format).
 */

require('dotenv').config({ path: require('path').resolve(__dirname, '../.env') });

const mongoose = require('mongoose');
const { encrypt } = require('../src/utils/encryption');

const ENV_KEY = 'DATA_ENCRYPTION_KEY';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function isEncrypted(value) {
  return typeof value === 'string' && value.includes(':') && value.length > 40;
}

function encryptValue(value) {
  if (value === null || value === undefined) return value;
  if (isEncrypted(value)) return value; // already encrypted
  return encrypt(String(value), ENV_KEY);
}

// ---------------------------------------------------------------------------
// Migrators (uses native MongoDB driver to bypass Mongoose type casting)
// ---------------------------------------------------------------------------

async function migrateCollection(db, collectionName, fieldUpdaters) {
  const collection = db.collection(collectionName);
  const total = await collection.countDocuments();
  console.log(`[${collectionName}] Total documents: ${total}`);

  let encrypted = 0;
  let skipped = 0;
  let errors = 0;

  const cursor = collection.find();
  while (await cursor.hasNext()) {
    const doc = await cursor.next();
    try {
      const $set = {};

      for (const updater of fieldUpdaters) {
        updater(doc, $set);
      }

      if (Object.keys($set).length > 0) {
        // Use native updateOne — bypasses Mongoose type casting
        await collection.updateOne({ _id: doc._id }, { $set });
        encrypted++;
      } else {
        skipped++;
      }
    } catch (err) {
      console.error(`[${collectionName}] Error on document ${doc._id}:`, err.message);
      errors++;
    }
  }

  console.log(`[${collectionName}] Encrypted: ${encrypted}, Already encrypted (skipped): ${skipped}, Errors: ${errors}`);
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  // Validate env
  if (!process.env.DATA_ENCRYPTION_KEY) {
    console.error('ERROR: DATA_ENCRYPTION_KEY environment variable is not set.');
    process.exit(1);
  }

  const uri = process.env.MONGODB_URI || 'mongodb://localhost:27017/smartsave';
  await mongoose.connect(uri);
  const db = mongoose.connection.db;
  console.log(`Connected to MongoDB: ${uri}`);

  // 1. Transaction — encrypt 'amount' and 'description'
  console.log('\n--- Transaction ---');
  await migrateCollection(db, 'transactions', [
    (doc, $set) => {
      if (!isEncrypted(doc.amount)) {
        $set.amount = encryptValue(doc.amount);
      }
    },
    (doc, $set) => {
      if (doc.description && !isEncrypted(doc.description)) {
        $set.description = encryptValue(doc.description);
      }
    },
  ]);

  // 2. Budget — encrypt 'amount' (NOT 'spent' — it's updated via $inc)
  console.log('\n--- Budget ---');
  await migrateCollection(db, 'budgets', [
    (doc, $set) => {
      if (!isEncrypted(doc.amount)) {
        $set.amount = encryptValue(doc.amount);
      }
    },
  ]);

  // 3. Goal — encrypt 'targetAmount' and 'currentAmount'
  console.log('\n--- Goal ---');
  await migrateCollection(db, 'goals', [
    (doc, $set) => {
      if (!isEncrypted(doc.targetAmount)) {
        $set.targetAmount = encryptValue(doc.targetAmount);
      }
    },
    (doc, $set) => {
      if (!isEncrypted(doc.currentAmount)) {
        $set.currentAmount = encryptValue(doc.currentAmount);
      }
    },
  ]);

  // 4. NetWorth — encrypt entries[].assets.* and entries[].liabilities.*
  console.log('\n--- NetWorth ---');
  await migrateCollection(db, 'networths', [
    (doc, $set) => {
      if (!doc.entries || doc.entries.length === 0) return;
      let changed = false;
      const encrypted = doc.entries.map(entry => {
        const e = { ...entry };
        for (const key of Object.keys(e.assets || {})) {
          if (!isEncrypted(e.assets[key])) {
            e.assets[key] = encryptValue(e.assets[key]);
            changed = true;
          }
        }
        for (const key of Object.keys(e.liabilities || {})) {
          if (!isEncrypted(e.liabilities[key])) {
            e.liabilities[key] = encryptValue(e.liabilities[key]);
            changed = true;
          }
        }
        return e;
      });
      if (changed) {
        $set.entries = encrypted;
      }
    },
  ]);

  // 5. AutoSave — encrypt 'amount', 'totalContributed', 'history[].amount'
  console.log('\n--- AutoSave ---');
  await migrateCollection(db, 'autosaves', [
    (doc, $set) => {
      if (!isEncrypted(doc.amount)) {
        $set.amount = encryptValue(doc.amount);
      }
    },
    (doc, $set) => {
      if (!isEncrypted(doc.totalContributed)) {
        $set.totalContributed = encryptValue(doc.totalContributed);
      }
    },
    (doc, $set) => {
      if (!doc.history || doc.history.length === 0) return;
      let changed = false;
      const encrypted = doc.history.map(h => {
        if (!isEncrypted(h.amount)) {
          changed = true;
          return { ...h, amount: encryptValue(h.amount) };
        }
        return h;
      });
      if (changed) {
        $set.history = encrypted;
      }
    },
  ]);

  console.log('\n--- Migration complete ---');
  await mongoose.disconnect();
  process.exit(0);
}

main().catch((err) => {
  console.error('Migration failed:', err);
  process.exit(1);
});
