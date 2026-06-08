const Notification = require('../models/Notification');

const notificationController = {
  async getAll(req, res, next) {
    try {
      const { page = 1, limit = 20, unreadOnly = false } = req.query;
      const query = { user: req.user.id };
      if (unreadOnly === 'true') query.isRead = false;

      const notifications = await Notification.find(query)
        .sort('-createdAt')
        .skip((page - 1) * limit)
        .limit(parseInt(limit));

      const total = await Notification.countDocuments(query);
      const unreadCount = await Notification.countDocuments({ user: req.user.id, isRead: false });

      res.json({
        success: true,
        data: {
          notifications,
          unreadCount,
          pagination: {
            page: parseInt(page),
            limit: parseInt(limit),
            total,
            pages: Math.ceil(total / limit),
          },
        },
      });
    } catch (error) {
      next(error);
    }
  },

  async markAsRead(req, res, next) {
    try {
      const notification = await Notification.findOneAndUpdate(
        { _id: req.params.id, user: req.user.id },
        { isRead: true },
        { new: true }
      );

      if (!notification) {
        return res.status(404).json({ success: false, message: 'Notification not found' });
      }

      res.json({ success: true, data: notification });
    } catch (error) {
      next(error);
    }
  },

  async markAllAsRead(req, res, next) {
    try {
      await Notification.updateMany(
        { user: req.user.id, isRead: false },
        { isRead: true }
      );

      res.json({ success: true, message: 'All notifications marked as read' });
    } catch (error) {
      next(error);
    }
  },

  async delete(req, res, next) {
    try {
      const notification = await Notification.findOneAndDelete({
        _id: req.params.id,
        user: req.user.id,
      });

      if (!notification) {
        return res.status(404).json({ success: false, message: 'Notification not found' });
      }

      res.json({ success: true, message: 'Notification deleted' });
    } catch (error) {
      next(error);
    }
  },
};

module.exports = notificationController;
