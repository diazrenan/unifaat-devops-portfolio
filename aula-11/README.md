# Blue/Green Deployment na AWS com Terraform

Infraestrutura completa para Blue/Green Deployment em AWS Learner Lab, incluindo Application Load Balancer, Target Groups, Security Groups e automação de deploy via GitHub Actions.

## Estrutura do Projeto

```
.
├── terraform/
│   ├── provider.tf              # Configuração do provider AWS
│   ├── variables.tf             # Variáveis e inputs
│   ├── alb.tf                   # Application Load Balancer + Listener
│   ├── target-groups.tf         # Blue e Green Target Groups
│   ├── security-groups.tf       # Security Groups (ALB e EC2)
│   ├── outputs.tf               # Outputs da infraestrutura
│   └── terraform.tfvars.example # Exemplo de variáveis customizadas
│
├── .github/workflows/
│   ├── deploy-blue-green.yml    # Workflow de deploy automático
│   └── rollback.yml             # Workflow de rollback (opcional)
│
├── EXPLICACAO.md                # Documentação técnica detalhada
├── ROLLBACK.md                  # Procedimentos de rollback
└── README.md                    # Este arquivo
```

## Quick Start

### Pré-requisitos

- AWS Account (Learner Lab)
- Terraform >= 1.0
- AWS CLI configurado
- GitHub Actions ativo (para deploy automático)

### 1. Deploy da Infraestrutura

```bash
cd terraform/

# Inicializar
terraform init

# Planejar mudanças
terraform plan

# Aplicar
terraform apply
```

Após `terraform apply`, você terá:
- ✅ Application Load Balancer
- ✅ 2 Target Groups (Blue e Green)
- ✅ 2 Security Groups (ALB + EC2)
- ✅ Health checks configurados

### 2. Outputs Importantes

```bash
# Obter outputs
terraform output -json

# Saída esperada:
{
  "alb_dns_name": "blue-green-app-alb-XXXX.us-east-1.elb.amazonaws.com",
  "blue_tg_arn": "arn:aws:elasticloadbalancing:us-east-1:...",
  "green_tg_arn": "arn:aws:elasticloadbalancing:us-east-1:...",
  "listener_arn": "arn:aws:elasticloadbalancing:us-east-1:...",
  ...
}
```

### 3. Registrar Instâncias EC2

Criar instâncias EC2 e registrá-las nos target groups:

```bash
# Environment Blue (produção atual)
aws elbv2 register-targets \
  --target-group-arn $(terraform output -raw blue_tg_arn) \
  --targets Id=i-XXXXXXXXX

# Environment Green (para novo deploy)
aws elbv2 register-targets \
  --target-group-arn $(terraform output -raw green_tg_arn) \
  --targets Id=i-YYYYYYYYY
```

### 4. Testar

```bash
# Obter DNS do ALB
ALB_DNS=$(terraform output -raw alb_dns_name)

# Testar
curl http://$ALB_DNS/
```
## Arquitetura

```
Internet
   ↓
┌─────────────────────────────┐
│  ALB (Port 80, 443)         │
│  SG: 0.0.0.0/0 → 80,443     │
└────────┬────────────────────┘
         │
    ┌────┴─────┐
    ↓          ↓
┌────────────┐ ┌──────────────┐
│  Blue TG   │ │  Green TG    │
│  :3000     │ │  :3000       │
└────┬───────┘ └──────┬───────┘
     │                │
     ↓                ↓
┌────────────┐ ┌──────────────┐
│  EC2 Blue  │ │  EC2 Green   │
│  SG: 3000  │ │  SG: 3000    │
│ (ALB only) │ │ (ALB only)   │
└────────────┘ └──────────────┘
```

**Fluxo de Tráfego:**
1. Internet faz request ao ALB na porta 80/443
2. ALB redireciona para o Target Group ativo (padrão: Blue)
3. Target Group faz health checks em :3000
4. Se OK, distribui tráfego entre instâncias saudáveis

## Configurações Padrão

| Componente | Valor | Descrição |
|---|---|---|
| **ALB** | Port 80 | HTTP público |
| **Listener** | HTTP/Port 80 | Recebe tráfego internet |
| **Target Group** | Port 3000 | Porta da aplicação |
| **Health Check** | 30s interval | Checagem a cada 30 segundos |
| **Health Matcher** | 200 | Apenas HTTP 200 é OK |
| **Healthy Threshold** | 2 | 2 checks OK antes de ativar |
| **Unhealthy Threshold** | 3 | 3 checks falha antes de remover |
| **Stickiness** | 24 horas | Sessões persistem na mesma instância |

