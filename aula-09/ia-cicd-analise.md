# Análise: Pipeline CI/CD com Amazon ECR e AI Review
**TechNova API — Aula 09**

---

## 1. Por que Amazon ECR como registry?

### 1.1 Comparativo de opções

| Critério | Amazon ECR | GitHub Container Registry (ghcr.io) | Docker Hub |
|---|---|---|---|
| **Integração com AWS** | Nativa — IAM, ECS, EKS, Lambda sem configuração extra | Requer credenciais externas | Requer credenciais externas |
| **Latência** | Mínima — imagem e infra na mesma região AWS | Depende da rede | Depende da rede |
| **Custo** | Pay-per-use (armazenamento + transferência) | Gratuito para repos públicos | Free tier limitado |
| **Autenticação** | Token temporário via `get-login-password` (expira em 12h) | PAT permanente ou GITHUB_TOKEN | Token permanente |
| **Scanning de vulnerabilidades** | Nativo com `scanOnPush=true` (via Amazon Inspector) | Básico via Dependabot | Somente plano pago |
| **Controle de acesso** | IAM policies granulares | Permissões de repo GitHub | Teams Docker Hub |

### 1.2 Decisão: ECR

A TechNova já opera sua infraestrutura na AWS. Usar o ECR elimina o problema de autenticação cross-cloud: o ECS/EKS/Lambda da AWS já tem acesso nativo ao ECR via IAM role, sem expor credenciais adicionais. A imagem trafega dentro da própria rede AWS (VPC → ECR), reduzindo latência e custos de egress.

### 1.3 Restrições do AWS Academy Learner Lab

O Learner Lab impõe limitações importantes que influenciaram a implementação:

| Restrição | Impacto | Solução adotada |
|---|---|---|
| **Credenciais expiram a cada sessão (~4h)** | CI/CD convencional com credenciais permanentes não funciona | `ecr-push.sh` local é o fluxo confiável; `ci.yml` é opcional/documentado |
| **Não é possível criar usuários/grupos/roles IAM** | Impossível criar um "deploy user" com permissões mínimas | Usamos as credenciais de sessão diretamente |
| **Sem `aws_session_token` → auth falha** | O token de sessão é obrigatório além de key/secret | O script valida com `sts get-caller-identity` antes de prosseguir |
| **Quota de recursos limitada** | ECR, compute e storage têm limites de lab | Pipeline enxuto, sem artefatos desnecessários |

**Fluxo confiável no Learner Lab:**
```
Abrir sessão Lab → copiar credenciais → export → ./ecr-push.sh
```

O `ci.yml` funciona desde que os 3 secrets sejam atualizados no GitHub a cada sessão. É viável para demonstração, mas não para produção contínua.

---

## 2. Estratégia de tagging

### 2.1 As três camadas de tags

```
sha-a3f9c21   ← rastreabilidade exata (imutável)
latest        ← conveniência para ambientes de desenvolvimento
1.2.3         ← versão exata (semver)
1.2           ← "última patch desta minor"
1             ← "última versão desta major"
```

### 2.2 Por que cada tag existe

**`sha-XXXXXXX` (SHA curto do commit)**
- Imutável: sempre aponta para exatamente o mesmo código
- Essencial para debugging em produção — você sabe exatamente qual commit está rodando
- Gerado via `git rev-parse --short HEAD` (7 chars)
- Fallback para timestamp se executado fora de um repositório git

**`latest`**
- Convenção universal do ecossistema Docker
- Útil em ambientes de desenvolvimento local (`docker pull technova-api`)
- **Nunca deve ser a única tag em produção** — não é rastreável
- Sempre aponta para o último push de `main`/`master`

**Tags semver (`1.2.3`, `1.2`, `1`)**
- Criadas apenas quando existe uma git tag `v*.*.*` exata no commit atual
- `1.2.3` → versão exata, para deploys determinísticos em produção
- `1.2` → "me dê a última patch da minor 1.2" — útil para atualizações automáticas de segurança dentro da mesma minor
- `1` → "me dê a última versão da major 1" — útil para ambientes que aceitam atualizações não-breaking

