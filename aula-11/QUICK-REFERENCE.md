# Quick Reference - Blue/Green Deployment

Referência rápida para comandos e procedimentos comuns.

## 📋 Checklist Rápido

### Setup Inicial
```bash
# 1. Deploy infraestrutura
cd terraform/
terraform init
terraform apply

# 2. Criar instâncias EC2 (2 unidades)
# Blue: produção atual
# Green: novo deploy

# 3. Registrar nos target groups
aws elbv2 register-targets --target-group-arn $(terraform output -raw blue_tg_arn) --targets Id=i-BLUE_ID
aws elbv2 register-targets --target-group-arn $(terraform output -raw green_tg_arn) --targets Id=i-GREEN_ID

# 4. Testar
ALB_DNS=$(terraform output -raw alb_dns_name)
curl http://$ALB_DNS/
```

### Deploy Novo
```bash
# 1. Fazer deploy no Green (standby)
# 2. Rodar testes no Green
# 3. Executar script de deploy
./scripts/deploy.sh deploy
# ou
.\scripts\deploy.ps1 deploy

# 4. Validar
curl http://$ALB_DNS/
```

### Rollback
```bash
# Se problema após deploy:
./scripts/deploy.sh rollback
# ou
.\scripts\deploy.ps1 rollback

# Tempo: < 30 segundos
```

## 🔑 Comandos Terraform

```bash
# Inicializar
terraform init

# Validar
terraform validate

# Planejar
terraform plan

# Aplicar
terraform apply

# Remover (cleanup)
terraform destroy

# Obter outputs
terraform output -json

# Output específico
terraform output -raw alb_dns_name
```

## 🌐 Comandos AWS CLI

### ALB & Listeners
```bash
# Listar ALBs
aws elbv2 describe-load-balancers

# Obter detalhes do listener
aws elbv2 describe-listeners --listener-arns <LISTENER_ARN>

# Modificar listener (switch traffic)
aws elbv2 modify-listener \
  --listener-arn <LISTENER_ARN> \
  --default-actions Type=forward,TargetGroupArn=<TARGET_GROUP_ARN>
```

### Target Groups
```bash
# Listar target groups
aws elbv2 describe-target-groups

# Ver health dos targets
aws elbv2 describe-target-health --target-group-arn <TG_ARN>

# Registrar target
aws elbv2 register-targets \
  --target-group-arn <TG_ARN> \
  --targets Id=<INSTANCE_ID>

# Deregistrar target
aws elbv2 deregister-targets \
  --target-group-arn <TG_ARN> \
  --targets Id=<INSTANCE_ID>
```

### EC2 Instances
```bash
# Listar instâncias
aws ec2 describe-instances

# Obter IP público
aws ec2 describe-instances \
  --query 'Reservations[].Instances[].[InstanceId,PublicIpAddress]'

# SSH numa instância
ssh -i key.pem ec2-user@PUBLIC_IP
```

## 🔍 Troubleshooting Rápido

### ALB não respondendo
```bash
# 1. Verificar security group
aws ec2 describe-security-groups --group-ids <SG_ID>

# 2. Verificar targets
aws elbv2 describe-target-health --target-group-arn <TG_ARN>

# 3. SSH na instância
ssh -i key.pem ec2-user@INSTANCE_IP
curl localhost:3000
```

### Health checks falhando
```bash
# 1. SSH na instância
ssh -i key.pem ec2-user@INSTANCE_IP

# 2. Verificar aplicação
ps aux | grep node
netstat -tlnp | grep 3000
curl -v localhost:3000

# 3. Verificar logs
tail -f /var/log/app.log
```

### Traffic não mudando
```bash
# 1. Verificar listener
aws elbv2 describe-listeners --listener-arns <LISTENER_ARN>

# 2. Verificar target group ativo
aws elbv2 describe-listeners \
  --listener-arns <LISTENER_ARN> \
  --query 'Listeners[0].DefaultActions[0].TargetGroupArn'

# 3. Modificar manualmente
aws elbv2 modify-listener \
  --listener-arn <LISTENER_ARN> \
  --default-actions Type=forward,TargetGroupArn=<NEW_TG_ARN>
```

## 📊 Monitorar Status

### Via Scripts
```bash
# Status completo
./scripts/deploy.sh status

# Ou
.\scripts\deploy.ps1 status
```

### Via CLI
```bash
# Health dos targets
aws elbv2 describe-target-health --target-group-arn $(terraform output -raw blue_tg_arn)
aws elbv2 describe-target-health --target-group-arn $(terraform output -raw green_tg_arn)

# Target group ativo
aws elbv2 describe-listeners \
  --listener-arns $(terraform output -raw listener_arn) \
  --query 'Listeners[0].DefaultActions[0].TargetGroupArn'

# Contar targets saudáveis
aws elbv2 describe-target-health \
  --target-group-arn <TG_ARN> \
  --query 'length(TargetHealthDescriptions[?TargetHealth.State==`healthy`])'
```

## 🔧 Customizações Rápidas

### Mudar porta da aplicação
```bash
terraform apply -var="instance_port=8080"
```

