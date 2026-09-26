# Aula 06 — Biblioteca de Módulos Terraform

## Visão Geral

Esta biblioteca fornece módulos Terraform reutilizáveis para provisionar infraestrutura na AWS. O objetivo é demonstrar como compor módulos independentes — cada um com responsabilidade única — para montar ambientes completos de forma consistente, sem duplicação de código.

Os módulos cobrem as quatro camadas fundamentais de uma aplicação web:

- **Rede** — VPC com subnets públicas e privadas
- **Segurança** — Security Groups configuráveis por regra
- **Computação** — Instâncias EC2
- **Dados** — Banco de dados RDS PostgreSQL

Cada ambiente (`dev`, `staging`) chama os mesmos módulos com variáveis diferentes, garantindo paridade de configuração entre ambientes.

---

## Arquitetura

Diagrama de dependências entre os módulos dentro de um ambiente:

```
┌─────────────────────────────────────────────────────┐
│                    Root Module                       │
│              (environments/dev ou staging)           │
└───────────────────────┬─────────────────────────────┘
                        │
                        ▼
              ┌─────────────────┐
              │   module "vpc"  │
              │                 │
              │  vpc_id ────────┼──────────────────┐
              │  public_subnet_ids ────────┐        │
              │  private_subnet_ids ───┐   │        │
              └─────────────────┘     │   │        │
                                      │   │        │
                        ┌─────────────┘   │        │
                        │                 │        │
                        ▼                 │        ▼
              ┌──────────────────┐        │  ┌──────────────────┐
              │ module "api_sg"  │        │  │ module "rds_sg"  │
              │                  │        │  │                  │
              │  sg_id ──────────┼──┐     │  │  sg_id ──────────┼──┐
              └──────────────────┘  │     │  └──────────────────┘  │
                                    │     │                         │
                        ┌───────────┘     │         ┌───────────────┘
                        │                 │         │
                        ▼                 ▼         ▼
              ┌──────────────────┐   ┌──────────────────────┐
              │ module           │   │ module "database"     │
              │ "api_server"     │   │                       │
              │ (EC2)            │   │ (RDS PostgreSQL)      │
              └──────────────────┘   └──────────────────────┘
```

**Fluxo de composição:**
1. `vpc` não depende de nenhum módulo — é a base
2. `api_sg` e `rds_sg` recebem `vpc_id` do `vpc`
3. `rds_sg` recebe `sg_id` do `api_sg` para restringir acesso ao banco
4. `api_server` recebe `subnet_id` do `vpc` e `sg_id` do `api_sg`
5. `database` recebe `subnet_ids` do `vpc` e `sg_id` do `rds_sg`

---

## Módulos Disponíveis

### Módulo VPC

**Descrição:** Cria uma VPC completa com subnets dinâmicas via `for_each`, Internet Gateway e route tables para subnets públicas. Subnets públicas e privadas são declaradas em um único mapa, separadas pelo campo `type`.

**Inputs:**
| Nome | Tipo | Obrigatório | Default | Descrição |
|------|------|:-----------:|---------|-----------|
| `vpc_cidr` | `string` | Sim | — | CIDR block da VPC |
| `subnets` | `map(object)` | Sim | — | Mapa de subnets com `cidr`, `az` e `type` (`"public"` ou `"private"`) |
| `project_name` | `string` | Sim | — | Nome do projeto |
| `environment` | `string` | Sim | — | Ambiente (`dev`, `staging`, `prod`) |

**Outputs:**
| Nome | Descrição |
|------|-----------|
| `vpc_id` | ID da VPC criada |
| `vpc_cidr` | CIDR block da VPC |
| `public_subnet_ids` | Mapa `nome => id` das subnets públicas |
| `private_subnet_ids` | Mapa `nome => id` das subnets privadas |
| `internet_gateway_id` | ID do Internet Gateway |

**Exemplo de uso:**
```hcl
module "vpc" {
  source       = "../../modules/vpc"
  vpc_cidr     = "10.0.0.0/16"
  project_name = "unifaat-devops"
  environment  = "dev"

  subnets = {
    "public-subnet-1"  = { cidr = "10.0.1.0/24",  az = "us-east-1a", type = "public"  }
    "public-subnet-2"  = { cidr = "10.0.2.0/24",  az = "us-east-1b", type = "public"  }
    "private-subnet-1" = { cidr = "10.0.10.0/24", az = "us-east-1a", type = "private" }
    "private-subnet-2" = { cidr = "10.0.11.0/24", az = "us-east-1b", type = "private" }
  }
}
```

---

