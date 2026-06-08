/**
 * AI Provider Configuration
 *
 * Supports OpenAI (GPT-5, GPT-4, GPT-3.5), Claude, and DeepSeek.
 * Configure via environment variables:
 *   AI_PROVIDER    = "openai" | "claude" | "deepseek"
 *   AI_API_KEY     = your API key
 *   AI_MODEL       = model name (e.g. gpt-4o, claude-sonnet-4, deepseek-chat)
 *   AI_TEMPERATURE = 0.0–1.0 (default 0.3 for financial accuracy)
 *   AI_MAX_TOKENS  = max response tokens (default 4096)
 */

const config = {
  // Provider: 'openai', 'claude', or 'deepseek'
  provider: process.env.AI_PROVIDER || 'openai',

  // API keys
  openaiApiKey: process.env.AI_API_KEY || process.env.OPENAI_API_KEY || '',
  claudeApiKey: process.env.CLAUDE_API_KEY || '',
  deepseekApiKey: process.env.DEEPSEEK_API_KEY || '',

  // Models
  openaiModel: process.env.AI_MODEL || process.env.OPENAI_MODEL || 'gpt-4o',
  claudeModel: process.env.CLAUDE_MODEL || 'claude-sonnet-4-20250514',
  deepseekModel: process.env.DEEPSEEK_MODEL || 'deepseek-chat',

  // Generation parameters
  temperature: parseFloat(process.env.AI_TEMPERATURE || '0.3'),
  maxTokens: parseInt(process.env.AI_MAX_TOKENS || '4096', 10),

  // Rate limiting
  maxRetries: parseInt(process.env.AI_MAX_RETRIES || '3', 10),
  retryDelayMs: parseInt(process.env.AI_RETRY_DELAY_MS || '1000', 10),

  // Endpoints
  openaiBaseUrl: process.env.OPENAI_BASE_URL || 'https://api.openai.com/v1',
  claudeBaseUrl: process.env.CLAUDE_BASE_URL || 'https://api.anthropic.com/v1',
  deepseekBaseUrl: process.env.DEEPSEEK_BASE_URL || 'https://api.deepseek.com/v1',

  // Is AI configured?
  get isConfigured() {
    if (this.provider === 'openai') return !!this.openaiApiKey;
    if (this.provider === 'claude') return !!this.claudeApiKey;
    if (this.provider === 'deepseek') return !!this.deepseekApiKey;
    return false;
  },
};

module.exports = config;
