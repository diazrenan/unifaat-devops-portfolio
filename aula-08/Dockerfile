# ─────────────────────────────────────────────
# Stage 1: dependencies
# ─────────────────────────────────────────────
FROM node:20-alpine AS deps

WORKDIR /app

# Copia apenas os arquivos de manifesto para aproveitar cache de camadas
COPY package*.json ./

# Instala somente dependências de produção
RUN npm ci --omit=dev

# ─────────────────────────────────────────────
# Stage 2: final image
# ─────────────────────────────────────────────
FROM node:20-alpine AS final

# Boa prática: não rodar como root
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copia dependências instaladas no stage anterior
COPY --from=deps /app/node_modules ./node_modules

# Copia o código fonte
COPY src/ ./src/
COPY package.json ./

# Define o usuário não-root
USER appuser

# Expõe porta padrão (documentação)
EXPOSE 3000

# Healthcheck básico
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD node -e "require('./src/utils')" || exit 1

# Comando de inicialização
CMD ["node", "src/index.js"]
