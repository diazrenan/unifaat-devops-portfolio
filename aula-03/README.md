# Aula 03 — Terraform + IAM Completo

## Identificação

* **Aluno:** Renan Dias
* **RA:** 6325033
* **Disciplina:** DevOps - UniFAAT 2026-2
* **Aula:** 03
* **Projeto:** TechNova — IAM com Terraform

## 1. Objetivo

Este projeto implementa uma estrutura completa de gerenciamento de identidades e acessos (IAM) para a TechNova utilizando Terraform.

A infraestrutura foi organizada com grupos, usuários, políticas de menor privilégio, uma Service Role para instâncias EC2 e um Instance Profile.

Todos os recursos utilizam o RA do aluno em seus nomes para evitar conflitos com recursos criados por outros alunos.

## 2. Arquitetura IAM

Foram definidos dois grupos:

### Developers

Grupo destinado aos desenvolvedores da TechNova.

Possui acesso de leitura aos buckets e objetos S3 relacionados à TechNova.

Usuários:

* `6325033-juliana-dev`
* `6325033-rafael-platform`
* `6325033-lucas-intern`

### Platform Engineering

Grupo destinado aos profissionais responsáveis pela infraestrutura.

Possui permissões para consultar instâncias EC2, iniciar e parar instâncias da TechNova e realizar operações de leitura e escrita no S3.

Usuário:

* `6325033-rafael-platform`

A separação por grupos evita que as permissões sejam configuradas individualmente em cada usuário e facilita a administração dos acessos.

## 3. Políticas

Foram criadas três políticas customizadas.

### 3.1 S3 Read

Política:

`6325033-technova-s3-read`

Permite somente:

* `s3:GetObject`
* `s3:ListBucket`

O acesso é limitado aos recursos cujo nome segue o padrão `technova-*`.

Essa política é associada ao grupo Developers.

### 3.2 EC2 + S3 Full

Política:

`6325033-technova-ec2-s3-full`

Permite:

* consultar informações de instâncias EC2;
* consultar tags das instâncias;
* iniciar instâncias;
* parar instâncias;
* ler objetos S3;
* gravar objetos S3;
* listar buckets S3.

As ações de Start e Stop da EC2 possuem uma condição baseada na tag:

`Project = TechNova`

Dessa forma, o usuário não pode iniciar ou parar indiscriminadamente qualquer instância fora do escopo definido para a TechNova.

Essa política é associada ao grupo Platform Engineering.

### 3.3 Deny Destructive

Política:

`6325033-technova-deny-destructive`

Possui uma negação explícita para ações destrutivas:

* `s3:Delete*`
* `ec2:Terminate*`

A política é associada ao grupo Developers como uma camada adicional de proteção.

## 4. Princípio do menor privilégio

O princípio do menor privilégio determina que cada usuário ou serviço deve receber somente as permissões necessárias para executar suas funções.

Neste projeto, isso é aplicado de diferentes formas.

### Exemplo 1 — Developers

Os desenvolvedores recebem somente:

```text
s3:GetObject
s3:ListBucket
```

Eles não recebem permissões gerais de administração do S3.

### Exemplo 2 — EC2 com condição de tag

As operações:

```text
ec2:StartInstances
ec2:StopInstances
```

possuem uma condição que exige:

```text
Project = TechNova
```

Assim, as permissões são restringidas aos recursos identificados como pertencentes ao projeto.

### Por que não utilizar AmazonS3FullAccess?

A política gerenciada `AmazonS3FullAccess` concederia permissões muito mais amplas do que as necessárias para os desenvolvedores.

Isso aumentaria o impacto de um erro ou comprometimento de uma credencial, pois o usuário poderia executar operações de escrita, exclusão e outras ações em recursos S3 que não fazem parte de sua função.

A utilização de políticas customizadas permite controlar exatamente quais ações são necessárias.

## 5. Diagrama de permissões

### Usuários e grupos

