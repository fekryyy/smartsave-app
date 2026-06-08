const { Server } = require('socket.io');
const { createAdapter } = require('@socket.io/redis-adapter');
const jwt = require('jsonwebtoken');
const config = require('../config');
const logger = require('../utils/logger');
const redisService = require('./redisService');

let io = null;

// Map userId -> Set<socketId> for multi-device support
const userSockets = new Map();

/**
 * Initialize Socket.io with the HTTP server.
 * Attaches Redis adapter if Redis is available.
 * Authenticates connections via JWT token in handshake auth.
 *
 * @param {http.Server} server — the HTTP server instance
 * @returns {Server} — the Socket.io server instance
 */
function initSocket(server) {
  if (io) return io;

  io = new Server(server, {
    cors: {
      origin: process.env.NODE_ENV === 'production' ? config.frontendUrl : '*',
      methods: ['GET', 'POST'],
      credentials: true,
    },
    pingTimeout: 60000,
    pingInterval: 25000,
  });

  // Attach Redis adapter for horizontal scaling (multi-process / multi-server)
  const redisClient = redisService.getClient();
  if (redisClient && redisService.isReady()) {
    const subClient = redisClient.duplicate();
    io.adapter(createAdapter(redisClient, subClient));
    logger.info('Socket.io Redis adapter attached');
  } else {
    logger.warn('Socket.io running without Redis adapter (single-instance only)');
  }

  // Authentication middleware
  io.use((socket, next) => {
    const token = socket.handshake.auth?.token || socket.handshake.query?.token;

    if (!token) {
      return next(new Error('Authentication required'));
    }

    try {
      const decoded = jwt.verify(token, config.jwtSecret);
      socket.userId = decoded.id;
      socket.userEmail = decoded.email;
      next();
    } catch (err) {
      return next(new Error('Invalid or expired token'));
    }
  });

  // Connection handler
  io.on('connection', (socket) => {
    const userId = socket.userId;
    logger.info(`Socket connected: user=${userId} socket=${socket.id}`);

    // Track user sockets
    if (!userSockets.has(userId)) {
      userSockets.set(userId, new Set());
    }
    userSockets.get(userId).add(socket.id);

    // Join user-specific room for targeted broadcasts
    socket.join(`user:${userId}`);

    // Notify other devices that this user came online
    socket.broadcast.to(`user:${userId}`).emit('user:online', {
      userId,
      timestamp: new Date().toISOString(),
    });

    // ── Event handlers ──

    // Client acknowledges receipt of a notification
    socket.on('notification:received', (notificationId) => {
      logger.debug(`User ${userId} received notification ${notificationId}`);
    });

    // Client requests to join a specific room (e.g., challenge updates)
    socket.on('room:join', (room) => {
      if (typeof room === 'string') {
        socket.join(room);
        logger.debug(`User ${userId} joined room ${room}`);
      }
    });

    socket.on('room:leave', (room) => {
      if (typeof room === 'string') {
        socket.leave(room);
      }
    });

    // General ping/pong for connection health
    socket.on('ping', () => {
      socket.emit('pong', { timestamp: Date.now() });
    });

    // ── Disconnection ──

    socket.on('disconnect', (reason) => {
      logger.info(`Socket disconnected: user=${userId} socket=${socket.id} reason=${reason}`);

      const sockets = userSockets.get(userId);
      if (sockets) {
        sockets.delete(socket.id);
        if (sockets.size === 0) {
          userSockets.delete(userId);
          // Notify other devices that user went fully offline
          socket.broadcast.to(`user:${userId}`).emit('user:offline', {
            userId,
            timestamp: new Date().toISOString(),
          });
        }
      }
    });
  });

  return io;
}

/**
 * Get the Socket.io server instance.
 */
function getIO() {
  return io;
}

/**
 * Check if a specific user has active socket connections.
 */
function isUserOnline(userId) {
  return userSockets.has(userId) && userSockets.get(userId).size > 0;
}

/**
 * Emit an event to a specific user (all their devices).
 */
function emitToUser(userId, event, data) {
  if (!io) return;
  io.to(`user:${userId}`).emit(event, data);
}

/**
 * Emit an event to a specific room.
 */
function emitToRoom(room, event, data) {
  if (!io) return;
  io.to(room).emit(event, data);
}

/**
 * Emit a notification to a user (convenience wrapper with ack tracking).
 */
function sendNotification(userId, notification) {
  emitToUser(userId, 'notification', {
    ...notification,
    sentAt: new Date().toISOString(),
  });
}

/**
 * Get online user count (across all connected clients).
 */
function getOnlineCount() {
  return io?.engine?.clientsCount || 0;
}

/**
 * Get list of online user IDs.
 */
function getOnlineUserIds() {
  return Array.from(userSockets.keys());
}

/**
 * Graceful shutdown: close all socket connections.
 */
async function shutdown() {
  if (io) {
    try {
      await io.close();
      logger.info('Socket.io closed gracefully');
    } catch (err) {
      logger.error(`Socket.io shutdown error: ${err.message}`);
    }
  }
}

module.exports = {
  initSocket,
  getIO,
  isUserOnline,
  emitToUser,
  emitToRoom,
  sendNotification,
  getOnlineCount,
  getOnlineUserIds,
  shutdown,
};