### Mudar frequency de health checks
```bash
terraform apply -var="health_check_interval=15"  # 15 segundos
```

### Desabilitar stickiness
```bash
terraform apply -var="stickiness_enabled=false"
```

### Desabilitar cross-zone
```bash
# Editar alb.tf, setar:
# enable_cross_zone_load_balancing = false
terraform apply
```

## 📈 Vars Comuns

```bash
# Arquivo terraform.tfvars (exemplo)
aws_region                       = "us-east-1"
app_name                        = "blue-green-app"
instance_port                   = 3000
health_check_interval           = 30
health_check_healthy_threshold  = 2
health_check_unhealthy_threshold = 3
stickiness_enabled              = true
```

## 🎯 Blue/Green Process (Resumido)

```
ATUAL                NOVO              APÓS SWITCH
─────────────       ─────────────     ────────────
Blue    100%   →    Green   0%    →    Green  100%
(produção)          (standby)          (produção)

Green    0%         Blue   100%         Blue    0%
(standby)           (fallback)          (standby)
```

### Passo-a-Passo
1. Deploy + testes no Green (0% tráfego)
2. Health checks passam no Green
3. ALB listener muda: Blue → Green
4. Blue vira standby para rollback
5. Se problema: Green → Blue (< 30s)

## 💾 Outputs Importantes

Após `terraform apply`:

```
alb_dns_name                = "blue-green-app-alb-XXXX.us-east-1.elb.amazonaws.com"
blue_tg_arn                 = "arn:aws:elasticloadbalancing:us-east-1:ACCOUNT:targetgroup/blue-green-app-blue-tg/XXX"
green_tg_arn                = "arn:aws:elasticloadbalancing:us-east-1:ACCOUNT:targetgroup/blue-green-app-green-tg/XXX"
listener_arn                = "arn:aws:elasticloadbalancing:us-east-1:ACCOUNT:listener/app/blue-green-app-alb/XXX"
instance_security_group_id  = "sg-XXXXXXXXX"
alb_security_group_id       = "sg-YYYYYYYYY"
```

Salvar em variáveis shell:
```bash
ALB_DNS=$(terraform output -raw alb_dns_name)
BLUE_TG=$(terraform output -raw blue_tg_arn)
GREEN_TG=$(terraform output -raw green_tg_arn)
LISTENER=$(terraform output -raw listener_arn)
INSTANCE_SG=$(terraform output -raw instance_security_group_id)
```

## 🛑 Emergency Rollback

Se tudo der errado:

```bash
# 1. Voltar para Blue imediatamente
aws elbv2 modify-listener \
  --listener-arn $LISTENER \
  --default-actions Type=forward,TargetGroupArn=$BLUE_TG

# 2. Validar
curl http://$ALB_DNS/

# 3. Investigar Green
# Debug na instância Green conforme necessário
```

**Tempo total: < 1 minuto**

## 📚 Arquivos de Referência

| Arquivo | Uso |
|---------|-----|
| **README.md** | Visão geral |
| **SETUP.md** | Setup passo-a-passo |
| **EXPLICACAO.md** | Decisões técnicas |
| **ROLLBACK.md** | Procedures de contingência |
| **QUICK-REFERENCE.md** | Este arquivo |

## 🔗 Referências Úteis

- [AWS ALB Docs](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS CLI Reference](https://docs.aws.amazon.com/cli/latest/reference/)
- [Blue/Green Pattern](https://martinfowler.com/bliki/BlueGreenDeployment.html)

## ⏱️ Tempos Típicos

| Operação | Tempo |
|----------|-------|
| terraform init | 30-60s |
| terraform apply | 2-3 min |
| Health check passar | 1-2 min |
| Switch traffic | < 5s |
| Full rollback | < 30s |
| Cleanup (destroy) | 1-2 min |

## 💡 Dicas Pro

1. **Salvar outputs**: `terraform output -json > outputs.json`
2. **Reutilizar valores**: `export VAR=$(terraform output -raw var_name)`
3. **Validar antes de apply**: `terraform plan` sempre
4. **Usar scripts**: Menos erro que CLI manual
5. **Monitorar logs**: `ssh` e `tail -f` durante deploy
6. **Health check debugging**: Testar manualmente `curl localhost:3000`
7. **Stickiness atenção**: Usuários podem ficar em versão antiga por 24h

## ❓ FAQ Rápido

**P: Quanto tempo leva para fazer switch?**  
R: < 5 segundos. Propagação completa: < 30 segundos.

**P: Posso fazer rollback?**  
R: Sim, em < 30 segundos. Apenas mude o listener de volta.

**P: Preciso de 2 instâncias?**  
R: Sim, um para Blue e outro para Green.

**P: Posso usar Auto Scaling?**  
R: Sim, mas isso é futuro - por enquanto é manual.

**P: Quanto custa?**  
R: ~$16/mês (ALB) + EC2 (depende da instância).

**P: Posso usar 1 única instância?**  
R: Não é ideal para Blue/Green - seria blue/blue.

---

**Salve este documento para referência rápida!**
