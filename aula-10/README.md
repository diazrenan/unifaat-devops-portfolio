# TechNova — Aula 10: GitOps com Terraform + CI/CD

## Pré-requisitos

- Conta AWS Academy Learner Lab ativa
- Repositório GitHub com os seguintes **Secrets** configurados:
  | Secret | Origem |
  |--------|--------|
  | `AWS_ACCESS_KEY_ID` | AWS Academy → AWS Details → AWS CLI |
  | `AWS_SECRET_ACCESS_KEY` | idem |
  | `AWS_SESSION_TOKEN` | idem |

> ⚠️ As credenciais do Learner Lab expiram a cada sessão (~4h). Atualize os secrets antes de cada execução.

## Estrutura

```
.github/workflows/
  terraform-plan.yml   # Plan automático em PRs (Req. 1)
  terraform-apply.yml  # Apply automático no merge (Req. 2)
  cd.yml               # Pipeline CD completo (Req. 3)
terraform/
  provider.tf          # Provider AWS + backend S3
  main.tf              # VPC, Subnet, EC2, Security Group
  variables.tf         # Variáveis
  outputs.tf           # Outputs
  terraform.tfvars     # Valores padrão
```

## Setup inicial (uma vez)

### 1. Criar bucket S3 para o estado Terraform

```bash
# Substitua <ACCOUNT_ID> pelo ID da sua conta AWS Academy
aws s3 mb s3://technova-tfstate-<ACCOUNT_ID> --region us-east-1

aws s3api put-bucket-versioning \
  --bucket technova-tfstate-<ACCOUNT_ID> \
  --versioning-configuration Status=Enabled
```

Atualize o nome do bucket em `terraform/provider.tf` → bloco `backend "s3"`.

### 2. Configurar Branch Protection no GitHub

Em **Settings → Branches → Branch protection rules** para `main`:
- ✅ Require status checks to pass before merging
- ✅ Status check: `Terraform Plan`
- ✅ Require branches to be up to date before merging

## Fluxo GitOps

```
feature/branch  →  PR para main  →  terraform-plan.yml executa
                                   └── Comentário com plan no PR
                                   └── PR bloqueado se plan falhar

merge para main  →  terraform-apply.yml executa
                    └── terraform apply automático
                    └── Outputs disponíveis no log
```

## Como reproduzir

1. Clone o repositório
2. Configure os secrets no GitHub
3. Crie o bucket S3 e atualize `provider.tf`
4. Crie uma branch `feature/infra-inicial`
5. Faça qualquer alteração em `terraform/`
6. Abra um PR para `main`
7. Observe o comentário do plan ser postado automaticamente
8. Faça o merge e observe o apply automático
