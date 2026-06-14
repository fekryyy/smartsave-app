const { encrypt, decrypt } = require('./encryption');

// Field-level encryption key.
// Uses DATA_ENCRYPTION_KEY if set, otherwise falls back to MFA_ENCRYPTION_KEY
// for backward compatibility with existing encrypted data.
const ENV_KEY = process.env.DATA_ENCRYPTION_KEY
  ? 'DATA_ENCRYPTION_KEY'
  : 'MFA_ENCRYPTION_KEY';

/**
 * Deeply walks a document tree following a dot-separated path
 * and transforms leaf values using the provided callback.
 *
 * Supports:
 *   - Simple paths:  "amount"
 *   - Nested paths:  "assets.cash"
 *   - Array paths:   "entries.assets.cash" — iterates array items
 *   - Array index:   not needed; all array elements are traversed
 *
 * @param {Object} obj - root object
 * @param {String} path - dot-separated field path
 * @param {Function} fn - (value) => transformedValue
 * @param {Object} [schemaType] - the Mongoose schema type for type coercion
 */
function traverseAndTransform(obj, path, fn, schemaType) {
  const parts = path.split('.');
  _traverse(obj, parts, 0, fn, schemaType);
}

/**
 * Known text-only field names (kept as string after decryption).
 * All other fields are converted to Number when possible.
 */
const TEXT_FIELDS = new Set([
  'description', 'note', 'notes', 'comment', 'comments', 'name', 'title',
  'summary', 'memo', 'reference', 'label',
]);

function _traverse(obj, parts, idx, fn, schemaType) {
  if (!obj || typeof obj !== 'object') return;
  const key = parts[idx];

  // Leaf node — transform
  if (idx === parts.length - 1) {
    const val = obj[key];
    if (val !== null && val !== undefined && val !== '') {
      obj[key] = fn(val, schemaType, key);
    }
    return;
  }

  const child = obj[key];

  // If this segment is an array, recurse into each element
  if (Array.isArray(child)) {
    for (let i = 0; i < child.length; i++) {
      _traverse(child[i], parts, idx + 1, fn, schemaType);
    }
    return;
  }

  // Otherwise continue into the sub-object
  _traverse(child, parts, idx + 1, fn, schemaType);
}

/**
 * Encrypt a raw value for storage.
 */
function encryptField(value, schemaType) {
  const str = String(value);
  // Don't double-encrypt already-encrypted values
  if (str.includes(':') && str.length > 40) return value;
  return encrypt(str, ENV_KEY);
}

/**
 * Decrypt a stored encrypted value back to its original type.
 *
 * @param {*} value      - the encrypted value
 * @param {String} [schemaType] - Mongoose schema type (e.g. 'Number', 'Mixed')
 * @param {String} [fieldName]  - leaf field name used to infer numeric vs text type
 * @returns {*} decrypted value (Number for numeric fields, String for text fields)
 */
function decryptField(value, schemaType, fieldName) {
  if (typeof value !== 'string' || !value.includes(':')) return value;
  try {
    const decrypted = decrypt(value, ENV_KEY);
    if (schemaType === 'Number') return parseFloat(decrypted) || 0;
    // For Mixed types, infer numeric vs text from field name
    if (schemaType === 'Mixed' || schemaType === undefined) {
      if (fieldName && TEXT_FIELDS.has(fieldName)) return decrypted;
      const num = parseFloat(decrypted);
      if (!isNaN(num)) return num;
    }
    return decrypted;
  } catch {
    return value; // Not encrypted with our key
  }
}

/**
 * Mongoose plugin for transparent field-level encryption.
 *
 * @param {Object} schema - Mongoose schema
 * @param {Object} options - { fields: string[] } — list of field paths to encrypt
 *
 * On pre('save'):               encrypts each field
 * On post('init'):              decrypts each field (find, findOne, findById)
 * On pre('findOneAndUpdate'):   encrypts $set payload
 * On post('findOneAndUpdate'):  decrypts returned doc
 *
 * Supports nested paths (e.g., "entries.assets.cash") and array subdocuments.
 *
 * NOTE: Encrypted fields CANNOT be queried with comparison operators ($gt,
 * $lt) or used in $sum/$avg aggregations. Filter on non-encrypted fields.
 *
 * WARNING: Do NOT encrypt _id, user, date, category, or any indexed/queried field.
 */
