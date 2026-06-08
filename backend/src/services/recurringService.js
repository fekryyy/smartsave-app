const cron = require('node-cron');
const RecurringTransaction = require('../models/RecurringTransaction');
const Transaction = require('../models/Transaction');
const logger = require('../utils/logger');

class RecurringService {
  start() {
    // Check every hour
    cron.schedule('0 * * * *', async () => {
      try {
        await this.processRecurringTransactions();
      } catch (error) {
        logger.error('Recurring transaction processing error:', error);
      }
    });
    logger.info('Recurring transaction service started');
  }

  async processRecurringTransactions() {
    const now = new Date();
    const dueTransactions = await RecurringTransaction.find({
      isActive: true,
      nextExecutionDate: { $lte: now },
      $or: [
        { endDate: null },
        { endDate: { $gte: now } },
      ],
    });

    for (const recurring of dueTransactions) {
      try {
        // Create the actual transaction
        await Transaction.create({
          user: recurring.user,
          type: recurring.type,
          amount: recurring.amount,
          category: recurring.category,
          description: recurring.description,
          date: now,
          paymentMethod: recurring.paymentMethod,
          isRecurring: true,
        });

        // Update recurring record
        recurring.lastExecuted = now;
        recurring.executionCount += 1;
        recurring.nextExecutionDate = recurring.calculateNextExecution();

        // Check if should end
        if (recurring.endDate && recurring.nextExecutionDate > recurring.endDate) {
          recurring.isActive = false;
        }

        await recurring.save();
        logger.info(`Recurring transaction executed: ${recurring.description} - $${recurring.amount}`);
      } catch (error) {
        logger.error(`Failed to process recurring transaction ${recurring._id}:`, error);
      }
    }
  }
}

module.exports = new RecurringService();
