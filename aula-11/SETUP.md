# Guia de Setup - Blue/Green Deployment

Instruções passo-a-passo para configurar a infraestrutura Blue/Green na AWS Learner Lab.

## ✅ Pré-requisitos

- [x] AWS Learner Lab account ativo
- [x] Terraform instalado (versão >= 1.0)
- [x] AWS CLI v2 configurado
- [x] Chave SSH para EC2 (criar nova ou usar existente)
- [x] Git (para versionamento)
- [x] GitHub account (para automação)

### Instalações Necessárias

#### Windows (PowerShell)

```powershell
# Terraform (usando Chocolatey)
choco install terraform

# AWS CLI v2
choco install awscli

# Verificar versões
terraform --version
aws --version
```

#### macOS

```bash
# Terraform
brew install terraform

# AWS CLI
brew install awscli

# Verificar
terraform --version
aws --version
```

#### Linux

```bash
# Terraform
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# AWS CLI
sudo apt-get install awscli
# ou pip install awscliv2
```

## 🔑 Configurar AWS Credentials

### Learner Lab - Obter Credenciais

1. Acessar https://awslearner.web.internal/
2. Clicar em "AWS Learner Lab"
3. Start lab
4. Clicar em "AWS Details"
5. Copiar as credenciais (Access Key ID, Secret Access Key, Session Token)

### Configurar AWS CLI

```bash
aws configure

# Será solicitado:
AWS Access Key ID: [paste from Lab]
AWS Secret Access Key: [paste from Lab]
Default region name: us-east-1
Default output format: json
```

### Salvar Credenciais (Opcional)

```bash
# Em ~/.aws/credentials (será criado automaticamente)
# Nunca commitar isso no Git!
```

### Testar Conexão

```bash
aws sts get-caller-identity
```

Deve retornar algo como:
```json
{
    "UserId": "AIDAI...",
    "Account": "ACCOUNT_ID",
    "Arn": "arn:aws:iam::ACCOUNT_ID:user/user"
}
```

## 📁 Preparar Repositório

### 1. Clonar ou Baixar o Projeto

```bash
# Opção A: Se em um repositório Git
git clone <seu-repo>
cd aula-11

# Opção B: Se baixou como ZIP
unzip aula-11.zip
cd aula-11
```

### 2. Revisar Estrutura

```bash
tree  # ou dir /s no Windows
```

Deve ter:
```
.
├── terraform/
│   ├── *.tf files
│   └── terraform.tfvars.example
├── .github/workflows/
│   └── deploy-blue-green.yml
├── README.md
├── EXPLICACAO.md
├── ROLLBACK.md
└── SETUP.md
```

## 🚀 Deploy da Infraestrutura

### 1. Inicializar Terraform

```bash
cd terraform/

# Baixar provider AWS e inicializar backend
terraform init

# Output esperado:
# Terraform has been successfully configured!
```

### 2. Validar Configuração

```bash
# Verificar sintaxe
terraform validate

# Deve retornar:
# Success! The configuration is valid.
```

### 3. Planejar Deploy

```bash
# Ver o que será criado
terraform plan

# Output mostrará:
# Plan: 6 to add, 0 to change, 0 to destroy.
```

### 4. Aplicar Configuração

```bash
# Deploy real
terraform apply

# Será perguntado: "Do you want to perform these actions?"
# Digitar: yes

# Aguardar ~2-3 minutos
```

### 5. Obter Outputs

```bash
# Após apply, obter informações importantes
terraform output

# Ou exportar para arquivo
terraform output -json > outputs.json
```

Outputs importantes:
```
alb_dns_name = "blue-green-app-alb-XXXX.us-east-1.elb.amazonaws.com"
blue_tg_arn = "arn:aws:elasticloadbalancing:..."
green_tg_arn = "arn:aws:elasticloadbalancing:..."
listener_arn = "arn:aws:elasticloadbalancing:..."
instance_security_group_id = "sg-XXXXXXXXX"
```

## 🖥️ Criar Instâncias EC2

### Opção 1: Via AWS Console

