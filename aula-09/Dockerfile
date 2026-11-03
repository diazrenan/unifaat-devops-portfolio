# ─────────────────────────────────────────────
# Stage 1 — deps: instala apenas prod dependencies
# ─────────────────────────────────────────────
FROM node:20-alpine AS deps

WORKDIR /app

COPY package*.json ./

RUN npm ci --omit=dev

# ─────────────────────────────────────────────
# Stage 2 — builder: compila/transpila o código
# ─────────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .

# Se o projeto tiver um step de build (ex: TypeScript), rode aqui
RUN npm run build --if-present

# ─────────────────────────────────────────────
# Stage 3 — runner: imagem final mínima
# ─────────────────────────────────────────────
FROM node:20-alpine AS runner

# Boa prática: não rodar como root
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copia dependências de produção do stage deps
COPY --from=deps /app/node_modules ./node_modules

# Copia código compilado (ou fonte) do stage builder
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/package*.json ./

# Variáveis de ambiente padrão
ENV NODE_ENV=production
ENV PORT=3000

EXPOSE 3000

USER appuser

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

CMD ["node", "dist/index.js"]