### 2.3 Quando usar cada tag

| Ambiente | Tag recomendada | Motivo |
|---|---|---|
| Produção | `sha-XXXXXXX` ou `1.2.3` | Determinístico, auditável |
| Staging | `1.2` | Recebe patches automáticos |
| Desenvolvimento | `latest` | Sempre atualizado |
| Rollback | `sha-XXXXXXX` | Precisão total |

### 2.4 Fluxo de criação de tags semver

```bash
# Quando pronto para release:
git tag v1.2.3
git push origin v1.2.3

# Localmente com o script:
./ecr-push.sh
# → push: sha-abc1234, latest, 1.2.3, 1.2, 1

# Via CI (ci.yml):
# git push --tags → dispara o job build-and-push automaticamente
```

---

## 3. Padrões que o AI Review verifica

O script `.github/scripts/ai-review.js` analisa apenas as **linhas adicionadas** no diff (linhas com `+`) de arquivos `.ts`, `.js`, `.tsx`, `.jsx`. Código removido não é analisado.

### 3.1 Findings CRITICAL (bloqueiam o PR)

| ID | Descrição | Exemplo detectado |
|---|---|---|
| `HARDCODED_SECRET` | Senha, token ou chave de API com valor literal | `const apiKey = "sk-abc123xyz"` |
| `AWS_ACCESS_KEY` | Padrão `AKIA` de AWS Access Key ID | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_KEY` | AWS Secret Access Key com valor literal | `aws_secret_key = "wJalrXUtn..."` |
| `SQL_INJECTION` | Query SQL montada com concatenação de input de request | `` "SELECT * FROM users WHERE id = " + req.params.id `` |
| `SQL_INJECTION_TEMPLATE` | Query SQL em template literal com interpolação de request | `` `SELECT * FROM users WHERE id = ${req.params.id}` `` |
| `EVAL_USAGE` | Uso de `eval()` — execução de código arbitrário | `eval(userInput)` |
| `EVAL_FUNCTION_CONSTRUCTOR` | `new Function()` — equivalente a eval | `new Function('return ' + code)()` |
| `EXEC_SHELL_INJECTION` | exec/spawn com input externo concatenado | `exec('ls ' + req.body.path)` |

### 3.2 Findings WARNING (não bloqueiam, mas devem ser revisados)

| ID | Descrição | Exemplo detectado |
|---|---|---|
| `CONSOLE_LOG` | `console.log()` em código de produção | `console.log(user.password)` |
| `EMPTY_CATCH` | Bloco catch vazio — erro silenciado | `catch (e) {}` |
| `TODO_FIXME` | Marcadores de código incompleto | `// TODO: validar input antes do release` |
| `DEBUGGER_STATEMENT` | Instrução debugger esquecida | `debugger;` |
| `WEAK_RANDOM` | `Math.random()` em contexto de segurança | `const token = Math.random().toString(36)` |

### 3.3 Findings INFO (informativos, não bloqueiam)

| ID | Descrição | Exemplo detectado |
|---|---|---|
| `ANY_TYPE` | Uso de tipo `any` em TypeScript | `function process(data: any)` |
| `CONSOLE_ERROR_WARN` | `console.error/warn` em produção | `console.error('falhou')` |
| `HARDCODED_URL` | URL de serviço externo no código | `const API = "https://api.pagamento.com"` |

---

## 4. Lógica de análise (prompt/algoritmo)

O AI Review **não usa um modelo de linguagem externo**. A análise é feita por um motor de regras baseado em expressões regulares aplicadas ao diff. Essa decisão foi intencional:

### 4.1 Por que regex em vez de LLM?