1. Acessar EC2 Dashboard
2. Clicar em "Launch Instance"
3. Configurar:
   - **AMI:** Amazon Linux 2 (t2.micro - free tier)
   - **Instance Type:** t2.micro
   - **Security Group:** selecionar `blue-green-app-instance-sg`
   - **Tag:** Name = "blue-green-app-blue"
4. Clicar "Launch"
5. Repetir para a instância "Green"

### Opção 2: Via AWS CLI

```bash
# Obter ID do security group
INSTANCE_SG=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=blue-green-app-instance-sg" \
  --query 'SecurityGroups[0].GroupId' \
  --output text)

# Obter ID da AMI mais recente do Amazon Linux 2
AMI_ID=$(aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
  --output text)

# Criar instância Blue
BLUE_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t2.micro \
  --security-group-ids $INSTANCE_SG \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=blue-green-app-blue},{Key=Env,Value=blue}]' \
  --query 'Instances[0].InstanceId' \
  --output text)

# Criar instância Green (copiar e mudar Name/Env)
GREEN_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t2.micro \
  --security-group-ids $INSTANCE_SG \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=blue-green-app-green},{Key=Env,Value=green}]' \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "Blue Instance: $BLUE_ID"
echo "Green Instance: $GREEN_ID"
```

## 📝 Registrar Instâncias nos Target Groups

### 1. Obter ARNs

```bash
cd terraform/

BLUE_TG=$(terraform output -raw blue_tg_arn)
GREEN_TG=$(terraform output -raw green_tg_arn)

echo "Blue TG: $BLUE_TG"
echo "Green TG: $GREEN_TG"
```

### 2. Registrar Instâncias

```bash
# Assumindo IDs das instâncias
BLUE_ID="i-XXXXXXXXX"
GREEN_ID="i-YYYYYYYYY"

# Registrar Blue no Blue Target Group
aws elbv2 register-targets \
  --target-group-arn $BLUE_TG \
  --targets Id=$BLUE_ID

# Registrar Green no Green Target Group
aws elbv2 register-targets \
  --target-group-arn $GREEN_TG \
  --targets Id=$GREEN_ID
```

### 3. Verificar Health Status

```bash
# Aguardar ~1-2 minutos para health checks iniciarem

# Verificar status
aws elbv2 describe-target-health \
  --target-group-arn $BLUE_TG

aws elbv2 describe-target-health \
  --target-group-arn $GREEN_TG

# Deve mostrar TargetHealth.State = "healthy"
```

## 📦 Deployar Aplicação

### 1. SSH nas Instâncias

```bash
# Obter IPs públicos
aws ec2 describe-instances \
  --query 'Reservations[].Instances[].[InstanceId,PublicIpAddress,Tags[?Key==`Name`].Value|[0]]' \
  --output text

# Conectar (usando a chave SSH)
ssh -i /path/to/key.pem ec2-user@INSTANCE_IP
```

### 2. Instalar Node.js (Exemplo)

```bash
# Na instância SSH
sudo yum update -y
sudo yum install -y nodejs npm

# Verificar
node --version
npm --version
```

### 3. Deployar Aplicação

```bash
# Criar app simples para teste
cat > app.js << 'EOF'
const http = require('http');

const server = http.createServer((req, res) => {
  const color = process.env.APP_COLOR || 'blue';
  res.writeHead(200, {'Content-Type': 'text/html'});
  res.end(`<h1>Blue/Green Deployment</h1><p>Serving from: ${color}</p>`);
});

server.listen(3000, () => {
  console.log('Server running on port 3000');
});
EOF

# Executar com PM2 (ou outro process manager)
sudo npm install -g pm2
export APP_COLOR=blue  # ou green
pm2 start app.js --name blue-green-app
pm2 startup
pm2 save
```

### 4. Testar Saúde da Aplicação

```bash
# Na instância
curl localhost:3000

# Deve retornar HTML com "blue" ou "green"
```

## 🧪 Testar ALB

### 1. Obter DNS do ALB

```bash
cd terraform/
ALB_DNS=$(terraform output -raw alb_dns_name)
echo $ALB_DNS
```

### 2. Aguardar Health Checks

