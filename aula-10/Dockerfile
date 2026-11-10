# =============================================================================
# Stage 1 — deps: instala APENAS dependências de produção
# =============================================================================
FROM node:20-alpine AS deps

WORKDIR /app

COPY technova-api/package.json ./

# ci garante instalação determinística (usa package-lock.json se existir)
RUN npm install --omit=dev --ignore-scripts

# =============================================================================
# Stage 2 — builder: copia código-fonte (sem node_modules de dev)
# =============================================================================
FROM node:20-alpine AS builder

WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY technova-api/src ./src
COPY technova-api/package.json ./

# =============================================================================
# Stage 3 — runner: imagem final mínima para produção
# =============================================================================
FROM node:20-alpine AS runner

# Cria usuário não-root para segurança
RUN addgroup -g 1001 -S nodejs && \
    adduser  -u 1001 -S technova -G nodejs

WORKDIR /app

# Copia apenas o necessário do stage builder
COPY --from=builder --chown=technova:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=technova:nodejs /app/src         ./src
COPY --from=builder --chown=technova:nodejs /app/package.json ./

USER technova

ENV NODE_ENV=production
ENV PORT=3000

EXPOSE 3000

# Health check nativo do Docker (usado pelo ECR e orquestradores)
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

CMD ["node", "src/index.js"]
