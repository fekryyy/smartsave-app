const Goal = require('../models/Goal');
const Transaction = require('../models/Transaction');
const Notification = require('../models/Notification');

const goalController = {
  async getAll(req, res, next) {
    try {
      const { status } = req.query;
      const query = { user: req.user.id };
      if (status) query.status = status;

      const goals = await Goal.find(query).sort('-createdAt');
      res.json({ success: true, data: goals });
    } catch (error) {
      next(error);
    }
  },

  async getById(req, res, next) {
    try {
      const goal = await Goal.findOne({ _id: req.params.id, user: req.user.id });
      if (!goal) {
        return res.status(404).json({ success: false, message: 'Goal not found' });
      }
      res.json({ success: true, data: goal });
    } catch (error) {
      next(error);
    }
  },

  async create(req, res, next) {
    try {
      const { title, description, targetAmount, targetDate, category, priority, icon, color, monthlyContribution } = req.body;

      const goal = await Goal.create({
        user: req.user.id,
        title,
        description,
        targetAmount,
        targetDate,
        category,
        priority: priority || 'medium',
        icon,
        color,
        monthlyContribution: monthlyContribution || 0,
      });

      res.status(201).json({ success: true, message: 'Goal created', data: goal });
    } catch (error) {
      next(error);
    }
  },

  async update(req, res, next) {
    try {
      const goal = await Goal.findOne({ _id: req.params.id, user: req.user.id });
      if (!goal) {
        return res.status(404).json({ success: false, message: 'Goal not found' });
      }

      const allowedUpdates = ['title', 'description', 'targetAmount', 'targetDate', 'category', 'priority', 'monthlyContribution', 'icon', 'color'];
      allowedUpdates.forEach(field => {
        if (req.body[field] !== undefined) {
          goal[field] = req.body[field];
        }
      });

      await goal.save();
      res.json({ success: true, message: 'Goal updated', data: goal });
    } catch (error) {
      next(error);
    }
  },

  async delete(req, res, next) {
    try {
      const goal = await Goal.findOneAndDelete({ _id: req.params.id, user: req.user.id });
      if (!goal) {
        return res.status(404).json({ success: false, message: 'Goal not found' });
      }
      res.json({ success: true, message: 'Goal deleted' });
    } catch (error) {
      next(error);
    }
  },

  async addContribution(req, res, next) {
    try {
      const { amount } = req.body;
      const goal = await Goal.findOne({ _id: req.params.id, user: req.user.id });

      if (!goal) {
        return res.status(404).json({ success: false, message: 'Goal not found' });
      }

      if (goal.status === 'completed') {
        return res.status(400).json({ success: false, message: 'Goal already completed' });
      }

      await goal.addContribution(amount);

      // Create expense transaction to deduct from balance
      await Transaction.create({
        user: req.user.id,
        type: 'expense',
        amount,
        category: 'Savings',
        description: `Contribution to "${goal.title}"`,
        date: new Date(),
      });

      // Create notification
      try {
        await Notification.create({
          user: req.user.id,
          type: 'goal_reminder',
          title: 'Savings Contribution',
          message: `\$${amount} added to "${goal.title}" goal`,
        });
      } catch (_) {}

      res.json({ success: true, message: 'Contribution added', data: goal });
    } catch (error) {
      next(error);
    }
  },

  async getProgress(req, res, next) {
    try {
      const goals = await Goal.find({ user: req.user.id, status: 'active' });

      const progress = goals.map(goal => ({
        id: goal._id,
        title: goal.title,
        targetAmount: goal.targetAmount,
        currentAmount: goal.currentAmount,
        progress: goal.progress,
        remaining: goal.remaining,
        estimatedCompletionDate: goal.estimatedCompletionDate,
        monthlyContribution: goal.monthlyContribution,
      }));

      res.json({ success: true, data: progress });
    } catch (error) {
      next(error);
    }
  },
};

module.exports = goalController;
