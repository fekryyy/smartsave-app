const Challenge = require('../models/Challenge');
const Achievement = require('../models/Achievement');
const UserStreak = require('../models/UserStreak');

const CHECKPOINTS = {
  first_transaction: { threshold: 1, points: 10 },
  ten_transactions: { threshold: 10, points: 50 },
  fifty_transactions: { threshold: 50, points: 200 },
  first_goal: { threshold: 1, points: 25 },
  goal_completed: { threshold: 1, points: 100 },
  budget_set: { threshold: 1, points: 15 },
  budget_on_track: { threshold: 1, points: 30 },
  seven_day_streak: { threshold: 7, points: 75 },
  thirty_day_streak: { threshold: 30, points: 500 },
  receipt_scanner: { threshold: 1, points: 10 },
  champion: { threshold: 5, points: 1000 },
};

async function checkAndAward(req, badge, current) {
  const info = CHECKPOINTS[badge];
  if (!info || current < info.threshold) return;

  const existing = await Achievement.findOne({ user: req.user.id, badge });
  if (existing) return;

  const titles = {
    first_transaction: 'First Transaction',
    ten_transactions: 'Getting Started',
    fifty_transactions: 'Finance Pro',
    first_goal: 'Goal Setter',
    goal_completed: 'Achiever',
    budget_set: 'Budget Master',
    budget_on_track: 'On Track',
    seven_day_streak: 'Week Warrior',
    thirty_day_streak: 'Monthly Champion',
    receipt_scanner: 'Receipt Detective',
    champion: 'SmartSave Champion',
  };

  await Achievement.create({
    user: req.user.id,
    badge,
    title: titles[badge] || badge,
    description: `Earned for reaching ${info.threshold} in ${badge.replace(/_/g, ' ')}`,
  });

  await UserStreak.findOneAndUpdate(
    { user: req.user.id },
    { $inc: { totalPoints: info.points } },
    { upsert: true },
  );
}

const challengeController = {
  async getAll(req, res, next) {
    try {
      const challenges = await Challenge.find({ user: req.user.id }).sort('-createdAt');
      const streak = await UserStreak.findOne({ user: req.user.id });
      const achievements = await Achievement.find({ user: req.user.id }).sort('-unlockedAt');
      res.json({ success: true, data: { challenges, streak, achievements } });
    } catch (error) {
      next(error);
    }
  },

  async joinChallenge(req, res, next) {
    try {
      const { title, description, type, goal, points, endDate } = req.body;
      const challenge = await Challenge.create({
        user: req.user.id, title, description, type, goal, points: points || 0, endDate,
      });
      res.status(201).json({ success: true, data: challenge });
    } catch (error) {
      next(error);
    }
  },

  async updateProgress(req, res, next) {
    try {
      const { progress } = req.body;
      const challenge = await Challenge.findOneAndUpdate(
        { _id: req.params.id, user: req.user.id },
        { progress },
        { new: true },
      );
      if (!challenge) return res.status(404).json({ success: false, message: 'Challenge not found' });

      if (challenge.progress >= challenge.goal && challenge.status === 'active') {
        challenge.status = 'completed';
        challenge.completedAt = new Date();
        await challenge.save();

        await UserStreak.findOneAndUpdate(
          { user: req.user.id },
          { $inc: { totalPoints: challenge.points } },
          { upsert: true },
        );
      }

      res.json({ success: true, data: challenge });
    } catch (error) {
      next(error);
    }
  },

  async awardAchievement(req, res, next) {
    try {
      const { badge } = req.body;
      await checkAndAward(req, badge, 1);
      const achievements = await Achievement.find({ user: req.user.id });
      const streak = await UserStreak.findOne({ user: req.user.id });
      res.json({ success: true, data: { achievements, streak } });
    } catch (error) {
      next(error);
    }
  },

  async awardByCount(req, res, next) {
    try {
      const { badge, count } = req.body;
      await checkAndAward(req, badge, count);
      const achievements = await Achievement.find({ user: req.user.id });
      const streak = await UserStreak.findOne({ user: req.user.id });
      res.json({ success: true, data: { achievements, streak } });
    } catch (error) {
      next(error);
    }
  },

  async recordLogin(req, res, next) {
    try {
      const streak = await UserStreak.findOne({ user: req.user.id }) || new UserStreak({ user: req.user.id });
      const now = new Date();
      const last = streak.lastLoginDate;

      if (last) {
        const diffDays = Math.floor((now - last) / (1000 * 60 * 60 * 24));
        if (diffDays === 1) {
          streak.loginStreak += 1;
        } else if (diffDays > 1) {
          streak.loginStreak = 1;
        }
      } else {
        streak.loginStreak = 1;
      }

      streak.lastLoginDate = now;
      if (streak.loginStreak > streak.bestLoginStreak) {
        streak.bestLoginStreak = streak.loginStreak;
      }

      await streak.save();
      await checkAndAward(req, 'seven_day_streak', streak.loginStreak);
      await checkAndAward(req, 'thirty_day_streak', streak.loginStreak);
      res.json({ success: true, data: streak });
    } catch (error) {
      next(error);
    }
  },

  async recordSpend(req, res, next) {
    try {
      const streak = await UserStreak.findOne({ user: req.user.id });
      if (streak) {
        streak.noSpendStreak = 0;
        streak.lastSpendDate = new Date();
        await streak.save();
      }
      res.json({ success: true, data: streak });
    } catch (error) {
      next(error);
    }
  },
};

module.exports = { challengeController, checkAndAward, CHECKPOINTS };