| Critério | Regex (adotado) | LLM externo |
|---|---|---|
| **Custo** | Zero | API paga (OpenAI, Claude, etc.) |
| **Determinismo** | 100% — mesma entrada, mesma saída | Não determinístico |
| **Latência** | < 1s | 5–30s por análise |
| **Dados externos** | Código não sai do repositório | Código enviado para terceiros |
| **Falsos positivos** | Controlável ajustando os padrões | Difícil de calibrar |
| **Auditabilidade** | Regras legíveis no código | Caixa preta |

Para um pipeline acadêmico que roda em repositório público, enviar código para APIs externas seria um risco desnecessário. As regras regex cobrem os casos críticos do exercício com precisão suficiente.

### 4.2 Fluxo do algoritmo

```
PR aberto/atualizado
       ↓
git diff base..head (apenas arquivos JS/TS)
       ↓
parseDiff() → extrai linhas adicionadas (+) com file e lineNumber
       ↓
Para cada linha × cada regra:
  - aplica fileFilter (se existir)
  - testa pattern (RegExp)
  - se casa → cria finding {ruleId, severity, file, line, snippet}
       ↓
formatComment() → gera Markdown com tabela de resumo + detalhes
       ↓
Posta/atualiza comentário no PR via GitHub API
       ↓
Quality Gate:
  CRITICAL > 0 → exit 1 → workflow falha → PR bloqueado
  CRITICAL = 0 → exit 0 → workflow passa → PR liberado para review humano
```

### 4.3 Lógica de decisão do Quality Gate

```
findings:
  CRITICAL ≥ 1  →  workflow: failure  →  PR: bloqueado
  WARNING  ≥ 1  →  workflow: success  →  PR: pode mergear (com atenção)
  INFO     ≥ 1  →  workflow: success  →  PR: pode mergear
  (nenhum)      →  workflow: success  →  PR: pode mergear
```

A severidade CRITICAL agrupa apenas vulnerabilidades de segurança direta (injection, credenciais expostas, execução de código arbitrário) — situações onde mergear sem corrigir representa risco real e imediato.

---

## 5. Quando confiar na IA vs quando exigir review humano

### 5.1 Confie na análise automática para

- **Bloquear o óbvio**: secrets hardcoded, eval(), SQL injection por concatenação são padrões claros. Se o detector apontou, há um problema real.
- **Sinalizar débito técnico**: TODO/FIXME, console.log, catch vazio são indicadores de código que precisa atenção antes do merge.
- **Screening inicial**: o AI review é uma primeira linha de defesa, não uma revisão completa. Reduz o trabalho do revisor humano ao filtrar problemas mecânicos.

### 5.2 Sempre exija review humano para

| Situação | Por quê a IA não é suficiente |
|---|---|
| Lógica de negócio complexa | O script não entende contexto — uma regra de desconto pode parecer correta sintaticamente mas estar errada semanticamente |
| Mudanças em autenticação/autorização | Falsos negativos são críticos aqui. O regex não cobre todos os vetores de bypass de auth |
| Refactorings grandes | A análise é por linha individual — não enxerga o impacto sistêmico de uma mudança arquitetural |
| Código criptográfico | Implementações criptográficas custom precisam de especialista, não de regex |
| Performance e escalabilidade | Fora do escopo da análise estática por padrões |
| Conflitos de merge | O diff pode não representar o estado final do código após resolução de conflito |

### 5.3 Regra prática

> A IA review bloqueia o que é **objetivamente errado**. O revisor humano julga o que é **subjetivamente correto**.

---

## 6. Limitações identificadas

### 6.1 Falsos positivos conhecidos

| Situação | Exemplo | Causa |
|---|---|---|
| Comentários de código | `// Nunca use: password = "hardcoded"` | O regex não ignora comentários |
| Strings em testes | `expect(query).toBe("SELECT * FROM...")` | Arquivo de teste não é filtrado |
| Documentação em código | `/** @example eval("código") */` | JSDoc não é excluído |
| URLs em constantes de config | `const DOCS_URL = "https://docs.minha-api.com"` | Qualquer URL externa dispara INFO |
| `console.log` em scripts de seed/migration | Arquivo de seed usa log para progresso | fileFilter só exclui por extensão, não por caminho |

