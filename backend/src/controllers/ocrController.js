const Tesseract = require('tesseract.js');
const Transaction = require('../models/Transaction');

const ocrController = {
  async scanReceipt(req, res, next) {
    try {
      if (!req.file) {
        return res.status(400).json({ success: false, message: 'Receipt image is required' });
      }

      const { data: { text } } = await Tesseract.recognize(req.file.path, 'eng', {
        logger: m => m.status === 'recognizing text' && process.env.NODE_ENV === 'development' && console.log(m),
      });

      // Extract information from OCR text
      const extracted = extractReceiptInfo(text);
      const amount = extracted.amount || 0;
      const merchant = extracted.merchant || '';
      const category = categorizeTransaction(merchant, text);
      const description = merchant || 'Receipt scan';

      if (amount > 0) {
        const transaction = await Transaction.create({
          user: req.user.id,
          type: 'expense',
          amount,
          category,
          description,
          date: new Date(),
          paymentMethod: 'Cash',
          tags: ['scan', 'receipt'],
          receiptUrl: req.file.path,
        });

        res.json({
          success: true,
          message: 'Receipt scanned successfully',
          data: {
            transaction,
            extracted: { amount, merchant, category },
            rawText: text.substring(0, 200),
          },
        });
      } else {
        res.json({
          success: true,
          message: 'Receipt scanned but could not detect amount. Please enter manually.',
          data: {
            extracted: { amount, merchant, category },
            rawText: text.substring(0, 200),
          },
        });
      }
    } catch (error) {
      next(error);
    }
  },
};

function extractReceiptInfo(text) {
  const lines = text.split('\n').map(l => l.trim()).filter(Boolean);
  let amount = 0;
  let merchant = '';

  // Find total amount
  const amountPatterns = [
    /total[:\s]*\$?([\d,]+\.?\d*)/i,
    /amount[:\s]*\$?([\d,]+\.?\d*)/i,
    /due[:\s]*\$?([\d,]+\.?\d*)/i,
    /sum[:\s]*\$?([\d,]+\.?\d*)/i,
    /grand total[:\s]*\$?([\d,]+\.?\d*)/i,
    /\$?([\d]+\.\d{2})\s*$/m,
  ];

  for (const pattern of amountPatterns) {
    const match = text.match(pattern);
    if (match) {
      amount = parseFloat(match[1].replace(',', ''));
      if (amount > 0) break;
    }
  }

  // Find merchant (usually first few lines)
  if (lines.length > 0) {
    merchant = lines[0];
  }

  return { amount, merchant };
}

function categorizeTransaction(merchant, text) {
  const lowerText = (merchant + ' ' + text).toLowerCase();

  if (/\b(restaurant|cafe|coffee|pizza|burger|food|grocery|supermarket|deli|bakery)\b/.test(lowerText)) return 'Food';
  if (/\b(gas|fuel|uber|lyft|taxi|metro|bus|train|parking|transport)\b/.test(lowerText)) return 'Transportation';
  if (/\b(mall|amazon|walmart|target|clothing|electronics|store|shop)\b/.test(lowerText)) return 'Shopping';
  if (/\b(electric|water|gas|internet|phone|rent|utility|bill)\b/.test(lowerText)) return 'Bills';
  if (/\b(cinema|movie|netflix|spotify|game|theater|concert|entertain)\b/.test(lowerText)) return 'Entertainment';
  if (/\b(pharmacy|hospital|doctor|clinic|medicine|health|dentist|optician)\b/.test(lowerText)) return 'Health';
  if (/\b(school|university|college|course|book|education|class)\b/.test(lowerText)) return 'Education';
  if (/\b(hotel|flight|airbnb|booking|resort|travel|trip|vacation)\b/.test(lowerText)) return 'Travel';

  return 'Other';
}

module.exports = ocrController;
