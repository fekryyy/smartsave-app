/**
 * PM2 Ecosystem Configuration for SmartSave Backend
 *
 * Start:  pm2 start ecosystem.config.js
 * Stop:   pm2 stop ecosystem.config.js
 * Status: pm2 status
 * Logs:   pm2 logs smartsave-backend
 * Reload: pm2 reload ecosystem.config.js
 */
module.exports = {
  apps: [
    {
      name: 'smartSave-backend',
      script: 'src/server.js',
      instances: process.env.PM2_INSTANCES || 'max', // Scale to all CPU cores
      exec_mode: 'cluster',
      env: {
        NODE_ENV: 'development',
        PORT: process.env.PORT || 5001,
        LOG_LEVEL: 'debug',
      },
      env_production: {
        NODE_ENV: 'production',
        PORT: process.env.PORT || 5000,
        LOG_LEVEL: 'info',
      },
      env_staging: {
        NODE_ENV: 'staging',
        PORT: process.env.PORT || 5000,
        LOG_LEVEL: 'info',
      },
      // Max memory before restart (prevents memory leaks)
      max_memory_restart: '512M',
      // Logging
      error_file: './logs/err.log',
      out_file: './logs/out.log',
      log_file: './logs/combined.log',
      time: true,
      // Watch for file changes in development
      watch: process.env.NODE_ENV === 'development' ? ['src'] : false,
      ignore_watch: ['node_modules', 'logs', '.git'],
      // Restart behavior
      min_uptime: '10s',
      max_restarts: 10,
      restart_delay: 5000,
      // Graceful shutdown
      kill_timeout: 10000,
      listen_timeout: 8000,
      shutdown_with_message: true,
    },
  ],
};