```bash
# Aguardar 1-2 minutos para health checks passarem
# Verificar status
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw blue_tg_arn)

# Deve mostrar "State": "healthy"
```

### 3. Fazer Requisição ao ALB

```bash
# Primeira requisição pode levar ~30 segundos
curl -v http://$ALB_DNS/

# Deve retornar HTML com "Serving from: blue"
```

## 🔄 Fazer Primeiro Blue/Green Switch

### Manual (via CLI)

```bash
# 1. Verificar target group ativo
LISTENER_ARN=$(terraform output -raw listener_arn)
aws elbv2 describe-listeners \
  --listener-arns $LISTENER_ARN \
  --query 'Listeners[0].DefaultActions[0].TargetGroupArn'

# 2. Fazer deploy e testes na instância Green

# 3. Switch para Green
GREEN_TG=$(terraform output -raw green_tg_arn)
aws elbv2 modify-listener \
  --listener-arn $LISTENER_ARN \
  --default-actions Type=forward,TargetGroupArn=$GREEN_TG

# 4. Validar
curl -v http://$ALB_DNS/

# Deve retornar "Serving from: green"
```

### Automático (via GitHub Actions)

1. Fazer push do código para GitHub
2. Ir para "Actions" → "Blue/Green Deployment"
3. Clicar "Run workflow"
4. Selecionar target color
5. Workflow executará automaticamente

## 🛡️ Validações Importantes

### Health Check Validação

```bash
# Verificar que health checks estão rodando
while true; do
  aws elbv2 describe-target-health \
    --target-group-arn $(terraform output -raw blue_tg_arn) \
    --query 'TargetHealthDescriptions[0]'
  sleep 5
done
```

### Tráfego Validação

```bash
# Fazer múltiplas requisições
for i in {1..10}; do
  curl -s http://$ALB_DNS/ | grep -o 'from: [a-z]*'
  echo " (requisição $i)"
done

# Todas devem retornar "blue" (ou green, dependendo do ativo)
```

## 🧹 Cleanup (Remover Recursos)

Quando terminar de testar:

```bash
# 1. Remover instâncias EC2 (opcional)
aws ec2 terminate-instances --instance-ids $BLUE_ID $GREEN_ID

# 2. Remover infraestrutura Terraform
cd terraform/
terraform destroy

# Será perguntado confirmação
# Digitar: yes

# Aguardar ~1-2 minutos para remover recursos
```

## ✅ Checklist de Setup

- [ ] AWS Learner Lab account criado
- [ ] Terraform instalado e testado
- [ ] AWS CLI configurado com credentials
- [ ] Repositório clonado/baixado
- [ ] `terraform init` executado
- [ ] `terraform plan` validado
- [ ] `terraform apply` executado com sucesso
- [ ] EC2 instances criadas e saudáveis
- [ ] Instâncias registradas nos target groups
- [ ] Health checks passando
- [ ] ALB respondendo com sucesso
- [ ] Primeiro Blue/Green switch validado
- [ ] GitHub Actions configurado (opcional)

## 🐛 Troubleshooting

### "terraform init" falha

```bash
# Verificar que AWS CLI está configurado
aws sts get-caller-identity

# Se falhar, reconfigurar
aws configure
```

### Health checks falhando

```bash
# SSH na instância e testar
ssh ec2-user@INSTANCE_IP
curl localhost:3000

# Verificar que aplicação está rodando
ps aux | grep node
netstat -tlnp | grep 3000
```

### ALB não responde

```bash
# Verificar security groups
aws ec2 describe-security-groups \
  --group-ids sg-XXXXXXXXX

# Verificar targets
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:...
```

## 📞 Próximas Etapas

1. ✅ Setup concluído
2. ⬜ Explorar Blue/Green switches
3. ⬜ Implementar automação de deploy (CodeDeploy)
4. ⬜ Adicionar Auto Scaling
5. ⬜ Configurar monitoramento (CloudWatch)
6. ⬜ Implementar canary deployments

---

**Dúvidas?** Consulte os outros documentos:
- `README.md` - Visão geral
- `EXPLICACAO.md` - Detalhes técnicos
- `ROLLBACK.md` - Procedimentos de contingência