```text
Juliana ────────┐
                │
Rafael ─────────┼──> Developers ──> S3 Read
                │                    │
Lucas ──────────┘                    └──> Deny Destructive

Rafael ───────────────> Platform Engineering
                              │
                              └──> EC2 + S3
```

### Service Role

```text
EC2
 │
 ▼
Instance Profile
 │
 ▼
SEURA-technova-ec2-role
 │
 ├── Trust Policy
 │       │
 │       └── ec2.amazonaws.com
 │
 └── S3 Access
         │
         ├── GetObject
         ├── PutObject
         └── ListBucket
```

## 6. Terraform

A infraestrutura é definida como código utilizando Terraform.

Comandos principais utilizados:

```bash
terraform init
```

Inicializa o projeto e instala o provider da AWS.

```bash
terraform validate
```

Verifica se a configuração Terraform está sintaticamente correta.

```bash
terraform fmt
```

Padroniza a formatação dos arquivos `.tf`.

```bash
terraform plan
```

Apresenta quais recursos serão criados, modificados ou destruídos antes da execução.

```bash
terraform apply
```

Aplica a infraestrutura na AWS.

```bash
terraform destroy
```

Remove os recursos criados durante o laboratório.

## 7. Organização dos arquivos

```text
aula-03/
├── .gitignore
├── main.tf
├── policies.tf
├── providers.tf
├── roles.tf
├── variables.tf
├── outputs.tf
├── terraform-plan-output.txt
└── README.md
```

### Responsabilidade dos arquivos

* `providers.tf` — configuração do Terraform e provider AWS.
* `main.tf` — usuários, grupos e memberships.
* `policies.tf` — políticas IAM e seus attachments.
* `roles.tf` — Service Role, política de confiança e Instance Profile.
* `variables.tf` — variáveis reutilizáveis do projeto.
* `outputs.tf` — informações exibidas após a execução.
* `terraform-plan-output.txt` — evidência do Terraform Plan.
* `README.md` — documentação do projeto.
* `.gitignore` — proteção contra envio de arquivos temporários e estado do Terraform.

## 8. Tags

Os recursos utilizam as seguintes tags:

```text
Project    = TechNova
ManagedBy  = Terraform
Aluno      = Renan Dias
RA         = 6325033
Disciplina = DevOps - UniFAAT 2026-2
Aula       = 03
```

As tags permitem identificar a finalidade dos recursos, o responsável pela criação e a atividade acadêmica relacionada.

## 9. AWS Academy Learner Lab

A execução do laboratório deve ser realizada no ambiente AWS Academy Learner Lab.

Antes da execução, é necessário verificar se as credenciais temporárias do laboratório estão configuradas corretamente no ambiente utilizado pelo Terraform.

## 10. Reflexão — AWS Console x Terraform

A criação manual de usuários, grupos, políticas e roles pelo AWS Console pode ser adequada para tarefas pequenas, porém torna-se mais difícil de controlar conforme a infraestrutura cresce.

Com Terraform, a infraestrutura fica declarada como código, permitindo visualizar exatamente quais permissões e recursos foram definidos.

O Terraform também facilita a revisão por Pull Request, versionamento no Git e auditoria das alterações.

Para este projeto, o Terraform é mais seguro e auditável porque as mudanças podem ser revisadas antes da aplicação e ficam registradas no histórico do repositório.

Além disso, a infraestrutura pode ser reproduzida de forma consistente, reduzindo erros de configuração manual.

## 11. Conclusão

O projeto demonstra a utilização de IAM com Terraform seguindo o princípio do menor privilégio.

A estrutura utiliza grupos para organização das permissões, políticas customizadas para limitar os acessos, condições para restringir operações sobre recursos específicos e uma negação explícita para ações destrutivas.

Também foi implementada uma Service Role para permitir que instâncias EC2 acessem recursos S3 por meio de um Instance Profile, sem necessidade de armazenar credenciais AWS diretamente na instância.
