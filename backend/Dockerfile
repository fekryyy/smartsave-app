# ─────────────────────────────────────────────────────────────
# SmartSave Backend — Multi-stage Docker Build
# ─────────────────────────────────────────────────────────────

# ---- Stage 1: Install dependencies ----
FROM node:20-alpine AS deps
WORKDIR /app

# Install only production dependencies first (caching layer)
COPY package.json package-lock.json* ./
RUN npm ci --only=production --ignore-scripts && \
    npm cache clean --force

# ---- Stage 2: Build / prepare ----
FROM node:20-alpine AS builder
WORKDIR /app

# Copy production node_modules from deps stage
COPY --from=deps /app/node_modules ./node_modules
COPY package.json ./
COPY src/ ./src/

# ---- Stage 3: Production runtime ----
FROM node:20-alpine AS runner
WORKDIR /app

# Create non-root user for security
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 smartsave

# Copy application code
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/src ./src
COPY --from=builder /app/package.json ./

# Create logs directory
RUN mkdir -p /app/logs && chown -R smartsave:nodejs /app

USER smartsave

EXPOSE 5000

ENV NODE_ENV=production \
    PORT=5000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:5000/api/health || exit 1

CMD ["node", "src/server.js"]