### Módulo Security Group

**Descrição:** Módulo genérico para criação de Security Groups. Funciona para qualquer camada (API, banco de dados, bastion). As regras de ingress são declaradas como lista de objetos, tornando o módulo completamente configurável pelo chamador. Egress `0.0.0.0/0` é sempre incluído por padrão.

**Inputs:**
| Nome | Tipo | Obrigatório | Default | Descrição |
|------|------|:-----------:|---------|-----------|
| `name` | `string` | Sim | — | Nome do Security Group |
| `vpc_id` | `string` | Sim | — | ID da VPC onde o SG será criado |
| `ingress_rules` | `list(object)` | Não | `[]` | Lista de regras de entrada (ver estrutura abaixo) |
| `environment` | `string` | Sim | — | Ambiente (`dev`, `staging`, `prod`) |
| `project_name` | `string` | Sim | — | Nome do projeto |

**Estrutura de `ingress_rules`:**
```hcl
{
  description     = string         # Descrição da regra
  from_port       = number         # Porta inicial
  to_port         = number         # Porta final
  protocol        = string         # "tcp", "udp" ou "-1"
  cidr_blocks     = list(string)   # Opcional, default []
  security_groups = list(string)   # Opcional, default []
}
```

**Outputs:**
| Nome | Descrição |
|------|-----------|
| `sg_id` | ID do Security Group criado |
| `sg_name` | Nome do Security Group criado |

**Exemplo de uso:**
```hcl
module "api_sg" {
  source       = "../../modules/security-group"
  name         = "api-sg"
  vpc_id       = module.vpc.vpc_id
  project_name = "unifaat-devops"
  environment  = "dev"

  ingress_rules = [
    {
      description     = "HTTP"
      from_port       = 80
      to_port         = 80
      protocol        = "tcp"
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
    },
    {
      description     = "HTTPS"
      from_port       = 443
      to_port         = 443
      protocol        = "tcp"
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
    }
  ]
}
```

---

### Módulo EC2

**Descrição:** Provisiona uma instância EC2 com AMI, tipo, subnet e Security Groups configuráveis. Inclui volume raiz `gp3` encriptado, IMDSv2 obrigatório por padrão e suporte a `user_data` opcional para scripts de inicialização.

**Inputs:**
| Nome | Tipo | Obrigatório | Default | Descrição |
|------|------|:-----------:|---------|-----------|
| `instance_name` | `string` | Sim | — | Nome da instância (tag `Name`) |
| `ami_id` | `string` | Sim | — | ID da AMI |
| `subnet_id` | `string` | Sim | — | ID da subnet onde a instância será criada |
| `security_group_ids` | `list(string)` | Sim | — | Lista de IDs dos Security Groups |
| `instance_type` | `string` | Não | `"t2.micro"` | Tipo da instância EC2 |
| `key_name` | `string` | Não | `null` | Nome do Key Pair para acesso SSH |
| `user_data` | `string` | Não | `null` | Script de inicialização (user data) |
| `root_volume_size` | `number` | Não | `20` | Tamanho do volume raiz em GB |
| `environment` | `string` | Sim | — | Ambiente (`dev`, `staging`, `prod`) |
| `project_name` | `string` | Sim | — | Nome do projeto |

**Outputs:**
| Nome | Descrição |
|------|-----------|
| `instance_id` | ID da instância EC2 |
| `public_ip` | IP público da instância |
| `private_ip` | IP privado da instância |

**Exemplo de uso:**
```hcl
module "api_server" {
  source       = "../../modules/ec2"
  instance_name      = "unifaat-devops-dev-api"
  ami_id             = "ami-0c02fb55956c7d316"
  subnet_id          = module.vpc.public_subnet_ids["public-subnet-1"]
  security_group_ids = [module.api_sg.sg_id]
  instance_type      = "t2.micro"
  key_name           = "meu-keypair"
  project_name       = "unifaat-devops"
  environment        = "dev"
}
```

---

### Módulo RDS

**Descrição:** Provisiona uma instância RDS PostgreSQL 16.3 com DB Subnet Group nas subnets privadas. Configurado com valores sensatos para desenvolvimento: sem Multi-AZ, sem snapshot final, `apply_immediately` ativo e storage encriptado.