### 6.2 Falsos negativos conhecidos (o que o detector NÃO pega)

| Vulnerabilidade | Por quê escapa |
|---|---|
| SQL injection com ORM customizado | O regex conhece padrões comuns mas não todos os ORMs |
| Secrets em variáveis com nomes incomuns | `const x = "sk-abc123"` — sem nome semântico não dispara |
| Prototype pollution | Requer análise de fluxo de dados, não regex |
| SSRF (Server-Side Request Forgery) | Padrão muito variado para regex simples |
| Lógica de autorização incorreta | Problema semântico, não sintático |
| Dependências vulneráveis | Fora do escopo — use `npm audit` ou Dependabot |

### 6.3 Limitações de contexto

O script analisa **linhas individuais** do diff. Isso significa:

- Não enxerga o contexto de 10 linhas acima/abaixo
- Não rastreia o fluxo de variáveis entre funções
- Não entende se uma variável `query` foi sanitizada antes de ser usada na linha detectada
- Uma variável chamada `password` pode ser apenas um nome de campo de formulário, não uma credencial

### 6.4 Mitigações recomendadas

```
Análise estática (este script)     → falsos positivos: médio | cobertura: básica
+
ESLint com plugins de segurança    → falsos positivos: baixo  | cobertura: média
(eslint-plugin-security, sonarjs)
+
SAST dedicado (Snyk, Semgrep)      → falsos positivos: baixo  | cobertura: alta
+
Review humano                      → falsos positivos: zero   | cobertura: total
```

A stack ideal usa o AI review como triagem rápida e barata, complementada por ferramentas especializadas e revisão humana para mudanças sensíveis.

---

## 7. Screenshots obrigatórios

Adicione as evidências na pasta `screenshots/`:

| Arquivo | O que deve mostrar |
|---|---|
| `ecr-console.png` | Console AWS ECR → repositório `technova-api` → aba "Images" com as tags `sha-XXXXXXX`, `latest` e semver (`1.x.x`, `1.x`, `1`) visíveis |
| `ai-review-comment.png` | Um PR no GitHub com o comentário do bot mostrando findings detectados (ao menos um CRITICAL ou WARNING) |
| `ecr-push-ok.png` | Terminal com a saída do `ecr-push.sh` chegando até "ecr-push.sh concluído com sucesso" — ou print do CI verde |
| `quality-gate-block.png` | Um PR com o check "Quality Gate" marcado como ❌ (failed) no GitHub, com o motivo CRITICAL visível |

### Como gerar o cenário do quality gate (para o screenshot)

Crie um branch de teste com código intencionalmente problemático:

```bash
git checkout -b test/quality-gate-demo
```

Adicione em qualquer arquivo `.ts`:

```typescript
// TESTE — remover após screenshot
const apiKey = "sk-abc123xyz456";          // dispara HARDCODED_SECRET (CRITICAL)
const query  = "SELECT * FROM users WHERE id = " + req.params.id; // SQL_INJECTION (CRITICAL)
```

Abra um PR desse branch para `main` → o AI review falhará com 2 findings CRITICAL.

Após o screenshot, feche o PR sem mergear e delete o branch.

---

## Referências

- [Amazon ECR — User Guide](https://docs.aws.amazon.com/AmazonECR/latest/userguide/what-is-ecr.html)
- [aws-actions/configure-aws-credentials](https://github.com/aws-actions/configure-aws-credentials)
- [aws-actions/amazon-ecr-login](https://github.com/aws-actions/amazon-ecr-login)
- [Semantic Versioning 2.0.0](https://semver.org/)
- [OWASP Top 10 — Injection](https://owasp.org/Top10/A03_2021-Injection/)
- [CWE-798 — Use of Hard-coded Credentials](https://cwe.mitre.org/data/definitions/798.html)
