# Plano de Rollback — Blue/Green Deployment

## Visão Geral

Em Blue/Green o rollback é uma operação de **redirecionamento de tráfego**, não de código. A instância Blue continua rodando a versão anterior durante todo o deploy do Green, tornando a reversão quase instantânea. O comando central é um único `aws elbv2 modify-listener`.

---

## Critérios que Indicam Necessidade de Rollback

Acione o rollback imediatamente se **qualquer um** dos itens abaixo for verdadeiro após o switch de tráfego:

### Sinais Críticos — Rollback Imediato (< 5 min)

| # | Critério | Como verificar |
|---|----------|---------------|
| 1 | Taxa de erros HTTP 5xx > 1% nos primeiros 5 minutos | CloudWatch → `HTTPCode_Target_5XX_Count` |
| 2 | Health check do TG Green reporta targets `unhealthy` | `aws elbv2 describe-target-health` |
| 3 | Latência P99 aumentou > 3× em relação à baseline do Blue | CloudWatch → `TargetResponseTime` |
| 4 | Container da aplicação parou ou entrou em crash loop | `docker ps` / `docker logs app` na instância Green |
| 5 | Smoke test retorna HTTP diferente de 2xx/3xx | `curl -s -o /dev/null -w "%{http_code}" http://ALB_DNS/` |
| 6 | Funcionalidade crítica de negócio está quebrada | Teste manual / monitoramento sintético |

### Sinais de Alerta — Decisão em até 15 min

| # | Critério | Como verificar |
|---|----------|---------------|
| 7 | Taxa de erros HTTP 4xx aumentou > 10× | CloudWatch → `HTTPCode_Target_4XX_Count` |
| 8 | Memória ou CPU da instância Green > 90% sustentado | CloudWatch → EC2 metrics |
| 9 | Logs mostram exceptions ou panics não esperados | `docker logs app --since 5m` |
| 10 | Dependência externa (banco, cache, API) está falhando apenas no Green | Comparar logs Blue vs Green |

---

## Janela de Decisão

```
Deploy concluído
      │
      ├─── 0 a 5 min ──► Monitoramento intensivo obrigatório
      │                   Critérios críticos (1-6) → rollback IMEDIATO
      │
      ├─── 5 a 15 min ──► Monitoramento ativo
      │                   Critérios de alerta (7-10) → avaliar e decidir
      │
      └─── > 15 min ────► Se estável, encerrar observação
                          Arquivar métricas baseline para próximo deploy
```

> **Regra prática:** se após 15 minutos você ainda está em dúvida sobre a saúde do Green, faça o rollback. O custo de reverter é zero; o custo de deixar um problema ativo não é.

---

## Comando de Rollback (Green → Blue)

### Passo 1 — Obter os ARNs necessários

Se você tiver o Terraform local:

```bash
cd terraform/

LISTENER_ARN=$(terraform output -raw listener_arn)
BLUE_TG_ARN=$(terraform output -raw blue_tg_arn)

echo "Listener : $LISTENER_ARN"
echo "Blue TG  : $BLUE_TG_ARN"
```

Ou via AWS CLI diretamente:

```bash
# Listar listener ARN pelo nome do ALB
LISTENER_ARN=$(aws elbv2 describe-listeners \
  --load-balancer-arn $(aws elbv2 describe-load-balancers \
    --names "blue-green-app-alb" \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text) \
  --query 'Listeners[0].ListenerArn' \
  --output text)

# Listar ARN do Target Group Blue pelo nome
BLUE_TG_ARN=$(aws elbv2 describe-target-groups \
  --names "blue-green-app-blue-tg" \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)
```

### Passo 2 — Executar o rollback

```bash
aws elbv2 modify-listener \
  --listener-arn "$LISTENER_ARN" \
  --default-actions Type=forward,TargetGroupArn="$BLUE_TG_ARN"
```

Resposta esperada (JSON com o listener atualizado):

```json
{
    "Listeners": [
        {
            "ListenerArn": "arn:aws:elasticloadbalancing:us-east-1:...",
            "DefaultActions": [
                {
                    "Type": "forward",
                    "TargetGroupArn": "arn:aws:...blue-green-app-blue-tg/..."
                }
            ]
        }
    ]
}
```

### Passo 3 — Confirmar que o rollback foi aplicado

```bash
# Verificar qual TG está ativo no listener
aws elbv2 describe-listeners \
  --listener-arns "$LISTENER_ARN" \
  --query 'Listeners[0].DefaultActions[0].TargetGroupArn' \
  --output text
```

O ARN retornado deve conter `blue-tg`.

### Passo 4 — Validar saúde do Blue

