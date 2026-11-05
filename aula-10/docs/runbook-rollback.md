# Runbook de Rollback — TechNova API

**Serviço:** technova-api  
**Infraestrutura:** EC2 (us-east-1) + Amazon ECR  
**Maintainer:** Time DevOps TechNova  
**Última revisão:** Novembro/2026

---

## Quando usar este runbook

Use este procedimento quando:

- O deploy mais recente passou no health check mas está causando erros em produção
- A nova versão apresenta regressão de funcionalidade identificada após o deploy
- O pipeline de CD está quebrado e é necessário voltar manualmente para uma versão estável
- Há necessidade de reverter a infraestrutura Terraform para um estado anterior

---

## Informações necessárias antes de começar

Colete estas informações antes de iniciar o rollback:

```
IP da EC2:         ________________________
Usuário SSH:       ec2-user
Caminho da chave:  ________________________  (ex: ~/chave-lab.pem)
ECR Registry:      <account-id>.dkr.ecr.us-east-1.amazonaws.com
Repositório ECR:   technova-api
Tag estável:       ________________________  (ex: a3f8c12)
Porta da app:      3000
```

---

## Opção A — Rollback via GitHub Actions (preferencial)

Este método é o mais seguro pois repete exatamente o mesmo pipeline que foi validado anteriormente.

**Pré-requisito:** as credenciais AWS nos GitHub Secrets ainda devem estar válidas (Lab ativo).

1. Acesse o repositório GitHub
2. Clique em **Actions** → **CD Pipeline**
3. Localize na lista a execução correspondente à versão estável (identifique pelo SHA do commit)
4. Clique nessa execução → botão **Re-run all jobs**
5. Acompanhe os 4 jobs: lint → test → build-push → deploy
6. Confirme que o job **deploy** termina com `✅ Health check PASSOU`

**Tempo estimado:** 3–5 minutos

---

## Opção B — Rollback manual via SSH

Use quando o GitHub Actions não estiver disponível ou as credenciais do Lab expiraram.

### Passo 1 — Conectar na EC2

```bash
chmod 400 chave-lab.pem
ssh -i chave-lab.pem ec2-user@<IP-DA-EC2>
```

### Passo 2 — Configurar credenciais AWS na EC2

As credenciais são necessárias para autenticar no ECR (registry privado).  
Obtenha os valores em **AWS Academy → AWS Details → AWS CLI**.

```bash
aws configure set aws_access_key_id     "ASIA..."
aws configure set aws_secret_access_key "..."
aws configure set aws_session_token     "..."
aws configure set region                "us-east-1"

# Validar que as credenciais funcionam
aws sts get-caller-identity
```

Saída esperada:
```json
{
    "UserId": "...",
    "Account": "123456789012",
    "Arn": "arn:aws:sts::123456789012:assumed-role/..."
}
```

### Passo 3 — Autenticar no ECR

> **Este passo é obrigatório.** Sem ele, o `docker pull` falha com `no basic auth credentials`.

```bash
REGISTRY=$(aws ecr get-authorization-token \
  --region us-east-1 \
  --query 'authorizationData[0].proxyEndpoint' \
  --output text | sed 's|https://||')

echo "Registry: ${REGISTRY}"

aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin "${REGISTRY}"
```

Saída esperada: `Login Succeeded`

### Passo 4 — Listar imagens disponíveis no ECR

```bash
aws ecr list-images \
  --repository-name technova-api \
  --region us-east-1 \
  --query 'imageIds[?imageTag!=`null`].imageTag' \
  --output table
```

Identifique a tag da versão estável (ex: `a3f8c12`).  
A tag `latest` aponta sempre para o último deploy — **não use para rollback**.

### Passo 5 — Executar o rollback (estratégia Recreate)

```bash
# Substitua <SHA-ESTAVEL> pela tag identificada no Passo 4
SHA_ESTAVEL="a3f8c12"
IMAGE_URI="${REGISTRY}/technova-api:${SHA_ESTAVEL}"

echo "=== Iniciando rollback para: ${IMAGE_URI} ==="

# Para e remove o container atual
docker stop technova-app && docker rm technova-app

# Baixa a versão estável
docker pull "${IMAGE_URI}"

# Sobe o container com a versão estável
docker run -d \
  --name technova-app \
  --restart unless-stopped \
  -p 3000:3000 \
  -e NODE_ENV=production \
  -e PORT=3000 \
  -e APP_VERSION="${SHA_ESTAVEL}" \
  "${IMAGE_URI}"

echo "=== Container iniciado. Aguardando warm-up (15s) ==="
sleep 15
```

### Passo 6 — Validar o health check

```bash
HTTP_STATUS=$(curl -s -o /tmp/health.json -w "%{http_code}" \
  http://localhost:3000/health)

echo "HTTP Status: ${HTTP_STATUS}"
cat /tmp/health.json

# Validação automática
if [ "${HTTP_STATUS}" = "200" ]; then
  echo "✅ Rollback CONCLUÍDO com sucesso — versão: ${SHA_ESTAVEL}"
else
  echo "❌ Health check FALHOU — verifique os logs abaixo"
  docker logs --tail 50 technova-app
  exit 1
fi
```

Saída esperada do health check:
```json
{
  "status": "ok",
  "service": "technova-api",
  "timestamp": "2026-11-05T20:00:00.000Z",
  "version": "a3f8c12"
}
```

### Passo 7 — Verificar que o container reinicia automaticamente

```bash
docker inspect technova-app \
  --format '{{.HostConfig.RestartPolicy.Name}}'
# Esperado: unless-stopped
```

---

## Rollback de Infraestrutura Terraform

Use quando for necessário reverter uma mudança de infraestrutura (ex: Security Group errado aplicado).

### Via GitHub Actions

1. No repositório, acesse o **histórico de commits** na `main`
2. Identifique o commit do estado estável
3. Crie uma branch `hotfix/rollback-infra` a partir desse commit
4. Abra um PR para `main` — o `terraform-plan.yml` mostrará o diff de reversão
5. Após revisão, faça o merge — o `terraform-apply.yml` aplica o rollback

### Via CLI (emergência)

```bash
# Na sua máquina local, com Terraform instalado
cd terraform/

# Configura credenciais AWS
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."
export AWS_DEFAULT_REGION="us-east-1"

terraform init

# Visualiza o estado atual vs o desejado
terraform plan

# Aplica (somente em emergência — quebra o princípio GitOps)
terraform apply
```

> ⚠️ O apply manual via CLI cria **drift** entre o Git e o estado real da AWS.  
> Após a emergência, commite as mudanças necessárias e execute o pipeline normalmente para sincronizar o estado.

---

## Checklist pós-rollback

- [ ] Health check retornando HTTP 200
- [ ] Verificar logs do container: `docker logs technova-app`
- [ ] Confirmar versão correta no health check (`version` no JSON)
- [ ] Notificar o time sobre o rollback realizado
- [ ] Abrir issue no repositório descrevendo o motivo do rollback
- [ ] Investigar a causa raiz antes de tentar um novo deploy

---

## Contatos de Emergência

| Responsável | Papel | Contato |
|-------------|-------|---------|
| _(seu nome)_ | DevOps | _(email/slack)_ |

---

## Histórico de Rollbacks

| Data | Versão revertida | Versão restaurada | Motivo | Responsável |
|------|-----------------|-------------------|--------|-------------|
| _(preencher após uso)_ | | | | |