module.exports = function encryptFieldsPlugin(schema, options) {
  const fields = options?.fields || [];
  if (fields.length === 0) return;

  // Pre-compute schema types for each field for type coercion on decrypt
  const fieldTypes = {};
  for (const field of fields) {
    // Get the Mongoose schema type for the leaf field
    const schemaPath = schema.path(field);
    fieldTypes[field] = schemaPath?.instance || 'String';
  }

  /**
   * Encrypt fields before saving.
   *
   * IMPORTANT: For top-level fields with schema type Number, Mongoose would
   * cast our encrypted string back to NaN on property set. We bypass this
   * by writing directly to _doc and calling markModified().
   *
   * For nested paths (e.g. "entries.assets.cash"), traverseAndTransform
   * modifies plain objects inside the doc, which don't have Mongoose casting.
   */
  schema.pre('save', function (next) {
    if (!this.isNew && !this.isModified()) return next();
    for (const field of fields) {
      if (field.includes('.')) {
        // Nested path — use traverseAndTransform (works on plain objects)
        traverseAndTransform(this._doc, field, encryptField);
      } else {
        // Top-level field — bypass Mongoose setter
        const originalValue = this[field];
        if (originalValue === null || originalValue === undefined || originalValue === '') continue;
        const encryptedValue = encryptField(originalValue);
        this._doc[field] = encryptedValue;
        if (this.$__parent) {
          this.$__parent._doc[field] = encryptedValue;
        }
        this.markModified(field);
      }
    }
    next();
  });

  /**
   * Decrypt a single document's fields by reading/writing from _doc.
   * This bypasses Mongoose's type casting (e.g. Number → NaN for encrypted strings).
   */
  function decryptDoc(doc) {
    if (!doc) return;
    const target = doc._doc || doc;
    for (const field of fields) {
      if (field.includes('.')) {
        traverseAndTransform(target, field, decryptField, fieldTypes[field]);
      } else {
        const value = target[field];
        if (value === null || value === undefined) continue;
        const decrypted = decryptField(value, fieldTypes[field], field);
        if (decrypted !== value) {
          target[field] = decrypted;
        }
      }
    }
  }

  /**
   * Decrypt fields when a document is hydrated from the database.
   */
  schema.post('init', function (doc) {
    decryptDoc(doc);
  });

  /**
   * Decrypt fields after save (create + update).
   */
  schema.post('save', function (doc) {
    decryptDoc(doc);
  });

  /**
   * Decrypt fields after find queries (non-lean only).
   */
  schema.post('find', function (docs) {
    if (!docs || !Array.isArray(docs)) return;
    for (const doc of docs) {
      decryptDoc(doc);
    }
  });

  /**
   * Decrypt fields after findOne, findById queries.
   */
  schema.post('findOne', function (doc) {
    decryptDoc(doc);
  });

  /**
   * Decrypt fields after findOneAndUpdate / findByIdAndUpdate.
   */
  schema.post('findOneAndUpdate', async function (doc) {
    decryptDoc(doc);
    if (doc) doc.$isNew = false;
  });

  /**
   * Encrypt fields in the update payload before the query hits MongoDB.
   */
  schema.pre('findOneAndUpdate', function (next) {
    const update = this.getUpdate();
    if (!update) return next();

    const ops = [update.$set, update, update.$setOnInsert].filter(Boolean);
    for (const op of ops) {
      for (const field of fields) {
        try {
          traverseAndTransform(op, field, encryptField);
        } catch {
          // Path may not exist in this op — skip
        }
      }
    }

    // Warn on $inc of encrypted fields
    if (update.$inc) {
      for (const field of fields) {
        if (update.$inc[field] !== undefined) {
          console.warn(
            `[encryptFields] $inc on encrypted field "${field}" is not supported. ` +
            'Use $set with the full computed value instead.'
          );
        }
      }
    }

    next();
  });
};