## 🔧 Customizações

### Mudar porta da aplicação

```bash
terraform apply -var="instance_port=8080"
```

### Adicionar HTTPS

```bash
# Criar certificado no ACM
# Depois adicionar em security-groups.tf e alb.tf
terraform apply
```

### Aumentar frequency de health checks

```bash
terraform apply -var="health_check_interval=15"  # 15 segundos
```

### Desabilitar stickiness

```bash
terraform apply -var="stickiness_enabled=false"
```

## Blue/Green Deployment

### Processo Típico

1. **Versão A (Blue)** está servindo 100% do tráfego
2. **Versão B (Green)** é deployada em novo environment
3. Testes são executados no Green (sem tráfego real)
4. Se OK, listener é reconfigurado: Blue → Green
5. Se problema, rollback instantâneo: Green → Blue

### Via GitHub Actions

```bash
# Fazer push para repositório com este código
# Ir para Actions → "Blue/Green Deployment"
# Clicar em "Run workflow"
# Selecionar target: blue ou green
# Deploy automático com health checks
```

### Manual via CLI

```bash
# Identificar target group ativo
aws elbv2 describe-listeners \
  --listener-arns $(terraform output -raw listener_arn) \
  --query 'Listeners[0].DefaultActions[0].TargetGroupArn'

# Fazer switch para Green
aws elbv2 modify-listener \
  --listener-arn $(terraform output -raw listener_arn) \
  --default-actions Type=forward,TargetGroupArn=$(terraform output -raw green_tg_arn)

# Verificar tráfego
curl http://$(terraform output -raw alb_dns_name)/
```

## Rollback

Em caso de problema pós-deploy:

```bash
# Identificar qual está ativo
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw green_tg_arn)

# Reverter para Blue
aws elbv2 modify-listener \
  --listener-arn $(terraform output -raw listener_arn) \
  --default-actions Type=forward,TargetGroupArn=$(terraform output -raw blue_tg_arn)
```

**Tempo de rollback:** < 30 segundos

Veja `ROLLBACK.md` para procedimentos detalhados.

## 🔐 Segurança

### Security Groups

| Componente | Inbound | Outbound |
|---|---|---|
| **ALB SG** | 80,443 from 0.0.0.0/0 | All to 0.0.0.0/0 |
| **EC2 SG** | 3000 from ALB SG only | All to 0.0.0.0/0 |

**Benefícios:**
- ✅ Instâncias não expostas diretamente
- ✅ Apenas ALB pode falar com EC2
- ✅ Fácil auditoria de acesso
- ✅ Escalável (novos SGs referenciam ALB SG)

### Best Practices Implementadas

- ✅ Tráfego HTTP com ALB (Layer 7)
- ✅ Health checks automáticos
- ✅ Stickiness opcional para sessões
- ✅ Cross-zone load balancing
- ✅ Security groups restritivos
- ✅ Default tags em todos recursos

##  Monitoramento

### CloudWatch Metrics (Adicionar depois)

```bash
# Monitorar taxa de erro
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name HTTPCode_Target_5XX_Count \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z \
  --period 300 \
  --statistics Sum
```

### Logs

Enable ALB access logs:
```hcl
# Em alb.tf
access_logs {
  bucket  = aws_s3_bucket.logs.id
  enabled = true
}
```

## Troubleshooting

### ALB não está recebendo tráfego

```bash
# 1. Verificar status dos targets
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw blue_tg_arn)

# 2. Verificar security groups
aws ec2 describe-security-groups \
  --group-ids $(terraform output -raw instance_security_group_id)

# 3. Testar manualmente
ssh ec2-user@INSTANCE_IP
curl localhost:3000
```

### Health checks falhando

```bash
# 1. Verificar logs da aplicação
ssh ec2-user@INSTANCE_IP
tail -f /var/log/app.log

# 2. Testar endpoint manualmente
curl -v http://INSTANCE_IP:3000/

# 3. Verificar se aplicação está rodando
ps aux | grep node
netstat -tlnp | grep 3000
```



