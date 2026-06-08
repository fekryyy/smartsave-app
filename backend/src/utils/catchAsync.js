/**
 * Wraps an async route handler to catch errors and forward them to Express error handler.
 * Usage: router.get('/', asyncHandler(controller.method))
 */
const asyncHandler = (fn) => (req, res, next) => {
  Promise.resolve(fn(req, res, next)).catch(next);
};

module.exports = asyncHandler;
