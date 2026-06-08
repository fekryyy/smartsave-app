const fs = require('fs');
const path = require('path');

const logDir = path.join(__dirname, '../../logs');
if (!fs.existsSync(logDir)) {
  fs.mkdirSync(logDir, { recursive: true });
}

const levels = {
  error: 0,
  warn: 1,
  info: 2,
  debug: 3,
};

class Logger {
  constructor() {
    this.level = process.env.LOG_LEVEL || 'debug';
    this.logFile = path.join(logDir, 'app.log');
    this.errorLogFile = path.join(logDir, 'error.log');
  }

  formatMessage(level, message) {
    const timestamp = new Date().toISOString();
    return `[${timestamp}] [${level.toUpperCase()}] ${message}`;
  }

  writeToFile(file, message) {
    try {
      fs.appendFileSync(file, message + '\n');
    } catch (err) {
      console.error('Failed to write log:', err);
    }
  }

  log(level, message) {
    if (levels[level] > levels[this.level]) return;
    const formatted = this.formatMessage(level, message);
    console.log(formatted);
    if (level === 'error') {
      this.writeToFile(this.errorLogFile, formatted);
    }
    this.writeToFile(this.logFile, formatted);
  }

  error(message) { this.log('error', message); }
  warn(message) { this.log('warn', message); }
  info(message) { this.log('info', message); }
  debug(message) { this.log('debug', message); }
}

module.exports = new Logger();
