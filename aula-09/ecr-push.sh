#!/usr/bin/env bash
# =============================================================================
# ecr-push.sh — Build & Push para Amazon ECR
# TechNova API | Aula 09 — Pipeline Completo
#
# Uso:
#   ./ecr-push.sh
#
# Pré-requisitos:
#   - AWS CLI v2 configurado (variáveis de ambiente ou ~/.aws/credentials)
#   - Docker em execução
#   - Credenciais do AWS Academy Learner Lab exportadas:
#       export AWS_ACCESS_KEY_ID=...
#       export AWS_SECRET_ACCESS_KEY=...
#       export AWS_SESSION_TOKEN=...
#       export AWS_DEFAULT_REGION=us-east-1
# =============================================================================

set -euo pipefail

# ─── Cores para output ────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()    { echo -e "\n${CYAN}══ $* ══${NC}"; }

# ─── Configurações ────────────────────────────────────────────────────────────
REPO_NAME="technova-api"
REGION="${AWS_DEFAULT_REGION:-us-east-1}"

# ─── Validações iniciais ──────────────────────────────────────────────────────
log_step "Validando pré-requisitos"

if ! command -v aws &>/dev/null; then
  log_error "AWS CLI não encontrado. Instale: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
  exit 1
fi
log_success "AWS CLI: $(aws --version 2>&1 | head -1)"

if ! command -v docker &>/dev/null; then
  log_error "Docker não encontrado. Instale: https://docs.docker.com/get-docker/"
  exit 1
fi
log_success "Docker: $(docker --version)"

if ! docker info &>/dev/null; then
  log_error "Docker daemon não está em execução. Inicie o Docker Desktop ou o serviço."
  exit 1
fi
log_success "Docker daemon: running"

# Verifica se as credenciais AWS estão funcionando
if ! aws sts get-caller-identity &>/dev/null; then
  log_error "Credenciais AWS inválidas ou expiradas."
  log_error "No Learner Lab: clique em 'AWS Details' → copie e exporte:"
  log_error "  export AWS_ACCESS_KEY_ID=..."
  log_error "  export AWS_SECRET_ACCESS_KEY=..."
  log_error "  export AWS_SESSION_TOKEN=..."
  exit 1
fi

# ─── Obtém Account ID dinamicamente ──────────────────────────────────────────
log_step "Identificando conta AWS"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
log_success "Account ID: ${ACCOUNT_ID}"
log_info    "Região: ${REGION}"

ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
ECR_REPO_URI="${ECR_REGISTRY}/${REPO_NAME}"
log_info "Registry: ${ECR_REGISTRY}"

# ─── Step 1: Cria repositório ECR (idempotente) ───────────────────────────────
log_step "Step 1 — Criando/verificando repositório ECR"

if aws ecr describe-repositories \
     --repository-names "${REPO_NAME}" \
     --region "${REGION}" &>/dev/null; then
  log_warn "Repositório '${REPO_NAME}' já existe — pulando criação."
else
  log_info "Criando repositório '${REPO_NAME}'..."
  aws ecr create-repository \
    --repository-name "${REPO_NAME}" \
    --region "${REGION}" \
    --image-scanning-configuration scanOnPush=true \
    --image-tag-mutability MUTABLE \
    --output table
  log_success "Repositório criado com sucesso."
fi

# ─── Step 2: Login no ECR ─────────────────────────────────────────────────────
log_step "Step 2 — Autenticando no ECR"

aws ecr get-login-password --region "${REGION}" \
  | docker login \
      --username AWS \
      --password-stdin \
      "${ECR_REGISTRY}"

log_success "Login no ECR realizado."

# ─── Step 3: Determina tags ───────────────────────────────────────────────────
log_step "Step 3 — Determinando tags da imagem"

# Tag SHA curto (7 chars) — rastreável ao commit exato
if git rev-parse --short HEAD &>/dev/null 2>&1; then
  SHORT_SHA=$(git rev-parse --short HEAD)
  TAG_SHA="sha-${SHORT_SHA}"
  log_success "Tag SHA: ${TAG_SHA}"
else
  log_warn "Não foi possível obter o SHA do git. Usando timestamp como fallback."
  TAG_SHA="sha-$(date +%Y%m%d%H%M%S)"
fi

# Tag latest — conveniência
TAG_LATEST="latest"
log_success "Tag latest: ${TAG_LATEST}"

# Tags semver — a partir de git tag v*.*.*
SEMVER_TAGS=()
GIT_TAG=""

if git describe --tags --exact-match HEAD 2>/dev/null | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+$'; then
  GIT_TAG=$(git describe --tags --exact-match HEAD 2>/dev/null)
  VERSION="${GIT_TAG#v}"          # Remove o 'v' → ex: 1.2.3
  MAJOR=$(echo "${VERSION}" | cut -d. -f1)
  MINOR=$(echo "${VERSION}" | cut -d. -f1-2)

  SEMVER_TAGS=("${VERSION}" "${MINOR}" "${MAJOR}")
  log_success "Tags semver detectadas: ${SEMVER_TAGS[*]}"
else
  log_warn "Nenhuma git tag semver encontrada no commit atual."
  log_warn "Para gerar tags semver: git tag v1.0.0 && ./ecr-push.sh"
fi

# ─── Step 4: Build da imagem ──────────────────────────────────────────────────
log_step "Step 4 — Build da imagem Docker (multi-stage)"

LOCAL_IMAGE="${REPO_NAME}:build-${TAG_SHA}"

docker build \
  --tag "${LOCAL_IMAGE}" \
  --label "git.sha=${TAG_SHA}" \
  --label "git.tag=${GIT_TAG:-untagged}" \
  --label "build.date=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --label "build.repo=${REPO_NAME}" \
  .

log_success "Imagem construída: ${LOCAL_IMAGE}"

# ─── Step 5: Tag e Push ───────────────────────────────────────────────────────
log_step "Step 5 — Tagging e Push para ECR"

# Agrupa todas as tags
ALL_TAGS=("${TAG_SHA}" "${TAG_LATEST}" "${SEMVER_TAGS[@]}")

PUSHED_TAGS=()

for TAG in "${ALL_TAGS[@]}"; do
  REMOTE_URI="${ECR_REPO_URI}:${TAG}"
  log_info "Tagueando → ${REMOTE_URI}"
  docker tag "${LOCAL_IMAGE}" "${REMOTE_URI}"

  log_info "Fazendo push → ${REMOTE_URI}"
  docker push "${REMOTE_URI}"
  log_success "Push concluído: ${TAG}"
  PUSHED_TAGS+=("${TAG}")
done

# ─── Resumo final ─────────────────────────────────────────────────────────────
log_step "Resumo"

echo -e "${GREEN}"
echo "  Repositório : ${ECR_REPO_URI}"
echo "  Tags enviadas:"
for T in "${PUSHED_TAGS[@]}"; do
  echo "    ✓  ${ECR_REPO_URI}:${T}"
done
echo -e "${NC}"

log_info "Para verificar no console ECR:"
log_info "  https://console.aws.amazon.com/ecr/repositories/${REPO_NAME}?region=${REGION}"
log_success "ecr-push.sh concluído com sucesso."