**Inputs:**
| Nome | Tipo | Obrigatório | Default | Descrição |
|------|------|:-----------:|---------|-----------|
| `db_name` | `string` | Sim | — | Nome do database |
| `db_username` | `string` | Sim | — | Usuário master |
| `db_password` | `string` (sensitive) | Sim | — | Senha master |
| `subnet_ids` | `list(string)` | Sim | — | IDs das subnets privadas para o DB Subnet Group |
| `security_group_ids` | `list(string)` | Sim | — | IDs dos Security Groups do RDS |
| `instance_class` | `string` | Não | `"db.t3.micro"` | Classe da instância RDS |
| `allocated_storage` | `number` | Não | `20` | Armazenamento em GB |
| `environment` | `string` | Sim | — | Ambiente (`dev`, `staging`, `prod`) |
| `project_name` | `string` | Sim | — | Nome do projeto |

**Outputs:**
| Nome | Descrição |
|------|-----------|
| `db_endpoint` | Endpoint de conexão do banco de dados |
| `db_name` | Nome do banco de dados |
| `db_port` | Porta do banco de dados (5432) |

**Exemplo de uso:**
```hcl
module "database" {
  source             = "../../modules/rds"
  db_name            = "appdb"
  db_username        = "postgres"
  db_password        = var.db_password
  subnet_ids         = values(module.vpc.private_subnet_ids)
  security_group_ids = [module.rds_sg.sg_id]
  instance_class     = "db.t3.micro"
  project_name       = "unifaat-devops"
  environment        = "dev"
}
```

---

## Como Usar — Criando um Novo Ambiente

Para criar um novo ambiente (ex: `prod`), siga os passos abaixo:

**1. Copie a estrutura de um ambiente existente:**
```bash
cp -r environments/staging environments/prod
```

**2. Atualize o `terraform.tfvars` com os valores do novo ambiente:**
```hcl
# environments/prod/terraform.tfvars
aws_region   = "us-east-1"
environment  = "prod"
project_name = "unifaat-devops"

vpc_cidr = "10.2.0.0/16"   # CIDR diferente dos outros ambientes

subnets = {
  "public-subnet-1"  = { cidr = "10.2.1.0/24",  az = "us-east-1a", type = "public"  }
  "public-subnet-2"  = { cidr = "10.2.2.0/24",  az = "us-east-1b", type = "public"  }
  "private-subnet-1" = { cidr = "10.2.10.0/24", az = "us-east-1a", type = "private" }
  "private-subnet-2" = { cidr = "10.2.11.0/24", az = "us-east-1b", type = "private" }
}

instance_type     = "t3.medium"
ami_id            = "ami-0c02fb55956c7d316"
key_name          = "prod-keypair"
db_instance_class = "db.t3.medium"
db_name           = "proddb"
db_username       = "postgres"
```

**3. Defina a senha do banco via variável de ambiente (nunca em arquivo):**
```bash
# Linux/macOS
export TF_VAR_db_password="senha-segura-aqui"

# Windows PowerShell
$env:TF_VAR_db_password = "senha-segura-aqui"
```

**4. Execute o fluxo padrão do Terraform:**
```bash
cd environments/prod

terraform init
terraform plan
terraform apply
```

**5. Para destruir o ambiente:**
```bash
terraform destroy
```

---

## Pré-requisitos

### Terraform
- Versão mínima: `>= 1.3.0` (necessário para `optional()` em variáveis de objeto)
- Download: https://developer.hashicorp.com/terraform/install

### AWS CLI
- Versão mínima: `>= 2.0`
- Configurar credenciais antes de rodar o Terraform:
```bash
aws configure
# ou via variáveis de ambiente:
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_DEFAULT_REGION="us-east-1"
```

### Permissões IAM
A conta AWS utilizada precisa de permissão para criar os seguintes recursos:

| Serviço | Ações necessárias |
|---------|-------------------|
| VPC | `ec2:CreateVpc`, `ec2:CreateSubnet`, `ec2:CreateInternetGateway`, `ec2:CreateRouteTable` |
| Security Group | `ec2:CreateSecurityGroup`, `ec2:AuthorizeSecurityGroupIngress` |
| EC2 | `ec2:RunInstances`, `ec2:DescribeInstances` |
| RDS | `rds:CreateDBInstance`, `rds:CreateDBSubnetGroup` |

### Key Pair
Para acesso SSH às instâncias EC2, crie um Key Pair na AWS antes de executar o Terraform:
```bash
aws ec2 create-key-pair \
  --key-name meu-keypair \
  --query 'KeyMaterial' \
  --output text > meu-keypair.pem

chmod 400 meu-keypair.pem
```

Em seguida, informe o nome no `terraform.tfvars`:
```hcl
key_name = "meu-keypair"
```

> **Atenção:** Nunca versione arquivos `.pem` ou `.tfvars` com senhas no repositório. Adicione-os ao `.gitignore`.