```bash
# Confirmar que todos os targets Blue estão healthy
aws elbv2 describe-target-health \
  --target-group-arn "$BLUE_TG_ARN" \
  --query 'TargetHealthDescriptions[*].{Instance:Target.Id,State:TargetHealth.State}' \
  --output table
```

### Passo 5 — Teste HTTP final

```bash
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --names "blue-green-app-alb" \
  --query 'LoadBalancers[0].DNSName' \
  --output text)

curl -s -o /dev/null -w "HTTP %{http_code} — %{time_total}s\n" "http://$ALB_DNS/"
```

Resultado esperado: `HTTP 200 — 0.XXXs`

**Tempo total do rollback (passos 2 a 5): < 2 minutos.**

---

## Rollback via GitHub Actions

Se preferir não usar o terminal local, dispare o workflow manualmente:

1. GitHub → aba **Actions**
2. Selecionar **Blue/Green Deployment** na lista
3. Clicar **Run workflow**
4. Preencher `image_tag` com a tag da versão Blue anterior (ex: SHA do último commit estável)
5. O job de rollback do pipeline reverte automaticamente o listener em caso de falha de health check

---

## Checklist Pós-Rollback

### Imediato (dentro dos primeiros 30 minutos)

- [ ] Confirmar que o Listener aponta para o Blue TG
- [ ] Confirmar que todos os targets Blue estão `healthy`
- [ ] Validar que o smoke test HTTP retorna 200
- [ ] Verificar que a taxa de erros 5xx voltou ao nível pré-deploy
- [ ] Notificar o time / stakeholders que o rollback foi executado

### Coleta de Evidências (1 a 2 horas após rollback)

- [ ] **Logs do container Green** — coletar antes que a instância seja desligada:
  ```bash
  ssh -i key.pem ec2-user@GREEN_HOST \
    "docker logs app --since 2h 2>&1" > logs/green-$(date +%Y%m%d-%H%M%S).log
  ```
- [ ] **Logs do ALB** — habilitar no S3 se ainda não estiver ativo:
  ```bash
  # Ver access logs (se habilitado)
  aws s3 ls s3://SEU-BUCKET-DE-LOGS/alb/
  ```
- [ ] **Métricas CloudWatch** — exportar dashboard do período do incidente (5 min antes e 15 min depois do switch)
- [ ] **Output do health check** — salvar o resultado do `describe-target-health` no momento da falha
- [ ] **Variáveis de ambiente e imagem** — registrar exatamente qual tag e imagem estava no container Green:
  ```bash
  ssh -i key.pem ec2-user@GREEN_HOST "docker inspect app --format '{{.Config.Image}}'"
  ```

### Postmortem (até 48 horas após o incidente)

- [ ] Criar documento de postmortem com estrutura mínima:

  ```
  ## Postmortem — Deploy Green [DATA]

  ### Resumo
  [1 parágrafo descrevendo o que aconteceu]

  ### Linha do Tempo
  - HH:MM  Deploy iniciado
  - HH:MM  Switch de tráfego executado
  - HH:MM  Primeiro sinal de problema detectado
  - HH:MM  Decisão de rollback tomada
  - HH:MM  Rollback executado
  - HH:MM  Serviço estabilizado

  ### Causa Raiz
  [Descrição técnica da causa]

  ### Impacto
  - Usuários afetados: X%
  - Duração do impacto: Y minutos
  - Erros registrados: Z

  ### O Que Funcionou Bem
  - [ex: rollback foi executado em < 2 min]

  ### O Que Pode Melhorar
  - [ações concretas com responsável e prazo]

  ### Ações de Acompanhamento
  - [ ] [Ação 1] — responsável — prazo
  - [ ] [Ação 2] — responsável — prazo
  ```

- [ ] Revisar se os critérios de rollback desta documentação precisam ser atualizados com base no que foi aprendido
- [ ] Atualizar testes automatizados para cobrir o cenário que causou a falha
- [ ] Validar se o pipeline de CI/CD precisa de gates adicionais (testes de integração, smoke tests pré-switch)

---

## Referência Rápida

```
PROBLEMA DETECTADO
       │
       ▼
Executar rollback (< 2 min):
  aws elbv2 modify-listener \
    --listener-arn "$LISTENER_ARN" \
    --default-actions Type=forward,TargetGroupArn="$BLUE_TG_ARN"
       │
       ▼
Confirmar health do Blue:
  aws elbv2 describe-target-health --target-group-arn "$BLUE_TG_ARN"
       │
       ▼
Testar HTTP:
  curl -s -o /dev/null -w "%{http_code}" http://ALB_DNS/
       │
       ▼
Coletar logs do Green e abrir postmortem
```
