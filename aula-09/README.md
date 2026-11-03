# TechNova API — Pipeline Completo com ECR + AI Review

Pipeline de CI/CD com build multi-stage, push para Amazon ECR e revisão automática de PRs por IA.

---

## Pré-requisitos

| Ferramenta | Versão mínima |
|------------|--------------|
| Docker     | 24+          |
| AWS CLI    | 2.x          |
| Node.js    | 20+          |
| Git        | 2.40+        |

---

## Estrutura do projeto

```
aula-09/
├── .github/
│   ├── workflows/
│   │   ├── ci.yml              # CI com push para ECR (Parte 7 — opcional)
│   │   └── ai-review.yml       # AI review automático em PRs
│   └── scripts/
│       └── ai-review.js        # Motor de análise de código
├── src/
│   └── index.ts                # Aplicação Express (TypeScript)
├── screenshots/                # Evidências obrigatórias
├── Dockerfile                  # Build multi-stage otimizado
├── .dockerignore               # Exclusões para o build
├── ecr-push.sh                 # Script principal: cria repo, login, build e push
├── tsconfig.json               # Configuração TypeScript
├── package.json
├── ia-cicd-analise.md          # Documentação da estratégia
└── README.md
```

---

## Como executar localmente

### 1. Instalar dependências

```bash
npm install
```

### 2. Rodar em desenvolvimento

```bash
npm run dev
```

A API sobe em `http://localhost:3000`.

Endpoints disponíveis:
- `GET /` — info do serviço
- `GET /health` — health check

### 3. Build TypeScript

```bash
npm run build
```

Gera os arquivos em `dist/`.

### 4. Rodar com Docker localmente

```bash
# Build da imagem
docker build -t technova-api:local .

# Executar container
docker run -p 3000:3000 technova-api:local

# Verificar health
curl http://localhost:3000/health
```

---

## Como fazer push para o Amazon ECR

### Configurar credenciais do Learner Lab

Antes de rodar o script, exporte as credenciais temporárias da sessão do AWS Academy:

```bash
export AWS_ACCESS_KEY_ID=<cole aqui>
export AWS_SECRET_ACCESS_KEY=<cole aqui>
export AWS_SESSION_TOKEN=<cole aqui>
export AWS_DEFAULT_REGION=us-east-1
```

> ⚠️ As credenciais do Learner Lab expiram a cada sessão (~4h). Sempre renove antes de executar.

### Executar o script principal

```bash
chmod +x ecr-push.sh
./ecr-push.sh
```

O script executa automaticamente:
1. Cria o repositório `technova-api` no ECR (idempotente)
2. Faz login no ECR
3. Faz build da imagem Docker multi-stage
4. Faz push com as tags:
   - `sha-XXXXXXX` — SHA curto do commit atual
   - `latest` — conveniência
   - `1.2.3`, `1.2`, `1` — semver (quando existe uma git tag `v*.*.*`)

### Push com tag semver

Para gerar as tags semver, crie uma git tag no padrão `v*.*.*` antes de rodar o script:

```bash
git tag v1.0.0
./ecr-push.sh
```

---

## AI Review em PRs

O workflow `.github/workflows/ai-review.yml` é acionado automaticamente em pull requests.

### O que ele detecta

| Severidade | Padrão detectado                          |
|------------|-------------------------------------------|
| CRITICAL   | Secrets hardcoded (API keys, tokens, senhas) |
| CRITICAL   | SQL injection (queries com concatenação)  |
| CRITICAL   | `eval()` com input externo                |
| WARNING    | `console.log` em código de produção       |
| WARNING    | Blocos `catch` vazios                     |
| INFO       | Outros code smells                        |

### Quality Gate

- **CRITICAL encontrado** → workflow falha → PR bloqueado  
- **WARNING / INFO apenas** → workflow passa → PR pode ser mergeado

---

## Evidências (screenshots)

Coloque na pasta `screenshots/`:

| Arquivo                  | Conteúdo esperado                                      |
|--------------------------|--------------------------------------------------------|
| `ecr-console.png`        | Repositório `technova-api` no console ECR com as tags  |
| `ai-review-comment.png`  | Comentário de AI review postado em um PR               |
| `ecr-push-ok.png`        | Execução do `ecr-push.sh` concluída (ou CI verde)      |
| `quality-gate-block.png` | PR bloqueado por finding CRITICAL                      |

---

## Linting

```bash
npm run lint
```

---

## Testes

```bash
npm test
```
